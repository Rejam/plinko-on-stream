@tool
class_name Peg extends StaticBody2D

## Drawn, not textured. ball_puck.png was 8x8 upscaled 1.5x, so it pixelated,
## and tinting it was multiplicative — a grey source caps every colour you can
## reach. draw_circle is resolution independent and takes the colour directly,
## so any value works and nothing softens when the peg grows.

@export var colour := Color(Color.BLACK, 0.2):
	set(value):
		colour = value
		queue_redraw()

@onready var _cpu_particles_2d: CPUParticles2D = $CPUParticles2D
@onready var _collision: CollisionShape2D = $PegCollision

## Radius comes off the collider so the disc cannot drift from the shape the
## ball actually hits. One number, authored in one place.
var _radius := 6.0

## Multiplier the hit pulse animates. Deliberately not the node's scale:
## scaling a StaticBody2D scales its collision shape too, which would move the
## trap threshold around silently every time a peg was struck.
var _pulse := 1.0:
	set(value):
		_pulse = value
		queue_redraw()

var _tween: Tween

const PULSE_PEAK := 2.5
const PULSE_TIME := 0.2



func _ready() -> void:
	var shape := _collision.shape
	if shape is CircleShape2D:
		_radius = (shape as CircleShape2D).radius
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius * _pulse, colour, true, -1.0, true)


func hit() -> void:
	_cpu_particles_2d.modulate = colour
	_cpu_particles_2d.restart()
	if _tween and _tween.is_valid():
		_tween.kill()
	_pulse = PULSE_PEAK
	_tween = create_tween()
	_tween.tween_property(self, "_pulse", 1.0, PULSE_TIME).set_ease(Tween.EASE_OUT)
