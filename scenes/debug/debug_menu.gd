extends CanvasLayer


@onready var panel: PanelContainer = %PanelContainer
@onready var toggle_button: Button = %ToggleButton

func _ready() -> void:
	if not OS.is_debug_build(): 
		queue_free()
		return
	panel.hide()
	toggle_button.pressed.connect(_on_toggle_pressed)

func _on_toggle_pressed() -> void:
	panel.visible = not panel.visible

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		panel.visible = not panel.visible
