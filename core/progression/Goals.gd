class_name Goals
extends RefCounted
## Meta visível no HUD: "o que vem a seguir e a que distância". Legibilidade de
## objetivo é um dos maiores preditores de retorno (o HUD mostrava só
## "NV.12 45% • ×3"). Estático: lê ContentDB/GameState, sem estado próprio.
## P0 primeira impressão: mostra nome do pet direto, sem "pet X", mais claro.

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
			var pid: String = String(pet.get("id", ""))
			best_text = ContentDB.pet_name(pid) if ContentDB.has_pet(pid) else String(pet.get("name", ""))
	for service: String in SERVICE_LABEL_KEY:
		var layout: Dictionary = ContentDB.service_layouts.get(service, {})
		var unlock: int = int(layout.get("unlock_level", 1))
		if unlock > level and unlock < best_level:
			best_level = unlock
			best_text = Loc.t(String(SERVICE_LABEL_KEY[service]))
	for entry: Dictionary in ContentDB.career.get("establishments", []):
		var unlock: int = int(entry.get("unlock_level", 1))
		if unlock > level and unlock < best_level:
			best_level = unlock
			best_text = String(entry.get("name", ""))
	if best_text.is_empty():
		return {}
	return {"level": best_level, "text": best_text}


## Linha do HUD: "PRÓXIMO: Nina • Nv.20 (62%)". No topo da carreira, prestígio.
## Nota10 P1-9: urgência semanal domingo
## Kids: esconde % e números quando kids_mode, deixa só nome com estrela (cognitivo 7 anos).
static func hud_line() -> String:
	var level: int = GameState.player_level
	var goal: Dictionary = next_unlock(level)
	var base: String = ""
	if bool(GameState.settings.get("kids_mode", false)):
		if goal.is_empty():
			base = "⭐ " + Loc.t("GOAL_PRESTIGE") % GameState.prestige_tokens_available()
		else:
			# kids: só nome + emoji, sem % nem Nv.XX — menos número abstrato
			base = "⭐ PRÓXIMO: " + String(goal["text"])
		return base
	if goal.is_empty():
		base = Loc.t("GOAL_PRESTIGE") % GameState.prestige_tokens_available()
	else:
		var percent: int = int(100.0 * GameState.player_xp / maxf(1.0, GameState.xp_to_next_level()))
		if int(goal["level"]) == level + 1:
			base = Loc.t("GOAL_NEXT_LEVEL") % [String(goal["text"]), percent]
		else:
			base = Loc.t("GOAL_LINE") % [String(goal["text"]), int(goal["level"]), percent]
	# Nota10: domingo último dia semanal
	if LiveOps.weekly_is_last_day() if LiveOps.has_method("weekly_is_last_day") else false:
		var summary: Dictionary = LiveOps.weekly_progress_summary() if LiveOps.has_method("weekly_progress_summary") else {}
		var done: int = int(summary.get("done", 0))
		var total: int = int(summary.get("total", 7))
		if done < total:
			base += " • ⏰ %d/%d" % [done, total]
	return base
