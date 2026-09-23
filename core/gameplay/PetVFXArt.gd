class_name PetVFXArt
extends RefCounted
## VFX de serviço, bolhas, corações, drips — extraído de PetShopCanvas para
## manter Main<1100 e canvas organizado, parte do upgrade 10/10 vivo.

static func draw_service_effects(shop, beat_pulse: float) -> void:
	var effect_count: int = int(shop.progress * 18.0) if shop._service_effect_active() else 0
	for i: int in effect_count:
		var angle: float = float(i) * 2.4 + shop.shake_phase * 0.6
		var radius: float = 70.0 + float(i % 5) * 23.0 + beat_pulse * 8.0
		var effect_pos: Vector2 = shop.pet_position + Vector2(cos(angle), sin(angle) * 0.5) * radius + Vector2(0, 70)
		if shop.service_mode == &"bath":
			var foam: Color = shop._bath_foam_color()
			var foam_r: float = 30.0 + (i % 3) * 6.0 + beat_pulse * 4.0
			shop.draw_circle(effect_pos, foam_r, Color(foam, 0.95))
			shop.draw_arc(effect_pos, foam_r * 0.85, 0, TAU, 20, foam.darkened(0.18), 4)
			if i % 4 == 0:
				shop.draw_circle(effect_pos + Vector2(-6, -6), 5.0, Color("ffffff", 0.6))
		elif shop.service_mode == &"groom":
			var tuft_a: Vector2 = effect_pos - Vector2(16, 10)
			var tuft_b: Vector2 = effect_pos + Vector2(16, 10)
			shop.draw_line(tuft_a, tuft_b, shop.ear_color, 9)
			shop.draw_line(effect_pos + Vector2(-14, 12), effect_pos + Vector2(14, -12), shop.fur_color, 7)
			if i % 3 == 0:
				shop.draw_circle(effect_pos, 4.0 + beat_pulse * 2.0, Color("ffffff", 0.7))
		elif shop.service_mode == &"dry":
			var wind_alpha: float = 0.75 + 0.25 * beat_pulse
			shop.draw_arc(effect_pos, 38.0, -0.9, 0.9, 14, Color("e1f5fe", wind_alpha), 7)
			shop.draw_arc(effect_pos, 28.0, -0.6, 0.6, 10, Color("b3e5fc", wind_alpha * 0.6), 4)
			if i % 5 == 0:
				shop.draw_circle(effect_pos, 3.0, Color("ffffff", 0.5))
		elif shop.service_mode == &"perfume":
			var mist_r: float = 16.0 + float(i % 3) * 5.0 + beat_pulse * 6.0
			shop.draw_circle(effect_pos, mist_r, Color("ce93d8", 0.42))
			shop.draw_circle(effect_pos, mist_r * 0.5, Color("ffffff", 0.32))
		else:
			var glint_r: float = 9.0 + float(i % 3) * 3.0 + beat_pulse * 3.0
			shop.draw_circle(effect_pos, glint_r, Color("ff8fb1", 0.78))
			shop.draw_arc(effect_pos, glint_r + 10.0, -0.7, 0.7, 8, Color("ffffff", 0.85), 3)
			if i % 4 == 0:
				_star(shop, effect_pos, 6.0 + beat_pulse * 2.0, Color("ffffff", 0.6))

static func draw_bubbles(shop, beat_pulse: float) -> void:
	for particle: Dictionary in shop.bubbles:
		var particle_alpha: float = clampf(float(particle["life"]), 0.0, 0.85)
		var beat_pop: float = 1.0 + beat_pulse * 0.22
		if shop.service_mode == &"bath":
			var bubble_foam: Color = shop._bath_foam_color()
			var bubble_r: float = float(particle["r"]) * beat_pop
			shop.draw_circle(particle["p"], bubble_r, Color(bubble_foam.lightened(0.35), particle_alpha))
			shop.draw_arc(particle["p"], bubble_r, 0, TAU, 18, bubble_foam.darkened(0.3), 3)
			shop.draw_circle(particle["p"] + Vector2(-bubble_r * 0.25, -bubble_r * 0.25), bubble_r * 0.22, Color("ffffff", particle_alpha * 0.55))
		elif shop.service_mode == &"groom":
			var tuft_size: float = float(particle["r"]) * 0.7 * beat_pop
			var tuft_color: Color = shop.fur_color
			tuft_color.a = particle_alpha
			shop.draw_line(particle["p"] - Vector2(tuft_size, 8), particle["p"] + Vector2(tuft_size, -8), tuft_color, 6)
			if particle_alpha > 0.5:
				shop.draw_circle(particle["p"], 3.0, Color("ffffff", particle_alpha * 0.4))
		elif shop.service_mode == &"dry":
			var wind_len: float = 42.0 * beat_pop
			shop.draw_line(particle["p"] - Vector2(wind_len, 0), particle["p"] + Vector2(24, 0), Color("e1f5fe", particle_alpha), 6)
			shop.draw_line(particle["p"] - Vector2(wind_len * 0.6, 8.0), particle["p"] + Vector2(16, 8), Color("b3e5fc", particle_alpha * 0.5), 3)
		elif shop.service_mode == &"perfume":
			var mist_r: float = float(particle["r"]) * 0.65 * beat_pop
			shop.draw_circle(particle["p"], mist_r, Color("ce93d8", particle_alpha * 0.7))
			shop.draw_circle(particle["p"], mist_r * 0.4, Color("ffffff", particle_alpha * 0.5))
		else:
			var bow_r: float = float(particle["r"]) * 0.5 * beat_pop
			shop.draw_circle(particle["p"], bow_r, Color("ff8fb1", particle_alpha))
			if particle_alpha > 0.4:
				_star(shop, particle["p"], bow_r * 0.6, Color("ffffff", particle_alpha * 0.7))

static func draw_hearts(shop) -> void:
	for heart: Dictionary in shop.hearts:
		shop._draw_heart(heart["p"], float(heart["size"]), Color("ff6f91", clampf(float(heart["life"]), 0.0, 1.0)))

static func draw_drips(shop) -> void:
	for drip: Dictionary in shop.water_drips:
		var alpha: float = clampf(float(drip["life"]) * 1.5, 0.0, 0.7)
		shop.draw_circle(drip["p"], float(drip["r"]), Color("4fc3f7", alpha))

static func draw_celebration(shop, beat_pulse: float) -> void:
	if shop.celebration <= 0.0 or not shop.special_reward_active:
		return
	var star_count: int = 20 if GameState.services_completed == 0 else 14
	for i: int in star_count:
		var angle: float = TAU * float(i) / float(star_count) + shop.shake_phase
		var star_pos: Vector2 = shop.pet_position + Vector2(cos(angle), sin(angle)) * (190.0 + beat_pulse * 26.0 + 12.0 * sin(shop.shake_phase * 6.0 + i))
		_star(shop, star_pos, 18.0 + (6.0 if GameState.services_completed == 0 else 0.0), Color("ffd54f" if i % 2 == 0 else "ff8fb1"))
	if GameState.services_completed == 0:
		for c: int in 12:
			var ca: float = TAU * float(c) / 12.0 + shop.shake_phase * 1.3
			var cr: float = 80.0 + float(c % 4) * 40.0 + 30.0 * sin(shop.shake_phase * 2.0 + c)
			var cpos: Vector2 = shop.pet_position + Vector2(cos(ca), sin(ca) * 0.6) * cr + Vector2(0, -120 - 40 * sin(shop.celebration * 3.0 + c))
			var ccol: Color = [Color("ff8fb1"), Color("4fc3f7"), Color("ffd54f"), Color("43a047"), Color("ce93d8")][c % 5]
			shop.draw_circle(cpos, 9.0 + 3.0 * sin(shop.shake_phase * 4.0 + c), ccol)

static func _star(shop, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var r: float = radius if i % 2 == 0 else radius * 0.42
		var angle: float = -PI / 2.0 + float(i) * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	shop.draw_colored_polygon(points, color)
