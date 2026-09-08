class_name RoundManager extends Node 

enum RoundState { REGISTRATION, PRE_DROP, DROPPING, DROP_RESOLVED, FINISHED }

signal round_state_changed(round_state: RoundState)
signal ball_requested(entry: Entry)
signal ball_released
signal entrants_changed(entries: Array[Entry])
signal drop_scored(player: Player, base_value: int)
signal entrant_registered(player: Player)

var round_state: RoundState = RoundState.REGISTRATION
var current_entry: Entry = null
var _entries: Dictionary[String, Entry] = {}
var _queue: Array[Entry] = []

static func get_round_state_label_text(state: RoundState) -> String:
	return RoundState.keys()[state]
	
func end_registration() -> void:
	if round_state != RoundState.REGISTRATION:
		return
	_next_entrant()

func register_entrant(player: Player, column: int, total: int) -> void:
	if round_state != RoundState.REGISTRATION:
		return
	var entry := Entry.make(player, column, total)
	if _entries.has(player.user_id):
		var old_entry = _entries[player.user_id]
		_queue.erase(old_entry)
	
	_entries[player.user_id] = entry
	_insert_into_queue(entry)
	entrants_changed.emit(_entries.values())
	entrant_registered.emit(player)

func notify_drop_scored(player: Player, base_value: int) -> void:
	# round_state leaves DROPPING as soon as a ball scores, so a second
	# report from the same ball is ignored.
	if round_state != RoundState.DROPPING:
		return
	if player.user_id != current_entry.player.user_id:
		push_error("Scored ball belongs to %s, expected %s" % [player.display_name, current_entry.player.display_name])
		return
	_set_round_state(RoundState.DROP_RESOLVED)
	drop_scored.emit(player, base_value)
	
func _next_entrant() -> void:
	if _queue.is_empty():
		current_entry = null
		_set_round_state(RoundState.FINISHED)
	else:
		current_entry = _queue.pop_front()
		entrants_changed.emit(_queue.duplicate())
		ball_requested.emit(current_entry)
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
	
func begin_round() -> void:
	_entries.clear()
	_queue.clear()
	entrants_changed.emit([] as Array[Entry])
	current_entry = null
	_set_round_state(RoundState.REGISTRATION)

func _set_round_state(new_state: RoundState) -> void:
	round_state = new_state
	round_state_changed.emit(new_state)
	
func redrop() -> void:
	if round_state != RoundState.DROPPING:
		return
	ball_requested.emit(current_entry)
	_set_round_state(RoundState.PRE_DROP)

func _insert_into_queue(entry: Entry) -> void:
	_queue.insert(_queue.bsearch_custom(entry, _by_total), entry)

func _by_total(a: Entry, b: Entry) -> bool:
	return a.total < b.total
