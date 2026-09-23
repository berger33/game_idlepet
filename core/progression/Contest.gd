class_name Contest
extends RefCounted
## Concurso semanal "Capa da Revista" (Parquinho → Álbum).
##
## Loop de retenção: de segunda a domingo cada passeio no quintal rende VOTOS
## (bom +1, perfeito +2, foto perfeita +3; sábado vale dobro). Três petshops
## rivais simulados sobem o placar ao longo da semana com metas sorteadas por
## semana e ajustadas ao progresso do jogador. No domingo o resultado fecha e
## vira um cartão de recompensa no próximo login — coletável em qualquer dia,
## também pelo Álbum. Estático (mesmo padrão DailySpin/Missions): lê e escreve
## os campos `park_contest_*` do GameState sem ampliar sua API pública.

const WEEK_SECONDS: int = 7 * 86400
const VOTES_GOOD: int = 1
const VOTES_PERFECT: int = 2
const VOTES_PERFECT_PHOTO: int = 3
const SATURDAY_MULT: int = 2
const HISTORY_MAX: int = 8
## Rivais: faixas de meta semanal (votos) e curva de crescimento durante a semana.
## `curve` < 1 larga na frente, > 1 cresce no fim — dá reviravolta e razão para voltar.
const RIVALS: Array[Dictionary] = [
	{"id": "cida", "name": "Spa Pet da Dona Cida", "emoji": "💅", "min": 24, "max": 40, "curve": 1.15},
	{"id": "focinho", "name": "Focinho Limpo", "emoji": "🧼", "min": 12, "max": 22, "curve": 0.7},
	{"id": "patas", "name": "Patas & Laços", "emoji": "🎀", "min": 5, "max": 10, "curve": 1.0},
]
const REWARD_RATIO: Array[float] = [0.0, 1.0, 0.5, 0.3, 0.15] # índice = colocação
const REWARD_EMBERS: Array[int] = [0, 3, 1, 0, 0]


## Mesma fórmula de GameState._week_key(): semana começa na segunda (UTC).
static func week_key_for(unix: int) -> String:
	var days: int = int(floor(float(unix) / 86400.0))
	return str(days - ((days + 3) % 7))


static func week_key() -> String:
	return week_key_for(int(Time.get_unix_time_from_system()))


static func seconds_to_close() -> int:
	var start: int = int(week_key()) * 86400
	return maxi(0, start + WEEK_SECONDS - int(Time.get_unix_time_from_system()))


static func week_progress() -> float:
	return clampf(1.0 - float(seconds_to_close()) / float(WEEK_SECONDS), 0.0, 1.0)


static func is_saturday() -> bool:
	var d: Dictionary = Time.get_datetime_dict_from_system()
	return int(d.get("weekday", -1)) == 6 # Godot: 0 dom … 6 sáb


## Garante que a semana corrente está aberta; fecha a anterior em `pending`.
static func sync() -> void:
	var key: String = week_key()
	var new_week: bool = GameState.park_contest_week != key
	if not new_week and GameState.park_contest_rivals.size() == RIVALS.size():
		return
	if new_week:
		if not GameState.park_contest_week.is_empty() and GameState.park_contest_points > 0:
			_close_week()
		GameState.park_contest_week = key
		GameState.park_contest_points = 0
		GameState.park_contest_photos = 0
		GameState.park_contest_last_rank = 0
	GameState.park_contest_rivals = _roll_rivals(key)
	SaveManager.request_save()


## Registra um passeio concluído e devolve os votos ganhos (0 se falhou).
static func register_walk(activity: String, success: bool, perfect: bool) -> int:
	sync()
	if not success:
		return 0
	var votes: int = VOTES_GOOD
	if perfect:
		votes = VOTES_PERFECT_PHOTO if activity == "photo" else VOTES_PERFECT
	if is_saturday():
		votes *= SATURDAY_MULT
	GameState.park_contest_points += votes
	if perfect and activity == "photo":
		GameState.park_contest_photos += 1
	GameState.park_contest_last_rank = rank()
	Analytics.track(&"contest_votes", {"activity": activity, "votes": votes, "total": GameState.park_contest_points, "rank": GameState.park_contest_last_rank})
	SaveManager.request_save()
	return votes


## Placar exibido do rival `index` agora (cresce ao longo da semana).
static func rival_score(index: int) -> int:
	var target: int = rival_target(index)
	var curve: float = float(RIVALS[index].get("curve", 1.0))
	return int(round(float(target) * pow(week_progress(), curve)))


static func rival_target(index: int) -> int:
	if index < 0 or index >= GameState.park_contest_rivals.size():
		return 0
	return int(GameState.park_contest_rivals[index])


## Colocação atual: 1 + rivais à frente. Sem votos = fora do pódio (4º).
static func rank() -> int:
	return _rank_for(GameState.park_contest_points, false)


## Votos que faltam para assumir a liderança agora (0 = já lidera).
static func votes_to_first() -> int:
	var best: int = 0
	for i: int in RIVALS.size():
		best = maxi(best, rival_score(i))
	return maxi(0, best + 1 - GameState.park_contest_points) if GameState.park_contest_points <= best else 0


## Foto completa do estado para UI (Álbum, painel do passeio, HUD).
static func status() -> Dictionary:
	sync()
	var rivals: Array[Dictionary] = []
	for i: int in RIVALS.size():
		rivals.append({"name": String(RIVALS[i]["name"]), "emoji": String(RIVALS[i]["emoji"]), "score": rival_score(i)})
	return {
		"week": GameState.park_contest_week,
		"points": GameState.park_contest_points,
		"photos": GameState.park_contest_photos,
		"rank": rank(),
		"rivals": rivals,
		"seconds_left": seconds_to_close(),
		"saturday": is_saturday(),
		"to_first": votes_to_first(),
		"pending": has_pending(),
	}


static func has_pending() -> bool:
	return not GameState.park_contest_pending.is_empty()


## Caiu de posição desde a última vez que viu o placar? (nudge de retorno)
static func was_overtaken() -> bool:
	sync()
	var last: int = GameState.park_contest_last_rank
	return last > 0 and GameState.park_contest_points > 0 and rank() > last


static func mark_seen() -> void:
	GameState.park_contest_last_rank = rank() if GameState.park_contest_points > 0 else 0


## Texto do badge no botão Álbum: "" quando não há nada a fazer.
static func badge_text() -> String:
	if has_pending():
		return "🏆"
	if was_overtaken():
		return "📰"
	return ""


## Entrega o resultado fechado. Retorna {} se não há nada a coletar.
static func claim() -> Dictionary:
	if not has_pending():
		return {}
	var result: Dictionary = GameState.park_contest_pending.duplicate()
	var placement: int = clampi(int(result.get("rank", 4)), 1, 4)
	var coins: int = int(result.get("coins", 0))
	var embers: int = int(result.get("embers", 0))
	if coins > 0:
		GameState.add_coins(float(coins), &"park_contest")
	if embers > 0:
		GameState.embers += embers
		EventBus.currency_changed.emit(&"embers", float(GameState.embers))
	if placement == 1:
		GameState.park_trophies += 1
		GameState.unlock_achievement("park_contest_win", 0, 2)
	GameState.park_contest_history.append({"week": String(result.get("week", "")), "rank": placement, "points": int(result.get("points", 0))})
	if GameState.park_contest_history.size() > HISTORY_MAX:
		GameState.park_contest_history = GameState.park_contest_history.slice(GameState.park_contest_history.size() - HISTORY_MAX)
	GameState.park_contest_pending = {}
	Analytics.track(&"park_contest_claimed", {"rank": placement, "coins": coins, "embers": embers, "trophies": GameState.park_trophies})
	SaveManager.request_save()
	result["trophies"] = GameState.park_trophies
	return result


static func best_rank() -> int:
	var best: int = 0
	for entry: Dictionary in GameState.park_contest_history:
		var r: int = int(entry.get("rank", 0))
		if r > 0 and (best == 0 or r < best):
			best = r
	return best


static func reward_coins_for(placement: int) -> int:
	var ratio: float = REWARD_RATIO[clampi(placement, 1, 4)]
	return int(round(float(Rewards.for_kind(&"weekly_chest", 200)) * ratio))


static func reward_embers_for(placement: int) -> int:
	return REWARD_EMBERS[clampi(placement, 1, 4)]


static func placement_label(placement: int) -> String:
	return Loc.t("CONTEST_RANK_%d" % clampi(placement, 1, 4))


static func format_time_left(seconds: int) -> String:
	if seconds >= 86400:
		return Loc.t("CONTEST_TIME_DAYS") % [seconds / 86400, (seconds % 86400) / 3600]
	if seconds >= 3600:
		return Loc.t("CONTEST_TIME_HOURS") % [seconds / 3600, (seconds % 3600) / 60]
	return Loc.t("CONTEST_TIME_MIN") % maxi(1, seconds / 60)


static func _rank_for(points: int, final: bool) -> int:
	if points <= 0:
		return 4
	var ahead: int = 0
	for i: int in RIVALS.size():
		var score: int = rival_target(i) if final else rival_score(i)
		if score > points:
			ahead += 1
	return 1 + ahead


static func _close_week() -> void:
	var placement: int = _rank_for(GameState.park_contest_points, true)
	# Um resultado antigo ainda não coletado é entregue direto para não se perder.
	if has_pending():
		var old: Dictionary = claim()
		EventBus.toast_requested.emit(Loc.t("CONTEST_AUTO_CLAIM") % [placement_label(int(old.get("rank", 4))), int(old.get("coins", 0))], Color("ffd54f"))
	GameState.park_contest_pending = {
		"week": GameState.park_contest_week,
		"points": GameState.park_contest_points,
		"photos": GameState.park_contest_photos,
		"rank": placement,
		"coins": reward_coins_for(placement),
		"embers": reward_embers_for(placement),
	}
	Analytics.track(&"park_contest_closed", {"week": GameState.park_contest_week, "rank": placement, "points": GameState.park_contest_points})


## Metas dos rivais para a semana: hash determinístico da chave + ajuste ao
## estágio do jogador (iniciante enfrenta metas menores; 1ª capa é alcançável).
static func _roll_rivals(key: String) -> Array[int]:
	var scale: float = 1.0
	if GameState.player_level < 5:
		scale = 0.55 + 0.09 * float(GameState.player_level)
	if GameState.park_plays_total < 5:
		scale = minf(scale, 0.5)
	var result: Array[int] = []
	for rival: Dictionary in RIVALS:
		var h: int = absi(("%s:%s" % [key, String(rival["id"])]).hash())
		var span: int = int(rival["max"]) - int(rival["min"]) + 1
		var base: int = int(rival["min"]) + (h % span)
		result.append(maxi(2, int(round(float(base) * scale))))
	return result
