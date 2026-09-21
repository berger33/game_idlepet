class_name DailySpin
extends RefCounted
## Roleta diária simples (gatilho retenção D1): 1× por dia, recompensa
## variável escalada à renda + chance de brasa. Sem backend, 100% local,
## com pesos que garantem dopamina.

const REWARDS: Array[Dictionary] = [
	{"type": "coins", "mult": 0.8, "weight": 30, "label": "Moedas"},
	{"type": "coins", "mult": 1.5, "weight": 25, "label": "Moedas em dobro!"},
	{"type": "coins", "mult": 2.5, "weight": 12, "label": "Super prêmio!"},
	{"type": "embers", "amount": 1, "weight": 20, "label": "1 Brasa!"},
	{"type": "embers", "amount": 2, "weight": 8, "label": "2 Brasas raras!"},
	{"type": "freeze", "amount": 1, "weight": 5, "label": "Freeze de streak!"},
]

static func can_spin() -> bool:
	var last: String = String(GameState.settings.get("last_spin_date", ""))
	var today: String = Time.get_date_string_from_system()
	return last != today

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
		EventBus.currency_changed.emit(&"coins", GameState.coins)
	elif type == "freeze":
		GameState.streak_freezes += int(reward.get("amount", 1))
	Analytics.track(&"daily_spin", {"type": type})

static func label_for(reward: Dictionary) -> String:
	var type: String = String(reward.get("type", "coins"))
	if type == "coins":
		var mult: float = float(reward.get("mult", 1.0))
		var amount: int = Rewards.scaled(Rewards.SECONDS[&"daily_mission"] * mult, int(50 * mult))
		return "🪙 +%d %s (%s)" % [amount, Loc.t("COINS"), String(reward.get("label", ""))]
	elif type == "embers":
		return "🔥 +%d %s (%s)" % [int(reward.get("amount", 1)), Loc.t("EMBERS"), String(reward.get("label", ""))]
	else:
		return "❄️ +%d Freeze! (%s)" % [int(reward.get("amount", 1)), String(reward.get("label", ""))]
