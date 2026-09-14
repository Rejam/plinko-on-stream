@tool
class_name Ramp extends StaticBody2D

## A deflector that breaks a ball out of a wall corridor. Place it against a
## wall with roughly half its width overlapping; the exposed face does the work.
##
## The 45 degree face is load-bearing, not decorative. In the gap between the
## wall and the face — which narrows downward — the wall normal points inward
## and the ramp normal points inward and up, so both push the ball the same way
## horizontally and nothing can balance it. The ball always slides clear. A
## shallower face erodes that argument and eventually holds a ball.
##
## Drawn from the same numbers the collider uses, so the art cannot drift from
## the shape. Same reason bucket.gd draws itself rather than carrying a sprite.

@export var size := 120.0:
	set(value):
		size = maxf(value, 1.0)
		_refresh()

@export var fill := Color(0.85, 0.2, 0.45):
	set(value):
		fill = value
		queue_redraw()

## Matches the walls by default. Friction stays 0 everywhere — see the ball's
## physics setup; bounce lives on the static side.
@export var bounce := 0.9:
	set(value):
		bounce = clampf(value, 0.0, 1.0)
		_refresh()

@onready var _collision: CollisionShape2D = $Collision


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return

	var rect := RectangleShape2D.new()
	rect.size = Vector2(size, size)
	_collision.shape = rect
	_collision.rotation = PI * 0.25

	var p_material := PhysicsMaterial.new()
	p_material.friction = 0.0
	p_material.bounce = bounce
	physics_material_override = p_material

	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, PI * 0.25, Vector2.ONE)
	draw_rect(Rect2(Vector2(size, size) * -0.5, Vector2(size, size)), fill)
