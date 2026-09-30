class_name TwitchPlayer extends Resource
## Identity is user_id — dedupe and standings key on it.
## display_name is for labels only; it can change.

@export var user_id: String = ""
@export var display_name: String = ""

static func make(id: String, name: String) -> TwitchPlayer:
	var player := TwitchPlayer.new()
	player.user_id = id
	player.display_name = name
	return player
