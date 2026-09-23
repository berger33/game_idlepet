class_name Research
extends RefCounted
## Pesquisa da franquia (GDD §14: "Tokens compram meta permanente"; sinks:
## pesquisa). A árvore vive em data/research.json; o estado é
## GameState.research_ids (persistido e preservado pelo prestígio — é o
## investimento que dá sentido a prestigiar de novo).
## Tudo estático, sem estado próprio: os efeitos são lidos nos hooks
## (SalonTuning.apply/compute_reward, fila do Main, cofre offline) via
## bonus(), no mesmo padrão de GameState.staff_bonus().

const TOAST_COLOR: Color = Color("ce93d8")

## Soma por efeito, memorizada: bonus() roda por frame na fila do Main e não
## deve alocar/iterar durante o gameplay. Invalidada ao pesquisar e ao carregar.
static var _bonus_cache: Dictionary = {}


static func invalidate_cache() -> void:
	_bonus_cache.clear()


static func owned(node_id: String) -> bool:
	return GameState.research_ids.has(node_id)


static func owned_count() -> int:
	return GameState.research_ids.size()


## Soma do efeito de todos os nós pesquisados (0.0 sem pesquisa).
## Chaves: bath_income, satisfaction, service_speed, patience, offline_rate.
static func bonus(effect: StringName) -> float:
	if _bonus_cache.has(effect):
		return float(_bonus_cache[effect])
	var total: float = 0.0
	for node_id: String in GameState.research_ids:
		var effects: Dictionary = ContentDB.research(node_id).get("effect", {})
		total += float(effects.get(String(effect), 0.0))
	_bonus_cache[effect] = total
	return total


static func cost(node_id: String) -> int:
	return maxi(1, int(ContentDB.research(node_id).get("cost", 1)))


static func requirements_met(node_id: String) -> bool:
	for required: Variant in ContentDB.research(node_id).get("requires", []):
		if not owned(String(required)):
			return false
	return true


static func can_buy(node_id: String) -> bool:
	if owned(node_id) or ContentDB.research(node_id).is_empty():
		return false
	return requirements_met(node_id) and GameState.franchise_tokens >= cost(node_id)


## Pesquisa um nó: debita tokens de franquia e liga o efeito para sempre.
static func buy(node_id: String) -> bool:
	if not can_buy(node_id):
		return false
	var price: int = cost(node_id)
	GameState.franchise_tokens -= price
	GameState.research_ids.append(node_id)
	invalidate_cache()
	Analytics.track(
		&"currency_spent",
		{"currency": "franchise_tokens", "amount": price, "sink": "research", "id": node_id}
	)
	Analytics.track(&"research_complete", {"id": node_id, "owned": owned_count()})
	EventBus.toast_requested.emit(
		Loc.t("RESEARCH_TOAST") % String(ContentDB.research(node_id).get("name", node_id)),
		TOAST_COLOR
	)
	SaveManager.request_save()
	return true


## Pré-requisitos ainda não pesquisados, por nome (UI: "Requer: X, Y").
static func missing_requirements(node_id: String) -> String:
	var names: PackedStringArray = []
	for required: Variant in ContentDB.research(node_id).get("requires", []):
		var required_id: String = String(required)
		if not owned(required_id):
			names.append(String(ContentDB.research(required_id).get("name", required_id)))
	return ", ".join(names)


## Efeito de um nó em texto: "Banho rende +10%".
static func effect_text(node_id: String) -> String:
	var parts: PackedStringArray = []
	var effects: Dictionary = ContentDB.research(node_id).get("effect", {})
	for key: String in effects:
		var percent: int = int(roundf(float(effects[key]) * 100.0))
		parts.append(Loc.t("RESEARCH_EFFECT_" + key) % percent)
	return " • ".join(parts)
