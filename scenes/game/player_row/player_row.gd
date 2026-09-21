class_name PlayerRow extends HBoxContainer

## One display-only line in a PlayerList: ball, name, value.
## Nothing here takes input — every node is MOUSE_FILTER_IGNORE so rows never
## look or behave like something clickable (the reason ItemList was replaced).

@onready var _ball: TextureRect = $BallIcon
@onready var _name: Label = $NameLabel
@onready var _value: Label = $ValueLabel

## Call after the row is in the tree (@onready refs).
func setup(user_id: String, display_name: String, value_text: String) -> void:
	_ball.texture = BallArt.texture_for(user_id)
	_name.text = display_name
	_value.text = value_text
