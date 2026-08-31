@tool
class_name Bucket extends Area2D

## Detects a ball and reports its base value. Nothing else —
## it does not free the ball and never sees the multiplier.

signal ball_entered(ball: Ball, base_value: int)

const HEIGHT := 64.0

@export_range(10, 100, 5, "prefer_slider") var base_value := 10:
	set(value):
		base_value = value
		_refresh()

@export_range(128, 640, 32, "or_greater", "prefer_slider") var width : int = 256:
	set(value):
		width = value
		_refresh()

@export_color_no_alpha var background_colour: Color = Color.PURPLE:
	set(value):
		background_colour = value
		_refresh()


@export_color_no_alpha var text_colour: Color = Color.WHITE:
	set(value):
		text_colour = value
		_refresh()
		
@onready var _collision: CollisionShape2D = %CollisionShape2D
@onready var _rect: ColorRect = %ColorRect
@onready var _label: Label = %Label


func _ready() -> void:
	_refresh()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)

func _refresh() -> void:
	if not is_node_ready():
		return
	var size := Vector2(width, HEIGHT)
	print(size)
	var shape := RectangleShape2D.new()
	shape.size = size
	_collision.shape = shape
	_rect.size = size
	_rect.position = -size / 2.0
	_rect.color = background_colour
	_label.size = size
	_label.add_theme_color_override("font_color", text_colour)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.text = str(base_value)

func _on_body_entered(body: Node2D) -> void:
	if body is Ball:
		ball_entered.emit(body, base_value)
