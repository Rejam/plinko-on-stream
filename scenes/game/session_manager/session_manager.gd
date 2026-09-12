class_name SessionManager extends Node

enum GameState { IDLE, REGISTRATION, PRE_DROP, DROPPING, DROP_RESOLVED, ROUND_OVER, SESSION_OVER }

const BLOCK_SIZE := 5

signal round_started(current_round: int, round_count: int, multiplier: int)
signal state_changed(game_state: GameState)
signal standings_updated(standings: Array[Standing])
signal ball_requested(entry: Entry)
signal ball_released
signal entrants_changed(entries: Array[Entry])
signal drop_resolved(player: Player, base_value: int, multiplier: int, points: int)

var game_state: GameState = GameState.IDLE

# Session-scoped. Never cleared while the session runs.
var standings: Dictionary[String, Standing] = {}
var round_count := 0
var current_round := 0

# Round-scoped. _reset_round() clears exactly these and nothing else.
# Anything added here must be added there.
var current_entry: Entry = null
var _entries: Dictionary[String, Entry] = {}
var _queue: Array[Entry] = []

var current_multiplier: int:
	get: return multiplier_for_round(current_round)

static func get_game_state_label_text(state: GameState) -> String:
	return GameState.keys()[state]

# --- session ---------------------------------------------------------------

func start_session(rounds: int) -> void:
	round_count = rounds
	current_round = 0
	_begin_round()

func next_round() -> void:
	if game_state != GameState.ROUND_OVER:
		return
	if current_round >= round_count:
		_set_game_state(GameState.SESSION_OVER)
	else:
		_begin_round()

## Rounds group into blocks of BLOCK_SIZE, each paying one multiple more than the last
func multiplier_for_round(round_number: int) -> int:
	var multiplier := (round_number - 1.0) / (BLOCK_SIZE) + 1
	return int(multiplier)

## Display order: total descending, then first-score order. seq is unique, so
## this is a total order — sort_custom's instability cannot reshuffle ties.
func sorted_standings() -> Array[Standing]:
	var rows: Array[Standing] = []
	rows.assign(standings.values())
	rows.sort_custom(_by_standing)
	return rows

func _by_standing(a: Standing, b: Standing) -> bool:
	if a.total == b.total:
		return a.seq < b.seq
	return a.total > b.total

func _begin_round() -> void:
	current_round += 1
	round_started.emit(current_round, round_count, current_multiplier)
	_reset_round()

func _reset_round() -> void:
	_entries.clear()
	_queue.clear()
	entrants_changed.emit([] as Array[Entry])
	current_entry = null
	_set_game_state(GameState.REGISTRATION)

# --- round -----------------------------------------------------------------

func register_entrant(player: Player, column: int) -> void:
	if game_state != GameState.REGISTRATION:
		return
	var total := 0
	if standings.has(player.user_id):
		total = standings[player.user_id].total
	var entry := Entry.make(player, column, total)
	if _entries.has(player.user_id):
		_queue.erase(_entries[player.user_id])

	_entries[player.user_id] = entry
	_insert_into_queue(entry)
	entrants_changed.emit(_waiting_entries())

func end_registration() -> void:
	if game_state != GameState.REGISTRATION:
		return
	_next_entrant()

func drop_next() -> void:
	if game_state != GameState.PRE_DROP:
		return
	ball_released.emit()
	_set_game_state(GameState.DROPPING)

func redrop() -> void:
	if game_state != GameState.DROPPING:
		return
	ball_requested.emit(current_entry)
	_set_game_state(GameState.PRE_DROP)

func continue_round() -> void:
	if game_state != GameState.DROP_RESOLVED:
		return
	_next_entrant()

## Returns false if the report was rejected, in which case the caller still owns
## the ball — the round stays in DROPPING and Redrop is the way out.
func notify_drop_scored(player: Player, base_value: int) -> bool:
	# game_state leaves DROPPING as soon as a ball scores, so a second
	# report from the same ball is ignored.
	if game_state != GameState.DROPPING:
		return false
	if player.user_id != current_entry.player.user_id:
		push_error("Scored ball belongs to %s, expected %s" % [player.display_name, current_entry.player.display_name])
		return false
	_set_game_state(GameState.DROP_RESOLVED)
 
	var multiplier := current_multiplier
	var points := base_value * multiplier
	var standing := _standing_for(player)
	standing.total += points
	standing.round_points[current_round] = points
	current_entry.scored = true
	entrants_changed.emit(_waiting_entries())
	standings_updated.emit(sorted_standings())
	drop_resolved.emit(player, base_value, multiplier, points)
	return true

func _next_entrant() -> void:
	if _queue.is_empty():
		current_entry = null
		entrants_changed.emit(_waiting_entries())
		_set_game_state(GameState.ROUND_OVER)
	else:
		current_entry = _queue.pop_front()
		entrants_changed.emit(_waiting_entries())
		ball_requested.emit(current_entry)
		_set_game_state(GameState.PRE_DROP)

## Everyone whose ball has not yet resolved this round, in drop order. The
## current dropper is included until their ball scores. Typed, because
## Dictionary.values() is not.
func _waiting_entries() -> Array[Entry]:
	var waiting: Array[Entry] = []
	if current_entry != null and not current_entry.scored:
		waiting.append(current_entry)
	waiting.append_array(_queue)
	return waiting

func _insert_into_queue(entry: Entry) -> void:
	_queue.insert(_queue.bsearch_custom(entry, _by_total, false), entry)

func _by_total(a: Entry, b: Entry) -> bool:
	return a.total < b.total

# --- standings -------------------------------------------------------------

## Standings fill as balls resolve, not at registration, so round one starts
## empty rather than as a screen of zeroes. Mints the Standing on first score.
func _standing_for(player: Player) -> Standing:
	if standings.has(player.user_id):
		standings[player.user_id].display_name = player.display_name
	else:
		# standings only ever grows, so size() is the first-score index.
		standings[player.user_id] = Standing.make(player, standings.size())
	return standings[player.user_id]

# --- state transitions -----------------------------------------------------

func _set_game_state(new_state: GameState) -> void:
	game_state = new_state
	state_changed.emit(new_state)
