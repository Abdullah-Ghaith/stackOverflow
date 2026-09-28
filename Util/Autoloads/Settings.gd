extends Node


var mouse_sensitivity: float = 0.3
var multiplayer_enabled: bool = false

enum SettingType {Sensitivity}


# ----
func adjust_setting(setting: SettingType, value : float) -> void:
	match setting:
		SettingType.Sensitivity:
			mouse_sensitivity = value
