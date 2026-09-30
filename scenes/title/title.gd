extends Control

const GAME_SCENE = preload("uid://bob0rs2tvh3yo")
const LENGTHS: Array[int] = [5, 10, 20]

@onready var _length_select: OptionButton = %LengthSelectButton
@onready var _start_button: Button = %StartButton

func _ready() -> void:
	for n in LENGTHS:
		_length_select.add_item("%d rounds" % n)
	_start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	var game := GAME_SCENE.instantiate()
	game.round_count = LENGTHS[_length_select.selected]
	var tree := get_tree()
	tree.root.add_child(game)
	tree.current_scene = game
	queue_free()
