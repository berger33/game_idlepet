extends Node
## Estado autoritativo serializável da sessão.

const SAVE_VERSION: int = 4
const MAX_CAREER_LEVEL: int = 120
var coins: float = 0.0
var embers: int = 0
var franchise_tokens: int = 0
var total_coins: float = 0.0
var bath_upgrade_level: int = 0
var combo: int = 0
var best_combo: int = 0
var services_completed: int = 0
var player_level: int = 1
var player_xp: int = 0
var reviews_total: int = 0
var reviews_sum: int = 0
var prestige_level: int = 0
var last_seen_unix: int = 0
var tutorial_complete: bool = false
var unlocked_pets: Array[String] = ["caramelo"]
var hired_staff: Array[String] = ["player"]
var achievement_ids: Array[String] = []
var mission_progress: Dictionary = {"services": 0, "perfect": 0, "upgrades": 0}
var claimed_missions: Array[String] = []
var missions_date: String = ""
var last_daily_claim: String = ""
var daily_streak: int = 0
var establishment_tier: int = 1
var passive_accumulator: float = 0.0
var active_play_seconds: float = 0.0
var pet_affection: Dictionary = {}
var settings: Dictionary = {
	"music": 0.7, "sfx": 0.9, "haptics": true, "reduced_particles": false, "eco_mode": false
}


func _ready() -> void:
	_refresh_daily_missions()
	EventBus.service_completed.connect(_on_service_completed)
	EventBus.service_failed.connect(_on_service_failed)


func _process(delta: float) -> void:
	active_play_seconds += delta
	if not hired_staff.has("bia"):
		return
	passive_accumulator += delta
	if passive_accumulator >= 5.0:
		var cycles: int = int(passive_accumulator / 5.0)
		passive_accumulator -= cycles * 5.0
		add_coins(
			float(cycles) * 2.0 * Economy.income_multiplier(bath_upgrade_level), &"staff_idle"
		)


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
	if bath_upgrade_level >= MAX_CAREER_LEVEL:
		return false
	var cost: float = Economy.upgrade_cost(bath_upgrade_level)
	if not spend_coins(cost, &"bath_upgrade"):
		return false
	bath_upgrade_level += 1
	mission_progress["upgrades"] = int(mission_progress.get("upgrades", 0)) + 1
	EventBus.upgrade_purchased.emit(&"bath", bath_upgrade_level)
	Analytics.track(&"establishment_upgrade", {"id": "bath", "level": bath_upgrade_level})
	SaveManager.request_save()
	return true


func register_review(stars: int) -> void:
	reviews_total += 1
	reviews_sum += clampi(stars, 1, 5)
	EventBus.review_received.emit(stars)


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
		"combo": combo,
		"best_combo": best_combo,
		"services_completed": services_completed,
		"player_level": player_level,
		"player_xp": player_xp,
		"reviews_total": reviews_total,
		"reviews_sum": reviews_sum,
		"prestige_level": prestige_level,
		"last_seen_unix": Time.get_unix_time_from_system(),
		"tutorial_complete": tutorial_complete,
		"unlocked_pets": unlocked_pets,
		"hired_staff": hired_staff,
		"achievement_ids": achievement_ids,
		"mission_progress": mission_progress,
		"claimed_missions": claimed_missions,
		"missions_date": missions_date,
		"last_daily_claim": last_daily_claim,
		"daily_streak": daily_streak,
		"establishment_tier": establishment_tier,
		"active_play_seconds": active_play_seconds,
		"pet_affection": pet_affection,
		"settings": settings
	}


func apply_dictionary(data: Dictionary) -> void:
	coins = float(data.get("coins", 0.0))
	embers = int(data.get("embers", 0))
	franchise_tokens = int(data.get("franchise_tokens", 0))
	total_coins = float(data.get("total_coins", coins))
	bath_upgrade_level = int(data.get("bath_upgrade_level", 0))
	combo = int(data.get("combo", 0))
	best_combo = int(data.get("best_combo", combo))
	services_completed = int(data.get("services_completed", 0))
	player_level = int(data.get("player_level", 1))
	player_xp = int(data.get("player_xp", 0))
	reviews_total = int(data.get("reviews_total", 0))
	reviews_sum = int(data.get("reviews_sum", 0))
	prestige_level = int(data.get("prestige_level", 0))
	last_seen_unix = int(data.get("last_seen_unix", 0))
	tutorial_complete = bool(data.get("tutorial_complete", false))
	unlocked_pets.assign(data.get("unlocked_pets", ["caramelo"]))
	hired_staff.assign(data.get("hired_staff", ["player"]))
	achievement_ids.assign(data.get("achievement_ids", []))
	mission_progress = data.get("mission_progress", {"services": 0, "perfect": 0, "upgrades": 0})
	claimed_missions.assign(data.get("claimed_missions", []))
	missions_date = String(data.get("missions_date", ""))
	_refresh_daily_missions()
	last_daily_claim = String(data.get("last_daily_claim", ""))
	daily_streak = int(data.get("daily_streak", 0))
	establishment_tier = int(data.get("establishment_tier", 1))
	active_play_seconds = float(data.get("active_play_seconds", 0.0))
	pet_affection = data.get("pet_affection", {})
	_reconcile_career_unlocks(false)
	settings.merge(data.get("settings", {}), true)
	EventBus.currency_changed.emit(&"coins", coins)


func _refresh_daily_missions() -> void:
	var today: String = Time.get_date_string_from_system()
	if missions_date == today:
		return
	missions_date = today
	claimed_missions.clear()
	mission_progress = {"services": 0, "perfect": 0, "upgrades": 0}


func claim_daily_reward() -> int:
	var today: String = Time.get_date_string_from_system()
	if last_daily_claim == today:
		return 0
	if not last_daily_claim.is_empty():
		var last_day_unix: int = int(
			Time.get_unix_time_from_datetime_string(last_daily_claim + "T00:00:00")
		)
		var today_unix: int = int(Time.get_unix_time_from_datetime_string(today + "T00:00:00"))
		if today_unix - last_day_unix > 36 * 3600:
			daily_streak = 0
	daily_streak = daily_streak % 7 + 1
	last_daily_claim = today
	var reward: int = 25 * daily_streak
	if daily_streak == 7 and not unlocked_pets.has("mel_golden"):
		unlocked_pets.append("mel_golden")
	add_coins(reward, &"daily_login")
	Analytics.track(&"daily_reward", {"day": daily_streak})
	SaveManager.request_save()
	return reward


func claim_mission(mission_id: StringName) -> bool:
	var id: String = String(mission_id)
	if claimed_missions.has(id):
		return false
	var ready: bool = (
		(id == "daily_bath_5" and int(mission_progress.get("services", 0)) >= 5)
		or (id == "daily_perfect_3" and int(mission_progress.get("perfect", 0)) >= 3)
		or (id == "daily_upgrade_1" and int(mission_progress.get("upgrades", 0)) >= 1)
	)
	if not ready:
		return false
	claimed_missions.append(id)
	add_coins(75, &"daily_mission")
	Analytics.track(&"daily_mission_complete", {"id": id})
	SaveManager.request_save()
	return true


func _on_service_completed(_service_id: StringName, quality: StringName, reward: float) -> void:
	services_completed += 1
	mission_progress["services"] = int(mission_progress.get("services", 0)) + 1
	if quality == &"perfect":
		mission_progress["perfect"] = int(mission_progress.get("perfect", 0)) + 1
	combo = combo + 1 if quality == &"perfect" else 0
	best_combo = maxi(best_combo, combo)
	if services_completed >= 8 and not hired_staff.has("bia"):
		hired_staff.append("bia")
		EventBus.toast_requested.emit("Bia foi contratada! +5% banho", Color("7ed957"))
	_check_achievements(quality)
	_add_xp(15 if quality == &"perfect" else 10)
	add_coins(reward, &"service")
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
		var level_reward: int = 20 + player_level * 5
		coins += level_reward
		total_coins += level_reward
		EventBus.toast_requested.emit(
			"Nível %d! +%d moedas" % [player_level, level_reward], Color("4fc3f7")
		)
		Analytics.track(&"level_up", {"level": player_level})
		_reconcile_career_unlocks(true)


func register_pet_interaction(pet_id: String) -> int:
	var touches: int = int(pet_affection.get(pet_id, 0)) + 1
	pet_affection[pet_id] = touches
	if touches in [1, 5, 20, 50]:
		Analytics.track(&"pet_affection_reached", {"pet_id": pet_id, "level": touches})
	if touches in [5, 20, 50]:
		var ember_reward: int = 1 if touches == 5 else (2 if touches == 20 else 3)
		embers += ember_reward
		EventBus.toast_requested.emit("Laço de amizade! +%d Brasas" % ember_reward, Color("ff8fb1"))
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
			EventBus.toast_requested.emit(
				"Novo pet: %s, %s!" % [profile.get("name", pet_id), profile.get("breed", "")],
				Color("ff8fb1")
			)
			Analytics.track(
				&"collection_unlock",
				{"id": pet_id, "category": "pet", "rarity": profile.get("rarity", "common")}
			)
	var new_tier: int = ContentDB.establishment_for_level(player_level)
	if new_tier > establishment_tier and show_feedback:
		EventBus.toast_requested.emit(
			"Novo capítulo: %s!" % ContentDB.establishment_name(new_tier), Color("ffd54f")
		)
	establishment_tier = new_tier


func _check_achievements(quality: StringName) -> void:
	if services_completed >= 1:
		_unlock_achievement("first_bath", 25)
	if quality == &"perfect":
		_unlock_achievement("perfect_1", 20)
	if best_combo >= 5:
		_unlock_achievement("combo_5", 50)


func _unlock_achievement(id: String, reward: int) -> void:
	if achievement_ids.has(id):
		return
	achievement_ids.append(id)
	coins += reward
	total_coins += reward
	Analytics.track(&"collection_unlock", {"id": id, "category": "achievement"})
	EventBus.toast_requested.emit("Conquista desbloqueada! +%d" % reward, Color("ffd54f"))


func _on_service_failed(_service_id: StringName, _reason: StringName) -> void:
	combo = 0
	EventBus.combo_changed.emit(combo)
