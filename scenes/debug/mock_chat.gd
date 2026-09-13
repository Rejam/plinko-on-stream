extends VBoxContainer

## Mock chat. Stands in for Twitch.entry_received so registration, dedupe and
## drop order can be exercised without a live channel.
##
## user_id is derived from the display name, so one name is one viewer across
## presses and across rounds. That stable id is what makes dedupe and
## total-based queue insertion testable. A fresh Player is minted per press,
## matching real chat — nothing here holds a Player across rounds.

const NAMES: PackedStringArray = [
	"quayside_kev", "hadrianstan", "bellringer92", "greggs_enjoyer",
	"toon_army_99", "pigeon_lad", "stotty_cake", "mag_pie",
	"dene_walker", "wor_lass", "tyne_bridge_fan", "coble_boat",
	"testing_123", "stormy", "po", "jan", "brynn_start", "fudder"
]

## Columns 1..SAFE_COLUMN_MAX are assumed valid on every board, since the script
## has no way to ask. Raise it to your real column count for a wider spread.
const SAFE_COLUMN_MAX := 7
## Rejected on any board: to_int() gives < 1, or a number no board reaches.
## Digits above 7 are deliberately absent — board1 has 8 columns, so "8" is a
## real entry there. "3.7" is absent too: to_int() truncates it to a valid 3.
const JUNK_COLUMNS: PackedStringArray = ["0", "-3", "banana", "", "99"]

@onready var add_button: Button = %AddEntrantButton
@onready var re_enter_button: Button = %ReEnterButton
@onready var junk_button: Button = %JunkEntryButton

var _next_name: int = 0
var _seen: PackedStringArray = []

func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	re_enter_button.pressed.connect(_on_re_enter_pressed)
	junk_button.pressed.connect(_on_junk_pressed)

## Next name in the list, valid column. Wraps after NAMES.size() presses, which
## is itself a dedupe. Only recorded once the entry is known to be valid.
func _on_add_pressed() -> void:
	var display_name := NAMES[_next_name % NAMES.size()]
	_next_name += 1
	Twitch.submit_entry(_mint(display_name), _safe_column())
	if not _seen.has(display_name):
		_seen.append(display_name)

## A name that has entered at some point this session. Same round: dedupe, the
## entry is replaced in place. Later round: same id, non-zero total, inserted by
## total rather than appended.
func _on_re_enter_pressed() -> void:
	if _seen.is_empty():
		push_warning("Mock chat: nobody has entered yet")
		return
	var display_name := _seen[randi_range(0, _seen.size() - 1)]
	Twitch.submit_entry(_mint(display_name), _safe_column())

## Parser fuzzing only. Never recorded — none of these should reach registration.
func _on_junk_pressed() -> void:
	var display_name := NAMES[randi_range(0, NAMES.size() - 1)]
	Twitch.submit_entry(_mint(display_name), JUNK_COLUMNS[randi_range(0, JUNK_COLUMNS.size() - 1)])

func _safe_column() -> String:
	return str(randi_range(1, SAFE_COLUMN_MAX))

func _mint(display_name: String) -> Player:
	return Player.make("mock_%s" % display_name, display_name)
