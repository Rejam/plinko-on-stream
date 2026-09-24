class_name PlayerList extends VBoxContainer

## Display-only list: a column of PlayerRows. clear() and add() are the whole API.

const ROW := preload("res://scenes/game/player_row/player_row.tscn")

## Removes rows immediately. queue_free alone would leave the old rows in the
## container, and visible, until the end of the frame.
func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func add(user_id: String, display_name: String, value_text: String) -> void:
	var row: PlayerRow = ROW.instantiate()
	add_child(row)
	row.setup(user_id, display_name, value_text)
