extends Node2D

@export var boards: Array[PackedScene] = []
@export var balls_remaining := 5

@onready var board_marker: Node2D = $BoardMarker

var ballScene := preload("res://scenes/game/ball/ball.tscn")
var game_round := 0
var board: Node2D = null

func _ready() -> void:
	_load_board()
	
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

func _next_round() -> void:
	game_round += 1
	_load_board.call_deferred()

func _on_next_round_pressed() -> void:
	_next_round()
