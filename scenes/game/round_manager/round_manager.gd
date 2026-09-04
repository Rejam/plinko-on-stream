class_name RoundManager extends Node 

enum RoundState { IDLE, REGISTRATION, PRE_DROP, DROPPING, DROP_RESOLVED, ROUND_FINISHED, SESSION_FINISHED }
const BLOCK_SIZE := 5

signal round_state_changed(round_state: RoundState)
signal round_changed(current_round: int, round_count: int)
signal ball_requested(player: Player)
signal ball_released
signal entrants_changed(players: Array[Player])
signal drop_scored(player: Player, base_value: int, multiplier: int, points: int)

var round_count := 0
var round_state: RoundState = RoundState.IDLE
var current_round := 0
var current_player: Player = null
var current_multiplier: int:
	get: return multiplier_for_round(current_round)
	
var _entries: Dictionary = {}
var _queue: Array[Player] = []

func start_session(rounds: int) -> void:
	round_count = rounds
	current_round = 0
	_begin_round()

func end_registration() -> void:
	if round_state != RoundState.REGISTRATION:
		return
	_build_queue()
	_next_entrant()

func register_entrant(player: Player, column: int) -> void:
	if round_state != RoundState.REGISTRATION:
		return
	player.column = column
	_entries[player.user_id] = player
	var entrants: Array[Player] = []
	entrants.assign(_entries.values())
	entrants_changed.emit(entrants)

func _build_queue() -> void:
	# Sorted by session total ascending once Session exists.
	_queue = []
	for id in _entries:
		_queue.append(_entries[id])

func notify_drop_scored(player: Player, base_value: int) -> void:
	# round_state leaves DROPPING as soon as a ball scores, so a second
	# report from the same ball is ignored.
	if round_state != RoundState.DROPPING:
		return
	if player.user_id != current_player.user_id:
		push_error("Scored ball belongs to %s, expected %s" % [player.display_name, current_player.display_name])
		return
	var points := base_value * current_multiplier
	drop_scored.emit(player, base_value, current_multiplier, points)
	_set_round_state(RoundState.DROP_RESOLVED)
	
func _next_entrant() -> void:
	if _queue.is_empty():
		current_player = null
		_set_round_state(RoundState.ROUND_FINISHED)
	else:
		current_player = _queue.pop_front()
		entrants_changed.emit(_queue.duplicate())
		ball_requested.emit(current_player)
		_set_round_state(RoundState.PRE_DROP)

func drop_next() -> void:
	if round_state != RoundState.PRE_DROP:
		return
	ball_released.emit()
	_set_round_state(RoundState.DROPPING)
	
func continue_round() -> void:
	if round_state != RoundState.DROP_RESOLVED:
		return
	_next_entrant()
	
func next_round() -> void:
	if round_state != RoundState.ROUND_FINISHED:
		return
	if current_round >= round_count:
		_set_round_state(RoundState.SESSION_FINISHED)
	else:
		_begin_round()
		
func end_session() -> void:
	if round_state == RoundState.SESSION_FINISHED:
		return
	_set_round_state(RoundState.SESSION_FINISHED)
		
func _begin_round() -> void:
	current_round += 1
	_entries.clear()
	_queue.clear()
	entrants_changed.emit([] as Array[Player])
	current_player = null
	round_changed.emit(current_round, round_count)
	_set_round_state(RoundState.REGISTRATION)

func _set_round_state(new_state: RoundState) -> void:
	round_state = new_state
	round_state_changed.emit(new_state)
	
func redrop() -> void:
	if round_state != RoundState.DROPPING:
		return
	ball_requested.emit(current_player)
	_set_round_state(RoundState.PRE_DROP)

## Rounds group into blocks of BLOCK_SIZE, each paying one multiple more than the last
func multiplier_for_round(round_number: int) -> int:
	var multiplier = (round_number - 1.0) / (BLOCK_SIZE) + 1
	return int(multiplier)
