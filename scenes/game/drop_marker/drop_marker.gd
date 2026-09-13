@tool
class_name DropMarker extends Node2D

## Target ring with the column number at its centre, drawn rather than textured
## so it scales with the board without new art. @tool so the board shows it in
## the editor.
##
## Drawn centred on its own origin, matching the drop position Marker2D it sits
## under — nothing here assumes a top-left origin.

@export_range(1, 16) var column: int = 1:
	set(value):
		column = value
		queue_redraw()

@export var radius: float = 40.0:
	set(value):
		radius = value
		queue_redraw()

## Single flat disc rather than a banded target — concentric rings competed with
## the ball for attention once one was falling through them.
@export var disc_colour: Color = Color(0.05, 0.05, 0.07, 0.45):
	set(value):
		disc_colour = value
		queue_redraw()

@export var number_colour: Color = Color(1, 1, 1, 0.65):
	set(value):
		number_colour = value
		queue_redraw()

@export var font_size: int = 26:
	set(value):
		font_size = value
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, disc_colour)
	var font := ThemeDB.fallback_font
	# draw_string anchors on the text baseline, so nudge down by ~a third of the
	# font size to sit it optically centred in the disc.
	draw_string(font, Vector2(-radius, font_size * 0.36), str(column),
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, number_colour)
