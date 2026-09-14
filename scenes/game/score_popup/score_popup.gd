class_name ScorePopup extends CanvasLayer

## Fanfare for a resolved drop. The score stopped being readable from the bucket
## the ball landed in once peg hits started paying, so the number has to be shown
## or the audience cannot follow why the standings moved.
##
## Scale and fade are tweened on the Content control, not on this CanvasLayer:
## a CanvasLayer is not a CanvasItem and has neither property.

const RISE_TIME := 0.25
const HOLD_TIME := 2.5
const FADE_TIME := 0.5
const START_SCALE := 0.7

@onready var _content: Control = %Content
@onready var _name_label: Label = %NameLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _ball_icon: TextureRect = %BallIcon
@onready var _confetti: CPUParticles2D = %Confetti
@onready var _dim: ColorRect = %Dim

var _tween: Tween


func _ready() -> void:
	_content.modulate.a = 0.0
	_dim.modulate.a = 0.0


func show_drop(player: Player, points: int, centre: Vector2) -> void:
	_name_label.text = player.display_name
	_score_label.text = "+%d" % points
	_ball_icon.texture = BallArt.texture_for(player.user_id)

	if _tween and _tween.is_valid():
		_tween.kill()

	# Centred on the board, not the viewport: the board occupies the left column
	# only, so screen centre sits off to the right of it. Dim stays fullscreen.
	_content.reset_size()
	_content.pivot_offset = _content.size * 0.5
	_content.position = centre - _content.size * 0.5

	_content.scale = Vector2(START_SCALE, START_SCALE)
	_content.modulate.a = 0.0
	_dim.modulate.a = 0.0

	# Burst from the middle of the popup. Parented to Content so it inherits the
	# fade, which is why it is positioned in Content's local space rather than
	# on the CanvasLayer.
	_confetti.position = _content.size * 0.5
	_confetti.restart()

	# parallel() attaches to the tweener it follows, rather than a mode that
	# stays switched on — with set_parallel the hold interval can silently join
	# the rise group instead of following it, collapsing the hold to nothing.
	_tween = create_tween()
	_tween.tween_property(_content, "scale", Vector2.ONE, RISE_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.parallel().tween_property(_content, "modulate:a", 1.0, RISE_TIME)
	_tween.parallel().tween_property(_dim, "modulate:a", 1.0, RISE_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(_content, "modulate:a", 0.0, FADE_TIME)
	_tween.parallel().tween_property(_dim, "modulate:a", 0.0, FADE_TIME)
