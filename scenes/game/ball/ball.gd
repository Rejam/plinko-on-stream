class_name Ball extends RigidBody2D

## Spin is cosmetic only. The body has friction 0, so contacts are purely normal
## and impart no torque — the ball would not rotate even with lock_rotation off.
## Rotating the sprite instead keeps the drop behaviour untouched while letting
## patterned balls read as rolling.

@onready var visible_on_screen: VisibleOnScreenNotifier2D = %VisibleOnScreen
@onready var _skin: Sprite2D = $Skin
@onready var _roll_radius: float = ($CollisionShape2D.shape as CircleShape2D).radius

## Multiplier on the rolling rate. 1.0 matches a ball rolling without slipping.
@export var spin_scale: float = 1.0

var owner_player: Player = null:
	set(value):
		owner_player = value
		if value != null and _skin != null:
			_apply_skin(value.user_id)

func _ready() -> void:
	visible_on_screen.screen_exited.connect(queue_free)
	if owner_player != null:
		_apply_skin(owner_player.user_id)

## Scales the shared texture to the collision radius so the ball on the board
## and the icon beside the player's name are the same artwork.
func _apply_skin(user_id: String) -> void:
	_skin.texture = BallArt.texture_for(user_id)
	var scale_factor := (_roll_radius * 2.0) / float(BallArt.SIZE)
	_skin.scale = Vector2(scale_factor, scale_factor)

func _physics_process(delta: float) -> void:
	if freeze or is_zero_approx(_roll_radius):
		return
	_skin.rotation += (linear_velocity.x / _roll_radius) * spin_scale * delta
