extends Control

## Scrolling ticker: join instruction, then the top TOP_N session standings.
##
## Two copies of the same strip chase each other, so the loop has no seam and
## no reset jump. StripB sits exactly one strip-width right of StripA; when A
## has travelled a full strip-width left, the offset wraps and they swap roles
## without anything moving on screen.
##
## The strip is padded to at least this Control's width. Without that padding a
## short strip — three players, say — would put its second copy on screen while
## the first was still visible, showing the same names twice at once. Padding
## to the viewport width means a repeat cannot appear until the previous copy
## has fully scrolled off.
##
## Uses %SessionManager rather than an exported reference because this lives in
## game.tscn. Extracting it to its own scene would break that lookup — % only
## resolves within its own scene.

## Pixels per second.
const SPEED := 45.0
const SEPARATOR := "     •     "
const JOIN_TEXT := "Type !plinko <column> in chat to join"
const TOP_N := 5

@onready var _session_manager: SessionManager = %SessionManager
@onready var _strip_a: Label = $StripA
@onready var _strip_b: Label = $StripB

var _offset := 0.0
var _strip_width := 0.0

func _ready() -> void:
	for strip in [_strip_a, _strip_b]:
		strip.autowrap_mode = TextServer.AUTOWRAP_OFF
		strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resized.connect(_remeasure)
	_session_manager.standings_updated.connect(_on_standings_updated)
	_set_strip_text(JOIN_TEXT)

func _process(delta: float) -> void:
	if _strip_width <= 0.0:
		return
	_offset -= SPEED * delta
	# One strip-width of travel puts B exactly where A started.
	if _offset <= -_strip_width:
		_offset += _strip_width
	_strip_a.position.x = _offset
	_strip_b.position.x = _offset + _strip_width

## Standings arrive already sorted by total descending, so the top N is a slice.
func _on_standings_updated(standings: Array[Standing]) -> void:
	_set_strip_text(_compose(standings))

func _compose(standings: Array[Standing]) -> String:
	var parts: PackedStringArray = [JOIN_TEXT]
	for i in mini(TOP_N, standings.size()):
		parts.append("%d. %s %d" % [i + 1, standings[i].display_name, standings[i].total])
	return SEPARATOR.join(parts)

func _set_strip_text(text: String) -> void:
	_strip_a.text = text
	_strip_b.text = text
	_remeasure()

## reset_size() shrinks each Label to its text, which is what makes the measured
## width the text width rather than the Control's. Re-run on resize because the
## padding below depends on this Control's current width.
func _remeasure() -> void:
	for strip in [_strip_a, _strip_b]:
		strip.reset_size()
		strip.position.y = (size.y - strip.size.y) / 2.0
	# The separator is inside the text, so a trailing gap is needed too —
	# otherwise the last entry butts against the next copy's join text.
	var content := _strip_a.size.x + _strip_a.get_theme_font("font").get_string_size(
		SEPARATOR, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_strip_a.get_theme_font_size("font_size")).x
	_strip_width = maxf(content, size.x)
	_offset = 0.0
