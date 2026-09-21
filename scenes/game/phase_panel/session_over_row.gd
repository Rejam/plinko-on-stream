class_name SessionOverRow extends HBoxContainer

## One line on the session-over card: ball, name, total, round-top stars.
## Own scene rather than PlayerRow: the star column exists only here.
##
## The star column is always laid out and only made transparent at zero, so
## totals line up whether or not a row has stars. StarCount has a fixed width
## in the scene for the same reason (1 vs 10).

@onready var _ball: TextureRect = $BallIcon
@onready var _name: Label = $NameLabel
@onready var _total: Label = $TotalLabel
@onready var _stars: HBoxContainer = $Stars
@onready var _star_count: Label = $Stars/StarCount

## Call after the row is in the tree (@onready refs).
func setup(user_id: String, display_name: String, total: int, stars: int) -> void:
	_ball.texture = BallArt.texture_for(user_id)
	_name.text = display_name
	_total.text = str(total)
	_star_count.text = str(stars)
	_stars.modulate.a = 1.0 if stars > 0 else 0.0
