class_name BathService
extends RefCounted
## Máquina de estados pura e testável do primeiro serviço.

enum State { WAITING, ACTIVE, COMPLETE, FAILED }
var state: State = State.WAITING
var progress: float = 0.0
var time_left: float = 0.0
var rub_distance: float = 0.0
var last_pointer: Vector2 = Vector2.ZERO
var has_pointer: bool = false

func start_service() -> void:
    state = State.ACTIVE
    progress = 0.0
    time_left = RemoteConfig.get_float("bath_duration")
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
        progress = clampf(progress + distance / 1450.0, 0.0, 1.0)
    last_pointer = pointer
    has_pointer = true
    return progress

func release_pointer() -> void:
    has_pointer = false

func finish() -> StringName:
    if state != State.ACTIVE:
        return &"invalid"
    var minimum: float = RemoteConfig.get_float("bath_target_min")
    var maximum: float = RemoteConfig.get_float("bath_target_max")
    if progress >= minimum and progress <= maximum:
        state = State.COMPLETE
        return &"perfect"
    if progress >= 0.62 and progress < 1.0:
        state = State.COMPLETE
        return &"good"
    state = State.FAILED
    return &"too_soon" if progress < 0.62 else &"overwashed"
