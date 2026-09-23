class_name BathService
extends RefCounted
## Máquina de estados pura e testável do atendimento.
##
## Onda 1 do design de engajamento (docs/DESIGN_ENGAJAMENTO.md): cada serviço
## tem um GESTO próprio em vez do mesmo "esfregar até encher":
##   bath    -> "rub"    dosagem clássica (esfregada livre + janela no aro)
##   groom   -> "stroke" traçado direcionado: N passos com eixo próprio
##   dry     -> "zone"   manter o bocal dentro do círculo que deriva no pet
##   perfume -> "pulse"  borrifadas no ritmo: contato novo com o anel aceso
##   style   -> "drop"   encaixe de precisão: colar na marca do pescoço
## Temperamento/espécie ajustam janela, tremor e ritmo (Main configura a
## partir do catálogo pets.json).

enum State { WAITING, ACTIVE, COMPLETE, FAILED }

## Abaixo disso, soltar a ferramenta não "entrega" o serviço (permite retomar esfregando).
const GOOD_FLOOR: float = 0.62

var state: State = State.WAITING
var progress: float = 0.0
var time_left: float = 0.0
var rub_distance: float = 0.0
var last_pointer: Vector2 = Vector2.ZERO
var has_pointer: bool = false
var duration_seconds: float = 6.0
var target_minimum: float = 0.82
var target_maximum: float = 0.96
var distance_required: float = 1450.0
## Gesto do serviço: eixo contabilizado, modo de preenchimento e limites.
## "rub" acumula distância de esfregada (filtrada pelo eixo); "hold" preenche
## por tempo enquanto a ferramenta está em contato (segurar = borrifar).
var axis: StringName = &"any"
var fill_mode: StringName = &"rub"
var rub_cap: float = 90.0
var hold_rate: float = 0.0

## Traçado (tosa): sequência de passos com eixo próprio; distância no eixo
## errado não pontua (aprende-se a "seguir a seta" — a seta é o stroke atual).
var stroke_axes: Array[StringName] = []
var stroke_quota: float = 520.0
var stroke_distance: float = 0.0
var stroke_index: int = 0

## Zona (secagem): alvo que deriva pelo corpo do pet; o contato dentro do
## raio enche, fora drena devagar — é preciso ACOMPANHAR o bocal.
var zone_target: Vector2 = Vector2.ZERO
var zone_home: Vector2 = Vector2.ZERO
var zone_radius: float = 80.0
var zone_speed: float = 0.9
var zone_drift_time: float = 0.0
var zone_inside: bool = false

## Pulso (perfume): anel acende em janelas; um NOVO contato na janela = acerto,
## contato na janela apagada = borrifada desperdiçada (pequena perda).
var pulse_period: float = 1.5
var pulse_window: float = 0.5
var pulse_time: float = 0.0
var pulses_needed: int = 3
var pulses_hit: int = 0
var pulse_miss_penalty: float = 0.03

## Encaixe (laço): marca no pescoço; a taxa de enchimento escala com a
## proximidade — colado na marca enche rápido, longe não enche.
var drop_target: Vector2 = Vector2.ZERO
var drop_radius: float = 80.0
var drop_rate: float = 0.8
var drop_distance: float = 9999.0

## Temperamento: tremor do UI de gesto (agitado) e pulinhos que interrompem
## o gesto por instantes (brincalhão) — o pet participa da dificuldade.
var shake_amplitude: float = 0.0
var hop_interval: float = -1.0
var hop_countdown: float = 0.0
var hop_left: float = 0.0
var hopping: bool = false


func configure(
	duration: float, target_min: float, target_max: float, required_distance: float
) -> void:
	duration_seconds = maxf(2.0, duration)
	target_minimum = clampf(target_min, 0.4, 0.95)
	target_maximum = clampf(target_max, target_minimum + 0.01, 1.0)
	distance_required = maxf(300.0, required_distance)


func configure_gesture(
	gesture_axis: StringName, mode: StringName, cap: float, rate: float
) -> void:
	axis = gesture_axis
	fill_mode = mode
	rub_cap = clampf(cap, 4.0, 90.0)
	hold_rate = clampf(rate, 0.0, 0.5)


func configure_strokes(axes: Array, quota: float) -> void:
	stroke_axes.clear()
	for entry: Variant in axes:
		stroke_axes.append(StringName(entry))
	stroke_quota = maxf(120.0, quota)


func configure_zone(home: Vector2, radius: float, speed: float) -> void:
	zone_home = home
	zone_radius = maxf(50.0, radius)
	zone_speed = clampf(speed, 0.2, 3.0)
	zone_target = home


func configure_pulses(needed: int, period: float, window: float) -> void:
	pulses_needed = clampi(needed, 1, 6)
	pulse_period = maxf(0.6, period)
	pulse_window = clampf(window, 0.12, 0.8)
	pulses_hit = 0
	pulse_time = 0.0


func configure_drop(target: Vector2, radius: float, rate: float) -> void:
	drop_target = target
	drop_radius = maxf(40.0, radius)
	drop_rate = clampf(rate, 0.05, 1.2)


func configure_temperament(shake: float, hop_every_seconds: float) -> void:
	shake_amplitude = clampf(shake, 0.0, 1.0)
	hop_interval = hop_every_seconds


func start_service() -> void:
	state = State.ACTIVE
	progress = 0.0
	time_left = duration_seconds
	rub_distance = 0.0
	has_pointer = false
	stroke_distance = 0.0
	stroke_index = 0
	zone_drift_time = 0.0
	zone_target = zone_home
	zone_inside = false
	pulse_time = 0.0
	pulses_hit = 0
	drop_distance = 9999.0
	hop_left = 0.0
	hopping = false
	hop_countdown = hop_interval if hop_interval > 0.0 else -1.0


func pulse_bright() -> bool:
	return fmod(pulse_time, pulse_period) < pulse_period * pulse_window


## Um novo contato da ferramenta com o pet (usado no modo pulso): acerto se
## o anel está aceso, desperdício se está apagado. Retorna o resultado.
func pulse_contact() -> StringName:
	if state != State.ACTIVE or fill_mode != &"pulse":
		return &"ignored"
	if hopping:
		return &"ignored"
	if pulses_hit >= pulses_needed:
		progress = 1.0
		return &"ignored"
	if pulse_bright():
		pulses_hit = mini(pulses_hit + 1, pulses_needed)
		progress = clampf(float(pulses_hit) / float(pulses_needed), 0.0, 1.0)
		return &"hit"
	progress = maxf(0.0, progress - pulse_miss_penalty)
	return &"miss"


func tick(delta: float) -> bool:
	if state != State.ACTIVE:
		return false
	# Pulinho do pet brincalhão: interrompe o gesto por um instante.
	if hop_left > 0.0:
		hop_left = maxf(0.0, hop_left - delta)
		hopping = hop_left > 0.0
		if hopping:
			time_left = maxf(0.0, time_left - delta)
			if time_left <= 0.0:
				state = State.FAILED
				return true
			return false
		# fim do pulinho: retoma
	elif hop_interval > 0.0:
		hop_countdown -= delta
		if hop_countdown <= 0.0:
			hop_left = 0.4
			hopping = true
			hop_countdown = hop_interval + randf_range(0.0, 1.5)
	# Zona de secagem deriva continuamente (lissajous suave e determinístico).
	if fill_mode == &"zone":
		zone_drift_time += delta * zone_speed
		zone_target = zone_home + Vector2(
			sin(zone_drift_time * 1.6) * 78.0, cos(zone_drift_time * 2.2) * 48.0
		)
		if has_pointer:
			if zone_inside and hop_left <= 0.0:
				progress = clampf(progress + hold_rate * delta, 0.0, 1.0)
			else:
				# Drenagem suave fora da zona (0.06 vs 0.08) — penaliza sem frustrar
				progress = maxf(0.0, progress - 0.06 * delta)
	elif fill_mode == &"pulse":
		pulse_time += delta
	elif fill_mode == &"hold" and has_pointer and hold_rate > 0.0:
		if hop_left <= 0.0:
			progress = clampf(progress + hold_rate * delta, 0.0, 1.0)
	elif fill_mode == &"drop" and has_pointer:
		if hop_left <= 0.0:
			var proximity: float = clampf(1.0 - drop_distance / drop_radius, 0.0, 1.0)
			# Curva quadrática: colado enche muito rápido, na borda quase nada
			if proximity > 0.0:
				progress = clampf(
					progress + drop_rate * proximity * proximity * delta, 0.0, 1.0
				)
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		state = State.FAILED
		return true
	return false


func rub(pointer: Vector2) -> float:
	if state != State.ACTIVE:
		return progress
	if fill_mode == &"rub" and has_pointer and hop_left <= 0.0:
		var delta_v: Vector2 = pointer - last_pointer
		var distance: float
		match axis:
			&"vertical":
				distance = absf(delta_v.y)
			&"horizontal":
				distance = absf(delta_v.x)
			_:
				distance = delta_v.length()
		distance = minf(distance, rub_cap)
		rub_distance += distance
		progress = clampf(progress + distance / distance_required, 0.0, 1.0)
	elif fill_mode == &"stroke" and has_pointer and hop_left <= 0.0:
			# Guard: tosa completa ou mal configurada — sem OOB (fix crash poodle)
			if stroke_axes.is_empty():
				last_pointer = pointer
				has_pointer = true
				return progress
			if stroke_index >= stroke_axes.size():
				progress = 1.0
				last_pointer = pointer
				has_pointer = true
				return progress
			# Só pontua o movimento no eixo do passo atual: "seguir a seta".
			var move: Vector2 = pointer - last_pointer
			var stroke_axis: StringName = stroke_axes[stroke_index]
			var along: float = absf(move.y if stroke_axis == &"vertical" else move.x)
			stroke_distance += minf(along, rub_cap)
			var total: float = stroke_quota * float(maxi(1, stroke_axes.size()))
			var done: float = stroke_quota * float(stroke_index) + stroke_distance
			progress = clampf(done / total, 0.0, 1.0)
			if stroke_distance >= stroke_quota:
				stroke_distance = 0.0
				stroke_index += 1
				# Trava no fim: não deixa índice estourar no próximo rub
				if stroke_index > stroke_axes.size():
					stroke_index = stroke_axes.size()
	elif fill_mode == &"zone":
		zone_inside = pointer.distance_to(zone_target) <= zone_radius
	elif fill_mode == &"drop":
		drop_distance = pointer.distance_to(drop_target)
	last_pointer = pointer
	has_pointer = true
	return progress


func release_pointer() -> void:
	has_pointer = false
	zone_inside = false


func finish() -> StringName:
	if state != State.ACTIVE:
		return &"invalid"
	if progress >= target_minimum and progress <= target_maximum:
		state = State.COMPLETE
		return &"perfect"
	if progress >= GOOD_FLOOR and progress < target_minimum:
		state = State.COMPLETE
		return &"good"
	state = State.FAILED
	return &"too_soon" if progress < GOOD_FLOOR else &"overwashed"
