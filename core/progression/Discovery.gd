class_name Discovery
extends RefCounted
## Descoberta de pets pela fila (auditoria §5): a coleção destravava sozinha
## por nível — sem surpresa nem escolha. Agora o PRÓXIMO pet da carreira pode
## aparecer como visitante antes do nível dele; atendê-lo 3 vezes o adota
## (entra na coleção com cartão de revelação). O destravar por nível continua
## como garantia — o visitante só antecipa e dá um mini-objetivo legível.
## Estado: GameState.visitor_progress (pet_id -> atendimentos), persistido.

const VISITS_TO_ADOPT: int = 3
const VISITOR_CHANCE: float = 0.15
## Janela de níveis à frente em que o próximo pet começa a visitar.
const LEVEL_WINDOW: int = 6


## Próximo pet ainda bloqueado dentro da janela; "" se não houver.
static func candidate() -> String:
	var level: int = GameState.player_level
	var best_level: int = level + LEVEL_WINDOW + 1
	var best_id: String = ""
	for pet: Dictionary in ContentDB.pets:
		var pet_id: String = String(pet.get("id", ""))
		var unlock: int = int(pet.get("unlock_level", 1))
		if GameState.unlocked_pets.has(pet_id) or unlock <= level:
			continue
		if unlock < best_level:
			best_level = unlock
			best_id = pet_id
	return best_id


static func progress(pet_id: String) -> int:
	return clampi(int(GameState.visitor_progress.get(pet_id, 0)), 0, VISITS_TO_ADOPT)


## Sorteio de visitante para a fila (chamado por SalonTuning.make_client).
static func roll_visitor() -> String:
	if randf() >= VISITOR_CHANCE:
		return ""
	return candidate()


## Atendimento concluído para um visitante. true quando ele foi adotado.
static func register_service(pet_id: String) -> bool:
	if GameState.unlocked_pets.has(pet_id) or not ContentDB.has_pet(pet_id):
		return false
	var visits: int = progress(pet_id) + 1
	GameState.visitor_progress[pet_id] = visits
	Analytics.track(&"visitor_served", {"pet_id": pet_id, "visits": visits})
	if visits < VISITS_TO_ADOPT:
		EventBus.toast_requested.emit(
			Loc.t("VISITOR_PROGRESS") % [
				String(ContentDB.pet(pet_id).get("name", pet_id)), visits, VISITS_TO_ADOPT
			],
			Color("ce93d8")
		)
		SaveManager.request_save()
		return false
	GameState.visitor_progress.erase(pet_id)
	GameState.unlocked_pets.append(pet_id)
	Analytics.track(
		&"collection_unlock",
		{
			"id": pet_id,
			"category": "pet",
			"rarity": ContentDB.pet(pet_id).get("rarity", "common"),
			"source": "visitor",
		}
	)
	EventBus.reveal_requested.emit(&"pet", {"id": pet_id, "adopted": true})
	SaveManager.request_save()
	return true
