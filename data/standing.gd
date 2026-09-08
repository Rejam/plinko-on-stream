class_name Standing extends Resource

@export var user_id: String = ""
@export var display_name: String = ""
@export var total: int = 0
@export var round_wins: int = 0
var round_points: Dictionary[int, int] = {}

static func make(player: Player) -> Standing:
	var standing := Standing.new()
	standing.user_id = player.user_id
	standing.display_name = player.display_name
	return standing

func points_in(round_number: int) -> int:
	return round_points.get(round_number, 0)
