class_name GestureArt
extends RefCounted
## UI de gesto da Onda 1 (docs/DESIGN_ENGAJAMENTO.md), desenhada sobre o pet:
## setas da tosa (traçado direcionado), zona da secagem (círculo que deriva),
## anel rítmico do perfume (janelas de borrifada) e marca de encaixe do laço.
## Também desenha o buddy da banheira dupla (Onda 3) e o tremor dos pets
## agitados. Tudo lê o estado de PetShopCanvas — mesma convenção de StationArt.


## Tremor do UI de gesto para pets agitados (temperamento do catálogo).
static func _jitter(shop) -> Vector2:
	var amplitude: float = float(shop.gesture_ui.get("shake", 0.0)) * 7.0
	if amplitude <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(shop.shake_phase * 31.0), cos(shop.shake_phase * 27.0)) * amplitude


static func _triangle(shop, tip: Vector2, direction: Vector2, color: Color) -> void:
	var side: Vector2 = Vector2(-direction.y, direction.x) * 9.6
	shop.draw_colored_polygon(
		PackedVector2Array([tip, tip - direction * 16.0 + side, tip - direction * 16.0 - side]),
		color
	)


## UI de gesto por serviço: setas da tosa, zona da secagem, anel rítmico do
## perfume e marca de encaixe do laço. Desenhada sobre o pet, sob o utensílio.
## Paleta de estado acessível: verde/vermelho viram azul/laranja no modo
## daltônico (settings["colorblind"]) — o núcleo do jogo é "soltar na faixa".
static func good_color(alpha: float = 1.0) -> Color:
	var base: Color = Color("4fc3f7") if _colorblind() else Color("7ed957")
	return Color(base, alpha)


static func bad_color(alpha: float = 1.0) -> Color:
	var base: Color = Color("ff9800") if _colorblind() else Color("ef5350")
	return Color(base, alpha)


static func _colorblind() -> bool:
	return bool(GameState.settings.get("colorblind", false))


static func draw_ghost(shop, body_center: Vector2) -> void:
	if shop.gesture_ui.is_empty() or not shop.service_active or shop.room_empty:
		return
	if not bool(GameState.settings.get("training_ghost", false)):
		return
	var mode: StringName = StringName(shop.gesture_ui.get("mode", &""))
	var ghost_col: Color = Color("ffffff", 0.18)
	var ghost_line: Color = Color("4fc3f7", 0.35)
	match mode:
		&"stroke":
			var axes: Array = shop.gesture_ui.get("axes", [])
			for i: int in maxi(1, axes.size()):
				var axis: StringName = StringName(axes[i]) if i < axes.size() else &"vertical"
				var anchor: Vector2 = body_center + Vector2(-180.0, -88.0 + i * 88.0)
				# Ghost ideal: linha tracejada translúcida + seta fantasma
				shop.draw_circle(anchor, 42.0, ghost_col)
				if axis == &"horizontal":
					for s: int in 4:
						var off: float = -24.0 + s * 16.0
						shop.draw_line(anchor + Vector2(off, 0), anchor + Vector2(off + 8, 0), ghost_line, 6.0)
				else:
					for s: int in 4:
						var off: float = -24.0 + s * 16.0
						shop.draw_line(anchor + Vector2(0, off), anchor + Vector2(0, off + 8), ghost_line, 6.0)
		&"zone":
			var radius: float = float(shop.gesture_ui.get("zone_radius", 80.0))
			# Ghost fixo no centro ideal (body_center) vs alvo móvel
			shop.draw_circle(body_center, radius, ghost_col)
			shop.draw_arc(body_center, radius, 0.0, TAU, 32, ghost_line, 4.0)
			shop.draw_arc(body_center, radius * 0.6, 0.0, TAU, 16, Color(ghost_line, 0.2), 2.0)
		&"pulse":
			var base_radius: float = 148.0
			shop.draw_arc(body_center, base_radius, 0.0, TAU, 40, ghost_line, 5.0)
			shop.draw_circle(body_center, base_radius, Color("4fc3f7", 0.08))
			var needed: int = maxi(1, int(shop.gesture_ui.get("pulses_needed", 3)))
			for i: int in needed:
				var pip: Vector2 = body_center + Vector2((i - (needed - 1) * 0.5) * 56.0, 240.0)
				shop.draw_circle(pip, 18.0, Color("ffffff", 0.15))
				shop.draw_arc(pip, 18.0, 0.0, TAU, 12, ghost_line, 3.0)
		&"drop":
			var radius: float = float(shop.gesture_ui.get("drop_radius", 80.0))
			var ideal: Vector2 = body_center + Vector2(0, -20)
			for seg: int in 12:
				shop.draw_arc(ideal, radius, TAU * seg / 12.0 + 0.09, TAU * (seg + 1) / 12.0 - 0.09, 6, Color(ghost_line.r, ghost_line.g, ghost_line.b, 0.25), 4.0)
			shop.draw_circle(ideal, 8.0, Color("ffffff", 0.15))


static func draw_gesture_ui(shop, body_center: Vector2) -> void:
	if shop.gesture_ui.is_empty() or not shop.service_active or shop.room_empty:
		return
	var mode: StringName = StringName(shop.gesture_ui.get("mode", &""))
	var jitter: Vector2 = _jitter(shop)
	var beat_pulse: float = pow(1.0 - AudioManager.beat_phase(), 2.0)
	match mode:
		&"stroke":
			# Tosa: setas de duas pontas — uma por passo do traçado.
			# Movidas para mais perto do pet (-180 vs -308) para leitura imediata.
			var axes: Array = shop.gesture_ui.get("axes", [])
			var current: int = int(shop.gesture_ui.get("stroke_index", 0))
			for i: int in maxi(1, axes.size()):
				var axis: StringName = StringName(axes[i]) if i < axes.size() else &"vertical"
				var anchor: Vector2 = (
					body_center
					+ Vector2(-180.0, -88.0 + i * 88.0)
					+ jitter * (1.0 if i == current else 0.3)
				)
				var color: Color
				if i < current:
					color = good_color(0.9)
				elif i == current:
					# Pulso no compasso para o passo atual
					var pulse: float = 0.85 + 0.15 * beat_pulse
					color = Color("ff8fb1", 0.95 * pulse)
					# Aro de destaque no passo atual
					shop.draw_circle(anchor, 36.0 + beat_pulse * 6.0, Color(color, 0.18))
				else:
					color = Color("ffffff", 0.35)
				if axis == &"horizontal":
					shop.draw_line(anchor + Vector2(-28.0, 0.0), anchor + Vector2(28.0, 0.0), color, 10.0)
					_triangle(shop, anchor + Vector2(-28.0, 0.0), Vector2(-1, 0), color)
					_triangle(shop, anchor + Vector2(28.0, 0.0), Vector2(1, 0), color)
				else:
					shop.draw_line(anchor + Vector2(0.0, -28.0), anchor + Vector2(0.0, 28.0), color, 10.0)
					_triangle(shop, anchor + Vector2(0.0, -28.0), Vector2(0, -1), color)
					_triangle(shop, anchor + Vector2(0.0, 28.0), Vector2(0, 1), color)
		&"zone":
			# Secagem: círculo-alvo que deriva pelo corpo; verde = bocal dentro.
			# Pulso suave no beat + anel duplo para leitura de precisão.
			var target: Vector2 = shop.gesture_ui.get("zone_target", body_center) + jitter
			var radius: float = float(shop.gesture_ui.get("zone_radius", 80.0))
			var inside: bool = bool(shop.gesture_ui.get("zone_inside", false))
			var zone_color: Color = good_color(0.9) if inside else Color("ffffff", 0.75)
			var pulse_r: float = radius + beat_pulse * 8.0
			shop.draw_circle(target, pulse_r, Color(zone_color.r, zone_color.g, zone_color.b, 0.10))
			shop.draw_arc(target, radius, 0.0, TAU, 48, zone_color, 6.0)
			shop.draw_arc(target, radius * 0.6, 0.0, TAU, 24, Color(zone_color, 0.35), 3.0)
			shop.draw_circle(target, 10.0, zone_color)
			if inside:
				# Brilho interno quando está secando certo
				shop.draw_circle(target, 18.0 + beat_pulse * 6.0, Color(zone_color, 0.25))
		&"pulse":
			# Perfume: anel que ACENDE na janela da borrifada + acertos em pips.
			# Anel escala com o beat para dar ritmo visual.
			var bright: bool = bool(shop.gesture_ui.get("pulse_bright", false))
			var base_radius: float = 148.0
			var ring_radius: float = base_radius + (18.0 if bright else 0.0) + beat_pulse * 6.0
			if bright:
				shop.draw_circle(body_center, ring_radius, Color("ffd54f", 0.18))
				shop.draw_arc(body_center, ring_radius, 0.0, TAU, 48, Color("ffd54f", 0.95), 12.0)
				shop.draw_arc(body_center, ring_radius - 18.0, 0.0, TAU, 48, Color("ffd54f", 0.4), 4.0)
			else:
				shop.draw_arc(body_center, base_radius, 0.0, TAU, 48, Color("ffffff", 0.4), 5.0)
			var needed: int = maxi(1, int(shop.gesture_ui.get("pulses_needed", 3)))
			var hit: int = int(shop.gesture_ui.get("pulses_hit", 0))
			for i: int in needed:
				var pip: Vector2 = body_center + Vector2((i - (needed - 1) * 0.5) * 56.0, 240.0)
				var is_hit: bool = i < hit
				var pip_r: float = 15.0 + (4.0 * beat_pulse if is_hit else 0.0)
				shop.draw_circle(
					pip, pip_r, Color("ffd54f", 0.95) if is_hit else Color("ffffff", 0.30)
				)
				shop.draw_arc(pip, pip_r, 0.0, TAU, 16, Color("263238", 0.35), 3.0)
				if is_hit:
					shop.draw_circle(pip, 6.0, Color("ffffff", 0.9))
		&"drop":
			# Laço: marca no pescoço; anel verde quando o laço está na zona.
			# Pulso + snap visual quando está dentro.
			var target: Vector2 = shop.gesture_ui.get("drop_target", body_center) + jitter * 0.5
			var radius: float = float(shop.gesture_ui.get("drop_radius", 80.0))
			var inside: bool = bool(shop.gesture_ui.get("drop_inside", false))
			var mark_color: Color = good_color(0.9) if inside else Color("ff8fb1", 0.9)
			var dash_alpha: float = 0.75 + 0.25 * beat_pulse if inside else 0.65
			for seg: int in 12:
				shop.draw_arc(
					target, radius, TAU * seg / 12.0 + 0.09, TAU * (seg + 1) / 12.0 - 0.09, 6,
					Color(mark_color.r, mark_color.g, mark_color.b, dash_alpha), 6.0
				)
			shop.draw_line(target + Vector2(-18, 0), target + Vector2(18, 0), mark_color, 6.0)
			shop.draw_line(target + Vector2(0, -18), target + Vector2(0, 18), mark_color, 6.0)
			if inside:
				shop.draw_circle(target, 12.0 + beat_pulse * 8.0, Color(mark_color, 0.28))
				shop.draw_circle(target, 6.0, Color("ffffff", 0.85))


## Banheira dupla (Onda 3) — 10/10 vivo: buddy respira, olha main pet, salta sincronizado no perfect.
static func draw_buddy(shop) -> void:
	if not shop.buddy_active or shop.room_empty or shop.buddy_pet_id.is_empty():
		return
	if shop.buddy_texture_id != shop.buddy_pet_id or shop.buddy_texture == null:
		var path: String = "res://art/pets/%s.png" % shop.buddy_pet_id
		if ResourceLoader.exists(path):
			shop.buddy_texture = load(path) as Texture2D
			shop.buddy_texture_id = shop.buddy_pet_id
		else:
			shop.buddy_texture = null
			shop.buddy_texture_id = ""
	if shop.buddy_texture == null:
		return
	var size: float = 170.0
	var feet: Vector2 = Vector2(196.0, 1198.0)
	var jump: float = float(shop.get("buddy_jump_height", 0.0))
	var eye_off: Vector2 = shop.get("buddy_eye_offset", Vector2.ZERO)
	var celebration: float = float(shop.get("buddy_celebration", 0.0))
	# breathing buddy
	var breathe: float = sin(shop.shake_phase * 2.2) * 0.008
	var scale_y: float = 1.0 + breathe
	var top: float = feet.y - 479.0 / 512.0 * size - jump
	# Espuminha animada
	var foam_r: float = 74.0 + sin(shop.shake_phase * 3.0) * 4.0
	var foam_alpha: float = 0.55 + 0.1 * sin(shop.shake_phase * 2.0)
	shop.draw_circle(feet + Vector2(0.0, -14.0), foam_r, Color("e1f5fe", foam_alpha))
	shop.draw_arc(feet + Vector2(0.0, -14.0), foam_r, 0.0, TAU, 24, Color("b3e5fc", 0.9), 5.0)
	# bolhas buddy quando celebra
	if celebration > 0.0:
		for i: int in 3:
			var ang: float = TAU * float(i) / 3.0 + shop.shake_phase * 2.0
			var bp: Vector2 = feet + Vector2(cos(ang), sin(ang)) * 20.0 + Vector2(0, -30 - jump * 0.5)
			shop.draw_circle(bp, 6.0 + sin(shop.shake_phase * 4.0 + i) * 2.0, Color("ffffff", 0.6))
	shop.draw_set_transform(Vector2(feet.x, feet.y - jump), 0.0, Vector2(1.0, scale_y))
	shop.draw_texture_rect(
		shop.buddy_texture, Rect2(-size * 0.5, top - feet.y + jump, size, size), false
	)
	shop.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# eye tracking buddy olha main pet
	if eye_off != Vector2.ZERO:
		var eye_center: Vector2 = feet + Vector2(0, -80) + Vector2(-18, -12)
		shop.draw_circle(eye_center + eye_off, 4.0, Color("ffffff", 0.85))
		shop.draw_circle(eye_center + Vector2(36, 0) + eye_off, 4.0, Color("ffffff", 0.85))
	# +40% pulsa com beat quando celebra
	var beat_pulse: float = 1.0
	if shop.get("celebration") != null:
		beat_pulse = 1.0 + sin(shop.shake_phase * 5.0) * 0.15 * (1.0 if celebration > 0.0 else 0.0)
	var label_size: float = 24.0 * beat_pulse
	var label_alpha: float = 0.65 + 0.25 * sin(shop.shake_phase * 3.0) if celebration > 0.0 else 0.65
	shop.draw_string(
		shop.UI_TITLE_FONT,
		feet + Vector2(-64.0, -150.0 - jump),
		"+40%",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		int(label_size),
		Color("263238", label_alpha)
	)
	if celebration > 0.0:
		shop.draw_string(shop.UI_TITLE_FONT, feet + Vector2(-28, -170 - jump), "✨", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd54f", 0.9))


## Snapshot por frame do estado do gesto para o canvas desenhar (Onda 1):
## cada modo expõe apenas o que a sua UI consome.
static func gesture_snapshot(bath: BathService) -> Dictionary:
	return {
		"mode": bath.fill_mode,
		"shake": bath.shake_amplitude,
		"target_min": bath.target_minimum,
		"target_max": bath.target_maximum,
		"axes": bath.stroke_axes,
		"stroke_index": bath.stroke_index,
		"zone_target": bath.zone_target,
		"zone_radius": bath.zone_radius,
		"zone_inside": bath.zone_inside,
		"pulse_bright": bath.pulse_bright(),
		"pulses_hit": bath.pulses_hit,
		"pulses_needed": bath.pulses_needed,
		"drop_target": bath.drop_target,
		"drop_radius": bath.drop_radius,
		"drop_inside": bath.drop_distance <= bath.drop_radius,
	}
