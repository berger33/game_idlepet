class_name BathService
extends RefCounted
## Máquina de estados pura e testável do primeiro serviço.

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


func configure(
	duration: float, target_min: float, target_max: float, required_distance: float
) -> void:
	duration_seconds = maxf(2.0, duration)
	target_minimum = clampf(target_min, 0.4, 0.95)
	target_maximum = clampf(target_max, target_minimum + 0.01, 1.0)
	distance_required = maxf(300.0, required_distance)


func start_service() -> void:
	state = State.ACTIVE
	progress = 0.0
	time_left = duration_seconds
	rub_distance = 0.0
	has_pointer = false


func tick(delta: float) -> bool:
	if state != State.ACTIVE:
		return false
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		state = State.FAILED
		return true
	return false


func rub(pointer: Vector2) -> float:
	if state != State.ACTIVE:
		return progress
	if has_pointer:
		var distance: float = minf(pointer.distance_to(last_pointer), 90.0)
		rub_distance += distance
		progress = clampf(progress + distance / distance_required, 0.0, 1.0)
	last_pointer = pointer
	has_pointer = true
	return progress


func release_pointer() -> void:
	has_pointer = false


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
