class_name Goals
extends RefCounted
## Meta visível no HUD: "o que vem a seguir e a que distância". Legibilidade de
## objetivo é um dos maiores preditores de retorno (o HUD mostrava só
## "NV.12 45% • ×3"). Estático: lê ContentDB/GameState, sem estado próprio.

## Gates dos serviços (mesma fonte de Rewards: data/service_layouts.json).
const SERVICE_LABEL_KEY: Dictionary = {
	"bath": "SERVICE_BATH",
	"groom": "SERVICE_GROOM",
	"dry": "SERVICE_DRY",
	"perfume": "SERVICE_PERFUME",
	"style": "SERVICE_STYLE",
}


## Próximo desbloqueio por nível: {"level": int, "text": String} ou {} no fim.
static func next_unlock(level: int) -> Dictionary:
	var best_level: int = GameState.MAX_CAREER_LEVEL + 1
	var best_text: String = ""
	for pet: Dictionary in ContentDB.pets:
		var unlock: int = int(pet.get("unlock_level", 1))
		if unlock > level and unlock < best_level:
			best_level = unlock
			best_text = Loc.t("GOAL_PET") % String(pet.get("name", ""))
	for service: String in SERVICE_LABEL_KEY:
		var layout: Dictionary = ContentDB.service_layouts.get(service, {})
		var unlock: int = int(layout.get("unlock_level", 1))
		if unlock > level and unlock < best_level:
			best_level = unlock
			best_text = Loc.t("GOAL_SERVICE") % Loc.t(String(SERVICE_LABEL_KEY[service]))
	for entry: Dictionary in ContentDB.career.get("establishments", []):
		var unlock: int = int(entry.get("unlock_level", 1))
		if unlock > level and unlock < best_level:
			best_level = unlock
			best_text = Loc.t("GOAL_CHAPTER") % String(entry.get("name", ""))
	if best_text.is_empty():
		return {}
	return {"level": best_level, "text": best_text}


## Linha do HUD: "PRÓXIMO: Nina • Nv.20 (62%)". No topo da carreira, prestígio.
static func hud_line() -> String:
	var level: int = GameState.player_level
	var goal: Dictionary = next_unlock(level)
	if goal.is_empty():
		return Loc.t("GOAL_PRESTIGE") % GameState.prestige_tokens_available()
	var percent: int = int(100.0 * GameState.player_xp / maxf(1.0, GameState.xp_to_next_level()))
	if int(goal["level"]) == level + 1:
		return Loc.t("GOAL_NEXT_LEVEL") % [String(goal["text"]), percent]
	return Loc.t("GOAL_LINE") % [String(goal["text"]), int(goal["level"]), percent]
