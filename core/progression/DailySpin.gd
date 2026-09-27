class_name DailySpin
extends RefCounted
## Roleta diária simples (gatilho retenção D1): 1× por dia, recompensa
## variável escalada à renda + chance de brasa. Sem backend, 100% local,
## com pesos que garantem dopamina.

const REWARDS: Array[Dictionary] = [
	{"type": "coins", "mult": 0.8, "weight": 30, "label": "SPIN_COINS"},
	{"type": "coins", "mult": 1.5, "weight": 25, "label": "SPIN_COINS_DOUBLE"},
	{"type": "coins", "mult": 2.5, "weight": 12, "label": "SPIN_SUPER"},
	{"type": "embers", "amount": 1, "weight": 20, "label": "SPIN_EMBER_1"},
	{"type": "embers", "amount": 2, "weight": 8, "label": "SPIN_EMBER_2"},
	{"type": "freeze", "amount": 1, "weight": 5, "label": "SPIN_FREEZE"},
]

static func can_spin() -> bool:
	var last: String = String(GameState.settings.get("last_spin_date", ""))
	var today: String = Time.get_date_string_from_system()
	if last.is_empty():
		return true
	if last == today:
		return false
	# Guard contra relógio voltado (Today < Last) — evita farm de roleta
	var last_unix: int = int(Time.get_unix_time_from_datetime_string(last + "T00:00:00"))
	var today_unix: int = int(Time.get_unix_time_from_datetime_string(today + "T00:00:00"))
	if last_unix > 0 and today_unix > 0 and today_unix < last_unix:
		Analytics.track(&"churn_risk_signal", {"reason": "spin_clock_rollback"})
		return false
	return true

static func spin() -> Dictionary:
	if not can_spin():
		return {}
	var today: String = Time.get_date_string_from_system()
	GameState.settings["last_spin_date"] = today
	SaveManager.request_save()
	# Sorteio ponderado
	var total: float = 0.0
	for r: Dictionary in REWARDS:
		total += float(r.get("weight", 1))
	var roll: float = randf() * total
	for reward: Dictionary in REWARDS:
		roll -= float(reward.get("weight", 1))
		if roll <= 0.0:
			_apply(reward)
			return reward
	var fallback: Dictionary = REWARDS[0]
	_apply(fallback)
	return fallback

static func _apply(reward: Dictionary) -> void:
	var type: String = String(reward.get("type", "coins"))
	if type == "coins":
		var mult: float = float(reward.get("mult", 1.0))
		var amount: int = Rewards.scaled(Rewards.SECONDS[&"daily_mission"] * mult, int(50 * mult))
		GameState.add_coins(float(amount), &"daily_spin")
	elif type == "embers":
		GameState.embers += int(reward.get("amount", 1))
		EventBus.currency_changed.emit(&"embers", float(GameState.embers))
	elif type == "freeze":
		GameState.streak_freezes += int(reward.get("amount", 1))
	Analytics.track(&"daily_spin", {"type": type})

static func label_for(reward: Dictionary) -> String:
	var type: String = String(reward.get("type", "coins"))
	# "label" guarda a CHAVE de localização (i18n), não o texto final.
	var label: String = Loc.t(String(reward.get("label", "")))
	if type == "coins":
		var mult: float = float(reward.get("mult", 1.0))
		var amount: int = Rewards.scaled(Rewards.SECONDS[&"daily_mission"] * mult, int(50 * mult))
		return Loc.t("SPIN_ROW_COINS") % [Loc.t("COINS"), amount, label]
	elif type == "embers":
		return Loc.t("SPIN_ROW_EMBERS") % [int(reward.get("amount", 1)), Loc.t("EMBERS"), label]
	else:
		return Loc.t("SPIN_ROW_FREEZE") % [int(reward.get("amount", 1)), label]
