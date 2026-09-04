class_name Board extends Node2D

## Expected children (authored per board in the editor, like pegs):
##   DropPositions/ — one Marker2D per column, left to right
##   Buckets/      — Bucket scenes with base_value set per instance
##   Pegs/, Walls/ — visual/physical content, opaque to this script

signal ball_scored(ball: Ball, base_value: int)

@export var ball_gravity_scale := 1.0

const BALL_SCENE = preload("uid://cthrtlsbusy3")

@onready var _drop_positions: Node2D = %DropPositions
@onready var _buckets: Node2D = %Buckets

func _ready() -> void:
	if column_count() == 0:
		push_error("%s has no drop positions" % scene_file_path)
	if _buckets.get_child_count() == 0:
		push_error("%s has no buckets" % scene_file_path)
	for bucket: Bucket in _buckets.get_children():
		bucket.ball_entered.connect(_on_bucket_ball_entered)
		
## Columns are 1-indexed to match the on-screen labels and the chat
## command (!plinko 1-7). Clamping bad input is the round manager's job.
## The board only answers what exists.
func column_count() -> int:
	return _drop_positions.get_child_count()

func get_valid_column(raw_column: String) -> int:
	if raw_column.is_empty():
		return randi_range(1, column_count())
	var value := raw_column.to_int()
	if value < 1 or value > column_count():
		return randi_range(1, column_count())
	return value
	
func drop_position(column: int) -> Vector2:
	var column_index = column - 1
	return _drop_positions.get_child(column_index).position

## Creates a ball held (frozen) at the column's drop position — the
## pre-drop state. The caller keeps the returned reference and owns
## the ball from here: releasing (freeze = false), redropping,
## freeing. The board never frees a ball.
func spawn_held_ball(column: int) -> Ball:
	var ball: Ball = BALL_SCENE.instantiate()
	ball.position = drop_position(column)
	ball.gravity_scale = ball_gravity_scale
	ball.freeze = true
	add_child(ball)
	return ball
	
func _on_bucket_ball_entered(ball: Ball, base_value: int) -> void:
	ball_scored.emit(ball, base_value)
