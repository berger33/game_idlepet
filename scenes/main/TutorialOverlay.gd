extends Control
## Tutorial spotlight não-bloqueante: escurece a tela ao redor do alvo
## (sem shader, com 4 retângulos de dim) e pulsa a borda + instrução.
## Avança apenas com eventos reais do jogo; sempre pulável.

const GUIDE_FONT: Font = preload("res://art/fonts/DejaVuSans-Bold.ttf")

var spotlight_rect: Rect2 = Rect2(0, 0, 0, 0)
var message: String = ""
var pulse: float = 0.0
var active: bool = false
var voice_button: Button = null


func _ready() -> void:
	# botão de voz no tutorial — mute já no 1º acesso sem abrir Ajustes
	voice_button = Button.new()
	voice_button.custom_minimum_size = Vector2(72, 72)
	voice_button.size = Vector2(72, 72)
	voice_button.position = Vector2(size.x - 88.0, 18.0 + _safe_top())
	voice_button.z_index = 10
	voice_button.mouse_filter = Control.MOUSE_FILTER_STOP
	voice_button.focus_mode = Control.FOCUS_NONE
	voice_button.pressed.connect(_on_voice_toggle)
	add_child(voice_button)
	_update_voice_button()
	# reposiciona se tela redimensionar / safe area mudar
	resized.connect(func() -> void:
		if is_instance_valid(voice_button):
			voice_button.position = Vector2(size.x - 88.0, 18.0 + _safe_top())
	)


func show_step(rect: Rect2, text: String) -> void:
	active = true
	visible = true
	spotlight_rect = rect
	message = text
	pulse = 0.0
	if is_instance_valid(voice_button):
		voice_button.visible = true
		_update_voice_button()
		voice_button.position = Vector2(size.x - 88.0, 18.0 + _safe_top())
	queue_redraw()


func finish() -> void:
	active = false
	visible = false
	if is_instance_valid(voice_button):
		voice_button.visible = false

func _on_voice_toggle() -> void:
	var enabled: bool = not bool(GameState.settings.get("voice", true))
	GameState.settings["voice"] = enabled
	SaveManager.request_save()
	AudioManager.apply_volumes()
	if not enabled:
		AudioManager.stop_voice()
	else:
		AudioManager.play_voice(&"welcome")
	_update_voice_button()
	EventBus.settings_changed.emit()

func _update_voice_button() -> void:
	if not is_instance_valid(voice_button):
		return
	var enabled: bool = bool(GameState.settings.get("voice", true))
	voice_button.text = "🔊" if enabled else "🔇"
	voice_button.tooltip_text = "Voz ligada — toque para mutar" if enabled else "Voz mutada — toque para ativar"
	# estilo rápido sem depender de Main._style (Control puro)
	var bg: Color = Color("4fc3f7") if enabled else Color("90a4ae")
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 36; sb.corner_radius_top_right = 36; sb.corner_radius_bottom_left = 36; sb.corner_radius_bottom_right = 36
	sb.content_margin_left = 8; sb.content_margin_right = 8; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.border_color = Color.WHITE; sb.border_width_left = 3; sb.border_width_right = 3; sb.border_width_top = 3; sb.border_width_bottom = 3
	voice_button.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sb2.bg_color = bg.lightened(0.08)
	voice_button.add_theme_stylebox_override("hover", sb2)
	voice_button.add_theme_color_override("font_color", Color.WHITE)

func _safe_top() -> float:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		if safe.position.y > 0:
			return clampf(float(safe.position.y) * 0.5, 0.0, 80.0)
	return 0.0


func _process(delta: float) -> void:
	if active:
		pulse += delta
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var dim: Color = Color("263238", 0.52)
	var r: Rect2 = spotlight_rect
	draw_rect(Rect2(0.0, 0.0, size.x, maxf(0.0, r.position.y)), dim)
	draw_rect(Rect2(0.0, r.end.y, size.x, maxf(0.0, size.y - r.end.y)), dim)
	draw_rect(Rect2(0.0, r.position.y, maxf(0.0, r.position.x), r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, maxf(0.0, size.x - r.end.x), r.size.y), dim)
	var glow: float = 0.55 + 0.35 * sin(pulse * 5.0)
	draw_rect(r, Color("ffd54f", glow), false, 9.0)
	draw_rect(r.grow(6.0), Color("ffd54f", glow * 0.22), false, 4.0)
	# Label reposiciona se sair da tela (pet embaixo) + safe area
	var safe_top: float = 0.0
	if OS.has_feature("mobile") or OS.has_feature("web"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		if safe.position.y > 0:
			safe_top = clampf(float(safe.position.y) * 0.5, 0.0, 80.0)
	var label_y: float = r.end.y + 20.0
	var arrow_up: bool = true
	if label_y + 110.0 > size.y - 90.0 - safe_top:
		label_y = r.position.y - 116.0
		arrow_up = false
		if label_y < safe_top + 20.0:
			label_y = safe_top + 20.0
	var label_rect: Rect2 = Rect2(60.0, label_y, 960.0, 96.0)
	draw_rect(label_rect, Color("263238", 0.96), true)
	draw_rect(label_rect, Color("ffd54f", 0.85), false, 3.0)
	# Seta animada apontando para o spotlight — bounce + glow extra no passo 2 (prateleira)
	var bounce: float = sin(pulse * 4.5) * 12.0
	var arrow_center: Vector2 = Vector2(r.position.x + r.size.x * 0.5, label_y + (96.0 if arrow_up else 0.0) + bounce * 0.25)
	var arrow_tip: Vector2 = Vector2(r.position.x + r.size.x * 0.5, (r.end.y + 6.0 + bounce) if arrow_up else (r.position.y - 6.0 - bounce))
	var arrow_dir: float = 1.0 if arrow_up else -1.0
	var tri: PackedVector2Array = PackedVector2Array([
		arrow_tip,
		arrow_center + Vector2(-18.0, 14.0 * arrow_dir),
		arrow_center + Vector2(18.0, 14.0 * arrow_dir)
	])
	draw_colored_polygon(tri, Color("ffd54f", 0.95))
	# Brilho extra no tip + segunda seta maior pulsante para tutorial 2/3 prateleira
	draw_circle(arrow_tip, 10.0 + 4.0 * sin(pulse * 6.0), Color("ffd54f", 0.35 + 0.2 * sin(pulse * 6.0)))
	var tri_big: PackedVector2Array = PackedVector2Array([
		arrow_tip + Vector2(0, -8.0 * arrow_dir),
		arrow_center + Vector2(-28.0, 22.0 * arrow_dir) + Vector2(0, bounce * 0.2),
		arrow_center + Vector2(28.0, 22.0 * arrow_dir) + Vector2(0, bounce * 0.2)
	])
	draw_colored_polygon(tri_big, Color("ffd54f", 0.22 + 0.15 * sin(pulse * 4.5)))
	# Linha tracejada animada conectando label ao alvo
	var steps: int = 6
	for s: int in steps:
		if s % 2 == 0:
			var t1: float = float(s) / float(steps)
			var t2: float = float(s + 1) / float(steps) * 0.9
			var p1: Vector2 = arrow_center.lerp(arrow_tip, t1)
			var p2: Vector2 = arrow_center.lerp(arrow_tip, t2)
			draw_line(p1, p2, Color("ffd54f", 0.55), 3.0)
	draw_string(
		GUIDE_FONT,
		Vector2(80.0, label_y + 62.0),
		message,
		HORIZONTAL_ALIGNMENT_CENTER,
		920.0,
		32,
		Color("ffd54f"),
	)
	# Mãozinha animada para 7 anos: loop 1.8s de arraste dentro da pílula (sem leitura)
	# Só nos passos que pedem arrastar (2/3) ou que mencionam ferramenta, para não poluir passo 1/3
	var show_hand: bool = message.contains("Arraste") or message.contains("2/3") or message.contains("DRAG") or message.begins_with("○●○")
	if show_hand:
		var t: float = fmod(pulse * 0.65, 1.0) # 1.54s loop
		# ease in-out para não parecer robótico
		var eased: float = t * t * (3.0 - 2.0 * t)
		var start_x: float = label_rect.position.x + 70.0
		var end_x: float = label_rect.position.x + label_rect.size.x - 70.0
		var hand_x: float = lerpf(start_x, end_x, eased)
		var hand_y: float = label_y + 48.0 + sin(pulse * 4.2) * 4.0
		var hand_pos: Vector2 = Vector2(hand_x, hand_y)
		var target_pos: Vector2 = Vector2(label_rect.position.x + label_rect.size.x - 36.0, label_y + 48.0)
		# trilha pontilhada atrás da mão
		var trail_steps: int = 7
		for s: int in trail_steps:
			var tt: float = float(s) / float(trail_steps)
			var tx: float = lerpf(start_x + 18.0, end_x - 18.0, tt)
			var alpha: float = 0.18 + 0.12 * sin(pulse * 5.0 + s * 0.9)
			var behind: bool = tx < hand_x
			if behind:
				draw_circle(Vector2(tx, hand_y), 4.0, Color("ffd54f", alpha))
		# destino patinha
		draw_circle(target_pos, 18.0, Color.WHITE)
		draw_string(GUIDE_FONT, target_pos + Vector2(-11, 7), "🐾", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("263238"))
		draw_circle(target_pos, 22.0, Color("ffd54f", 0.22 + 0.10 * sin(pulse * 3.0)))
		# mão — círculo branco + emoji + sombra
		draw_circle(hand_pos + Vector2(2, 3), 26.0, Color("263238", 0.18))
		draw_circle(hand_pos, 24.0, Color.WHITE)
		draw_circle(hand_pos, 26.0, Color("ffd54f", 0.35), false, 2.5)
		# emoji centralizado (DejaVu não tem emoji, mas Godot faz fallback; se falhar, a seta abaixo garante leitura)
		draw_string(GUIDE_FONT, hand_pos + Vector2(-14, 11), "👆", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("263238"))
		# seta física garantida mesmo sem emoji
		var hand_tip: Vector2 = hand_pos + Vector2(14, 0)
		var tri_hand: PackedVector2Array = PackedVector2Array([hand_tip, hand_tip + Vector2(-10, -6), hand_tip + Vector2(-10, 6)])
		draw_colored_polygon(tri_hand, Color("ffd54f", 0.95))
