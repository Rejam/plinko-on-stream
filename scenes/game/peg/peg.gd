class_name Peg extends StaticBody2D

@onready var _cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@onready var _sprite_2d: Sprite2D = $Sprite2D

var _tween: Tween

func hit() -> void:
	_cpu_particles_2d.restart()
	if _tween and _tween.is_valid():
		_tween.kill()
	_sprite_2d.scale = Vector2(4, 4)
	_tween = create_tween()
	_tween.tween_property(_sprite_2d, "scale", Vector2(1.5, 1.5), 0.2).set_ease(Tween.EASE_OUT)
