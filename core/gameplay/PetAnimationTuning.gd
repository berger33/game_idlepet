class_name PetAnimationTuning
extends RefCounted
## Helper estático 10/10 — toda matemática de animação viva fica aqui para
## manter PetShopCanvas <1000 linhas e Main <1100. Nenhum PNG novo exigido
## para P0-P1, apenas deformação procedural dos sprites existentes.

# ── Respiração & Bob por temperamento + afeto + rush + porte + fila vazia ──

static func breathing_scale(
	temperament: StringName,
	affection: int,
	rush_active: bool,
	vip_active: bool,
	empty_time: float,
	phase: float,
	small_breed: bool,
	large_breed: bool
) -> Vector2:
	# freq base e amplitude por temperamento
	var freq: float = 2.2
	var amp_x: float = 0.004
	var amp_y: float = 0.012
	match temperament:
		&"calm", &"gentle":
			freq = 1.4
			amp_x = 0.002
			amp_y = 0.008
		&"elegant":
			freq = 1.6
			amp_x = 0.0025
			amp_y = 0.009
		&"happy", &"curious":
			freq = 2.2
			amp_x = 0.004
			amp_y = 0.012
		&"playful":
			freq = 2.6
			amp_x = 0.005
			amp_y = 0.014
		&"active", &"irritated":
			freq = 3.2
			amp_x = 0.006
			amp_y = 0.018
		&"anxious", &"fearful":
			# irregular: base 2.2 + oscilação lenta 1.7 rad
			freq = 2.2 + sin(phase * 1.7) * 0.6
			amp_x = 0.003 + absf(sin(phase * 7.3)) * 0.002
			amp_y = 0.010 + absf(cos(phase * 6.1)) * 0.006
	# porte
	if small_breed:
		freq *= 1.2
		amp_x *= 0.9
	elif large_breed:
		freq *= 0.85
		amp_y *= 1.15
	# afeto: pet relaxado respira mais lento e suave
	if affection >= 50:
		freq *= 0.75
		amp_x *= 0.8
		amp_y *= 0.8
	elif affection >= 25:
		freq *= 0.85
		amp_x *= 0.85
		amp_y *= 0.9
	# rush: alerta, respira rápido
	if rush_active:
		freq *= 1.5
		amp_y *= 1.2
	if vip_active:
		freq *= 1.15
		amp_x *= 1.1
	# fila vazia >8s: quase dormindo, lento
	if empty_time > 8.0:
		freq *= 0.7
		amp_y *= 0.7
	if empty_time > 12.0:
		freq *= 0.6
	var sx: float = 1.0 - sin(phase * freq) * amp_x
	var sy: float = 1.0 + sin(phase * freq) * amp_y
	return Vector2(sx, sy)

static func bob_amplitude(
	temperament: StringName,
	affection: int,
	happy: bool,
	rush_active: bool,
	empty_time: float,
	phase: float
) -> float:
	var base_freq: float = 5.0
	var amp: float = 3.0 if happy else 1.2
	match temperament:
		&"calm", &"gentle", &"elegant":
			base_freq = 1.8
			amp *= 0.7
		&"playful", &"active":
			base_freq = 6.5
			amp *= 1.2
		&"anxious", &"fearful":
			base_freq = 4.0
			amp += sin(phase * 9.0) * 0.6 # tremida
		&"irritated":
			base_freq = 5.5
			amp *= 1.1
	if affection >= 50:
		amp *= 0.6
		base_freq *= 0.8
	if rush_active:
		amp *= 1.3
		base_freq *= 1.2
	if empty_time > 8.0:
		amp *= 0.5
		base_freq *= 0.6
	return sin(phase * base_freq) * amp

# ── Cauda com personalidade ──

static func tail_wag(
	species: StringName,
	temperament: StringName,
	affection: int,
	happy: bool,
	celebration: float,
	phase: float,
	breed_name: String,
	is_small: bool,
	is_large: bool
) -> float:
	# retorna radianos de wag (para arc)
	var wag: float = 0.0
	var affection_factor: float = float(affection) / 50.0 # 0-1
	var breed_factor: float = 1.0
	if is_small:
		breed_factor = 1.3
	elif is_large:
		breed_factor = 0.8
	# Basset/Beagle etc cauda mais lenta pesada
	if breed_name.contains("Basset") or breed_name.contains("Beagle") or breed_name.contains("Dachshund"):
		breed_factor *= 0.7
	if species == &"cat":
		# gato: flick rápido + spike aleatório
		var base: float = sin(phase * 8.0) * 0.15
		# spike a cada ~2-4s usando hash da fase
		var spike_phase: float = fmod(phase, 3.2)
		var spike: float = 0.0
		if spike_phase < 0.18:
			spike = sin(PI * spike_phase / 0.18) * 0.6
		wag = (base + spike) * (0.5 + affection_factor * 0.5)
		if happy or celebration > 0.0:
			# gato feliz: slow sway, não wag frenético
			wag = sin(phase * 0.9) * 0.25 + base * 0.5
		# afeto baixo = cauda baixa (offset negativo)
		if affection < 10:
			wag -= 0.3
	else:
		# cão: wag clássico, frequência cresce com afeto e felicidade
		var freq: float = (4.0 + affection_factor * 2.5) * breed_factor
		if happy or celebration > 0.0:
			freq *= 1.5
		var amp: float = (0.25 + affection_factor * 0.35) * breed_factor
		if celebration > 0.0:
			amp *= 2.5
		wag = sin(phase * freq) * amp
		# temperamento
		match temperament:
			&"playful", &"active":
				wag *= 1.3
			&"fearful", &"anxious":
				wag *= 0.5
				if affection < 10:
					wag -= 0.25
			&"calm", &"gentle":
				wag *= 0.7
	return wag

# ── Olho que segue ferramenta ──

static func eye_offset(
	target: Vector2,
	body_center: Vector2,
	temperament: StringName,
	anticipation: float,
	affection: int,
	rush_active: bool
) -> Vector2:
	var dir: Vector2 = target - body_center
	var dist: float = dir.length()
	if dist < 1.0:
		return Vector2.ZERO
	dir = dir.normalized()
	# distância máxima do olho (px no sprite)
	var max_offset: float = 6.0
	# temperamento modula quanto olha
	match temperament:
		&"fearful":
			max_offset = 3.0
			# evita contato: olha para lado oposto quando anticipation alta
			if anticipation > 0.5:
				dir = -dir
				max_offset = 2.0
		&"anxious":
			max_offset = 3.5
		&"curious", &"playful":
			max_offset = 7.5
		&"calm", &"gentle", &"elegant":
			max_offset = 5.0
	# afeto aumenta contato visual
	if affection >= 25:
		max_offset += 1.0
	if affection >= 50:
		max_offset += 1.5
	if rush_active:
		max_offset += 1.0
	# clamp por distância: mais perto = mais offset, mas limitado
	var t: float = clampf(dist / 400.0, 0.0, 1.0)
	# curva: perto 0-100px = offset máximo, longe diminui
	var proximity_factor: float = 1.0 - t * 0.6
	return dir * max_offset * proximity_factor

# ── Orelha secondary motion ──

static func ear_jiggle(
	species: StringName,
	breed_name: String,
	phase: float,
	jump_height: float,
	celebration: float,
	happy: bool
) -> Vector2:
	var ear_factor: float = 1.0
	# orelhas grandes e moles balançam mais
	if breed_name.contains("Basset") or breed_name.contains("Beagle") or breed_name.contains("Dachshund"):
		ear_factor = 2.5
	elif breed_name.contains("Poodle") or breed_name.contains("Samoieda") or breed_name.contains("Maine Coon"):
		ear_factor = 1.8
	elif breed_name.contains("Husky") or breed_name.contains("Akita") or breed_name.contains("Corgi") or breed_name.contains("Spitz") or breed_name.contains("Doberman") or breed_name.contains("Pinscher"):
		ear_factor = 0.4
	elif species == &"cat":
		ear_factor = 0.6
	else:
		ear_factor = 1.0
	var y: float = sin(phase * 5.0 + jump_height * 0.05) * (1.5 * ear_factor)
	if happy or celebration > 0.0:
		y += sin(phase * 7.0) * 1.0 * ear_factor
	y += jump_height * 0.04 * ear_factor
	# x leve balanço lateral
	var x: float = sin(phase * 3.2) * 0.8 * ear_factor
	return Vector2(x, y)

# ── Antecipação (<220px) ──

static func anticipation_factor(tool_pos: Vector2, body_center: Vector2, service_active: bool, tool_visible: bool) -> float:
	if not service_active or not tool_visible:
		return 0.0
	var dist: float = tool_pos.distance_to(body_center)
	if dist > 220.0:
		return 0.0
	return 1.0 - dist / 220.0

static func anticipation_reaction_scale(temperament: StringName, anticipation: float) -> Vector2:
	if anticipation <= 0.0:
		return Vector2.ONE
	match temperament:
		&"fearful", &"anxious":
			# encolhe
			return Vector2(1.0 - anticipation * 0.08, 1.0 + anticipation * 0.05)
		&"irritated":
			return Vector2(1.0 + anticipation * 0.04, 1.0 - anticipation * 0.03)
		_:
			# feliz/curioso inclina levemente (scale x maior)
			return Vector2(1.0 + anticipation * 0.03, 1.0 - anticipation * 0.02)

static func anticipation_spin(temperament: StringName, anticipation: float) -> float:
	if anticipation <= 0.0:
		return 0.0
	match temperament:
		&"fearful", &"anxious":
			return -anticipation * 0.04
		&"irritated":
			return anticipation * 0.02 * sin(Time.get_ticks_msec() * 0.01)
		_:
			return anticipation * 0.03

# ── Micro idles ──

static func micro_idle_name(
	idle_phase: float,
	empty_time: float,
	temperament: StringName,
	affection: int,
	random_seed: float
) -> StringName:
	# random_seed = fmod(phase, algo) ou randf, para variar
	# prioridade: fila vazia > yawn/sleep
	if empty_time > 12.0:
		return &"sleep" if random_seed < 0.6 else &"yawn"
	if empty_time > 6.0:
		return &"yawn" if random_seed < 0.5 else &"sniff"
	# temperamento influencia
	match temperament:
		&"playful", &"active":
			if random_seed < 0.25:
				return &"paw_shift"
			elif random_seed < 0.5:
				return &"tail_flick"
			elif random_seed < 0.7:
				return &"ear_twitch"
			else:
				return &"sniff"
		&"calm", &"gentle":
			if random_seed < 0.4:
				return &"blink_double"
			elif random_seed < 0.7:
				return &"nose_wiggle"
			else:
				return &"ear_twitch"
		&"anxious", &"fearful":
			if random_seed < 0.4:
				return &"ear_twitch"
			elif random_seed < 0.7:
				return &"paw_shift"
			else:
				return &"nose_wiggle"
		_:
			# distribuição geral
			if random_seed < 0.18:
				return &"ear_twitch"
			elif random_seed < 0.36:
				return &"nose_wiggle"
			elif random_seed < 0.54:
				return &"paw_shift"
			elif random_seed < 0.72:
				return &"yawn"
			elif random_seed < 0.86:
				return &"sniff"
			else:
				return &"tail_flick"

static func micro_idle_duration(state: StringName) -> float:
	match state:
		&"ear_twitch":
			return 0.18
		&"nose_wiggle":
			return 0.32
		&"paw_shift":
			return 0.22
		&"yawn":
			return 0.75
		&"sniff":
			return 0.42
		&"tail_flick":
			return 0.20
		&"blink_double":
			return 0.35
		&"sleep":
			return 2.5
		_:
			return 0.25

static func micro_idle_overlay_alpha(state: StringName) -> float:
	match state:
		&"yawn", &"sleep":
			return 0.85
		&"sniff":
			return 0.6
		_:
			return 0.55

# ── Piscada por espécie ──

static func blink_duration(species: StringName, temperament: StringName) -> Vector2:
	# x = duration janela fechada, y = intervalo ciclo
	if species == &"cat":
		# gato pisca mais lento, fenda
		var dur: float = 0.22
		var interval: float = 3.8
		if temperament == &"calm" or temperament == &"gentle":
			interval = 4.5
			dur = 0.28
		elif temperament == &"active" or temperament == &"playful":
			interval = 3.2
		return Vector2(dur, interval)
	else:
		var dur: float = 0.13
		var interval: float = 4.7
		if temperament == &"anxious" or temperament == &"fearful":
			interval = 3.5
			dur = 0.10
		elif temperament == &"calm":
			interval = 5.2
		return Vector2(dur, interval)

# ── Sombra reativa ──

static func shadow_scale(
	reaction_scale: Vector2,
	jump_height: float,
	happy: bool,
	celebration: float,
	empty_time: float
) -> Vector2:
	var sx: float = 1.0
	var sy: float = 1.0
	# squash: sombra larga curta
	if reaction_scale.y < 0.97:
		sx = 1.0 + (1.0 - reaction_scale.y) * 3.0
		sy = 0.7 + reaction_scale.y * 0.3
	# salto: sombra pequena clara
	if jump_height > 1.0:
		var t: float = clampf(jump_height / 72.0, 0.0, 1.0)
		sx *= 1.0 - t * 0.4
		sy *= 1.0 - t * 0.5
	if celebration > 0.0:
		sx *= 0.8
		sy *= 0.6
	if empty_time > 12.0:
		sx *= 1.2
		sy *= 0.8
	return Vector2(sx, sy)

static func shadow_alpha(jump_height: float, celebration: float) -> float:
	var base: float = 0.16
	if jump_height > 1.0:
		base *= 1.0 - clampf(jump_height / 72.0, 0.0, 1.0) * 0.6
	if celebration > 0.0:
		base *= 0.5
	return base

# ── Acessório flutter ──

static func accessory_sway(phase: float, jump_height: float, fit: float) -> Vector2:
	var sway_x: float = sin(phase * 2.0 + jump_height * 0.08) * 2.0 * fit
	var sway_y: float = sin(phase * 2.6) * 1.0 * fit + jump_height * 0.02 * fit
	return Vector2(sway_x, sway_y)

# ── Física pelo/vento ──

static func wind_offset(zone_target: Vector2, body_center: Vector2, inside: bool) -> Vector2:
	if not inside:
		return Vector2.ZERO
	var dir: Vector2 = (zone_target - body_center)
	if dir.length() < 1.0:
		return Vector2.ZERO
	return dir.normalized() * 2.0

# ── Afeto escala corações ──

static func affection_heart_scale(affection: int, index: int) -> float:
	var base: float = 20.0
	if affection >= 50:
		base = 28.0
	elif affection >= 25:
		base = 24.0
	# variação por índice para não ficar idêntico
	return base + float(index) * 2.0

# ── Porte helpers ──

static func is_small_breed(breed_name: String) -> bool:
	return (
		breed_name.contains("Pinscher")
		or breed_name.contains("Yorkshire")
		or breed_name.contains("Pug")
		or breed_name.contains("Maltês")
		or breed_name.contains("Munchkin")
		or breed_name.contains("Shih-tzu")
	)

static func is_large_breed(breed_name: String) -> bool:
	return (
		breed_name.contains("Golden")
		or breed_name.contains("Labrador")
		or breed_name.contains("Samoieda")
		or breed_name.contains("Bernês")
		or breed_name.contains("Maine Coon")
	)

static func ear_size_factor(breed_name: String, species: StringName) -> float:
	if breed_name.contains("Basset") or breed_name.contains("Beagle") or breed_name.contains("Dachshund"):
		return 2.5
	if breed_name.contains("Poodle") or breed_name.contains("Samoieda") or breed_name.contains("Maine Coon"):
		return 1.8
	if breed_name.contains("Husky") or breed_name.contains("Akita") or breed_name.contains("Corgi") or breed_name.contains("Spitz") or breed_name.contains("Doberman") or breed_name.contains("Pinscher"):
		return 0.4
	if species == &"cat":
		return 0.6
	return 1.0
