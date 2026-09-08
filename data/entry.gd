class_name Entry extends Resource

@export var player: Player
@export var column: int = 0
@export var total: int = 0

static func make(_player: Player, _column: int, _total: int) -> Entry:
	var entry := Entry.new()
	entry.player = _player
	entry.column = _column
	entry.total = _total
	return entry
