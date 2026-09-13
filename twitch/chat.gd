class_name TwitchChat extends Node

enum ChatState { DISCONNECTED, CONNECTING, CONNECTED }

signal message_received(player: Player, message: String)
signal chat_state_changed(state: ChatState)

const IRC_URL := "wss://irc-ws.chat.twitch.tv:443"
## Fixed. Backoff only earns its keep over minutes, and MAX_ATTEMPTS already
## bounds the whole retry window to ~15s.
const RETRY_DELAY := 3.0
## Bounds a dead-token loop. Twitch rate-limits repeated failed auth, so
## retrying forever digs the hole deeper. Five tries, then stay down.
const MAX_ATTEMPTS := 5
## Godot's own liveness mechanism: the peer sends WebSocket ping control frames
## at this interval. At the default of 0 it sends none, so an idle socket never
## writes — and TCP only learns a peer is gone when a write fails. Without this,
## a pulled cable leaves the socket at STATE_OPEN indefinitely and the close
## check below never fires.
const HEARTBEAT_INTERVAL := 10.0

var chat_state: ChatState = ChatState.DISCONNECTED

var _socket := WebSocketPeer.new()
var _access_token: String = ""
var _user_login: String = ""
var _handshake_sent: bool = false
var _last_ready_state := WebSocketPeer.STATE_CLOSED
var _attempts := 0
var _retry_countdown := 0.0

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if _retry_countdown > 0.0:
		_retry_countdown -= delta
		if _retry_countdown <= 0.0:
			_open_socket()
		return
	_poll_socket()

func connect_to_chat(access_token: String, user_login: String) -> void:
	_access_token = access_token
	_user_login = user_login
	_attempts = 0
	set_process(true)
	_open_socket()

## A fresh peer per attempt. Reusing a closed WebSocketPeer is documented as
## allowed but has been unreliable across 4.x, and a new one costs nothing.
func _open_socket() -> void:
	_attempts += 1
	_handshake_sent = false
	_socket = WebSocketPeer.new()
	_socket.heartbeat_interval = HEARTBEAT_INTERVAL
	_last_ready_state = WebSocketPeer.STATE_CONNECTING
	_set_chat_state(ChatState.CONNECTING)
	if _socket.connect_to_url(IRC_URL) != OK:
		_on_connection_lost("connect_to_url refused")

## Manual recovery from the give-up state. MAX_ATTEMPTS stops the retry loop so
## a dead token cannot hammer Twitch's auth rate limit; this is the way back in
## without restarting. Ignored unless we have actually given up, so a stray
## click cannot tear down a working connection or restart a pending retry.
## Also ignored with no token — nothing to reconnect with.
func retry() -> void:
	if chat_state != ChatState.DISCONNECTED or _access_token.is_empty():
		return
	_attempts = 0
	set_process(true)
	_open_socket()

func _poll_socket() -> void:
	_socket.poll()
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not _handshake_sent:
		_send_handshake()

	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet().get_string_from_utf8()
		for line in packet.split("\r\n", false):
			_handle_line(line)

	# A drop is the transition into CLOSED, not the raw value — the socket also
	# reads CLOSED before the first connect, which would fire a false drop.
	# Checked after the packet drain so the last lines before a close still land.
	if state == WebSocketPeer.STATE_CLOSED and _last_ready_state != WebSocketPeer.STATE_CLOSED:
		_on_connection_lost("close code %d" % _socket.get_close_code())
	_last_ready_state = state

## Fire and forget. The handshake going out says nothing about whether Twitch
## accepted the token, so CONNECTED is set on the 001 welcome, not here.
func _send_handshake() -> void:
	_handshake_sent = true
	_socket.send_text("PASS oauth:%s" % _access_token)
	_socket.send_text("NICK %s" % _user_login)
	_socket.send_text("CAP REQ :twitch.tv/tags")
	_socket.send_text("JOIN #%s" % _user_login)

func _on_connection_lost(reason: String) -> void:
	_handshake_sent = false
	if _attempts >= MAX_ATTEMPTS:
		push_warning("Twitch chat - gave up after %d attempts (%s)" % [_attempts, reason])
		_set_chat_state(ChatState.DISCONNECTED)
		set_process(false)
		return
	push_warning("Twitch chat - lost (%s), retry %d/%d in %.0fs" % [
		reason, _attempts + 1, MAX_ATTEMPTS, RETRY_DELAY])
	_set_chat_state(ChatState.CONNECTING)
	_retry_countdown = RETRY_DELAY

func _set_chat_state(state: ChatState) -> void:
	if chat_state == state:
		return
	chat_state = state
	chat_state_changed.emit(state)

func _handle_line(line: String) -> void:
	if line.begins_with("PING"):
		_socket.send_text("PONG :tmi.twitch.tv")
	elif line.contains("PRIVMSG"):
		_parse_chat_line(line)
	elif line.contains(" 001 "):
		# Welcome. Only now is the token known good, so only now does the
		# attempt counter reset. Resetting on handshake-sent instead would let
		# a dead token retry forever.
		_attempts = 0
		_set_chat_state(ChatState.CONNECTED)
	elif line.contains("RECONNECT"):
		# Twitch cycling a server. Close and let the retry path handle it.
		# Sits below the PRIVMSG branch so chat text cannot reach it.
		_socket.close()
	else:
		print("Twitch chat - IRC: ", line)

func _parse_chat_line(line: String) -> void:
	var tags := {}
	var rest := line

	if line.begins_with("@"):
		var split_idx := line.find(" ")
		tags = _parse_tags(line.substr(1, split_idx - 1))
		rest = line.substr(split_idx + 1)
	
	var player := Player.make(tags.get("user-id", ""), tags.get("display-name", _user_from(rest)))
	message_received.emit(player, _message_from(rest))

func _parse_tags(raw: String) -> Dictionary:
	var tags := {}
	for pair in raw.split(";"):
		var kv := pair.split("=", true, 1)
		if kv.size() == 2:
			tags[kv[0]] = kv[1]
	return tags

func _user_from(rest: String) -> String:
	return rest.get_slice("!", 0).lstrip(":")

func _message_from(rest: String) -> String:
	var colon_idx := rest.find(" :", rest.find("PRIVMSG"))
	return rest.substr(colon_idx + 2) if colon_idx != -1 else ""
