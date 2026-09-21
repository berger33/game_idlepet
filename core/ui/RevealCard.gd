class_name RevealCard
extends RefCounted
## Cartão modal de revelação (auditoria de retenção: tudo que importava —
## novo pet, novo capítulo, cofre, conquista, presente — era um toast de 1,4 s).
## Um cartão por vez, em fila: vários eventos no mesmo instante (level-up +
## pet + capítulo) aparecem em sequência, cada um com seu momento.
## Estático e sem cena própria: usa as factories do Main (_button/_style,
## mesmo padrão de SessionFeedback) para não engordar o Main.
##
## spec: {
##   "title": String, "body": String, "color": Color,
##   "image": String (caminho de recurso, opcional), "primary": String (texto do botão),
##   "secondary": String (opcional), "on_secondary": Callable (opcional),
##   "sound": StringName (opcional), "on_close": Callable (opcional)
## }

static var _queue: Array[Dictionary] = []
static var _active: bool = false


static func enqueue(main: Control, spec: Dictionary) -> void:
	_queue.append(spec)
	if not _active:
		_show_next(main)


static func is_showing() -> bool:
	return _active


static func _show_next(main: Control) -> void:
	if _queue.is_empty() or not is_instance_valid(main):
		_active = false
		return
	_active = true
	var spec: Dictionary = _queue.pop_front()
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.09, 0.12, 0.15, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(backdrop)
	var card: PanelContainer = PanelContainer.new()
	var accent: Color = spec.get("color", main.PINK)
	card.add_theme_stylebox_override("panel", main._style(Color("ffffff", 0.97), 40, 34, accent, 6))
	# Ancorado no centro e crescendo para os dois lados: o cartão fica centrado
	# seja qual for a altura final do texto (sem medir layout na mão).
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size = Vector2(860, 0)
	card.modulate.a = 0.0
	backdrop.add_child(card)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	card.add_child(box)
	box.add_child(_label(String(spec.get("title", "")), 44, accent.darkened(0.25), true))
	var image_path: String = String(spec.get("image", ""))
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		var portrait: TextureRect = TextureRect.new()
		portrait.texture = load(image_path)
		portrait.custom_minimum_size = Vector2(360, 360)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(portrait)
	box.add_child(_label(String(spec.get("body", "")), 30, main.CHARCOAL, true))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)
	var close: Callable = func() -> void:
		if spec.has("on_close") and (spec["on_close"] as Callable).is_valid():
			(spec["on_close"] as Callable).call()
		backdrop.queue_free()
		AudioManager.play(&"tap")
		# Próximo cartão só depois que este saiu da árvore (evita empilhar).
		main.get_tree().process_frame.connect(func() -> void: _show_next(main), CONNECT_ONE_SHOT)
	var secondary_text: String = String(spec.get("secondary", ""))
	if not secondary_text.is_empty():
		var secondary: Button = main._button(secondary_text, main.BLUE, 360, 96)
		secondary.pressed.connect(
			func() -> void:
				if spec.has("on_secondary") and (spec["on_secondary"] as Callable).is_valid():
					(spec["on_secondary"] as Callable).call()
				close.call()
		)
		buttons.add_child(secondary)
	var primary: Button = main._button(String(spec.get("primary", "OK")), accent, 360, 96)
	primary.pressed.connect(close)
	buttons.add_child(primary)
	# Anima depois do layout calcular o tamanho real (pivô no centro certo).
	main._pop_panel.call_deferred(card)
	var sound: StringName = StringName(String(spec.get("sound", "")))
	if sound != &"":
		AudioManager.play(sound)
	HapticsManager.success()


static func _label(text: String, size: int, color: Color, wrap: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(780, 0)
	return label
