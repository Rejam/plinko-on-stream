extends Node2D

@export var boards: Array[PackedScene] = []
@export var round_count := 10

@onready var board_marker: Node2D = %BoardMarker
@onready var round_manager: RoundManager = %RoundManager
@onready var next_round_button: Button = %NextRoundButton
@onready var drop_ball_button: Button = %DropBallButton
@onready var round_status_label: Label = %RoundStatusLabel
@onready var end_reg_button: Button = %EndRegistrationButton
@onready var continue_button: Button = %ContinueButton
@onready var entrants_list: ItemList = %EntrantsList

var board: Board = null
var current_ball: Ball = null

func _ready() -> void:
	next_round_button.pressed.connect(round_manager.next_round)
	drop_ball_button.pressed.connect(round_manager.drop_next)
	end_reg_button.pressed.connect(round_manager.end_registration)
	continue_button.pressed.connect(round_manager.continue_round)
	round_manager.round_state_changed.connect(_on_round_state_changed)
	round_manager.round_changed.connect(_on_round_changed)
	round_manager.ball_requested.connect(_on_ball_requested)
	round_manager.ball_released.connect(_on_ball_released)
	round_manager.entrants_changed.connect(_on_entrants_changed)
	round_manager.start_session(round_count)

func _on_round_changed(_current_round: int, _round_count: int) -> void:
	_load_board.call_deferred()

func _get_board() -> Board:
	if not boards:
		push_error("No boards have been added")
		return null
	var board_index := (round_manager.current_round - 1) % boards.size()
	return boards[board_index].instantiate()

func _load_board() -> void:
	_clear_current_board()
	board = _get_board()
	if not board: return
	board_marker.add_child(board)
	board.ball_scored.connect(_on_ball_scored)

func _clear_current_board() -> void:
	if not board: return
	board.ball_scored.disconnect(_on_ball_scored)
	board.queue_free()

func _on_ball_requested(player: Player) -> void:
	if not board: return
	var column := randi_range(1, board.column_count())
	current_ball = board.spawn_held_ball(column)
	current_ball.owner_player = player

func _on_ball_released() -> void:
	if not current_ball: return
	current_ball.freeze = false
	# help prevent balls resting on grid aligned pegs
	current_ball.apply_central_impulse(Vector2(randf_range(-20, 20), 0))

func _on_ball_scored(ball: Ball, base_value: int) -> void:
	current_ball = null
	print("game - _on_ball_scored: %s scored %d" % [ball.owner_player.display_name, base_value])
	round_manager.notify_ball_scored(ball, base_value)

func _on_round_state_changed(round_state: RoundManager.RoundState) -> void:
	round_status_label.text = RoundManager.RoundState.keys()[round_state]
	
func _on_entrants_changed(entrants: Array[Player]) -> void:
	entrants_list.clear()
	for player in entrants:
		entrants_list.add_item(player.display_name)
