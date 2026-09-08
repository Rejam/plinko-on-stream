class_name SessionManager extends Node

enum SessionState { IDLE, RUNNING, FINISHED }
const BLOCK_SIZE := 5

signal round_started(current_round: int, round_count: int, multiplier: int)
signal state_changed(round_state: RoundManager.RoundState, session_state: SessionState)
signal standings_updated(standings: Dictionary[String, Standing])
signal round_won(winners: Array[Standing])
signal ball_requested(entry: Entry)
signal ball_released
signal entrants_changed(entries: Array[Entry])
signal drop_resolved(player: Player, base_value: int, multiplier: int, points: int)

@onready var round_manager: RoundManager = $RoundManager

var standings: Dictionary[String, Standing] = {}
var session_state: SessionState = SessionState.IDLE
var round_count := 0
var current_round := 0
var current_multiplier: int:
	get: return multiplier_for_round(current_round)

func _ready() -> void:
	round_manager.drop_scored.connect(_on_drop_scored)
	round_manager.entrant_registered.connect(_entrant_registered)
	round_manager.round_state_changed.connect(_on_round_state_changed)
	round_manager.ball_requested.connect(ball_requested.emit)
	round_manager.ball_released.connect(ball_released.emit)
	round_manager.entrants_changed.connect(entrants_changed.emit)
	
func start_session(rounds: int) -> void:
	round_count = rounds
	current_round = 0
	_set_session_state(SessionState.RUNNING)
	_begin_round()

func register_entrant(player: Player, column: int) -> void:
	var total := 0
	if standings.has(player.user_id):
		total = standings[player.user_id].total
	round_manager.register_entrant(player, column, total)

func end_registration() -> void:
	round_manager.end_registration()

func drop_next() -> void:
	round_manager.drop_next()

func redrop() -> void:
	round_manager.redrop()

func notify_drop_scored(player: Player, base_value: int) -> void:
	round_manager.notify_drop_scored(player, base_value)
	
func continue_round() -> void:
	round_manager.continue_round()

func next_round() -> void:
	if round_manager.round_state != RoundManager.RoundState.FINISHED:
		return
	if current_round >= round_count:
		_set_session_state(SessionState.FINISHED)
	else:
		_begin_round()

## Rounds group into blocks of BLOCK_SIZE, each paying one multiple more than the last
func multiplier_for_round(round_number: int) -> int:
	var multiplier = (round_number - 1.0) / (BLOCK_SIZE) + 1
	return int(multiplier)

func _begin_round() -> void:
	current_round += 1
	round_started.emit(current_round, round_count, current_multiplier)
	round_manager.begin_round()

func round_winners(round_number: int) -> Array[Standing]:
	var best := 0
	var winners: Array[Standing] = []
	for standing:Standing in standings.values():
		var points := standing.points_in(round_number)
		if points > best:
			best = points
			winners.clear()
		if points == best and points > 0:
			winners.append(standing)
	return winners	

func _on_drop_scored(player: Player, base_value: int) -> void:
	var points := base_value * current_multiplier
	var standing := standings[player.user_id]
	standing.total += points
	standing.round_points[current_round] = points
	standings_updated.emit(standings)
	drop_resolved.emit(player, base_value, current_multiplier, points)

func _entrant_registered(player: Player) -> void:
	if standings.has(player.user_id):
		standings[player.user_id].display_name = player.display_name
	else:
		standings[player.user_id] = Standing.make(player)

func _resolve_round_winner() -> void:
	var winners := round_winners(current_round)
	for standing in winners:
		standing.round_wins += 1
	round_won.emit(winners)

func _on_round_state_changed(state: RoundManager.RoundState) -> void:
	if state == RoundManager.RoundState.FINISHED:
		_resolve_round_winner()
	state_changed.emit(state, session_state)

func _set_session_state(new_state: SessionState) -> void:
	session_state = new_state
	state_changed.emit(round_manager.round_state, new_state)
