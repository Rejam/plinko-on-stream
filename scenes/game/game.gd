extends Node2D

@export var boards: Array[PackedScene] = []
@export var round_count := 10

@onready var board_marker: BoardMarker = %BoardMarker
@onready var round_manager: RoundManager = %RoundManager
@onready var next_round_button: Button = %NextRoundButton
@onready var drop_ball_button: Button = %DropBallButton
@onready var round_status_label: Label = %RoundStatusLabel
@onready var end_reg_button: Button = %EndRegistrationButton
@onready var continue_button: Button = %ContinueButton
@onready var entrants_waiting: ItemList = %EntrantsWaiting
@onready var redrop_button: Button = %RedropButton
@onready var current_ball_label: Label = %CurrentBallLabel
@onready var last_drop_label: Label = %LastDropLabel

var current_ball: Ball = null

func _ready() -> void:
	next_round_button.pressed.connect(round_manager.next_round)
	drop_ball_button.pressed.connect(round_manager.drop_next)
	end_reg_button.pressed.connect(round_manager.end_registration)
	continue_button.pressed.connect(round_manager.continue_round)
	redrop_button.pressed.connect(round_manager.redrop)
	round_manager.round_state_changed.connect(_on_round_state_changed)
	round_manager.round_changed.connect(_on_round_changed)
	round_manager.ball_requested.connect(_on_ball_requested)
	round_manager.ball_released.connect(_on_ball_released)
	round_manager.entrants_changed.connect(_on_entrants_changed)
	round_manager.drop_scored.connect(_on_drop_scored)
	board_marker.setup(boards)
	board_marker.ball_scored.connect(_on_ball_scored)
	round_manager.start_session(round_count)
	Twitch.entry_received.connect(_on_entry_received)

func _on_round_changed(current_round: int, _round_count: int) -> void:
	board_marker.swap_to.call_deferred(current_round)

func _on_ball_requested(player: Player) -> void:
	if is_instance_valid(current_ball):
		current_ball.queue_free()
	current_ball = board_marker.spawn_held_ball(player.column)
	current_ball.owner_player = player
	current_ball_label.text = "Next up: %s" % [player.display_name]

func _on_ball_released() -> void:
	if not is_instance_valid(current_ball): return
	current_ball.freeze = false
	# help prevent balls resting on grid aligned pegs
	current_ball.apply_central_impulse(Vector2(randf_range(-20, 20), 0))

func _on_ball_scored(ball: Ball, base_value: int) -> void:
	if ball != current_ball: return
	current_ball = null
	round_manager.notify_drop_scored(ball.owner_player, base_value)

func _on_round_state_changed(round_state: RoundManager.RoundState) -> void:
	round_status_label.text = RoundManager.RoundState.keys()[round_state]
	end_reg_button.disabled = round_state != RoundManager.RoundState.REGISTRATION
	drop_ball_button.disabled = round_state != RoundManager.RoundState.PRE_DROP
	redrop_button.disabled = round_state != RoundManager.RoundState.DROPPING
	continue_button.disabled = round_state != RoundManager.RoundState.DROP_RESOLVED
	next_round_button.disabled = round_state != RoundManager.RoundState.ROUND_FINISHED
	if round_state in [
		RoundManager.RoundState.REGISTRATION,
		RoundManager.RoundState.ROUND_FINISHED,
		RoundManager.RoundState.SESSION_FINISHED,
	]:
		current_ball_label.text = "Next up:"
	
func _on_entrants_changed(entrants: Array[Player]) -> void:
	entrants_waiting.clear()
	for player in entrants:
		entrants_waiting.add_item("%s : %s" % [player.display_name, player.column])

func _on_entry_received(player: Player, raw_column: String) -> void:
	var column := board_marker.parse_column(raw_column)
	round_manager.register_entrant(player, column)

func _on_drop_scored(player: Player, base_value: int, multiplier: int, points: int) -> void:
	if multiplier == 1:
		last_drop_label.text = "%s · %d" % [player.display_name, points]
	else:
		last_drop_label.text = "%s · %d × %d = %d" % [player.display_name, base_value, multiplier, points]
