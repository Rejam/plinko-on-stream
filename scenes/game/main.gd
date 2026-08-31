extends Node2D

@export var boards: Array[PackedScene] = []
@export var balls_per_round := 5

@onready var board_marker: Node2D = %BoardMarker
@onready var next_round_button: Button = %NextRoundButton
@onready var drop_ball_button: Button = %DropBallButton

const ball_scene := preload("uid://cthrtlsbusy3")
var game_round := 0
var board: Node2D = null
var balls_remaining := 0

func _ready() -> void:
	next_round_button.pressed.connect(_next_round)
	drop_ball_button.pressed.connect(_dropball)
	_load_board()
	_reset_balls()
	
func _get_board() -> Node:
	if not boards:
		push_error("No boards have been added")
		return null
	var board_index := game_round % boards.size()
	return boards[board_index].instantiate()
	
func _load_board() -> void:
	_clear_current_board()
	board = _get_board()
	if not board: return
	board_marker.add_child(board)

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
	var ball : Ball = ball_scene.instantiate()
	ball.position = Vector2(randi_range(100, 1000), randi_range(20, 50))
	board.add_child(ball)
	balls_remaining -= 1
