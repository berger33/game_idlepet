extends Control
## Guia Bia — overlay do tutorial e dos "primeiros passos". Escurece a tela ao
## redor do alvo (4 retângulos, sem shader), pulsa a borda, desenha a seta e a
## mãozinha (toque ou arraste real: da prateleira até o pet) e mostra a Bia
## num cartão com retrato + balão em máquina de escrever, sempre no lado
## oposto ao alvo. Sem voz: toda a orientação é visual. Não bloqueia o jogo
## (mouse_filter IGNORE no overlay; só o cartão captura toques).

const GUIDE_FONT: Font = preload("res://art/fonts/DejaVuSans-Bold.ttf")
const PORTRAITS: Dictionary = {
	&"hello": preload("res://art/characters/bia_hello.png"),
	&"point": preload("res://art/characters/bia_point.png"),
	&"cheer": preload("res://art/characters/bia_cheer.png"),
	&"think": preload("res://art/characters/bia_think.png"),
}
const GOLD: Color = Color("ffd54f")
const CHARCOAL: Color = Color("263238")
const PINK: Color = Color("ff8fb1")
const CARD_X: float = 60.0
const CARD_W: float = 960.0
const TYPE_SPEED: float = 42.0 # caracteres por segundo

var spotlight_rect: Rect2 = Rect2()
var has_target: bool = false
var message: String = ""
var pulse: float = 0.0
var active: bool = false
## Tutorial principal em andamento: dicas temporárias (show_hint) são ignoradas.
var locked: bool = false
var typed: float = 0.0
var hint_left: float = 0.0
var hand_from: Vector2 = Vector2.ZERO
var hand_to: Vector2 = Vector2.ZERO
var hand_mode: StringName = &"" # "" | tap | drag
var on_action: Callable = Callable()

var card: PanelContainer
var portrait: TextureRect
var portrait_bg: Panel
var name_label: Label
var bubble_label: Label
var action_button: Button
var hand_layer: Control


func _ready() -> void:
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", StyleFactory.box(Color("ffffff", 0.97), 30, 18, GOLD, 4))
	card.gui_input.connect(_on_card_input)
	add_child(card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var avatar: Control = Control.new()
	avatar.custom_minimum_size = Vector2(240, 240)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(avatar)
	portrait_bg = Panel.new()
	portrait_bg.add_theme_stylebox_override("panel", StyleFactory.box(Color("ffe1ec"), 110, 0, PINK, 4))
	portrait_bg.position = Vector2(10, 20)
	portrait_bg.size = Vector2(220, 220)
	portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(portrait_bg)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(-5, -10)
	portrait.size = Vector2(250, 250)
	portrait.pivot_offset = Vector2(125, 230)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(portrait)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	row.add_child(column)
	name_label = Label.new()
	name_label.text = Loc.t("GUIDE_NAME")
	name_label.add_theme_color_override("font_color", PINK)
	column.add_child(name_label)
	bubble_label = Label.new()
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.add_theme_color_override("font_color", CHARCOAL)
	bubble_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble_label.custom_minimum_size = Vector2(620, 0)
	column.add_child(bubble_label)
	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(260, 68)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.add_theme_color_override("font_color", Color.WHITE)
	action_button.add_theme_color_override("font_hover_color", Color.WHITE)
	action_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	action_button.add_theme_stylebox_override("normal", StyleFactory.box(Color("2e7d32"), 30, 10))
	action_button.add_theme_stylebox_override("hover", StyleFactory.box(Color("388e3c"), 30, 10, Color.WHITE, 2))
	action_button.add_theme_stylebox_override("pressed", StyleFactory.box(Color("1b5e20"), 30, 10))
	action_button.pressed.connect(_on_action_pressed)
	InteractionFX.bind_button(action_button)
	column.add_child(action_button)
	hand_layer = Control.new()
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_layer.draw.connect(_draw_hand)
	add_child(hand_layer)
	card.visible = false


## Fala da Bia. `rect` vazio = sem alvo (cartão centralizado, tela toda esmaecida).
## `hand`: &"tap" pulsa no centro do alvo; &"drag" anima de `from` até `to`.
func show_guide(text: String, mood: StringName = &"point", rect: Rect2 = Rect2(), button_text: String = "", callback: Callable = Callable(), hand: StringName = &"", from: Vector2 = Vector2.ZERO, to: Vector2 = Vector2.ZERO) -> void:
	active = true
	visible = true
	hint_left = 0.0
	spotlight_rect = rect
	has_target = rect.size.x > 0.0 and rect.size.y > 0.0
	message = text
	typed = 0.0
	pulse = 0.0
	hand_mode = hand
	hand_from = from
	hand_to = to
	on_action = callback
	_apply_font_scale()
	portrait.texture = PORTRAITS.get(mood, PORTRAITS[&"point"]) as Texture2D
	bubble_label.text = text
	bubble_label.visible_characters = 0
	action_button.text = button_text
	action_button.visible = not button_text.is_empty()
	card.visible = true
	_place_card()
	card.pivot_offset = card.size * 0.5
	if _reduced_motion():
		# P3: "movimento reduzido" (eco/reduced_particles) dispensa a entrada animada.
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		portrait.scale = Vector2.ONE
	else:
		card.modulate.a = 0.0
		card.scale = Vector2(0.94, 0.94)
		var tween: Tween = card.create_tween().set_parallel(true)
		tween.tween_property(card, "modulate:a", 1.0, 0.18)
		tween.tween_property(card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		portrait.scale = Vector2(0.86, 0.86)
		portrait.create_tween().tween_property(portrait, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()
	hand_layer.queue_redraw()


## T-04: cartão respeita Ajustes → fonte (kids força ≥1.1 no jogo inteiro).
func _apply_font_scale() -> void:
	var fs: float = SalonTuning.font_scale()
	name_label.add_theme_font_size_override("font_size", int(22 * fs))
	bubble_label.add_theme_font_size_override("font_size", int(30 * fs))
	action_button.add_theme_font_size_override("font_size", int(26 * fs))
	# Alvo de toque nunca abaixo do padrão do projeto (64 px).
	action_button.custom_minimum_size = Vector2(260, maxf(68.0, 64.0))


func _reduced_motion() -> bool:
	return bool(GameState.settings.get("reduced_particles", false))


## Dica temporária (ex.: ferramenta errada). Ignorada durante o tutorial principal.
func show_hint(rect: Rect2, text: String, seconds: float = 1.2) -> void:
	if locked or (active and hint_left <= 0.0):
		return
	show_guide(text, &"point", rect, "", Callable(), &"tap", rect.get_center(), rect.get_center())
	hint_left = seconds


## Compatibilidade com o overlay antigo (spotlight + texto).
func show_step(rect: Rect2, text: String) -> void:
	show_guide(text, &"point", rect)


## Toques sobre o cartão da Bia não chegam ao salão (Main._input roda antes da GUI).
func blocks_event(event: InputEvent) -> bool:
	if not active or not is_instance_valid(card) or not card.visible:
		return false
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouse:
		return card.get_global_rect().has_point(event.position)
	return false


func finish() -> void:
	active = false
	visible = false
	locked = false
	hint_left = 0.0
	hand_mode = &""
	on_action = Callable()
	if is_instance_valid(card):
		card.visible = false


func _process(delta: float) -> void:
	if not active:
		return
	# P3: com movimento reduzido o relógio visual congela (sem pulso/sorriso).
	pulse += 0.0 if _reduced_motion() else delta
	if bubble_label.visible_characters >= 0 and bubble_label.visible_characters < message.length():
		typed += delta * TYPE_SPEED
		bubble_label.visible_characters = mini(int(typed), message.length())
		if bubble_label.visible_characters >= message.length():
			bubble_label.visible_characters = -1
	if hint_left > 0.0:
		hint_left -= delta
		if hint_left <= 0.0:
			finish()
			return
	_place_card()
	queue_redraw()
	hand_layer.queue_redraw()


## Cartão no lado oposto ao alvo: logo abaixo se couber, senão logo acima;
## sem alvo, centralizado verticalmente.
func _place_card() -> void:
	var card_h: float = maxf(card.size.y, card.get_combined_minimum_size().y)
	card.size.x = CARD_W
	var safe_top: float = SalonTuning.safe_area_top()
	var y: float = (size.y - card_h) * 0.5
	if has_target:
		var below: float = spotlight_rect.end.y + 40.0
		var above: float = spotlight_rect.position.y - 40.0 - card_h
		if below + card_h <= size.y - 300.0:
			y = below
		elif above >= safe_top + 130.0:
			y = above
		else:
			y = safe_top + 130.0 if spotlight_rect.get_center().y > size.y * 0.5 else size.y - card_h - 300.0
	card.position = Vector2(CARD_X, y)


func _on_card_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if tap and bubble_label.visible_characters >= 0:
		bubble_label.visible_characters = -1
		typed = float(message.length())


func _on_action_pressed() -> void:
	AudioManager.play(&"tap")
	HapticsManager.light()
	var callback: Callable = on_action
	on_action = Callable()
	if callback.is_valid():
		callback.call()
	elif active:
		finish()


func _draw() -> void:
	if not active:
		return
	if not has_target:
		draw_rect(Rect2(Vector2.ZERO, size), Color(CHARCOAL, 0.55))
		return
	var dim: Color = Color(CHARCOAL, 0.52)
	var r: Rect2 = spotlight_rect
	draw_rect(Rect2(0.0, 0.0, size.x, maxf(0.0, r.position.y)), dim)
	draw_rect(Rect2(0.0, r.end.y, size.x, maxf(0.0, size.y - r.end.y)), dim)
	draw_rect(Rect2(0.0, r.position.y, maxf(0.0, r.position.x), r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, maxf(0.0, size.x - r.end.x), r.size.y), dim)
	var glow: float = 0.55 + 0.35 * sin(pulse * 5.0)
	draw_rect(r, Color(GOLD, glow), false, 9.0)
	draw_rect(r.grow(6.0), Color(GOLD, glow * 0.22), false, 4.0)
	# Seta do cartão até o alvo (bounce), com trilha pontilhada
	var card_above: bool = card.position.y + card.size.y * 0.5 < r.get_center().y
	var start: Vector2 = Vector2(clampf(r.get_center().x, card.position.x + 80.0, card.position.x + card.size.x - 80.0), card.position.y + card.size.y if card_above else card.position.y)
	var bounce: float = sin(pulse * 4.5) * 10.0
	var tip: Vector2 = Vector2(r.get_center().x, (r.position.y - 8.0 - bounce) if card_above else (r.end.y + 8.0 + bounce))
	if start.distance_to(tip) < 24.0:
		return
	var dir: Vector2 = (tip - start).normalized()
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	for s: int in 8:
		if s % 2 == 0:
			draw_line(start.lerp(tip, float(s) / 8.0), start.lerp(tip, float(s + 1) / 8.0 * 0.92), Color(GOLD, 0.6), 4.0)
	var base: Vector2 = tip - dir * 30.0
	draw_colored_polygon(PackedVector2Array([tip, base + normal * 18.0, base - normal * 18.0]), Color(GOLD, 0.95))
	draw_circle(tip, 8.0 + 3.0 * sin(pulse * 6.0), Color(GOLD, 0.3 + 0.2 * sin(pulse * 6.0)))


## Mãozinha (camada acima do cartão): toque pulsante ou arraste real.
func _draw_hand() -> void:
	if not active or hand_mode == &"":
		return
	var pos: Vector2 = hand_to
	if hand_mode == &"drag" and hand_from.distance_to(hand_to) > 1.0:
		var t: float = fmod(pulse * 0.55, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		pos = hand_from.lerp(hand_to, eased)
		for s: int in 9:
			var tt: float = float(s) / 9.0
			if tt < eased:
				hand_layer.draw_circle(hand_from.lerp(hand_to, tt), 5.0, Color(GOLD, 0.35))
		hand_layer.draw_circle(hand_to, 26.0 + 6.0 * sin(pulse * 3.0), Color(GOLD, 0.22))
	else:
		var ring: float = fmod(pulse * 1.2, 1.0)
		hand_layer.draw_arc(pos, 22.0 + ring * 40.0, 0.0, TAU, 40, Color(GOLD, 0.7 * (1.0 - ring)), 4.0)
		pos += Vector2(0.0, sin(pulse * 6.0) * 5.0)
	hand_layer.draw_circle(pos + Vector2(2, 3), 27.0, Color(CHARCOAL, 0.18))
	hand_layer.draw_circle(pos, 25.0, Color.WHITE)
	hand_layer.draw_arc(pos, 27.0, 0.0, TAU, 40, Color(GOLD, 0.5), 2.5)
	# Dedo apontando vetorial: emoji de ponteiro vira □ (tofu) no web sem fonte emoji.
	_draw_pointing_hand(pos)


## Mãozinha simples (punho + indicador) desenhada com polígonos — sem emoji.
func _draw_pointing_hand(at: Vector2) -> void:
	var skin: Color = Color("ffcc80")
	var outline: Color = CHARCOAL
	# Indicador para cima
	var finger: Rect2 = Rect2(at.x - 5.0, at.y - 22.0, 10.0, 22.0)
	hand_layer.draw_rect(finger.grow(2.0), outline)
	hand_layer.draw_rect(finger, skin)
	# Punho/MP dobrados
	var palm: Rect2 = Rect2(at.x - 12.0, at.y - 2.0, 24.0, 16.0)
	hand_layer.draw_rect(palm.grow(2.0), outline)
	hand_layer.draw_rect(palm, skin)
	# Polegar
	var thumb: Rect2 = Rect2(at.x - 16.0, at.y + 2.0, 10.0, 10.0)
	hand_layer.draw_rect(thumb.grow(2.0), outline)
	hand_layer.draw_rect(thumb, skin)
