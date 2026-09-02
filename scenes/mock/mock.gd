extends Control

const NAMES: PackedStringArray = [
	"quayside_kev", "hadrianstan", "bellringer92", "greggs_enjoyer",
	"toon_army_99", "pigeon_lad", "stotty_cake", "mag_pie",
	"dene_walker", "wor_lass", "tyne_bridge_fan", "coble_boat",
]
const COLUMNS: PackedStringArray = ["3", "1", "", "5", "banana", "7", "2", "99", "4", "6"]

@onready var add_entrants_button: Button = $AddEntrantsButton

var _next_id: int = 1

func _ready() -> void:
	add_entrants_button.pressed.connect(_on_ten_entrants_pressed)
	
func _on_ten_entrants_pressed() -> void:
	for i in 3:
		var col := COLUMNS[i % COLUMNS.size()]
		Twitch.submit_entry(_new_player(), col)

func _new_player() -> Player:
	var id := "mock_%d" % _next_id
	var _name: String = NAMES[(_next_id - 1) % NAMES.size()]
	_next_id += 1
	return Player.make(id, _name)
