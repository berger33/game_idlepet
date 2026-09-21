class_name RushTuning
extends RefCounted
## Helper estático para pico do bairro + prova social + DDA.
## Mantém Main.gd abaixo de 1100 linhas (pattern SalonTuning/Research).

static func update_rush_labels(rush_active: bool, rush_left: float, rush_cooldown: float, rush_label: Label, rush_bar: ProgressBar) -> void:
	if rush_active:
		var total: float = RemoteConfig.get_float("rush_duration")
		var ratio: float = clampf(rush_left / maxf(0.1, total), 0.0, 1.0)
		if is_instance_valid(rush_label):
			rush_label.text = Loc.t("RUSH_ACTIVE") % int(ceilf(maxf(0.0, rush_left)))
			rush_label.modulate = Color("ffd54f") if fmod(rush_left, 0.8) < 0.4 else Color("ff8f00")
		if is_instance_valid(rush_bar):
			rush_bar.value = ratio * 100.0
			rush_bar.visible = true
	else:
		if is_instance_valid(rush_label):
			rush_label.text = Loc.t("RUSH_COOLDOWN") % int(ceilf(rush_cooldown)) if rush_cooldown <= 15.0 else ""
		if is_instance_valid(rush_bar):
			rush_bar.visible = false

static func proof_text() -> String:
	var names: Array[String] = ["Ana", "Carlos", "Bia", "Rafa", "Luna", "Maya", "Zé", "Téo", "Duda", "Leo"]
	var pets: Array[String] = ["Caramelo", "Mimi", "Thor", "Luna", "Bob", "Mel", "Nina", "Pipoca"]
	var msgs: Array[String] = ["amou o banho!", "★★★★★", "voltará!", "cheiroso!", "perfeito!", "obrigada!"]
	return "💬 %s: %s %s" % [names[randi() % names.size()], pets[randi() % pets.size()], msgs[randi() % msgs.size()]]

static func patience_factor(base: float, assistance: int) -> float:
	return base * 1.15 if assistance > 0 else base

static func window_bonus(base: float, assistance: int) -> float:
	return base + 0.20 if assistance > 0 else base
