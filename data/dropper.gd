class_name Dropper extends Resource
## Identity is user_id — dedupe and standings key on it.
## display_name is for labels only; it can change.

@export var user_id: String = ""
@export var display_name: String = ""

static func make(id: String, name: String) -> Dropper:
	var dropper := Dropper.new()
	dropper.user_id = id
	dropper.display_name = name
	return dropper
