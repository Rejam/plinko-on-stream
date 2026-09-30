extends Node

const CLIENT_ID := "4nycp3krnclb23fk6san5za367vezq"
const REDIRECT_PORT := 3000
const SCOPES := [
	"chat:read",
	#"bits:read",
	#"channel:read:subscriptions",
	#"channel:read:redemptions"
]

# --- PUBLIC SIGNALS (the game listens to these) ---
signal login_completed(user_login: String)
signal login_failed
signal entry_received(player: TwitchPlayer, raw_column: String)
signal chat_state_changed(state: TwitchChat.ChatState)
#signal reward_redeemed(user: String, reward_title: String, user_input: String)

# --- PUBLIC STATE ---
var access_token: String = ""
var user_id: String = ""
var user_login: String = ""
var is_logged_in: bool = false

var _auth: TwitchAuth
var _chat: TwitchChat
#var _eventsub: TwitchEventSub

func _ready() -> void:
	# Keep sockets alive even if game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	_auth = TwitchAuth.new()
	add_child(_auth)
	_auth.login_completed.connect(_on_login_completed)
	_auth.login_failed.connect(login_failed.emit)
	_chat = TwitchChat.new()
	add_child(_chat)
	_chat.message_received.connect(_on_chat_message)
	_chat.chat_state_changed.connect(chat_state_changed.emit)
	#
	#_eventsub = TwitchEventSub.new()
	#add_child(_eventsub)
	#_eventsub.redemption_received.connect(_on_redemption)


## Login happens on the title screen, so anything in game.tscn is created after
## chat has already connected and has missed the emit. Read the state instead of
## assuming DISCONNECTED.
func chat_state() -> TwitchChat.ChatState:
	return _chat.chat_state


## Manual reconnect, for the connection indicator's click handler.
func retry_chat() -> void:
	_chat.retry()


func start_login() -> void:
	_auth.start_login(CLIENT_ID, REDIRECT_PORT, SCOPES)


## Logs out: stops chat and deletes the saved token, so the next
## start_login() opens the browser.
func disconnect_account() -> void:
	_chat.disconnect_from_chat()
	_auth.clear_saved_login()
	access_token = ""
	user_id = ""
	user_login = ""
	is_logged_in = false


## Same for a browser login and a saved login.
func _on_login_completed(token: String, id: String, login: String) -> void:
	access_token = token
	user_id = id
	user_login = login
	is_logged_in = true

	_chat.connect_to_chat(token, login)
	#_eventsub.init(token, id, CLIENT_ID)
	login_completed.emit(login)


func _on_chat_message(player: TwitchPlayer, message: String) -> void:
	var parts := message.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var command := parts[0]
	var raw_column := parts[1] if parts.size() > 1 else ""
	if command.to_lower() == "!plinko":
		submit_entry(player, raw_column)


func submit_entry(player: TwitchPlayer, raw_column: String) -> void:
	entry_received.emit(player, raw_column)
	
#func _on_redemption(user: String, reward_title: String, user_input: String) -> void:
	#reward_redeemed.emit(user, reward_title, user_input)
