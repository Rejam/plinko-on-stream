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

## Alternating bands, drawn outermost first. Filled rather than outlined so the
## marker reads against any board background instead of relying on contrast
## with whatever is behind it.
@export var band_colour: Color = Color(0.86, 0.18, 0.18):
	set(value):
		band_colour = value
		queue_redraw()

@export var alt_band_colour: Color = Color(0.97, 0.97, 0.95):
	set(value):
		alt_band_colour = value
		queue_redraw()

@export var edge_colour: Color = Color(0.06, 0.06, 0.08, 0.85):
	set(value):
		edge_colour = value
		queue_redraw()

@export var font_size: int = 30:
	set(value):
		font_size = value
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, edge_colour)
	draw_circle(Vector2.ZERO, radius * 0.92, band_colour)
	draw_circle(Vector2.ZERO, radius * 0.66, alt_band_colour)
	draw_circle(Vector2.ZERO, radius * 0.40, band_colour)
	var font := ThemeDB.fallback_font
	# draw_string anchors on the text baseline, so nudge down by ~a third of the
	# font size to sit it optically centred in the ring.
	draw_string(font, Vector2(-radius, font_size * 0.36), str(column),
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, alt_band_colour)
