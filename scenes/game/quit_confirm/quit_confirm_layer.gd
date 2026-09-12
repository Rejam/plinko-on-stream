extends CanvasLayer

## Confirm step for abandoning a live session. Owns its own buttons; Game only
## calls open(). Cancel hides it, Quit returns to the title screen.

@onready var _cancel_button: Button = $Scrim/Card/Margin/Content/ButtonRow/CancelButton
@onready var _confirm_button: Button = $Scrim/Card/Margin/Content/ButtonRow/ConfirmQuitButton

func _ready() -> void:
	visible = false
	_cancel_button.pressed.connect(close)
	_confirm_button.pressed.connect(_on_confirmed)

func open() -> void:
	visible = true

func close() -> void:
	visible = false

func _on_confirmed() -> void:
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")
