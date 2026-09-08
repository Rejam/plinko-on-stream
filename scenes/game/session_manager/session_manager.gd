class_name SessionManager extends Node

enum SessionState { IDLE, RUNNING, FINISHED }
enum RoundState { REGISTRATION, PRE_DROP, DROPPING, DROP_RESOLVED, FINISHED }

const BLOCK_SIZE := 5

signal round_started(current_round: int, round_count: int, multiplier: int)
signal state_changed(round_state: RoundState, session_state: SessionState)
signal standings_updated(standings: Dictionary[String, Standing])
signal round_won(winners: Array[Standing])
signal ball_requested(entry: Entry)
signal ball_released
signal entrants_changed(entries: Array[Entry])
signal drop_resolved(player: Player, base_value: int, multiplier: int, points: int)

# Session-scoped. Never cleared while the session runs.
var standings: Dictionary[String, Standing] = {}
var session_state: SessionState = SessionState.IDLE
var round_count := 0
var current_round := 0

# Round-scoped. _reset_round() clears exactly these and nothing else.
# Anything added here must be added there.
var round_state: RoundState = RoundState.REGISTRATION
var current_entry: Entry = null
var _entries: Dictionary[String, Entry] = {}
var _queue: Array[Entry] = []

var current_multiplier: int:
	get: return multiplier_for_round(current_round)

static func get_round_state_label_text(state: RoundState) -> String:
	return RoundState.keys()[state]

# --- session ---------------------------------------------------------------

func start_session(rounds: int) -> void:
	round_count = rounds
	current_round = 0
	_set_session_state(SessionState.RUNNING)
	_begin_round()

func next_round() -> void:
	if round_state != RoundState.FINISHED:
		return
	if current_round >= round_count:
		_set_session_state(SessionState.FINISHED)
	else:
		_begin_round()

## Rounds group into blocks of BLOCK_SIZE, each paying one multiple more than the last
func multiplier_for_round(round_number: int) -> int:
	var multiplier := (round_number - 1.0) / (BLOCK_SIZE) + 1
	return int(multiplier)

func round_winners(round_number: int) -> Array[Standing]:
	var best := 0
	var winners: Array[Standing] = []
	for standing: Standing in standings.values():
		var points := standing.points_in(round_number)
		if points > best:
			best = points
			winners.clear()
		if points == best and points > 0:
			winners.append(standing)
	return winners

func _begin_round() -> void:
	current_round += 1
	round_started.emit(current_round, round_count, current_multiplier)
	_reset_round()

func _reset_round() -> void:
	_entries.clear()
	_queue.clear()
	entrants_changed.emit([] as Array[Entry])
	current_entry = null
	_set_round_state(RoundState.REGISTRATION)

# --- round -----------------------------------------------------------------

func register_entrant(player: Player, column: int) -> void:
	if round_state != RoundState.REGISTRATION:
		return
	var total := 0
	if standings.has(player.user_id):
		total = standings[player.user_id].total
	var entry := Entry.make(player, column, total)
	if _entries.has(player.user_id):
		_queue.erase(_entries[player.user_id])

	_entries[player.user_id] = entry
	_insert_into_queue(entry)
	entrants_changed.emit(_entries.values())
	_record_standing(player)

func end_registration() -> void:
	if round_state != RoundState.REGISTRATION:
		return
	_next_entrant()

func drop_next() -> void:
	if round_state != RoundState.PRE_DROP:
		return
	ball_released.emit()
	_set_round_state(RoundState.DROPPING)

func redrop() -> void:
	if round_state != RoundState.DROPPING:
		return
	ball_requested.emit(current_entry)
	_set_round_state(RoundState.PRE_DROP)

func continue_round() -> void:
	if round_state != RoundState.DROP_RESOLVED:
		return
	_next_entrant()

## Returns false if the report was rejected, in which case the caller still owns
## the ball — the round stays in DROPPING and Redrop is the way out.
func notify_drop_scored(player: Player, base_value: int) -> bool:
	# round_state leaves DROPPING as soon as a ball scores, so a second
	# report from the same ball is ignored.
	if round_state != RoundState.DROPPING:
		return false
	if player.user_id != current_entry.player.user_id:
		push_error("Scored ball belongs to %s, expected %s" % [player.display_name, current_entry.player.display_name])
		return false
	if not standings.has(player.user_id):
		push_error("No standing for %s" % player.display_name)
		return false
	_set_round_state(RoundState.DROP_RESOLVED)
 
	var multiplier := current_multiplier
	var points := base_value * multiplier
	var standing := standings[player.user_id]
	standing.total += points
	standing.round_points[current_round] = points
	standings_updated.emit(standings)
	drop_resolved.emit(player, base_value, multiplier, points)
	return true

func _next_entrant() -> void:
	if _queue.is_empty():
		current_entry = null
		_set_round_state(RoundState.FINISHED)
	else:
		current_entry = _queue.pop_front()
		entrants_changed.emit(_queue.duplicate())
		ball_requested.emit(current_entry)
		_set_round_state(RoundState.PRE_DROP)

func _insert_into_queue(entry: Entry) -> void:
	_queue.insert(_queue.bsearch_custom(entry, _by_total, false), entry)

func _by_total(a: Entry, b: Entry) -> bool:
	return a.total < b.total

# --- standings -------------------------------------------------------------

func _record_standing(player: Player) -> void:
	if standings.has(player.user_id):
		standings[player.user_id].display_name = player.display_name
	else:
		standings[player.user_id] = Standing.make(player)
	standings_updated.emit(standings)

func _resolve_round_winner() -> void:
	var winners := round_winners(current_round)
	for standing in winners:
		standing.round_wins += 1
	round_won.emit(winners)

# --- state transitions -----------------------------------------------------

func _set_round_state(new_state: RoundState) -> void:
	round_state = new_state
	if new_state == RoundState.FINISHED:
		_resolve_round_winner()
	state_changed.emit(new_state, session_state)

func _set_session_state(new_state: SessionState) -> void:
	session_state = new_state
	state_changed.emit(round_state, new_state)
