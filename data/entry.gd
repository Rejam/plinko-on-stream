class_name Entry extends Resource

@export var player: Player
@export var column: int = 0
@export var total: int = 0

@warning_ignore("shadowed_variable")
static func make(player: Player, column: int, total: int) -> Entry: 
	var entry := Entry.new()
	entry.player = player
	entry.column = column
	entry.total = total
	return entry
