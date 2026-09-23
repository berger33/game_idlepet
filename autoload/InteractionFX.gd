extends Node
## Feedback universal para todo Button: squash, overshoot, som e haptic.

const PRESS_SCALE: Vector2 = Vector2(0.94, 0.94)
const OVERSHOOT_SCALE: Vector2 = Vector2(1.025, 1.025)
var bound_buttons: Dictionary = {}


func bind_button(button: Button) -> void:
	var instance_id: int = button.get_instance_id()
	if bound_buttons.has(instance_id):
		return
	bound_buttons[instance_id] = true
	button.resized.connect(_center_pivot.bind(button))
	button.tree_exiting.connect(_forget.bind(instance_id))
	button.button_down.connect(_press.bind(button))
	button.button_up.connect(_release.bind(button))
	button.mouse_entered.connect(_hover.bind(button))
	button.mouse_exited.connect(_unhover.bind(button))
	button.focus_entered.connect(_hover.bind(button))
	button.focus_exited.connect(_unhover.bind(button))
	button.pressed.connect(_feedback.bind(button))
	_center_pivot(button)


func _center_pivot(button: Button) -> void:
	if is_instance_valid(button):
		button.pivot_offset = button.size * 0.5


func _press(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	_tween_scale(button, PRESS_SCALE, 0.07)


func _release(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var tween: Tween = button.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", OVERSHOOT_SCALE, 0.08)
	tween.tween_property(button, "scale", Vector2.ONE, 0.11)


func _hover(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled or OS.has_feature("mobile"):
		return
	_tween_scale(button, Vector2(1.015, 1.015), 0.1)


func _unhover(button: Button) -> void:
	if not is_instance_valid(button) or button.button_pressed:
		return
	_tween_scale(button, Vector2.ONE, 0.1)


func _feedback(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	AudioManager.play(&"tap")
	HapticsManager.light()
	_spawn_sparkle(button)


func _spawn_sparkle(button: Button) -> void:
	var sparkle: Label = Label.new()
	sparkle.text = "✦"
	sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkle.add_theme_font_size_override("font_size", 34)
	sparkle.add_theme_color_override("font_color", Color("fff3a6"))
	sparkle.position = button.size * 0.5 - Vector2(16, 22)
	button.add_child(sparkle)
	var tween: Tween = sparkle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sparkle, "position:y", sparkle.position.y - 38.0, 0.35)
	tween.tween_property(sparkle, "modulate:a", 0.0, 0.35)
	tween.tween_property(sparkle, "scale", Vector2(1.5, 1.5), 0.35)
	tween.set_parallel(false)
	tween.tween_callback(sparkle.queue_free)


func _tween_scale(button: Button, target: Vector2, duration: float) -> void:
	var tween: Tween = button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target, duration)


func _forget(instance_id: int) -> void:
	bound_buttons.erase(instance_id)
