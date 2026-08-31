extends Node2D

@export var boards: Array[PackedScene] = []
@export var balls_remaining := 5

@onready var board_marker: Node2D = $BoardMarker

var ballScene := preload("res://scenes/game/ball/ball.tscn")
var game_round := 0
var board: Node2D = null
var remaining_ball_count := 0

func _ready() -> void:
	_load_board()
	_reset_balls()
	
func _get_board() -> Node:
	if not boards:
		push_error("No boards have been added")
		return null
	var board_index := game_round % boards.size()
	return boards[board_index].instantiate()
	
func _load_board() -> void:
	clear_current_board()
	board = _get_board()
	if not board: return
	board_marker.add_child(board)

func clear_current_board() -> void:
	if not board: return
	board.queue_free()

func _reset_balls() -> void:
	remaining_ball_count = balls_remaining
	
func _next_round() -> void:
	game_round += 1
	_reset_balls.call_deferred()
	_load_board.call_deferred()

func _on_next_round_pressed() -> void:
	_next_round()
	
func _input(event: InputEvent) -> void:
	if event.is_action_released("drop_ball"):
		dropball()

func dropball() -> void:
	if not remaining_ball_count: return
	var ball : Ball = ballScene.instantiate()
	ball.position = Vector2(randi_range(100, 1000), randi_range(20, 50))
	board_marker.add_child(ball)
	remaining_ball_count -= 1
