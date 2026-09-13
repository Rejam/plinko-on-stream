extends HBoxContainer

## Chat connection indicator for the ticker row. Self-subscribes to the Twitch
## autoload rather than taking an exported reference
##
## Green: Twitch sent the 001 welcome. Yellow: connecting or retrying, and it
## will probably fix itself. Red: gave up; click to retry

const COLOURS := {
	TwitchChat.ChatState.DISCONNECTED: Color(0.8, 0.2, 0.2),
	TwitchChat.ChatState.CONNECTING: Color(0.9, 0.7, 0.1),
	TwitchChat.ChatState.CONNECTED: Color(0.3, 0.75, 0.3),
}

@onready var _dot: ColorRect = $Dot

func _ready() -> void:
	Twitch.chat_state_changed.connect(_on_chat_state_changed)
	_on_chat_state_changed(Twitch.chat_state())

func _on_chat_state_changed(state: TwitchChat.ChatState) -> void:
	_dot.color = COLOURS[state]
	
	if state == TwitchChat.ChatState.DISCONNECTED:
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
	else: mouse_default_cursor_shape = CURSOR_ARROW

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		Twitch.retry_chat()
		accept_event()
