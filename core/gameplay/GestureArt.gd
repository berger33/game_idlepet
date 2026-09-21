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


static func draw_gesture_ui(shop, body_center: Vector2) -> void:
	if shop.gesture_ui.is_empty() or not shop.service_active or shop.room_empty:
		return
	var mode: StringName = StringName(shop.gesture_ui.get("mode", &""))
	var jitter: Vector2 = _jitter(shop)
	match mode:
		&"stroke":
			# Tosa: setas de duas pontas — uma por passo do traçado.
			var axes: Array = shop.gesture_ui.get("axes", [])
			var current: int = int(shop.gesture_ui.get("stroke_index", 0))
			for i: int in maxi(1, axes.size()):
				var axis: StringName = StringName(axes[i]) if i < axes.size() else &"vertical"
				var anchor: Vector2 = (
					body_center
					+ Vector2(-308.0, -96.0 + i * 96.0)
					+ jitter * (1.0 if i == current else 0.3)
				)
				var color: Color
				if i < current:
					color = good_color(0.9)
				elif i == current:
					color = Color("ff8fb1", 0.95)
				else:
					color = Color("ffffff", 0.35)
				if axis == &"horizontal":
					shop.draw_line(anchor + Vector2(-26.0, 0.0), anchor + Vector2(26.0, 0.0), color, 9.0)
					_triangle(shop, anchor + Vector2(-26.0, 0.0), Vector2(-1, 0), color)
					_triangle(shop, anchor + Vector2(26.0, 0.0), Vector2(1, 0), color)
				else:
					shop.draw_line(anchor + Vector2(0.0, -26.0), anchor + Vector2(0.0, 26.0), color, 9.0)
					_triangle(shop, anchor + Vector2(0.0, -26.0), Vector2(0, -1), color)
					_triangle(shop, anchor + Vector2(0.0, 26.0), Vector2(0, 1), color)
		&"zone":
			# Secagem: círculo-alvo que deriva pelo corpo; verde = bocal dentro.
			var target: Vector2 = shop.gesture_ui.get("zone_target", body_center) + jitter
			var radius: float = float(shop.gesture_ui.get("zone_radius", 110.0))
			var inside: bool = bool(shop.gesture_ui.get("zone_inside", false))
			var zone_color: Color = good_color(0.9) if inside else Color("ffffff", 0.75)
			shop.draw_circle(target, radius, Color(zone_color.r, zone_color.g, zone_color.b, 0.10))
			shop.draw_arc(target, radius, 0.0, TAU, 48, zone_color, 6.0)
			shop.draw_circle(target, 10.0, zone_color)
		&"pulse":
			# Perfume: anel que ACENDE na janela da borrifada + acertos em pips.
			var bright: bool = bool(shop.gesture_ui.get("pulse_bright", false))
			var ring_radius: float = 168.0 + (14.0 if bright else 0.0)
			if bright:
				shop.draw_circle(body_center, ring_radius, Color("ffd54f", 0.14))
				shop.draw_arc(body_center, ring_radius, 0.0, TAU, 48, Color("ffd54f", 0.95), 12.0)
			else:
				shop.draw_arc(body_center, ring_radius, 0.0, TAU, 48, Color("ffffff", 0.4), 5.0)
			var needed: int = maxi(1, int(shop.gesture_ui.get("pulses_needed", 3)))
			var hit: int = int(shop.gesture_ui.get("pulses_hit", 0))
			for i: int in needed:
				var pip: Vector2 = body_center + Vector2((i - (needed - 1) * 0.5) * 52.0, 240.0)
				shop.draw_circle(
					pip, 13.0, Color("ffd54f", 0.95) if i < hit else Color("ffffff", 0.30)
				)
				shop.draw_arc(pip, 13.0, 0.0, TAU, 16, Color("263238", 0.35), 3.0)
		&"drop":
			# Laço: marca no pescoço; anel verde quando o laço está na zona.
			var target: Vector2 = shop.gesture_ui.get("drop_target", body_center) + jitter * 0.5
			var radius: float = float(shop.gesture_ui.get("drop_radius", 110.0))
			var inside: bool = bool(shop.gesture_ui.get("drop_inside", false))
			var mark_color: Color = good_color(0.9) if inside else Color("ff8fb1", 0.9)
			for seg: int in 12:
				shop.draw_arc(
					target, radius, TAU * seg / 12.0 + 0.09, TAU * (seg + 1) / 12.0 - 0.09, 6,
					Color(mark_color.r, mark_color.g, mark_color.b, 0.65), 6.0
				)
			shop.draw_line(target + Vector2(-16, 0), target + Vector2(16, 0), mark_color, 6.0)
			shop.draw_line(target + Vector2(0, -16), target + Vector2(0, 16), mark_color, 6.0)


## Banheira dupla (Onda 3): o buddy é atendido em paralelo no cantinho da cena.
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
	var top: float = feet.y - 479.0 / 512.0 * size
	# Espuminha do atendimento em paralelo.
	shop.draw_circle(feet + Vector2(0.0, -14.0), 74.0, Color("e1f5fe", 0.55))
	shop.draw_arc(feet + Vector2(0.0, -14.0), 74.0, 0.0, TAU, 24, Color("b3e5fc", 0.9), 5.0)
	shop.draw_texture_rect(
		shop.buddy_texture, Rect2(feet.x - size * 0.5, top, size, size), false
	)
	shop.draw_string(
		shop.UI_TITLE_FONT,
		feet + Vector2(-64.0, -150.0),
		"+40%",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		24,
		Color("263238", 0.65)
	)


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
