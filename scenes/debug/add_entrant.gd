extends Control

const NAMES: PackedStringArray = [
	"quayside_kev", "hadrianstan", "bellringer92", "greggs_enjoyer",
	"toon_army_99", "pigeon_lad", "stotty_cake", "mag_pie",
	"dene_walker", "wor_lass", "tyne_bridge_fan", "coble_boat",
]
const COLUMNS: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-3", "3.7", "banana", "", 7, []]

var _next_id: int = 1

func _ready() -> void:
	self.pressed.connect(_on_entrant_pressed)
	
func _on_entrant_pressed() -> void:
	var col := COLUMNS[randi_range(0, COLUMNS.size() - 1)]
	Twitch.submit_entry(_new_player(), col)

func _new_player() -> Player:
	var id := "mock_%d" % _next_id
	var _name: String = NAMES[(_next_id - 1) % NAMES.size()]
	_next_id += 1
	return Player.make(id, _name)
