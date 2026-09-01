class_name TwitchChat extends Node

signal message_received(player: Player, message: String)

const IRC_URL := "wss://irc-ws.chat.twitch.tv:443"

var _socket := WebSocketPeer.new()
var _access_token: String = ""
var _user_login: String = ""
var _handshake_sent: bool = false

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	_poll_socket()

func connect_to_chat(access_token: String, user_login: String) -> void:
	_access_token = access_token
	_user_login = user_login
	_socket.connect_to_url(IRC_URL)
	set_process(true)

func _poll_socket() -> void:
	_socket.poll()

	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not _handshake_sent:
		_send_handshake()

	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet().get_string_from_utf8()
		for line in packet.split("\r\n", false):
			_handle_line(line)

func _send_handshake() -> void:
	_handshake_sent = true
	_socket.send_text("PASS oauth:%s" % _access_token)
	_socket.send_text("NICK %s" % _user_login)
	_socket.send_text("CAP REQ :twitch.tv/tags")
	_socket.send_text("JOIN #%s" % _user_login)

func _handle_line(line: String) -> void:
	if line.begins_with("PING"):
		_socket.send_text("PONG :tmi.twitch.tv")
	elif line.contains("PRIVMSG"):
		_parse_chat_line(line)
	else:
		print("IRC: ", line)

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
