class_name CameraShakeNode extends Node

@export var x_camera_shake : float = 10.0
@export var y_camera_shake : float = 10.0


func _shake_camera():
	SignalBus.shake_camera.emit(x_camera_shake, y_camera_shake)
