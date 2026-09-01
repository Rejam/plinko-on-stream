class_name Player extends Resource
## Identity is user_id — dedupe and standings key on it.
## display_name is for labels only; it can change.

@export var user_id: String = ""
@export var display_name: String = ""

static func make(id: String, name: String) -> Player:
	var player := Player.new()
	player.user_id = id
	player.display_name = name
	return player
