extends Node


func light() -> void:
	if bool(GameState.settings.get("haptics", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(25, 0.25)


func success() -> void:
	if bool(GameState.settings.get("haptics", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(55, 0.5)


func error() -> void:
	if bool(GameState.settings.get("haptics", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(90, 0.65)
