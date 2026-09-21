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
	for weekly_event: Dictionary in _load_array(EVENTS_PATH, "weekly"):
		var day: int = int(weekly_event.get("weekday", -1))
		if day >= 0 and day <= 6 and not weekly_events.has(day):
			weekly_events[day] = weekly_event
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


func staff_name(id: String) -> String:
	var entry: Dictionary = staff_by_id.get(id, {})
	return String(entry.get("name", id))


func staff(id: String) -> Dictionary:
	return staff_by_id.get(id, {})


func achievement_name(id: String) -> String:
	var entry: Dictionary = achievements_by_id.get(id, {})
	return String(entry.get("name", id))


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
