class_name Board extends Node2D

signal ball_scored(ball: Ball, base_value: int)

@export var ball_gravity_scale := 1.0

@export var ball_spawn_y := -60.0

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

## Buckets display base × multiplier. Scoring is unaffected; see Bucket.
func set_multiplier(multiplier: int) -> void:
	for bucket: Bucket in _buckets.get_children():
		bucket.multiplier = multiplier

## Columns are 1-indexed to match the on-screen labels and the chat
## command (!plinko 1-7). Clamping bad input is the round manager's job.
## The board only answers what exists.
func column_count() -> int:
	return _drop_positions.get_child_count()

func drop_position(column: int) -> Vector2:
	var column_index = column - 1
	return _drop_positions.get_child(column_index).position

## Creates a ball held (frozen) above the column's drop position — the
## pre-drop state. The caller keeps the returned reference and owns
## the ball from here: releasing (freeze = false), redropping,
## freeing. The board never frees a ball.
func spawn_held_ball(column: int) -> Ball:
	_set_active_column(column)
	var ball: Ball = BALL_SCENE.instantiate()
	ball.position = Vector2(drop_position(column).x, ball_spawn_y)
	ball.gravity_scale = ball_gravity_scale
	ball.freeze = true
	add_child(ball)
	return ball
	
## Indexes DropPositions by child order, the same lookup drop_position uses, so
## the lit marker cannot be a different column from the one the ball spawns in.
## Keying off DropMarker.column would let one mistyped export light up in the
## wrong place while the drop still went where it should.
func _set_active_column(column: int) -> void:
	for index in _drop_positions.get_child_count():
		var marker := _drop_positions.get_child(index) as DropMarker
		if marker:
			marker.active = index == column - 1

func _on_bucket_ball_entered(ball: Ball, base_value: int) -> void:
	ball_scored.emit(ball, base_value)
