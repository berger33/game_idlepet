extends RefCounted
## Lógica das 3 atividades do Parquinho: ball (arrastar bolinha), treat (esconder petisco), photo (foto do grupo).
## Design: fora da banheira, a cada X tempo (RemoteConfig 2h), recompensa afeto+coins, sem punir fila.

enum State {IDLE, ACTIVE, COMPLETE, FAILED}
enum Activity {BALL, TREAT, PHOTO}

const ACTIVITY_IDS: Dictionary = {&"ball": Activity.BALL, &"treat": Activity.TREAT, &"photo": Activity.PHOTO}
const ACTIVITY_NAMES: Dictionary = {Activity.BALL: &"ball", Activity.TREAT: &"treat", Activity.PHOTO: &"photo"}

## Durações base (confortáveis, pet respira em cena — não é ritmo de banheira)
const DURATIONS: Dictionary = {
	Activity.BALL: 12.0,
	Activity.TREAT: 10.0,
	Activity.PHOTO: 10.0,
}
## Alvo para perfeito: centro da barra
const TARGET_MIN: float = 0.72
const TARGET_MAX: float = 1.0

var activity: Activity = Activity.BALL
var state: State = State.IDLE
var duration: float = 12.0
var time_left: float = 12.0
var progress: float = 0.0 # 0..1
var score: int = 0 # acertos (bolinha / treat / foto)
var target_hits: int = 0
var perfect: bool = false
var playful_hop: bool = false

# ball: arrastar bolinha até o pet
var ball_pos: Vector2 = Vector2(540, 1050)
var ball_held: bool = false
var fetch_count: int = 0

# treat: 3 potes, um com petisco
var treat_slots: Array[int] = [0, 0, 0] # 0 vazio, 1 tem petisco
var treat_choice: int = -1
var treat_revealed: bool = false
var treat_hidden_slot: int = 1

# photo: alinhar 3 pets no quadro
var photo_align: float = 0.0 # 0..1 alinhamento
var photo_shots: int = 0
var photo_window: float = 0.0

func configure(id: StringName) -> void:
	activity = ACTIVITY_IDS.get(id, Activity.BALL)
	duration = DURATIONS.get(activity, 12.0)
	time_left = duration
	progress = 0.0
	score = 0
	target_hits = 0
	fetch_count = 0
	photo_shots = 0
	photo_align = 0.0
	perfect = false
	state = State.IDLE
	treat_choice = -1
	treat_revealed = false
	treat_hidden_slot = randi() % 3
	treat_slots = [0, 0, 0]
	treat_slots[treat_hidden_slot] = 1
	ball_pos = Vector2(540, 1050)
	ball_held = false
	photo_window = randf_range(2.5, 5.0)

func start() -> void:
	state = State.ACTIVE
	time_left = duration
	progress = 0.0

func tick(delta: float) -> bool:
	if state != State.ACTIVE:
		return false
	time_left = maxf(0.0, time_left - delta)
	if activity == Activity.PHOTO:
		photo_window -= delta
		if photo_window <= 0.0:
			# janela de foto: pico de alinhamento
			photo_align = clampf(photo_align + randf_range(-0.25, 0.35), 0.0, 1.0)
			photo_window = randf_range(1.2, 2.0)
		else:
			photo_align = move_toward(photo_align, 0.5, delta * 0.25)
	if time_left <= 0.0:
		state = State.FAILED
		return true
	return false

func drag_ball(to: Vector2, pet_focus: Vector2) -> void:
	if state != State.ACTIVE or activity != Activity.BALL:
		return
	ball_pos = to
	var dist: float = to.distance_to(pet_focus)
	if dist < 110.0:
		# perto do pet: acumula progresso e conta fetch
		progress = clampf(progress + 0.018, 0.0, 1.0)
		if fetch_count < 10 and progress > float(fetch_count + 1) * 0.09:
			fetch_count += 1
			score += 1
			playful_hop = true
	else:
		playful_hop = false
		progress = clampf(progress - 0.004, 0.0, 1.0)

func pick_treat(slot: int) -> void:
	if state != State.ACTIVE or activity != Activity.TREAT or treat_revealed:
		return
	treat_choice = clampi(slot, 0, 2)
	treat_revealed = true
	progress = 0.85 if treat_slots[treat_choice] == 1 else 0.35
	score = 1 if treat_slots[treat_choice] == 1 else 0
	if score == 1:
		fetch_count = 3
		perfect = true

func try_photo() -> bool:
	if state != State.ACTIVE or activity != Activity.PHOTO:
		return false
	photo_shots += 1
	# foto perfeita se alinhamento > 0.72 no momento do clique
	if photo_align >= TARGET_MIN:
		score += 1
		progress = clampf(progress + 0.42, 0.0, 1.0)
		if progress >= 0.92:
			perfect = true
		return true
	else:
		progress = clampf(progress - 0.08, 0.0, 1.0)
		return false

func finish() -> StringName:
	if state != State.ACTIVE:
		return &"fail"
	if activity == Activity.BALL:
		if progress >= 0.88 and fetch_count >= 3:
			perfect = progress >= 0.96
			state = State.COMPLETE
			return &"perfect" if perfect else &"good"
		elif progress >= 0.62:
			state = State.COMPLETE
			return &"good"
		else:
			state = State.FAILED
			return &"fail"
	elif activity == Activity.TREAT:
		if treat_choice < 0:
			state = State.FAILED
			return &"fail"
		state = State.COMPLETE
		return &"perfect" if score == 1 else &"good"
	elif activity == Activity.PHOTO:
		if progress >= 0.72:
			state = State.COMPLETE
			return &"perfect" if perfect and score >= 2 else &"good"
		else:
			state = State.FAILED
			return &"fail"
	state = State.FAILED
	return &"fail"

func quick_hint() -> String:
	match activity:
		Activity.BALL: return Loc.t("PARK_HINT_BALL")
		Activity.TREAT: return Loc.t("PARK_HINT_TREAT")
		Activity.PHOTO: return Loc.t("PARK_HINT_PHOTO")
		_: return ""
