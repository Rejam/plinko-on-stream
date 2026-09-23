extends Node2D

@onready var animatable_body_2d: AnimatableBody2D = %AnimatableBody2D

@export var anti_clockwise : bool = false

func _physics_process(delta: float) -> void:
	if anti_clockwise:
		animatable_body_2d.rotation -= delta * 8
	else:
		animatable_body_2d.rotation += delta * 8
	
