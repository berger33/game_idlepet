class_name Missions
extends RefCounted
## Missões diárias dirigidas por data/daily_missions.json (antes: 3 fixas e
## triviais cravadas no código; o catálogo, com a épica, era lido só pelos testes).
##
## Todo dia: 3 missões regulares sorteadas por peso com semente = data (mesmo
## resultado em qualquer aparelho/reinício) + a épica. Metas escalam com o nível
## (×1 até 24, ×2 até 49, ×3 depois) para continuarem sendo "cerca de uma sessão".
## Recompensa em moedas é escalada à renda (Rewards); brasas ficam como no JSON.
## Estado (ids do dia, progresso, claims) vive em GameState; aqui só regras.

const REGULAR_COUNT: int = 3
## Métrica do JSON -> chave de progresso em GameState.mission_progress.
const METRIC_KEY: Dictionary = {
	"services": "services",
	"perfect": "perfect",
	"perfect_services": "perfect",
	"upgrades": "upgrades",
	"four_plus_reviews": "four_plus_reviews",
	"combo_reached": "combo_reached",
}
const PROGRESS_KEYS: Array[String] = [
	"services", "perfect", "upgrades", "four_plus_reviews", "combo_reached"
]


## Sorteio determinístico do dia: 3 regulares por peso + todas as épicas.
static func roll_for_day(day_key: String, level: int) -> Array[String]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(day_key)
	var pool: Array[Dictionary] = []
	var result: Array[String] = []
	for mission: Dictionary in ContentDB.daily_missions:
		if int(mission.get("min_tier", 1)) > ContentDB.establishment_for_level(level):
			continue
		if bool(mission.get("epic", false)):
			result.append(String(mission["id"]))
		else:
			pool.append(mission)
	var regulars: Array[String] = []
	while regulars.size() < REGULAR_COUNT and not pool.is_empty():
		var total: float = 0.0
		for mission: Dictionary in pool:
			total += maxf(0.1, float(mission.get("weight", 1)))
		var roll: float = rng.randf() * total
		var picked: int = pool.size() - 1
		for index: int in pool.size():
			roll -= maxf(0.1, float(pool[index].get("weight", 1)))
			if roll <= 0.0:
				picked = index
				break
		regulars.append(String(pool[picked]["id"]))
		pool.remove_at(picked)
	regulars.append_array(result)
	return regulars


## Multiplicador de meta pelo nível de carreira.
static func target_scale(level: int) -> int:
	return 1 + mini(2, int(level / 25.0))


static func target(mission: Dictionary) -> int:
	return maxi(1, int(mission.get("target", 1)) * target_scale(GameState.player_level))


static func progress_key(mission: Dictionary) -> String:
	return String(METRIC_KEY.get(String(mission.get("metric", "services")), "services"))


static func value(mission: Dictionary) -> int:
	return mini(int(GameState.mission_progress.get(progress_key(mission), 0)), target(mission))


static func is_ready(mission: Dictionary) -> bool:
	return value(mission) >= target(mission)


static func is_epic(mission: Dictionary) -> bool:
	return bool(mission.get("epic", false))


## Missões do dia (dicionários do catálogo), na ordem sorteada; épica por último.
static func today() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in GameState.daily_mission_ids:
		var mission: Dictionary = ContentDB.daily_mission(id)
		if not mission.is_empty():
			result.append(mission)
	return result


## Quantas regulares já foram resgatadas hoje (o passe avança com as 3).
static func regular_claimed_count() -> int:
	var count: int = 0
	for mission: Dictionary in today():
		if not is_epic(mission) and GameState.claimed_missions.has(String(mission["id"])):
			count += 1
	return count


## Moedas da missão escaladas à renda (piso = valor do JSON).
static func coin_reward(mission: Dictionary) -> int:
	var reward: Dictionary = mission.get("reward", {})
	if not reward.has("coins"):
		return 0
	var seconds: float = float(Rewards.SECONDS[&"daily_mission"]) * (2.0 if is_epic(mission) else 1.0)
	return Rewards.scaled(seconds, int(reward.get("coins", 0)))


static func ember_reward(mission: Dictionary) -> int:
	var reward: Dictionary = mission.get("reward", {})
	return int(reward.get("embers", 0))


## Rótulo localizado "MÉTRICA valor/meta".
static func label(mission: Dictionary) -> String:
	var key: String = "MISSION_METRIC_" + String(mission.get("metric", "services"))
	return Loc.t(key) % [value(mission), target(mission)]


## Texto da recompensa: "R$ 320" (realismo) ou "5 Brasas".
static func reward_text(mission: Dictionary) -> String:
	var embers: int = ember_reward(mission)
	if embers > 0:
		return "%d %s" % [embers, Loc.t("EMBERS")]
	return "%s %d" % [Loc.t("COINS"), coin_reward(mission)]
