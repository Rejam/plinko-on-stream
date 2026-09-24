class_name Hud extends CanvasLayer

## HUD controls and readouts, driven by SessionManager.

@export var session_manager: SessionManager
@export var quit_confirm_layer: CanvasLayer

@onready var drop_ball_button: Button = %DropBallButton
@onready var end_reg_button: Button = %EndRegistrationButton
@onready var continue_button: Button = %ContinueButton
@onready var redrop_button: Button = %RedropButton
@onready var quit_button: Button = %QuitButton
@onready var round_status_label: Label = %RoundStatusLabel
@onready var multiplier_label: Label = %MultiplierLabel
@onready var queue_title: Label = %QueueTitle
@onready var entrants_waiting_list: PlayerList = %EntrantsWaitingList
@onready var standings_list: PlayerList = %StandingsList
@onready var current_ball_icon: TextureRect = %BallIcon
@onready var current_ball_label: Label = %CurrentBallLabel
@onready var hits_label: Label = %HitsLabel

var _ball: Ball = null

func _ready() -> void:
	drop_ball_button.pressed.connect(session_manager.drop_next)
	end_reg_button.pressed.connect(session_manager.end_registration)
	continue_button.pressed.connect(session_manager.continue_round)
	redrop_button.pressed.connect(session_manager.redrop)
	quit_button.pressed.connect(quit_confirm_layer.open)
	session_manager.state_changed.connect(_on_state_changed)
	session_manager.round_started.connect(_on_round_started)
	session_manager.entrants_changed.connect(_on_entrants_changed)
	session_manager.standings_updated.connect(_on_standings_updated)

func set_ball(ball: Ball) -> void:
	_ball = ball

func _process(_delta: float) -> void:
	if session_manager.game_state != SessionManager.GameState.DROPPING:
		return
	if not is_instance_valid(_ball):
		return
	if session_manager.current_entry == null:
		return
	hits_label.text = "· %d" % _ball.peg_hits

func _on_round_started(current_round: int, total_rounds: int, multiplier: int) -> void:
	multiplier_label.text = "Round %d/%d · %dx" % [current_round, total_rounds, multiplier]

func _on_state_changed(game_state: SessionManager.GameState) -> void:
	end_reg_button.disabled = game_state != SessionManager.GameState.REGISTRATION
	drop_ball_button.disabled = game_state != SessionManager.GameState.PRE_DROP
	redrop_button.disabled = game_state != SessionManager.GameState.DROPPING
	continue_button.disabled = game_state != SessionManager.GameState.DROP_RESOLVED
	_update_current_ball_label(game_state)
	if game_state == SessionManager.GameState.SESSION_OVER:
		round_status_label.text = "SESSION FINISHED"
	else:
		round_status_label.text = SessionManager.get_game_state_label_text(game_state)

func _update_current_ball_label(game_state: SessionManager.GameState) -> void:
	var entry := session_manager.current_entry
	var showing := entry != null and game_state in [
		SessionManager.GameState.PRE_DROP, SessionManager.GameState.DROPPING]
	current_ball_icon.visible = showing
	if not showing:
		current_ball_label.text = ""
		hits_label.text = ""
		return
	current_ball_label.text = "%s is up" % entry.player.display_name
	hits_label.text = "· 0"
	current_ball_icon.texture = BallArt.texture_for(entry.player.user_id)

func _on_entrants_changed(entrants: Array[Entry]) -> void:
	queue_title.text = "Queue (%d)" % entrants.size()
	entrants_waiting_list.clear()
	for entrant in entrants:
		entrants_waiting_list.add(entrant.player.user_id, entrant.player.display_name,
			str(entrant.column))

func _on_standings_updated() -> void:
	standings_list.clear()
	var round_number := session_manager.current_round
	for standing in session_manager.round_standings():
		standings_list.add(standing.user_id, standing.display_name,
			str(standing.points_in(round_number)))
