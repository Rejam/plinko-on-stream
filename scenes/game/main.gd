extends Node2D

@export var boards: Array[PackedScene] = []
@export var balls_per_round := 5

@onready var board_marker: Node2D = %BoardMarker
@onready var next_round_button: Button = %NextRoundButton
@onready var drop_ball_button: Button = %DropBallButton

var game_round := 0
var balls_remaining := 0
var board: Board = null

func _ready() -> void:
	next_round_button.pressed.connect(_next_round)
	drop_ball_button.pressed.connect(_dropball)
	_load_board()
	_reset_balls()
	
func _get_board() -> Board:
	if not boards:
		push_error("No boards have been added")
		return null
	var board_index := game_round % boards.size()
	return boards[board_index].instantiate()
	
func _load_board() -> void:
	_clear_current_board()
	board = _get_board()
	if not board: return
	print(board.ball_gravity_scale)
	board_marker.add_child(board)
	board.ball_scored.connect(_on_ball_scored)

func _clear_current_board() -> void:
	if not board: return
	board.queue_free()

func _reset_balls() -> void:
	balls_remaining = balls_per_round
	
func _next_round() -> void:
	game_round += 1
	_reset_balls()
	_load_board.call_deferred()

func _dropball() -> void:
	if not balls_remaining: return
	if not board: return
	var column := randi_range(1, board.column_count())
	var ball := board.spawn_held_ball(column)
	ball.freeze = false
	# help prevent balls resting on grid aligned pegs
	ball.apply_central_impulse(Vector2(randf_range(-20, 20), 0))
	balls_remaining -= 1

func _on_ball_scored(ball: Ball, base_value: int) -> void:
	print("%s scored %d" % [ball.name, base_value])
