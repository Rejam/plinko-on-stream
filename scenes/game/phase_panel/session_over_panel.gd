extends CanvasLayer

## Shows the final standings card. Terminal — never dismissed, so it carries its
## own Back to Title button with no confirm step; there is no live session left
## to abandon.
##
## session_manager is assigned in the inspector. It points outside this scene,
## so an instance that loses the reference fails loudly rather than silently.

@export var session_manager: SessionManager

@onready var _standings_list: ItemList = $Scrim/Card/ResultsContainer/StandingsList
@onready var _back_to_title_button: Button = $Scrim/Card/ResultsContainer/BackToTitleButton

func _ready() -> void:
	visible = false
	if session_manager == null:
		push_error("%s has no SessionManager assigned" % name)
		return
	session_manager.state_changed.connect(_on_state_changed)
	_back_to_title_button.pressed.connect(_on_back_to_title)

func _on_state_changed(game_state: SessionManager.GameState) -> void:
	visible = game_state == SessionManager.GameState.SESSION_OVER
	if not visible:
		return
	_standings_list.clear()
	for standing in session_manager.sorted_standings():
		_standings_list.add_item("%s : %d" % [standing.display_name, standing.total])

func _on_back_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")
