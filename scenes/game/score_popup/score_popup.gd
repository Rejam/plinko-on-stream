class_name ScorePopup extends CanvasLayer

const RISE_TIME := 0.25
const HOLD_TIME := 2.5
const FADE_TIME := 0.5
const START_SCALE := 0.7

@onready var _card: PanelContainer = %Card
@onready var _name_label: Label = %NameLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _ball_icon: TextureRect = %BallIcon
@onready var _confetti: CPUParticles2D = %Confetti
@onready var _dim: ColorRect = %Dim

var _tween: Tween


func _ready() -> void:
	visible = false
	# The theme styles Panel but not PanelContainer: copy it so in sync
	_card.add_theme_stylebox_override("panel", _card.get_theme_stylebox("panel", "Panel"))
	_card.modulate.a = 0.0
	_dim.modulate.a = 0.0
	# Not saved by the scene for a container child.
	_card.pivot_offset_ratio = Vector2(0.5, 0.5)


func show_drop(player: Player, bucket_points: int, peg_hits: int, points: int) -> void:
	_name_label.text = player.display_name
	_score_label.text = "%d + %d = %d" % [bucket_points, peg_hits, points]
	_ball_icon.texture = BallArt.texture_for(player.user_id)

	visible = true

	if _tween and _tween.is_valid():
		_tween.kill()

	_card.scale = Vector2(START_SCALE, START_SCALE)
	_card.modulate.a = 0.0
	_dim.modulate.a = 0.0

	_confetti.restart()

	_tween = create_tween()
	_tween.tween_property(_card, "scale", Vector2.ONE, RISE_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.parallel().tween_property(_card, "modulate:a", 1.0, RISE_TIME)
	_tween.parallel().tween_property(_dim, "modulate:a", 1.0, RISE_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(_card, "modulate:a", 0.0, FADE_TIME)
	_tween.parallel().tween_property(_dim, "modulate:a", 0.0, FADE_TIME)

	_tween.tween_callback(func() -> void: visible = false)
