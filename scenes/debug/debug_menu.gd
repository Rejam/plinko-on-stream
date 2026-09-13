extends CanvasLayer


@onready var panel: PanelContainer = %PanelContainer
@onready var toggle_button: Button = %ToggleButton
@onready var kill_chat_button: Button = %KillChatButton
@onready var force_chat_dead_button: Button = %ForceChatDeadButton

func _ready() -> void:
	if not OS.is_debug_build(): 
		queue_free()
		return
	panel.hide()
	toggle_button.pressed.connect(_on_toggle_pressed)
	kill_chat_button.pressed.connect(_on_kill_chat_pressed)
	force_chat_dead_button.pressed.connect(_on_force_chat_dead_pressed)

## Closes the live socket, which is a real close through the real detection
## path — the same thing Twitch's own RECONNECT command does. Reaches into
## Twitch's internals rather than adding a debug-only method to chat.gd; this
## whole node is freed outside debug builds, so none of it ships.
##
## Cannot reproduce a half-open socket: that needs a real TCP write to fail.
func _on_kill_chat_pressed() -> void:
	Twitch._chat._socket.close()

## Jumps straight to the give-up state: attempts already exhausted, so
## _on_connection_lost stops retrying and goes red. Tests the red state and the
## recovery from it, nothing else — detection and the retry loop are bypassed.
func _on_force_chat_dead_pressed() -> void:
	Twitch._chat._attempts = TwitchChat.MAX_ATTEMPTS
	Twitch._chat._on_connection_lost("debug: forced dead")

func _on_toggle_pressed() -> void:
	panel.visible = not panel.visible

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		panel.visible = not panel.visible
