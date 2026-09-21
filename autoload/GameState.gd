extends Node
## Estado autoritativo serializável da sessão.

const SAVE_VERSION: int = 12
const MAX_CAREER_LEVEL: int = 120
const HIRE_COSTS: Dictionary = {"common": 150, "rare": 400, "epic": 900, "legendary": 2000}
## Fração da estação/ferramentas herdada ao prestigiar e nível de recomeço
## (todos os serviços abertos): prestigiar deixa de ser "perder 2h por +10%".
const PRESTIGE_KEEP_RATIO: float = 0.25
const PRESTIGE_START_LEVEL: int = 10
## Glossário da equipe: o que cada passivo faz em uma palavra (a UI explica a
## vocação sem exigir decisão prévia do jogador).
const STAFF_VOCATION: Dictionary = {
	"speed": "VOCATION_GROOMER",
	"bath_speed": "VOCATION_BATHER",
	"groom_quality": "VOCATION_STYLIST",
	"veterinary_xp": "VOCATION_VETERINARY",
	"patience": "VOCATION_MASSEUSE",
	"perfect_window": "VOCATION_PERFECTIONIST",
}
var coins: float = 0.0
var embers: int = 0
var franchise_tokens: int = 0
var total_coins: float = 0.0
var bath_upgrade_level: int = 0
var tool_upgrade_levels: Dictionary = {"soap": 0, "clipper": 0, "dryer": 0, "perfume": 0, "bow": 0}
var combo: int = 0
var best_combo: int = 0
## Maestria (C2): usos por ferramenta — selos em 100/500/2000 usos.
var tool_uses: Dictionary = {}
## Pico do bairro (B3): durante o rush, serviço bom não quebra o combo.
var rush_combo_protection: bool = false
var best_streak: int = 0
var weekly_chest_week: String = ""
# Folga de combo da sessão: o primeiro Good de uma sequência não zera o combo
# (fail sempre zera). Não persiste de propósito — é alívio de flow, não meta.
var combo_grace_used: bool = false
var services_completed: int = 0
var player_level: int = 1
var player_xp: int = 0
var reviews_total: int = 0
var reviews_sum: int = 0
var five_star_reviews: int = 0
var total_perfect_services: int = 0
var offline_seconds_collected: float = 0.0
var prestige_level: int = 0
## Tokens de franquia já concedidos por prestígio (Economy.prestige_tokens(total)
## é cumulativo; antes subtraía-se o nº de prestígios e tokens saíam em dobro).
var prestige_tokens_collected: int = 0
## Pesquisa da franquia (data/research.json): nós comprados com tokens de
## franquia. Meta permanente — sobrevive ao prestígio (ver Research.gd).
var research_ids: Array[String] = []
var last_seen_unix: int = 0
var tutorial_complete: bool = false
var unlocked_pets: Array[String] = ["caramelo"]
var hired_staff: Array[String] = ["player"]
var achievement_ids: Array[String] = []
var unlocked_cosmetics: Array[String] = []
## Slot ativo por categoria: "bath" | "pet_accessory" | "wall" -> cosmetic id.
var active_cosmetics: Dictionary = {}
var mission_progress: Dictionary = {
	"services": 0, "perfect": 0, "upgrades": 0, "four_plus_reviews": 0, "combo_reached": 0
}
var claimed_missions: Array[String] = []
var missions_date: String = ""
## Missões do dia sorteadas do catálogo (data/daily_missions.json) — ver Missions.gd.
var daily_mission_ids: Array[String] = []
## Missões semanais: reiniciam na segunda-feira (chave = dia unix da semana).
var weekly_progress: Dictionary = {
	"services": 0, "perfect": 0, "combo_max": 0, "tips": 0, "style": 0, "vip": 0, "spend": 0
}
var claimed_weeklies: Array[String] = []
var week_start: String = ""
var last_daily_claim: String = ""
var daily_streak: int = 0
var streak_freezes: int = 1
var pass_day_unlocked: int = 0
var pass_day_claimed: int = 0
var pass_advance_day: String = ""
var last_return_day: String = ""
var establishment_tier: int = 1
var passive_accumulator: float = 0.0
var active_play_seconds: float = 0.0
var pet_affection: Dictionary = {}
## Pet preferido (buddy): entra na fila com prioridade e lidera a coleção.
var favorite_pet: String = "caramelo"
## Visitantes misteriosos (Discovery.gd): pet ainda bloqueado -> atendimentos.
var visitor_progress: Dictionary = {}
## Meta do dia do evento (LiveOps): atendimentos do serviço em destaque hoje.
var event_goal_date: String = ""
var event_goal_count: int = 0
var event_goal_claimed: bool = false
var settings: Dictionary = {
	"music": 0.7,
	"sfx": 0.9,
	"haptics": true,
	"reduced_particles": false,
	"eco_mode": false,
	"font_scale": 1.0,
	"left_handed": false,
}


func _ready() -> void:
	_refresh_daily_missions()
	EventBus.service_completed.connect(_on_service_completed)
	EventBus.service_failed.connect(_on_service_failed)


func _process(delta: float) -> void:
	active_play_seconds += delta
	if hired_staff.size() <= 1:
		return
	# Equipe como automação (idle de verdade): cada contratado rende uma fração
	# da renda ativa estimada sozinho (staff.json "automation"), a cada 5 s.
	passive_accumulator += delta
	if passive_accumulator >= 5.0:
		var cycles: int = int(passive_accumulator / 5.0)
		passive_accumulator -= cycles * 5.0
		var passive: float = Rewards.passive_income_per_second() * 5.0 * float(cycles)
		if passive >= 1.0:
			add_coins(floor(passive), &"staff_idle")


func add_coins(amount: float, source: StringName) -> void:
	if amount <= 0.0:
		return
	coins += amount
	total_coins += amount
	EventBus.currency_changed.emit(&"coins", coins)
	Analytics.track(
		&"currency_earned", {"type": "coins", "source": String(source), "amount": amount}
	)


func spend_coins(amount: float, sink: StringName) -> bool:
	if amount <= 0.0 or coins < amount:
		return false
	coins -= amount
	EventBus.currency_changed.emit(&"coins", coins)
	Analytics.track(&"currency_spent", {"type": "coins", "sink": String(sink), "amount": amount})
	return true


func buy_bath_upgrade() -> bool:
	_refresh_daily_missions()
	if bath_upgrade_level >= MAX_CAREER_LEVEL:
		return false
	var cost: float = Economy.upgrade_cost(bath_upgrade_level)
	if not spend_coins(cost, &"bath_upgrade"):
		return false
	bath_upgrade_level += 1
	mission_progress["upgrades"] = int(mission_progress.get("upgrades", 0)) + 1
	register_weekly_spend(int(cost))
	EventBus.upgrade_purchased.emit(&"bath", bath_upgrade_level)
	Analytics.track(&"establishment_upgrade", {"id": "bath", "level": bath_upgrade_level})
	_check_achievements()
	SaveManager.request_save()
	return true


func tool_upgrade_cost(tool_id: StringName) -> float:
	var level: int = clampi(int(tool_upgrade_levels.get(String(tool_id), 0)), 0, 30)
	var base_cost: float = (
		{&"soap": 18.0, &"clipper": 35.0, &"dryer": 55.0, &"perfume": 80.0, &"bow": 120.0}
		. get(tool_id, 25.0)
	)
	return ceil(base_cost * pow(1.24, level))


func buy_tool_upgrade(tool_id: StringName) -> bool:
	var key: String = String(tool_id)
	var level: int = clampi(int(tool_upgrade_levels.get(key, 0)), 0, 30)
	var cost: float = tool_upgrade_cost(tool_id)
	if level >= 30 or not spend_coins(cost, &"tool_upgrade"):
		return false
	tool_upgrade_levels[key] = level + 1
	mission_progress["upgrades"] = int(mission_progress.get("upgrades", 0)) + 1
	register_weekly_spend(int(cost))
	EventBus.upgrade_purchased.emit(tool_id, level + 1)
	Analytics.track(&"tool_upgrade", {"id": key, "level": level + 1})
	_check_achievements()
	SaveManager.request_save()
	return true


func tool_bonus(tool_id: StringName) -> float:
	return 1.0 + clampi(int(tool_upgrade_levels.get(String(tool_id), 0)), 0, 30) * 0.04


## Maestria (C2): cada atendimento conta um uso da ferramenta; ao cruzar
## 100/500/2000 usos o jogador ganha um selo (retornado UMA vez, p/ toast).
func register_tool_use(tool_id: StringName) -> Dictionary:
	var key: String = String(tool_id)
	var before: int = int(tool_uses.get(key, 0))
	var count: int = before + 1
	tool_uses[key] = count
	var steps: Array[int] = SalonTuning.TOOL_MASTERY_STEPS
	for i: int in steps.size():
		if before < steps[i] and count >= steps[i]:
			return {"milestone": i + 1}
	return {}


## Soma dos passivos contratados de um tipo (staff.json agora dirige o jogo).
func staff_bonus(passive_type: StringName) -> float:
	var total: float = 0.0
	for staff_id: String in hired_staff:
		var entry: Dictionary = ContentDB.staff_by_id.get(staff_id, {})
		var passive: Dictionary = entry.get("passive", {})
		if String(passive.get("type", "")) == String(passive_type):
			total += float(passive.get("value", 0.0))
	return total


## Custo de contratação: piso por raridade, escalado a minutos de renda atual
## (sink que acompanha a curva — antes 150–2000 fixos, triviais após 1h).
func hire_cost(staff_id: String) -> int:
	var rarity: String = String(
		ContentDB.staff_by_id.get(staff_id, {}).get("rarity", "common")
	)
	return Rewards.hire_price(staff_id, int(HIRE_COSTS.get(rarity, 150)))


func hire_staff(staff_id: String) -> bool:
	if staff_id == "player" or hired_staff.has(staff_id):
		return false
	if not ContentDB.staff_by_id.has(staff_id):
		return false
	if not spend_coins(float(hire_cost(staff_id)), &"hire_staff"):
		return false
	hired_staff.append(staff_id)
	Analytics.track(&"staff_hired", {"id": staff_id})
	SaveManager.request_save()
	return true


func buy_cosmetic(cosmetic_id: String) -> bool:
	if unlocked_cosmetics.has(cosmetic_id):
		return false
	var entry: Dictionary = ContentDB.cosmetic(cosmetic_id)
	var price: Dictionary = entry.get("price", {})
	if price.is_empty():
		return false
	var coin_price: int = Rewards.cosmetic_price(cosmetic_id)
	var ember_price: int = int(price.get("embers", 0))
	if coins < float(coin_price) or embers < ember_price:
		return false
	if coin_price > 0:
		spend_coins(float(coin_price), &"cosmetic")
	if ember_price > 0:
		embers -= ember_price
		EventBus.currency_changed.emit(&"coins", coins)
	unlocked_cosmetics.append(cosmetic_id)
	Analytics.track(&"cosmetic_bought", {"id": cosmetic_id})
	SaveManager.request_save()
	return true


## Equipa (ou desequipar, se já ativo) um cosmético owned; 1 por slot.
func equip_cosmetic(cosmetic_id: String) -> bool:
	if not unlocked_cosmetics.has(cosmetic_id):
		return false
	var slot: String = String(ContentDB.cosmetic(cosmetic_id).get("slot", ""))
	if slot.is_empty():
		return false
	if String(active_cosmetics.get(slot, "")) == cosmetic_id:
		active_cosmetics.erase(slot)
		Analytics.track(&"cosmetic_unequipped", {"id": cosmetic_id})
	else:
		active_cosmetics[slot] = cosmetic_id
		Analytics.track(&"cosmetic_equipped", {"id": cosmetic_id})
	SaveManager.request_save()
	EventBus.settings_changed.emit()
	return true


func active_cosmetic(slot: String) -> String:
	return String(active_cosmetics.get(slot, ""))


## Prestígio: tokens disponíveis ainda não convertidos em nível de franquia.
func prestige_tokens_available() -> int:
	return maxi(0, Economy.prestige_tokens(total_coins) - prestige_tokens_collected)


func can_prestige() -> bool:
	return prestige_tokens_available() > 0 and player_level >= 15


## Reinicia a corrida em troca de tokens de franquia (+10%/nível). Mantém
## brasas, pets, cosméticos, conquistas, streak/passe, pesquisa, o total
## acumulado, 25% da estação/ferramentas e recomeça no nível 10.
func perform_prestige() -> bool:
	if not can_prestige():
		return false
	var gain: int = prestige_tokens_available()
	franchise_tokens += gain
	prestige_tokens_collected += gain
	prestige_level += 1
	bath_upgrade_level = int(bath_upgrade_level * PRESTIGE_KEEP_RATIO)
	for tool: String in tool_upgrade_levels:
		tool_upgrade_levels[tool] = int(int(tool_upgrade_levels[tool]) * PRESTIGE_KEEP_RATIO)
	tool_uses = {}
	rush_combo_protection = false
	combo = 0
	player_level = PRESTIGE_START_LEVEL
	player_xp = 0
	_refresh_daily_missions()
	hired_staff = ["player"]
	establishment_tier = ContentDB.establishment_for_level(player_level)
	# Caixa inicial da nova corrida: um minuto da renda do recomeço (piso 150).
	coins = float(Rewards.for_kind(&"prestige_start", 150))
	Analytics.track(&"prestige_performed", {"level": prestige_level, "tokens": gain})
	SaveManager.request_save()
	return true



func register_review(stars: int) -> void:
	var safe_stars: int = clampi(stars, 1, 5)
	reviews_total += 1
	reviews_sum += safe_stars
	if safe_stars == 5:
		five_star_reviews += 1
	if safe_stars >= 4:
		_refresh_daily_missions()
		mission_progress["four_plus_reviews"] = int(mission_progress.get("four_plus_reviews", 0)) + 1
	EventBus.review_received.emit(safe_stars)


func review_average() -> float:
	return 5.0 if reviews_total == 0 else float(reviews_sum) / float(reviews_total)


func to_dictionary() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": coins,
		"embers": embers,
		"franchise_tokens": franchise_tokens,
		"total_coins": total_coins,
		"bath_upgrade_level": bath_upgrade_level,
		"tool_upgrade_levels": tool_upgrade_levels,
		"tool_uses": tool_uses,
		"combo": combo,
		"best_combo": best_combo,
		"services_completed": services_completed,
		"player_level": player_level,
		"player_xp": player_xp,
		"reviews_total": reviews_total,
		"reviews_sum": reviews_sum,
		"five_star_reviews": five_star_reviews,
		"total_perfect_services": total_perfect_services,
		"offline_seconds_collected": offline_seconds_collected,
		"prestige_level": prestige_level,
		"prestige_tokens_collected": prestige_tokens_collected,
		"research_ids": research_ids,
		"last_seen_unix": Time.get_unix_time_from_system(),
		"tutorial_complete": tutorial_complete,
		"unlocked_pets": unlocked_pets,
		"hired_staff": hired_staff,
		"achievement_ids": achievement_ids,
		"unlocked_cosmetics": unlocked_cosmetics,
		"active_cosmetics": active_cosmetics,
		"mission_progress": mission_progress,
		"claimed_missions": claimed_missions,
		"missions_date": missions_date,
		"daily_mission_ids": daily_mission_ids,
		"weekly_progress": weekly_progress,
		"claimed_weeklies": claimed_weeklies,
		"week_start": week_start,
		"last_daily_claim": last_daily_claim,
		"daily_streak": daily_streak,
		"best_streak": best_streak,
		"weekly_chest_week": weekly_chest_week,
		"streak_freezes": streak_freezes,
		"pass_day_unlocked": pass_day_unlocked,
		"pass_day_claimed": pass_day_claimed,
		"pass_advance_day": pass_advance_day,
		"last_return_day": last_return_day,
		"establishment_tier": establishment_tier,
		"active_play_seconds": active_play_seconds,
		"pet_affection": pet_affection,
		"favorite_pet": favorite_pet,
		"visitor_progress": visitor_progress,
		"event_goal_date": event_goal_date,
		"event_goal_count": event_goal_count,
		"event_goal_claimed": event_goal_claimed,
		"settings": settings
	}


func apply_dictionary(data: Dictionary) -> void:
	coins = maxf(0.0, float(data.get("coins", 0.0)))
	embers = maxi(0, int(data.get("embers", 0)))
	franchise_tokens = maxi(0, int(data.get("franchise_tokens", 0)))
	total_coins = maxf(coins, float(data.get("total_coins", coins)))
	bath_upgrade_level = clampi(int(data.get("bath_upgrade_level", 0)), 0, MAX_CAREER_LEVEL)
	tool_upgrade_levels = _safe_tool_levels(data.get("tool_upgrade_levels", {}))
	tool_uses = _safe_int_map(data.get("tool_uses", {}), 1000000)
	combo = clampi(int(data.get("combo", 0)), 0, 1000)
	best_combo = maxi(combo, int(data.get("best_combo", combo)))
	services_completed = maxi(0, int(data.get("services_completed", 0)))
	player_level = clampi(int(data.get("player_level", 1)), 1, MAX_CAREER_LEVEL)
	player_xp = maxi(0, int(data.get("player_xp", 0)))
	if player_level < MAX_CAREER_LEVEL:
		player_xp = mini(player_xp, xp_to_next_level() - 1)
	else:
		player_xp = 0
	reviews_total = maxi(0, int(data.get("reviews_total", 0)))
	reviews_sum = clampi(int(data.get("reviews_sum", 0)), 0, reviews_total * 5)
	five_star_reviews = clampi(int(data.get("five_star_reviews", 0)), 0, reviews_total)
	total_perfect_services = clampi(
		int(data.get("total_perfect_services", 0)), 0, services_completed
	)
	offline_seconds_collected = maxf(0.0, float(data.get("offline_seconds_collected", 0.0)))
	prestige_level = clampi(int(data.get("prestige_level", 0)), 0, 100)
	prestige_tokens_collected = maxi(
		prestige_level, int(data.get("prestige_tokens_collected", prestige_level))
	)
	research_ids = _valid_research_array(data.get("research_ids", []))
	Research.invalidate_cache()
	last_seen_unix = maxi(0, int(data.get("last_seen_unix", 0)))
	tutorial_complete = bool(data.get("tutorial_complete", false))
	unlocked_pets = _valid_pet_array(data.get("unlocked_pets", []))
	if unlocked_pets.is_empty():
		unlocked_pets = ["caramelo"]
	hired_staff = _safe_string_array(data.get("hired_staff", ["player"]))
	if not hired_staff.has("player"):
		hired_staff.push_front("player")
	achievement_ids = _safe_string_array(data.get("achievement_ids", []))
	unlocked_cosmetics = _safe_string_array(data.get("unlocked_cosmetics", []))
	mission_progress = _safe_dictionary(data.get("mission_progress", {}), {})
	for metric: String in Missions.PROGRESS_KEYS:
		mission_progress[metric] = maxi(0, int(mission_progress.get(metric, 0)))
	claimed_missions = _safe_string_array(data.get("claimed_missions", []))
	missions_date = String(data.get("missions_date", ""))
	daily_mission_ids = _safe_string_array(data.get("daily_mission_ids", []))
	weekly_progress = _safe_dictionary(
		data.get("weekly_progress", {}),
		{"services": 0, "perfect": 0, "combo_max": 0, "tips": 0, "style": 0, "vip": 0, "spend": 0}
	)
	for weekly_metric: String in ["services", "perfect", "combo_max", "tips", "style", "vip", "spend"]:
		weekly_progress[weekly_metric] = maxi(0, int(weekly_progress.get(weekly_metric, 0)))
	claimed_weeklies = _safe_string_array(data.get("claimed_weeklies", []))
	week_start = String(data.get("week_start", ""))
	_refresh_weekly_missions()
	_refresh_daily_missions()
	last_daily_claim = String(data.get("last_daily_claim", ""))
	daily_streak = clampi(int(data.get("daily_streak", 0)), 0, 7)
	best_streak = clampi(int(data.get("best_streak", 0)), daily_streak, 7)
	weekly_chest_week = String(data.get("weekly_chest_week", ""))
	streak_freezes = clampi(int(data.get("streak_freezes", 1)), 0, 99)
	pass_day_unlocked = clampi(int(data.get("pass_day_unlocked", 0)), 0, 28)
	pass_day_claimed = clampi(
		int(data.get("pass_day_claimed", 0)), 0, pass_day_unlocked
	)
	pass_advance_day = String(data.get("pass_advance_day", ""))
	last_return_day = String(data.get("last_return_day", ""))
	establishment_tier = clampi(int(data.get("establishment_tier", 1)), 1, 10)
	active_play_seconds = maxf(0.0, float(data.get("active_play_seconds", 0.0)))
	pet_affection = _safe_dictionary(data.get("pet_affection", {}), {})
	favorite_pet = String(data.get("favorite_pet", "caramelo"))
	if not unlocked_pets.has(favorite_pet):
		favorite_pet = "caramelo"
	visitor_progress = _safe_int_map(data.get("visitor_progress", {}), Discovery.VISITS_TO_ADOPT)
	event_goal_date = String(data.get("event_goal_date", ""))
	event_goal_count = maxi(0, int(data.get("event_goal_count", 0)))
	event_goal_claimed = bool(data.get("event_goal_claimed", false))
	_refresh_event_goal()
	_sanitize_affection()
	_reconcile_career_unlocks(false)
	var saved_settings: Variant = data.get("settings", {})
	if saved_settings is Dictionary:
		settings.merge(saved_settings, true)
	_sanitize_settings()
	_check_achievements()
	EventBus.currency_changed.emit(&"coins", coins)


func _safe_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value:
		if item is String:
			var text: String = String(item)
			if not text.is_empty() and not result.has(text):
				result.append(text)
	return result


func _valid_pet_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for id: String in _safe_string_array(value):
		if ContentDB.has_pet(id):
			result.append(id)
	return result


func _valid_research_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for id: String in _safe_string_array(value):
		if ContentDB.research_by_id.has(id):
			result.append(id)
	return result


func _safe_tool_levels(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result: Dictionary = {}
	for tool_id: String in ["soap", "clipper", "dryer", "perfume", "bow"]:
		result[tool_id] = clampi(int(source.get(tool_id, 0)), 0, 30)
	return result


func _safe_int_map(value: Variant, max_value: int) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result: Dictionary = {}
	for key: String in source:
		result[key] = clampi(int(source[key]), 0, max_value)
	return result


func _safe_dictionary(value: Variant, fallback: Dictionary) -> Dictionary:
	if value is Dictionary:
		var safe_value: Dictionary = value
		return safe_value.duplicate(true)
	return fallback.duplicate(true)


func _sanitize_affection() -> void:
	var clean: Dictionary = {}
	for id: Variant in pet_affection:
		if id is String:
			var pet_id: String = String(id)
			if ContentDB.has_pet(pet_id):
				clean[pet_id] = clampi(int(pet_affection[id]), 0, 50)
	pet_affection = clean


func _sanitize_settings() -> void:
	settings["music"] = clampf(float(settings.get("music", 0.7)), 0.0, 1.0)
	settings["sfx"] = clampf(float(settings.get("sfx", 0.9)), 0.0, 1.0)
	settings["haptics"] = bool(settings.get("haptics", true))
	settings["reduced_particles"] = bool(settings.get("reduced_particles", false))
	settings["eco_mode"] = bool(settings.get("eco_mode", false))
	settings["colorblind"] = bool(settings.get("colorblind", false))
	settings["assist_window"] = bool(settings.get("assist_window", false))
	settings["analytics_consent"] = bool(settings.get("analytics_consent", false))
	settings["font_scale"] = clampf(float(settings.get("font_scale", 1.0)), 0.8, 1.4)
	settings["left_handed"] = bool(settings.get("left_handed", false))
	settings["shop_name"] = String(settings.get("shop_name", "")).strip_edges().left(18)


func _refresh_daily_missions() -> void:
	var today: String = Time.get_date_string_from_system()
	if missions_date == today and not daily_mission_ids.is_empty():
		return
	if missions_date != today:
		claimed_missions.clear()
		mission_progress = {}
		for metric: String in Missions.PROGRESS_KEYS:
			mission_progress[metric] = 0
	missions_date = today
	daily_mission_ids = Missions.roll_for_day(today, player_level)


func is_daily_claimed_today() -> bool:
	_refresh_daily_missions()
	return last_daily_claim == Time.get_date_string_from_system()


func claim_daily_reward() -> int:
	var today: String = Time.get_date_string_from_system()
	if last_daily_claim == today:
		return 0
	if not last_daily_claim.is_empty():
		var last_day_unix: int = int(
			Time.get_unix_time_from_datetime_string(last_daily_claim + "T00:00:00")
		)
		var today_unix: int = int(Time.get_unix_time_from_datetime_string(today + "T00:00:00"))
		if today_unix <= last_day_unix:
			Analytics.track(&"churn_risk_signal", {"reason": "daily_clock_rollback"})
			return 0
		if today_unix - last_day_unix > 36 * 3600:
			var gap_hours: int = floori(float(today_unix - last_day_unix) / 3600.0)
			if streak_freezes > 0 and gap_hours <= 60:
				streak_freezes -= 1
				EventBus.toast_requested.emit(Loc.t("FREEZE_USED"), Color("4fc3f7"))
				Analytics.track(&"streak_freeze_used", {"gap_hours": gap_hours})
			else:
				daily_streak = 0
	daily_streak = daily_streak % 7 + 1
	best_streak = maxi(best_streak, daily_streak)
	last_daily_claim = today
	var reward: int = Rewards.scaled(
		float(Rewards.SECONDS[&"streak_day"]) * daily_streak, 25 * daily_streak
	)
	if daily_streak == 7 and not unlocked_pets.has("mel_golden"):
		unlocked_pets.append("mel_golden")
	if daily_streak in [3, 5, 7]:
		streak_freezes += 1
		EventBus.toast_requested.emit(Loc.t("FREEZE_EARNED"), Color("7ed957"))
	add_coins(reward, &"daily_login")
	Analytics.track(&"daily_reward", {"day": daily_streak})
	SaveManager.request_save()
	return reward


func claim_mission(mission_id: StringName) -> bool:
	_refresh_daily_missions()
	var id: String = String(mission_id)
	if claimed_missions.has(id) or not daily_mission_ids.has(id):
		return false
	var mission: Dictionary = ContentDB.daily_mission(id)
	if mission.is_empty() or not Missions.is_ready(mission):
		return false
	claimed_missions.append(id)
	var coin_reward: int = Missions.coin_reward(mission)
	if coin_reward > 0:
		add_coins(float(coin_reward), &"daily_mission")
	var ember_reward: int = Missions.ember_reward(mission)
	if ember_reward > 0:
		embers += ember_reward
		EventBus.currency_changed.emit(&"embers", float(embers))
	Analytics.track(&"daily_mission_complete", {"id": id, "epic": Missions.is_epic(mission)})
	if Missions.regular_claimed_count() >= Missions.REGULAR_COUNT:
		_advance_pass()
	SaveManager.request_save()
	return true


## Chave da segunda-feira desta semana (dia unix), estável entre dias.
func _week_key() -> String:
	var days: int = int(floor(Time.get_unix_time_from_system() / 86400.0))
	return str(days - ((days + 3) % 7))


func _refresh_weekly_missions() -> void:
	var week: String = _week_key()
	if week_start == week:
		return
	week_start = week
	weekly_progress = {
		"services": 0, "perfect": 0, "combo_max": 0, "tips": 0, "style": 0, "vip": 0, "spend": 0
	}
	claimed_weeklies.clear()


func weekly_value(metric: String) -> int:
	_refresh_weekly_missions()
	return int(weekly_progress.get(metric, 0))


func register_weekly_event(metric: StringName) -> void:
	_refresh_weekly_missions()
	weekly_progress[String(metric)] = int(weekly_progress.get(String(metric), 0)) + 1


func register_weekly_spend(amount: int) -> void:
	_refresh_weekly_missions()
	weekly_progress["spend"] = int(weekly_progress.get("spend", 0)) + maxi(0, amount)


func claim_weekly(mission_id: StringName) -> bool:
	_refresh_weekly_missions()
	var id: String = String(mission_id)
	if claimed_weeklies.has(id):
		return false
	var data: Dictionary = ContentDB.weekly_mission(id)
	if data.is_empty():
		return false
	var metric: String = String(data.get("metric", ""))
	if int(weekly_progress.get(metric, 0)) < int(data.get("target", 1)):
		return false
	claimed_weeklies.append(id)
	var reward: Dictionary = data.get("reward", {})
	if reward.has("coins"):
		add_coins(
			float(Rewards.for_kind(&"weekly_mission", int(reward["coins"]))), &"weekly_mission"
		)
	if reward.has("embers"):
		embers += int(reward["embers"])
		EventBus.currency_changed.emit(&"embers", float(embers))
	Analytics.track(&"weekly_mission_complete", {"id": id})
	SaveManager.request_save()
	return true


## Meta do dia do evento: zera quando o dia muda.
func _refresh_event_goal() -> void:
	var today: String = Time.get_date_string_from_system()
	if event_goal_date == today:
		return
	event_goal_date = today
	event_goal_count = 0
	event_goal_claimed = false


## Resgata a meta do dia (moedas escaladas + brasas). Uma vez por dia.
func claim_event_goal() -> bool:
	_refresh_event_goal()
	if event_goal_claimed or event_goal_count < LiveOps.event_goal_target():
		return false
	event_goal_claimed = true
	var coins_reward: int = Rewards.for_kind(&"event_goal", 300)
	add_coins(float(coins_reward), &"event_goal")
	embers += LiveOps.EVENT_GOAL_EMBERS
	EventBus.currency_changed.emit(&"embers", float(embers))
	Analytics.track(&"event_goal_claimed", {"weekday": LiveOps.weekday(), "coins": coins_reward})
	SaveManager.request_save()
	return true


## Sink de prestige (auditoria de retenção): 1 token de franquia vira 5 brasas.
## Fecha o loop da moeda órfã sem criar paywall nem segunda economia dura.
func convert_franchise_token() -> bool:
	if franchise_tokens <= 0:
		return false
	franchise_tokens -= 1
	embers += 5
	EventBus.currency_changed.emit(&"embers", float(embers))
	EventBus.toast_requested.emit("Token de franquia convertido: +5 Brasas", Color("ffd54f"))
	Analytics.track(&"currency_spent", {"currency": "franchise_tokens", "amount": 1})
	SaveManager.request_save()
	return true


## Baú semanal: completar E claimar as 7 semanais paga um bônus único por
## semana. Chamado após cada claim semanal.
func check_weekly_chest() -> bool:
	_refresh_weekly_missions()
	if weekly_chest_week == week_start:
		return false
	for weekly: Dictionary in ContentDB.weekly_missions:
		if not claimed_weeklies.has(String(weekly["id"])):
			return false
	weekly_chest_week = week_start
	embers += 3
	var chest_coins: int = Rewards.for_kind(&"weekly_chest", 200)
	add_coins(float(chest_coins), &"weekly_chest")
	EventBus.currency_changed.emit(&"embers", float(embers))
	EventBus.toast_requested.emit(Loc.t("WEEKLY_CHEST_TOAST") % [chest_coins, 3], Color("ffd54f"))
	Analytics.track(&"weekly_mission_complete", {"id": "weekly_chest"})
	SaveManager.request_save()
	return true


## Pass de 28 dias: um dia destravado por ciclo diário completo (3 missões).
func _advance_pass() -> void:
	var today: String = Time.get_date_string_from_system()
	if pass_advance_day == today or pass_day_unlocked >= 28:
		return
	pass_advance_day = today
	pass_day_unlocked = mini(28, pass_day_unlocked + 1)
	EventBus.toast_requested.emit(
		"%s %d/28" % [Loc.t("PASS_UNLOCKED"), pass_day_unlocked], Color("4fc3f7")
	)
	Analytics.track(&"pass_unlocked", {"day": pass_day_unlocked})


func claim_pass_day() -> bool:
	if pass_day_claimed >= pass_day_unlocked:
		return false
	var reward: Dictionary = ContentDB.pass_day(pass_day_claimed + 1)
	pass_day_claimed += 1
	if reward.has("coins"):
		add_coins(float(Rewards.pass_day_coins(pass_day_claimed)), &"pass")
	if reward.has("embers"):
		embers += int(reward["embers"])
		EventBus.currency_changed.emit(&"coins", coins)
	if reward.has("freeze"):
		streak_freezes += int(reward["freeze"])
	Analytics.track(&"pass_claim", {"day": pass_day_claimed})
	SaveManager.request_save()
	return true


## Bônus de retorno: ausência >= 48h rende presente (moedas + 1 freeze).
func check_return_bonus() -> bool:
	var today: String = Time.get_date_string_from_system()
	if last_return_day == today or last_seen_unix <= 0:
		return false
	var absent_hours: float = (Time.get_unix_time_from_system() - last_seen_unix) / 3600.0
	if absent_hours < 48.0:
		return false
	last_return_day = today
	streak_freezes += 1
	add_coins(
		float(Rewards.for_kind(&"return_bonus", 200 + 25 * mini(player_level, 20))), &"return_bonus"
	)
	Analytics.track(&"return_bonus", {"absent_hours": absent_hours})
	SaveManager.request_save()
	return true


func _on_service_completed(service_id: StringName, quality: StringName, reward: float) -> void:
	_refresh_daily_missions()
	_refresh_weekly_missions()
	_refresh_event_goal()
	if LiveOps.event_goal_counts(service_id):
		event_goal_count += 1
	services_completed += 1
	mission_progress["services"] = int(mission_progress.get("services", 0)) + 1
	weekly_progress["services"] = int(weekly_progress.get("services", 0)) + 1
	if quality == &"perfect":
		mission_progress["perfect"] = int(mission_progress.get("perfect", 0)) + 1
		weekly_progress["perfect"] = int(weekly_progress.get("perfect", 0)) + 1
		total_perfect_services += 1
	if quality == &"perfect":
		combo += 1
		combo_grace_used = false
	elif quality == &"good" and combo > 0 and not combo_grace_used:
		# Folga: o primeiro Good de uma sequência preserva o ritmo; fail zera.
		combo_grace_used = true
	else:
		combo = 0
		combo_grace_used = false
	best_combo = maxi(best_combo, combo)
	weekly_progress["combo_max"] = maxi(int(weekly_progress.get("combo_max", 0)), combo)
	mission_progress["combo_reached"] = maxi(int(mission_progress.get("combo_reached", 0)), combo)
	if services_completed >= 8 and not hired_staff.has("bia"):
		hired_staff.append("bia")
		EventBus.toast_requested.emit(Loc.t("BIA_HIRED"), Color("7ed957"))
	_add_xp(15 if quality == &"perfect" else 10)
	add_coins(reward, &"service")
	_check_achievements()
	EventBus.combo_changed.emit(combo)
	SaveManager.request_save()


func xp_to_next_level() -> int:
	return 50 + (player_level - 1) * 25


func _add_xp(amount: int) -> void:
	if player_level >= MAX_CAREER_LEVEL:
		return
	player_xp += amount
	while player_level < MAX_CAREER_LEVEL and player_xp >= xp_to_next_level():
		player_xp -= xp_to_next_level()
		player_level += 1
		var level_reward: int = Rewards.for_kind(&"level_up", 20 + player_level * 5)
		coins += level_reward
		total_coins += level_reward
		EventBus.toast_requested.emit(
			Loc.t("LEVEL_UP_TOAST") % [player_level, level_reward], Color("4fc3f7")
		)
		AudioManager.play(&"level_up")
		HapticsManager.success()
		# Serviço novo (gates em service_layouts.json): cartão com o gesto, não toast.
		for service: String in ContentDB.service_layouts:
			var layout: Dictionary = ContentDB.service_layouts[service]
			if int(layout.get("unlock_level", 1)) == player_level:
				EventBus.reveal_requested.emit(&"service", {"service": service, "level": player_level})
		Analytics.track(&"level_up", {"level": player_level})
		_reconcile_career_unlocks(true)


## Define o pet preferido (buddy); precisa estar desbloqueado.
func set_favorite_pet(pet_id: String) -> bool:
	if not unlocked_pets.has(pet_id) or favorite_pet == pet_id:
		return false
	favorite_pet = pet_id
	Analytics.track(&"favorite_pet_set", {"pet_id": pet_id})
	SaveManager.request_save()
	EventBus.settings_changed.emit()
	return true


func staff_vocation(staff_id: String) -> String:
	var member: Dictionary = ContentDB.staff(staff_id)
	return String(STAFF_VOCATION.get(String(member.get("passive", {}).get("type", "speed")), ""))


func register_pet_interaction(pet_id: String) -> int:
	var previous_touches: int = clampi(int(pet_affection.get(pet_id, 0)), 0, 50)
	var touches: int = mini(50, previous_touches + 1)
	pet_affection[pet_id] = touches
	var reached_new_milestone: bool = touches != previous_touches and touches in [1, 5, 20, 50]
	if reached_new_milestone:
		Analytics.track(&"pet_affection_reached", {"pet_id": pet_id, "level": touches})
	if reached_new_milestone and touches in [5, 20, 50]:
		var ember_reward: int = 1 if touches == 5 else (2 if touches == 20 else 3)
		embers += ember_reward
		EventBus.toast_requested.emit(Loc.t("AFFECTION_TOAST") % ember_reward, Color("ff8fb1"))
	SaveManager.request_save()
	return touches


func _reconcile_career_unlocks(show_feedback: bool) -> void:
	var available: Array[String] = ContentDB.unlocked_pet_ids(player_level)
	for pet_id: String in available:
		if unlocked_pets.has(pet_id):
			continue
		unlocked_pets.append(pet_id)
		if show_feedback:
			var profile: Dictionary = ContentDB.pet(pet_id)
			EventBus.reveal_requested.emit(&"pet", {"id": pet_id})
			Analytics.track(
				&"collection_unlock",
				{"id": pet_id, "category": "pet", "rarity": profile.get("rarity", "common")}
			)
	var new_tier: int = ContentDB.establishment_for_level(player_level)
	if new_tier > establishment_tier and show_feedback:
		EventBus.reveal_requested.emit(&"chapter", {"tier": new_tier})
	establishment_tier = new_tier


func _check_achievements() -> void:
	if services_completed >= 1:
		_unlock_achievement("first_bath", 25)
	if total_perfect_services >= 1:
		_unlock_achievement("perfect_1", 0, 2)
	if total_perfect_services >= 10:
		_unlock_achievement("perfect_10", 150)
	if best_combo >= 5:
		_unlock_achievement("combo_5", 0, 3)
	if best_combo >= 20:
		_unlock_achievement("combo_20")
		if not unlocked_cosmetics.has("crown_bubbles"):
			unlocked_cosmetics.append("crown_bubbles")
	if total_coins >= 500.0:
		_unlock_achievement("earn_500", 50)
	if bath_upgrade_level >= 5:
		_unlock_achievement("upgrade_5", 0, 2)
	if five_star_reviews >= 10:
		_unlock_achievement("reviews_10", 120)
	if unlocked_pets.size() >= 5:
		_unlock_achievement("collect_5", 0, 4)
	if offline_seconds_collected >= 3600.0:
		_unlock_achievement("offline_1h", 100)
	# Leva D7/D30 (auditoria de retenção): metas longas com recompensa variada.
	if best_combo >= 50:
		_unlock_achievement("combo_50", 0, 5)
	if total_perfect_services >= 100:
		_unlock_achievement("perfect_100", 400)
	if services_completed >= 100:
		_unlock_achievement("services_100", 200)
	if services_completed >= 500:
		_unlock_achievement("services_500", 0, 4)
	if services_completed >= 1000:
		_unlock_achievement("services_1000", 0, 8)
	if five_star_reviews >= 50:
		_unlock_achievement("reviews_50", 300)
	if unlocked_pets.size() >= 15:
		_unlock_achievement("collect_15", 0, 3)
	if unlocked_pets.size() >= 30:
		_unlock_achievement("collect_30", 0, 5)
	if unlocked_pets.size() >= 50:
		_unlock_achievement("collect_50", 0, 10)
	if unlocked_cosmetics.size() >= 5:
		_unlock_achievement("cosmetics_5", 200)
	if hired_staff.size() >= 3:
		_unlock_achievement("staff_2", 0, 2)
	if hired_staff.size() >= 6:
		_unlock_achievement("staff_5", 0, 4)
	if bath_upgrade_level >= 25:
		_unlock_achievement("upgrade_25", 500)
	if bath_upgrade_level >= 50:
		_unlock_achievement("upgrade_50", 0, 6)
	if prestige_level >= 1:
		_unlock_achievement("prestige_1", 0, 5)
	if offline_seconds_collected >= 28800.0:
		_unlock_achievement("offline_8h", 250)
	if total_coins >= 5000.0:
		_unlock_achievement("rich_5000", 0, 3)
	if best_streak >= 7:
		_unlock_achievement("streak_7", 0, 4)
	if player_level >= 25:
		_unlock_achievement("level_25", 300)
	for touches: Variant in pet_affection.values():
		if int(touches) >= 50:
			_unlock_achievement("friend_50", 0, 4)
			break


func register_offline_collection(seconds: float) -> void:
	offline_seconds_collected += maxf(0.0, seconds)
	_check_achievements()


func _unlock_achievement(id: String, coins_reward: int = 0, embers_reward: int = 0) -> void:
	if achievement_ids.has(id):
		return
	achievement_ids.append(id)
	var scaled_coins: int = Rewards.for_kind(&"achievement", coins_reward) if coins_reward > 0 else 0
	if scaled_coins > 0:
		add_coins(scaled_coins, &"achievement")
	if embers_reward > 0:
		embers += embers_reward
	Analytics.track(&"collection_unlock", {"id": id, "category": "achievement"})
	EventBus.reveal_requested.emit(
		&"achievement", {"id": id, "coins": scaled_coins, "embers": embers_reward}
	)


func _on_service_failed(_service_id: StringName, _reason: StringName) -> void:
	combo = 0
	EventBus.combo_changed.emit(combo)
