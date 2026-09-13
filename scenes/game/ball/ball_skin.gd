@tool
class_name BallSkin extends Node2D

## Drawn rather than textured, so every viewer gets a distinct ball with no art.
## Lives as a child of the ball body and is rotated cosmetically by Ball — the
## body itself has lock_rotation on.
##
## Appearance is derived from user_id, so the same viewer gets the same ball
## every round and every session without anything being stored.

enum Pattern { SOLID, HALVED, RING, QUARTERED }

@export var pattern: Pattern = Pattern.SOLID:
	set(value):
		pattern = value
		queue_redraw()

@export var base_colour: Color = Color(0.85, 0.25, 0.25):
	set(value):
		base_colour = value
		queue_redraw()

@export var accent_colour: Color = Color(0.97, 0.97, 0.95):
	set(value):
		accent_colour = value
		queue_redraw()

@export var outline_colour: Color = Color(0.05, 0.05, 0.07):
	set(value):
		outline_colour = value
		queue_redraw()

@export var radius: float = 19.0:
	set(value):
		radius = value
		queue_redraw()

## Saturation and value are fixed so no hash can land on something that
## disappears against a board background.
static func colours_for(user_id: String) -> Array[Color]:
	var h := absi(user_id.hash())
	var hue := float(h % 360) / 360.0
	var accent_hue := fposmod(hue + 0.5, 1.0)
	return [Color.from_hsv(hue, 0.68, 0.92), Color.from_hsv(accent_hue, 0.45, 0.98)]

static func pattern_for(user_id: String) -> Pattern:
	var h := absi(user_id.hash())
	return (h / 360) % Pattern.size() as Pattern

func apply(user_id: String) -> void:
	var pair := colours_for(user_id)
	base_colour = pair[0]
	accent_colour = pair[1]
	pattern = pattern_for(user_id)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, outline_colour)
	var r := radius * 0.88
	draw_circle(Vector2.ZERO, r, base_colour)
	match pattern:
		Pattern.HALVED:
			draw_arc_wedge(r, 0.0, PI)
		Pattern.RING:
			draw_circle(Vector2.ZERO, r * 0.55, accent_colour)
		Pattern.QUARTERED:
			draw_arc_wedge(r, 0.0, PI * 0.5)
			draw_arc_wedge(r, PI, PI * 1.5)
		_:
			pass

## Filled wedge between two angles, built as a triangle fan so it works without
## a texture.
func draw_arc_wedge(r: float, from: float, to: float) -> void:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var steps := 16
	for i in range(steps + 1):
		var t := from + (to - from) * (float(i) / steps)
		points.append(Vector2(cos(t), sin(t)) * r)
	draw_colored_polygon(points, accent_colour)
