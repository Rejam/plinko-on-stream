class_name BoardMarker extends Node2D

signal ball_scored(ball: Ball, base_value: int)

var _boards: Array[PackedScene] = []
var _board: Board = null

func setup(boards: Array[PackedScene]) -> void:
	_boards = boards

func swap_to(round_number: int) -> void:
	_clear()
	if _boards.is_empty():
		push_error("No boards have been added")
		return
	_board = _boards[(round_number - 1) % _boards.size()].instantiate()
	add_child(_board)
	_board.ball_scored.connect(ball_scored.emit)

func spawn_held_ball(column: int) -> Ball:
	if not _board: return null
	return _board.spawn_held_ball(column)

func parse_column(raw_column: String) -> int:
	var count := _board.column_count()
	var value := raw_column.to_int()
	if value < 1 or value > count:
		return randi_range(1, count)
	return value

func _clear() -> void:
	if not _board: return
	_board.ball_scored.disconnect(ball_scored.emit)
	_board.queue_free()
	_board = null
