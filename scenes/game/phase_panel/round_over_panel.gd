extends CanvasLayer

## Shows the round-over card and fills it from standings on entry. Owns its own
## visibility and its Next Round button — Game does not toggle it.
##
## session_manager is assigned in the inspector. It points outside this scene,
## so an instance that loses the reference fails loudly rather than silently.

@export var session_manager: SessionManager

@onready var _standings_list: ItemList = $Scrim/Card/ResultsContainer/StandingsList
@onready var _next_round_button: Button = $Scrim/Card/ResultsContainer/NextRoundButton

func _ready() -> void:
	visible = false
	if session_manager == null:
		push_error("%s has no SessionManager assigned" % name)
		return
	session_manager.state_changed.connect(_on_state_changed)
	_next_round_button.pressed.connect(session_manager.next_round)

## Filled on entry rather than from standings_updated — the panel is hidden
## while scores move.
func _on_state_changed(game_state: SessionManager.GameState) -> void:
	visible = game_state == SessionManager.GameState.ROUND_OVER
	if not visible:
		return
	_standings_list.clear()
	for standing in session_manager.sorted_standings():
		_standings_list.add_item("%s : %d" % [standing.display_name, standing.total],
			BallArt.texture_for(standing.user_id))
