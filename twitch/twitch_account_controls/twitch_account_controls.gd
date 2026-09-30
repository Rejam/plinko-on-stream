class_name TwitchAccountControls extends VBoxContainer

@onready var _connect_button: Button = %ConnectButton
@onready var _connect_status: Label = %ConnectStatusLabel
@onready var _disconnect_button: Button = %DisconnectButton

func _ready() -> void:
	Twitch.login_completed.connect(_on_login_completed)
	Twitch.login_failed.connect(_on_login_failed)
	_connect_button.pressed.connect(_on_connect_pressed)
	_connect_status.text = "Not connected"
	_disconnect_button.pressed.connect(_on_disconnect_pressed)
	_disconnect_button.visible = Twitch.is_logged_in
	if Twitch.is_logged_in:
		_on_login_completed(Twitch.user_login)
	

func _on_connect_pressed() -> void:
	_connect_button.disabled = true
	_connect_status.text = "Connecting…"
	Twitch.start_login()


func _on_login_completed(user_login: String) -> void:
	_connect_button.disabled = true
	_disconnect_button.visible = true
	_connect_status.text = "Connected as %s" % user_login


func _on_login_failed() -> void:
	_connect_button.disabled = false
	_connect_status.text = "Connection failed"


func _on_disconnect_pressed() -> void:
	Twitch.disconnect_account()
	_disconnect_button.visible = false
	_connect_button.disabled = false
	_connect_status.text = "Not connected"
