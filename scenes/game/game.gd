extends Node2D

@export var boards: Array[PackedScene] = []
@export var round_count := 10

@onready var board_marker: BoardMarker = %BoardMarker
@onready var session_manager: SessionManager = %SessionManager
@onready var next_round_button: Button = %NextRoundButton
@onready var drop_ball_button: Button = %DropBallButton
@onready var round_status_label: Label = %RoundStatusLabel
@onready var end_reg_button: Button = %EndRegistrationButton
@onready var continue_button: Button = %ContinueButton
@onready var entrants_waiting_list: ItemList = %EntrantsWaitingList
@onready var redrop_button: Button = %RedropButton
@onready var current_ball_label: Label = %CurrentBallLabel
@onready var last_drop_label: Label = %LastDropLabel
@onready var multiplier_label: Label = %MultiplierLabel
@onready var standings_list: ItemList = %StandingsList
@onready var round_winner_label: Label = %RoundWinnerLabel
@onready var registration_layer: CanvasLayer = %RegistrationLayer
@onready var round_over_layer: CanvasLayer = %RoundOverLayer

var current_ball: Ball = null

func _ready() -> void:
	next_round_button.pressed.connect(session_manager.next_round)
	drop_ball_button.pressed.connect(session_manager.drop_next)
	end_reg_button.pressed.connect(session_manager.end_registration)
	continue_button.pressed.connect(session_manager.continue_round)
	redrop_button.pressed.connect(session_manager.redrop)
	session_manager.state_changed.connect(_on_state_changed)
	session_manager.round_started.connect(_on_round_started)
	session_manager.ball_requested.connect(_on_ball_requested)
	session_manager.ball_released.connect(_on_ball_released)
	session_manager.drop_resolved.connect(_on_drop_resolved)
	session_manager.entrants_changed.connect(_on_entrants_changed)
	session_manager.standings_updated.connect(_on_standings_updated)
	session_manager.round_won.connect(_on_round_won)
	board_marker.setup(boards)
	board_marker.ball_scored.connect(_on_ball_scored)
	session_manager.start_session(round_count)
	Twitch.entry_received.connect(_on_entry_received)

func _on_round_started(current_round: int, total_rounds: int, multiplier: int) -> void:
	last_drop_label.text = ""
	round_winner_label.text = ""
	multiplier_label.text = "Round %d/%d · %dx" % [current_round, total_rounds, multiplier]
	board_marker.swap_to.call_deferred(current_round)

func _on_ball_requested(entry: Entry) -> void:
	if is_instance_valid(current_ball):
		current_ball.queue_free()
	current_ball = board_marker.spawn_held_ball(entry.column)
	current_ball.owner_player = entry.player
	current_ball_label.text = "Next up: %s" % [entry.player.display_name]

func _on_ball_released() -> void:
	if not is_instance_valid(current_ball): return
	current_ball.freeze = false
	# help prevent balls resting on grid aligned pegs
	current_ball.apply_central_impulse(Vector2(randf_range(-20, 20), 0))

func _on_ball_scored(ball: Ball, base_value: int) -> void:
	if ball != current_ball: return
	if session_manager.notify_drop_scored(ball.owner_player, base_value):
		current_ball = null

func _on_state_changed(game_state: SessionManager.GameState) -> void:
	var session_over := game_state == SessionManager.GameState.SESSION_OVER
	end_reg_button.disabled = game_state != SessionManager.GameState.REGISTRATION
	drop_ball_button.disabled = game_state != SessionManager.GameState.PRE_DROP
	redrop_button.disabled = game_state != SessionManager.GameState.DROPPING
	continue_button.disabled = game_state != SessionManager.GameState.DROP_RESOLVED
	next_round_button.disabled = game_state != SessionManager.GameState.ROUND_OVER
	registration_layer.visible = game_state == SessionManager.GameState.REGISTRATION
	round_over_layer.visible = game_state == SessionManager.GameState.ROUND_OVER
	if game_state in [SessionManager.GameState.REGISTRATION, SessionManager.GameState.ROUND_OVER]:
		current_ball_label.text = "Next up:"
	if session_over:
		round_status_label.text = "SESSION FINISHED"
	else:
		round_status_label.text = SessionManager.get_game_state_label_text(game_state)
		
func _on_entrants_changed(entrants: Array[Entry]) -> void:
	entrants_waiting_list.clear()
	for entrant in entrants:
		entrants_waiting_list.add_item("%s : %s" % [entrant.player.display_name, entrant.column])

func _on_entry_received(player: Player, raw_column: String) -> void:
	var column := board_marker.parse_column(raw_column)
	if column == BoardMarker.NO_COLUMN: return
	session_manager.register_entrant(player, column)

func _on_drop_resolved(player: Player, base_value: int, multiplier: int, points: int) -> void:
	if multiplier == 1:
		last_drop_label.text = "%s · %d" % [player.display_name, points]
	else:
		last_drop_label.text = "%s · %d × %d = %d" % [player.display_name, base_value, multiplier, points]

func _on_standings_updated(standings: Dictionary[String, Standing]) -> void:
	var rows: Array[Standing] = []
	rows.assign(standings.values())
	rows.sort_custom(func(a, b): return a.total > b.total)
	standings_list.clear()
	for standing in rows:
		standings_list.add_item("%s : %d" % [standing.display_name, standing.total])

func _on_round_won(winners: Array[Standing]) -> void:
	if winners.is_empty():
		round_winner_label.text = ""
		return
	var names: Array[String] = []
	for standing in winners:
		names.append(standing.display_name)
	round_winner_label.text = "Round winner: %s · %d" % [
		", ".join(names), winners[0].points_in(session_manager.current_round)]
