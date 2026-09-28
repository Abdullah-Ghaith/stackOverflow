class_name ShakingCamera extends Camera3D

@export var shake_fade: float = 10.0

var _x_shake_strength: float = 0.0
var _y_shake_strength: float = 0.0

@onready var _base_rotation: Vector3 = self.rotation

func _ready() -> void:
	SignalBus.shake_camera.connect(trigger_shake)

func trigger_shake(x_shake: float, y_shake: float) -> void:
	_x_shake_strength = x_shake
	_y_shake_strength = y_shake

func _process(delta: float) -> void:
	if _x_shake_strength > 0:
		_x_shake_strength = lerp(_x_shake_strength, 0.0, shake_fade * delta)
	if _y_shake_strength > 0:
		_y_shake_strength = lerp(_y_shake_strength, 0.0, shake_fade * delta)

	if _x_shake_strength > 0.001 or _y_shake_strength > 0.001:
		rotation = _base_rotation + Vector3(
			randf_range(-_x_shake_strength, _x_shake_strength),
			randf_range(-_y_shake_strength, _y_shake_strength),
			0.0
		)
