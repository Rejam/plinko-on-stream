extends Control

const GAME_SCENE = preload("uid://bob0rs2tvh3yo")
const LENGTHS: Array[int] = [5, 10, 20]

@onready var _connect_button: Button = %ConnectButton
@onready var _connect_status: Label = %ConnectStatusLabel
@onready var _length_select: OptionButton = %LengthSelectButton
@onready var _start_button: Button = %StartButton

func _ready() -> void:
	_connect_button.pressed.connect(_on_connect_pressed)
	_connect_status.text = "Not connected"
	Twitch.login_completed.connect(_on_login_completed)
	Twitch.login_failed.connect(_on_login_failed)
	for n in LENGTHS:
		_length_select.add_item("%d rounds" % n)
	_length_select.select(1)
	_start_button.pressed.connect(_on_start_pressed)
	
func _on_connect_pressed() -> void:
	_connect_button.disabled = true
	_connect_status.text = "Connecting…"
	Twitch.start_login()
	
func _on_login_completed(user_login: String) -> void:
	_connect_status.text = "Connected as %s" % user_login

func _on_login_failed() -> void:
	_connect_button.disabled = false
	_connect_status.text = "Connection failed"

func _on_start_pressed() -> void:
	var game := GAME_SCENE.instantiate()
	game.round_count = LENGTHS[_length_select.selected]
	var tree := get_tree()
	tree.root.add_child(game)
	tree.current_scene = game
	queue_free()
