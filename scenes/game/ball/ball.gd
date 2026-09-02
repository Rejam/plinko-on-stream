class_name Ball extends RigidBody2D

@onready var visible_on_screen: VisibleOnScreenNotifier2D = %VisibleOnScreen

var owner_player: Player = null

func _ready() -> void:
	visible_on_screen.screen_exited.connect(queue_free)
	
