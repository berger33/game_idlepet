extends Node
## Catálogo validado em memória para evitar parsing/alocação durante gameplay.

const PETS_PATH: String = "res://data/pets.json"
const CAREER_PATH: String = "res://data/career_track.json"
const STAFF_PATH: String = "res://data/staff.json"
const ACHIEVEMENTS_PATH: String = "res://data/achievements.json"
const COSMETICS_PATH: String = "res://data/cosmetics.json"
const PASS_PATH: String = "res://data/pass.json"
const WEEKLY_PATH: String = "res://data/weekly_missions.json"
const SERVICE_LAYOUTS_PATH: String = "res://data/service_layouts.json"
const EVENTS_PATH: String = "res://data/events.json"
const RESEARCH_PATH: String = "res://data/research.json"
const DAILY_PATH: String = "res://data/daily_missions.json"

var pets: Array[Dictionary] = []
var pets_by_id: Dictionary = {}
var career: Dictionary = {}
var staff_members: Array[Dictionary] = []
var staff_by_id: Dictionary = {}
var achievements: Array[Dictionary] = []
var achievements_by_id: Dictionary = {}
var cosmetics: Array[Dictionary] = []
var cosmetics_by_id: Dictionary = {}
var pass_days: Array[Dictionary] = []
var weekly_missions: Array[Dictionary] = []
var weekly_by_id: Dictionary = {}
var service_layouts: Dictionary = {}
## Agenda semanal (events.json "weekly"): índice = weekday 0..6 (0 = domingo).
var weekly_events: Dictionary = {}
## Temporadas (events.json "seasonal"): id -> entrada com months/cosmetic.
var seasonal_events: Array[Dictionary] = []
var seasonal_by_id: Dictionary = {}
## Árvore de pesquisa da franquia (research.json): sink dos tokens de prestígio.
var research_nodes: Array[Dictionary] = []
var research_by_id: Dictionary = {}
## Catálogo de missões diárias (daily_missions.json) — sorteio em Missions.gd.
var daily_missions: Array[Dictionary] = []
var daily_by_id: Dictionary = {}


func _ready() -> void:
	pets = _load_array(PETS_PATH, "pets")
	for pet_entry: Dictionary in pets:
		var id: String = String(pet_entry.get("id", ""))
		if not id.is_empty() and not pets_by_id.has(id):
			pets_by_id[id] = pet_entry
	career = _load_dictionary(CAREER_PATH)
	staff_members = _load_array(STAFF_PATH, "staff")
	for member: Dictionary in staff_members:
		var member_id: String = String(member.get("id", ""))
		if not member_id.is_empty() and not staff_by_id.has(member_id):
			staff_by_id[member_id] = member
	achievements = _load_array(ACHIEVEMENTS_PATH, "achievements")
	for achievement: Dictionary in achievements:
		var achievement_id: String = String(achievement.get("id", ""))
		if not achievement_id.is_empty() and not achievements_by_id.has(achievement_id):
			achievements_by_id[achievement_id] = achievement
	cosmetics = _load_array(COSMETICS_PATH, "cosmetics")
	for look: Dictionary in cosmetics:
		var look_id: String = String(look.get("id", ""))
		if not look_id.is_empty() and not cosmetics_by_id.has(look_id):
			cosmetics_by_id[look_id] = look
	pass_days = _load_array(PASS_PATH, "pass")
	weekly_missions = _load_array(WEEKLY_PATH, "missions")
	for weekly: Dictionary in weekly_missions:
		var weekly_id: String = String(weekly.get("id", ""))
		if not weekly_id.is_empty() and not weekly_by_id.has(weekly_id):
			weekly_by_id[weekly_id] = weekly
	for stage: Dictionary in _load_dictionary(SERVICE_LAYOUTS_PATH).get("stages", []):
		var stage_service: String = String(stage.get("service", ""))
		if not stage_service.is_empty():
			service_layouts[stage_service] = stage
	var weekly_override_json: String = ""
	var seasonal_override_json: String = ""
	# RemoteConfig pode ainda não estar pronto no _ready; leitura defensiva.
	if Engine.has_singleton("RemoteConfig") or (is_inside_tree() and has_node("/root/RemoteConfig")):
		weekly_override_json = RemoteConfig.get_string("events_weekly_override")
		seasonal_override_json = RemoteConfig.get_string("events_seasonal_override")
	else:
		# Fallback: tenta via autoload direto se existir
		var rc: Node = get_node_or_null("/root/RemoteConfig")
		if rc != null:
			weekly_override_json = rc.get_string("events_weekly_override")
			seasonal_override_json = rc.get_string("events_seasonal_override")

	if not weekly_override_json.is_empty():
		var parsed_weekly: Variant = JSON.parse_string(weekly_override_json)
		if parsed_weekly is Array:
			for weekly_event: Variant in parsed_weekly:
				if not weekly_event is Dictionary:
					continue
				var day: int = int((weekly_event as Dictionary).get("weekday", -1))
				if day >= 0 and day <= 6 and not weekly_events.has(day):
					weekly_events[day] = weekly_event as Dictionary
	else:
		for weekly_event: Dictionary in _load_array(EVENTS_PATH, "weekly"):
			var day: int = int(weekly_event.get("weekday", -1))
			if day >= 0 and day <= 6 and not weekly_events.has(day):
				weekly_events[day] = weekly_event

	if not seasonal_override_json.is_empty():
		var parsed_seasonal: Variant = JSON.parse_string(seasonal_override_json)
		if parsed_seasonal is Array:
			seasonal_events = []
			seasonal_by_id.clear()
			for season: Variant in parsed_seasonal:
				if not season is Dictionary:
					continue
				var s: Dictionary = season as Dictionary
				seasonal_events.append(s)
				var season_id: String = String(s.get("id", ""))
				if not season_id.is_empty() and not seasonal_by_id.has(season_id):
					seasonal_by_id[season_id] = s
	else:
		seasonal_events = _load_array(EVENTS_PATH, "seasonal")
		for season: Dictionary in seasonal_events:
			var season_id: String = String(season.get("id", ""))
			if not season_id.is_empty() and not seasonal_by_id.has(season_id):
				seasonal_by_id[season_id] = season
	research_nodes = _load_array(RESEARCH_PATH, "nodes")
	for node: Dictionary in research_nodes:
		var node_id: String = String(node.get("id", ""))
		if not node_id.is_empty() and not research_by_id.has(node_id):
			research_by_id[node_id] = node
	daily_missions = _load_array(DAILY_PATH, "missions")
	for mission: Dictionary in daily_missions:
		var mission_id: String = String(mission.get("id", ""))
		if not mission_id.is_empty() and not daily_by_id.has(mission_id):
			daily_by_id[mission_id] = mission


func cosmetic(id: String) -> Dictionary:
	return cosmetics_by_id.get(id, {})


## Evento semanal de um dia (0 = domingo); {} se a agenda não cobrir o dia.
func weekly_event_for(weekday: int) -> Dictionary:
	return weekly_events.get(clampi(weekday, 0, 6), {})


## Temporada cujo período inclui o mês (1..12); {} fora de temporada.
func seasonal_for_month(month: int) -> Dictionary:
	for season: Dictionary in seasonal_events:
		for value: Variant in season.get("months", []):
			if int(value) == month:
				return season
	return {}


func seasonal(id: String) -> Dictionary:
	return seasonal_by_id.get(id, {})


func research(id: String) -> Dictionary:
	return research_by_id.get(id, {})


func daily_mission(id: String) -> Dictionary:
	return daily_by_id.get(id, {})


## Recompensa do dia N do pass (1..28); retorna {} fora do intervalo.
func pass_day(day: int) -> Dictionary:
	if day < 1 or day > pass_days.size():
		return {}
	return pass_days[day - 1]


func weekly_mission(id: String) -> Dictionary:
	return weekly_by_id.get(id, {})


## Layout de serviço (fonte única: data/service_layouts.json). pet_position
## é a âncora dos PÉS do pet; shelf_y são os centros verticais dos utensílios.
func service_layout(service: StringName) -> Dictionary:
	var fallback: Dictionary = {"pet_position": [540, 1160], "shelf_y": [560, 730, 900, 1070, 1240]}
	var layout: Dictionary = service_layouts.get(String(service), {}) as Dictionary
	return layout if not layout.is_empty() else fallback


func _localized_or(key: String, fallback: String) -> String:
	var localized: String = Loc.t(key)
	# Loc.t returns key itself when missing — treat as not localized
	if localized == key:
		return fallback
	return localized


func staff_name(id: String) -> String:
	var entry: Dictionary = staff_by_id.get(id, {})
	var fallback: String = String(entry.get("name", id))
	return _localized_or("STAFF_" + id.to_upper(), fallback)


func staff(id: String) -> Dictionary:
	return staff_by_id.get(id, {})


func achievement_name(id: String) -> String:
	var entry: Dictionary = achievements_by_id.get(id, {})
	var fallback: String = String(entry.get("name", id))
	return _localized_or("ACH_" + id.to_upper(), fallback)


func pet_name(id: String) -> String:
	var entry: Dictionary = pets_by_id.get(id, {})
	var fallback: String = String(entry.get("name", id))
	return _localized_or("PET_" + id.to_upper(), fallback)


func cosmetic_name(id: String) -> String:
	var entry: Dictionary = cosmetics_by_id.get(id, {})
	var fallback: String = String(entry.get("name", id))
	return _localized_or("COS_" + id.to_upper(), fallback)


func research_name(id: String) -> String:
	var entry: Dictionary = research_by_id.get(id, {})
	var fallback: String = String(entry.get("name", id))
	return _localized_or("RESEARCH_" + id.to_upper(), fallback)


func has_pet(id: String) -> bool:
	return pets_by_id.has(id)


func pet(id: String) -> Dictionary:
	return pets_by_id.get(id, pets_by_id.get("caramelo", {}))


func unlocked_pet_ids(level: int) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in pets:
		if int(entry.get("unlock_level", 1)) <= level:
			result.append(String(entry["id"]))
	return result


func establishment_for_level(level: int) -> int:
	var result: int = 1
	for entry: Dictionary in career.get("establishments", []):
		if level >= int(entry.get("unlock_level", 1)):
			result = int(entry.get("tier", result))
	return result


func establishment_name(tier: int) -> String:
	for entry: Dictionary in career.get("establishments", []):
		if int(entry.get("tier", 0)) == tier:
			return String(entry.get("name", "Petshop"))
	return "Petshop"


## Reaplica overrides remotos (chamado quando RemoteConfig recebe payload).
func apply_remote_overrides() -> void:
	var weekly_json: String = RemoteConfig.get_string("events_weekly_override")
	var seasonal_json: String = RemoteConfig.get_string("events_seasonal_override")
	if not weekly_json.is_empty():
		var parsed: Variant = JSON.parse_string(weekly_json)
		if parsed is Array:
			weekly_events.clear()
			for weekly_event: Variant in parsed:
				if not weekly_event is Dictionary:
					continue
				var day: int = int((weekly_event as Dictionary).get("weekday", -1))
				if day >= 0 and day <= 6:
					weekly_events[day] = weekly_event as Dictionary
	if not seasonal_json.is_empty():
		var parsed_s: Variant = JSON.parse_string(seasonal_json)
		if parsed_s is Array:
			seasonal_events.clear()
			seasonal_by_id.clear()
			for season: Variant in parsed_s:
				if not season is Dictionary:
					continue
				var s: Dictionary = season as Dictionary
				seasonal_events.append(s)
				var sid: String = String(s.get("id", ""))
				if not sid.is_empty():
					seasonal_by_id[sid] = s


func weekly_featured_cosmetic() -> String:
	var featured: String = RemoteConfig.get_string("weekly_featured_cosmetic")
	if not featured.is_empty() and cosmetics_by_id.has(featured):
		return featured
	# Fallback: rotação semanal por hash da semana (sem backend)
	var week_key: int = int(Time.get_unix_time_from_system() / 604800.0)
	var list: Array[String] = []
	for c: Dictionary in cosmetics:
		var cid: String = String(c.get("id", ""))
		if not cid.is_empty() and c.has("price"):
			list.append(cid)
	if list.is_empty():
		return ""
	return list[week_key % list.size()]


func _load_array(path: String, key: String) -> Array[Dictionary]:
	var payload: Dictionary = _load_dictionary(path)
	var result: Array[Dictionary] = []
	for item: Variant in payload.get(key, []):
		if item is Dictionary:
			var entry: Dictionary = item
			result.append(entry)
	return result


func _load_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Conteúdo ausente: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("JSON inválido: " + path)
	return {}
