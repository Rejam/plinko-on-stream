extends Node

const CLIENT_ID := "vcke9lww8ciefo8bimxd2k795m2kr4"
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
signal chat_message(user: String, message: String, tags: Dictionary)
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
	#
	#_eventsub = TwitchEventSub.new()
	#add_child(_eventsub)
	#_eventsub.redemption_received.connect(_on_redemption)

func start_login() -> void:
	_auth.start_login(CLIENT_ID, REDIRECT_PORT, SCOPES)

func _on_login_completed(token: String, id: String, login: String) -> void:
	access_token = token
	user_id = id
	user_login = login
	is_logged_in = true

	_chat.connect_to_chat(token, login)
	#_eventsub.init(token, id, CLIENT_ID)
	login_completed.emit(login)

func _on_chat_message(user: String, message: String, tags: Dictionary) -> void:
	chat_message.emit(user, message, tags)

#func _on_redemption(user: String, reward_title: String, user_input: String) -> void:
	#reward_redeemed.emit(user, reward_title, user_input)
