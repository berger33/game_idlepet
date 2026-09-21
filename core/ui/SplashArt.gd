class_name SplashArt
extends RefCounted
## Splash com barra de progresso que só aparece se carregamento >1s (P1).
## Sem assets: ColorRect + Label + ProgressBar via código, overlay no Main.

static func make_splash(parent: Control) -> Dictionary:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	parent.add_child(layer)
	var root: ColorRect = ColorRect.new()
	root.color = Color("ffe3ec")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var center: Control = Control.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var title: Label = Label.new()
	title.text = "🐾 Pet Shop Tycoon"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 600)
	title.size = Vector2(1080, 100)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("263238"))
	center.add_child(title)
	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.color = Color("263238", 0.15)
	bar_bg.position = Vector2(140, 960)
	bar_bg.size = Vector2(800, 22)
	center.add_child(bar_bg)
	var bar: ColorRect = ColorRect.new()
	bar.color = Color("ff8fb1")
	bar.position = Vector2(140, 960)
	bar.size = Vector2(0, 22)
	center.add_child(bar)
	var tip: Label = Label.new()
	tip.text = Loc.t("LOADING") if Loc.has_method("t") else "Carregando..."
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.position = Vector2(0, 1020)
	tip.size = Vector2(1080, 60)
	tip.add_theme_font_size_override("font_size", 26)
	tip.add_theme_color_override("font_color", Color("8d5a77"))
	center.add_child(tip)
	return {"layer": layer, "root": root, "bar": bar, "bar_bg": bar_bg, "title": title, "tip": tip, "elapsed": 0.0, "visible": false}

static func update_splash(splash: Dictionary, delta: float, loading_progress: float) -> bool:
	# Retorna true se ainda está carregando
	splash["elapsed"] = float(splash["elapsed"]) + delta
	var elapsed: float = float(splash["elapsed"])
	# Só mostra se >1s (requisito)
	if elapsed > 1.0 and not bool(splash["visible"]):
		splash["visible"] = true
		var root: ColorRect = splash["root"] as ColorRect
		if is_instance_valid(root):
			root.visible = true
	if bool(splash["visible"]):
		var bar: ColorRect = splash["bar"] as ColorRect
		if is_instance_valid(bar):
			var target_w: float = 800.0 * clampf(loading_progress, 0.0, 1.0)
			bar.size.x = lerpf(bar.size.x, target_w, delta * 6.0)
	# Se progresso 100% e já passou 1s, pode esconder
	if loading_progress >= 1.0 and elapsed > 0.5:
		return false
	return true

static func hide_splash(splash: Dictionary) -> void:
	if splash.is_empty():
		return
	var layer: CanvasLayer = splash.get("layer") as CanvasLayer
	if is_instance_valid(layer):
		var tween: Tween = layer.create_tween()
		tween.tween_property(splash["root"], "modulate:a", 0.0, 0.35)
		tween.tween_callback(layer.queue_free)
