class_name Ball extends RigidBody2D

@onready var visible_on_screen: VisibleOnScreenNotifier2D = %VisibleOnScreen

func _ready() -> void:
	visible_on_screen.screen_exited.connect(queue_free)
	
