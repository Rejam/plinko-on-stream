class_name Standing extends Resource

@export var user_id: String = ""
@export var display_name: String = ""
@export var total: int = 0
## Registration order. Tie-break for display so equal totals hold their position
## instead of reshuffling on every drop.
@export var seq: int = 0
var round_points: Dictionary[int, int] = {}

@warning_ignore("shadowed_variable")
static func make(player: Player, seq: int) -> Standing:
	var standing := Standing.new()
	standing.user_id = player.user_id
	standing.display_name = player.display_name
	standing.seq = seq
	return standing

func points_in(round_number: int) -> int:
	return round_points.get(round_number, 0)
