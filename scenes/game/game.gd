extends Node2D

@export var boards: Array[PackedScene] = []
@export var round_count := 10

@onready var board_marker: BoardMarker = %BoardMarker
@onready var session_manager: SessionManager = %SessionManager
@onready var score_popup: ScorePopup = %ScorePopup
@onready var hud: Hud = $HUD

var current_ball: Ball = null

func _ready() -> void:
	session_manager.round_started.connect(_on_round_started)
	session_manager.ball_requested.connect(_on_ball_requested)
	session_manager.ball_released.connect(_on_ball_released)
	session_manager.drop_resolved.connect(_on_drop_resolved)
	board_marker.setup(boards)
	board_marker.ball_scored.connect(_on_ball_scored)
	session_manager.start_session(round_count)
	Twitch.entry_received.connect(_on_entry_received)

func _on_round_started(current_round: int, _total_rounds: int, multiplier: int) -> void:
	board_marker.swap_to.call_deferred(current_round, multiplier)

func _on_ball_requested(entry: Entry) -> void:
	if is_instance_valid(current_ball):
		current_ball.queue_free()
	current_ball = board_marker.spawn_held_ball(entry.column)
	current_ball.owner_player = entry.player
	hud.set_ball(current_ball)

func _on_ball_released() -> void:
	if not is_instance_valid(current_ball): return
	current_ball.freeze = false
	# help prevent balls resting on grid aligned pegs
	current_ball.apply_central_impulse(Vector2(randf_range(-20, 20), 0))

func _on_ball_scored(ball: Ball, base_value: int) -> void:
	if ball != current_ball: return
	if session_manager.notify_drop_scored(ball.owner_player, base_value, ball.peg_hits):
		current_ball = null

func _on_entry_received(player: Player, raw_column: String) -> void:
	var column := board_marker.parse_column(raw_column)
	if column == BoardMarker.NO_COLUMN: return
	session_manager.register_entrant(player, column)

func _on_drop_resolved(player: Player, base_value: int, multiplier: int, peg_hits: int, points: int) -> void:
	score_popup.show_drop(player, base_value * multiplier, peg_hits, points)
