extends Node2D

@export var boards: Array[PackedScene] = []
@export var round_count := 10

@onready var board_marker: BoardMarker = %BoardMarker
@onready var session_manager: SessionManager = %SessionManager
@onready var drop_ball_button: Button = %DropBallButton
@onready var round_status_label: Label = %RoundStatusLabel
@onready var end_reg_button: Button = %EndRegistrationButton
@onready var continue_button: Button = %ContinueButton
@onready var entrants_waiting_list: ItemList = %EntrantsWaitingList
@onready var redrop_button: Button = %RedropButton
@onready var current_ball_label: Label = %CurrentBallLabel
@onready var current_ball_icon: TextureRect = %BallIcon
@onready var multiplier_label: Label = %MultiplierLabel
@onready var standings_list: ItemList = %StandingsList
@onready var facecam_reserve: Control = %FacecamReserve
@onready var quit_button: Button = %QuitButton
@onready var quit_confirm_layer: CanvasLayer = %QuitConfirmLayer

var current_ball: Ball = null

func _ready() -> void:
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
	board_marker.setup(boards)
	board_marker.ball_scored.connect(_on_ball_scored)
	session_manager.start_session(round_count)
	Twitch.entry_received.connect(_on_entry_received)
	quit_button.pressed.connect(quit_confirm_layer.open)

func _on_round_started(current_round: int, total_rounds: int, multiplier: int) -> void:
	multiplier_label.text = "Round %d/%d · %dx" % [current_round, total_rounds, multiplier]
	board_marker.swap_to.call_deferred(current_round)

func _on_ball_requested(entry: Entry) -> void:
	if is_instance_valid(current_ball):
		current_ball.queue_free()
	current_ball = board_marker.spawn_held_ball(entry.column)
	current_ball.owner_player = entry.player

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
	_update_current_ball_label(game_state)
	if session_over:
		round_status_label.text = "SESSION FINISHED"
	else:
		round_status_label.text = SessionManager.get_game_state_label_text(game_state)

## Reads current_entry, which SessionManager assigns before it emits the state
## change, so PRE_DROP and DROPPING both see the entry they belong to.
func _update_current_ball_label(game_state: SessionManager.GameState) -> void:
	var entry := session_manager.current_entry
	var showing := entry != null and game_state in [
		SessionManager.GameState.PRE_DROP, SessionManager.GameState.DROPPING]
	current_ball_icon.visible = showing
	if not showing:
		current_ball_label.text = ""
		return
	current_ball_label.text = "%s is up" % entry.player.display_name
	current_ball_icon.texture = BallArt.texture_for(entry.player.user_id)

func _on_entrants_changed(entrants: Array[Entry]) -> void:
	entrants_waiting_list.clear()
	for entrant in entrants:
		entrants_waiting_list.add_item("%s : %s" % [entrant.player.display_name, entrant.column],
			BallArt.texture_for(entrant.player.user_id))

func _on_entry_received(player: Player, raw_column: String) -> void:
	var column := board_marker.parse_column(raw_column)
	if column == BoardMarker.NO_COLUMN: return
	session_manager.register_entrant(player, column)

func _on_drop_resolved(_player: Player, _base_value: int, _multiplier: int, _points: int) -> void:
	# Unconsumed. The score lands in the standings list; base_value and
	# multiplier are exposed nowhere else, so this stays as the hook for an
	# on-board score popup.
	pass

func _on_standings_updated(standings: Array[Standing]) -> void:
	standings_list.clear()
	for standing in standings:
		standings_list.add_item("%s : %d" % [standing.display_name, standing.total],
			BallArt.texture_for(standing.user_id))
