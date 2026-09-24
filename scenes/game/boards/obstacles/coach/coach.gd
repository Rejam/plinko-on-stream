extends Node2D

@export var speed: float = 200.0
## Root x at which the coach art is fully past the board's right edge.
## The art starts 40px left of the root, and the board is 1600 wide.
@export var end_x: float = 1640.0
@export var start_delay: float = 0.0

@onready var audio: AudioStreamPlayer2D = %AudioStreamPlayer2D

var _start_x: float
var _timer := 0.0

func _ready() -> void:
	_start_x = position.x


func _physics_process(delta: float) -> void:
	
	if not _timer > start_delay:
		_timer += delta
		return
		
	position.x += speed * delta
	if position.x > end_x:
		position.x = _start_x


func on_ball_hit() -> void:
	if not audio.playing:
		audio.play()
