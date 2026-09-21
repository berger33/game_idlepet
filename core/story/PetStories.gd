class_name PetStories
extends RefCounted
## Gera micro-narrativas para pets a partir dos dados existentes (breed,
## temperament, city, preferred_service, patience, base_tip, rarity) sem
## alterar JSON. Usado em fila, coleção e resultado para criar vínculo
## emocional (storytelling) e gatilhos de curiosidade/prova social.

const TEMPERAMENT_BIOS: Dictionary = {
	&"happy": ["adora colo", "abana o rabo sem parar", "chegou correndo"],
	&"calm": ["observa tudo calmo", "respira fundo", "é zen"],
	&"playful": ["trouxe bolinha", "quer brincar", "pulou na banheira"],
	&"active": ["não para quieto", "cheio de energia", "late animado"],
	&"anxious": ["está nervoso", "precisa de carinho", "treme um pouquinho"],
	&"fearful": ["se esconde atrás da dona", "olhos arregalados", "precisa de calma"],
	&"irritated": ["rosnou na rua", "está de mau humor", "dona pediu paciência"],
	&"curious": ["cheira tudo", "explorou o quintal", "fuça em tudo"],
	&"gentle": ["encosta a cabeça", "é um doce", "pede carinho suave"],
	&"elegant": ["anda como modelo", "pose de capa", "olhar de diva"],
}

const CITY_FLAVOR: Dictionary = {
	"vila_pacata": "da vila",
	"suburbio": "do subúrbio",
	"centro": "do centro",
	"metropole": "da metrópole",
	"litoral": "da praia",
	"serra": "da serra",
	"capital": "da capital",
}

const SERVICE_NEED: Dictionary = {
	&"bath": ["rolou na lama", "cheio de folhas", "precisa de banho urgente"],
	&"groom": ["pelos embaraçados", "tosa atrasada", "pelo nos olhos"],
	&"dry": ["voltou da chuva", "molhado da praia", "pingando"],
	&"perfume": ["vai para festa", "encontro marcado", "quer cheirar bem"],
	&"style": ["aniversário hoje", "foto para Instagram", "quer lacinho novo"],
}

static func bio(profile: Dictionary) -> String:
	var temperament: StringName = StringName(profile.get("temperament", "happy"))
	var service: StringName = StringName(profile.get("preferred_service", "bath"))
	var city: String = String(profile.get("city", "vila_pacata"))
	var breed: String = String(profile.get("breed", "pet"))
	var bio_temper: String = _pick(TEMPERAMENT_BIOS.get(temperament, TEMPERAMENT_BIOS[&"happy"]), profile)
	var need: String = _pick(SERVICE_NEED.get(service, SERVICE_NEED[&"bath"]), profile)
	var city_text: String = String(CITY_FLAVOR.get(city, "do bairro"))
	return "%s %s %s — %s." % [breed, city_text, bio_temper, need]

static func queue_story(profile: Dictionary, service: String = "") -> String:
	var patience: int = int(profile.get("patience", 42))
	var tip: float = float(profile.get("base_tip", 1.0))
	var patience_text: String = "paciência curta" if patience < 32 else ("tranquilo" if patience > 46 else "paciência média")
	var pay_text: String = "paga bem" if tip >= 2.0 else ("paga +" if tip >= 1.4 else "pagamento normal")
	var need: String = ""
	if not service.is_empty():
		var svc: StringName = StringName(service)
		var arr: Array = SERVICE_NEED.get(svc, [])
		if not arr.is_empty():
			need = " • %s" % _pick(arr, profile)
	return "%s • %s%s" % [patience_text, pay_text, need]

static func affection_memory(pet_id: String, level: int) -> String:
	var memories: Dictionary = {
		1: "Primeiro carinho! %s ainda te cheira desconfiado.",
		5: "%s te trouxe uma bolinha! Laço de amizade nível 5.",
		10: "10 carinhos! %s dormiu na sua banheira ontem.",
		20: "%s te considera família! 20 carinhos, ele te espera na porta.",
		25: "25! %s te deu um presente — bandana improvisada com pelo.",
		50: "50 carinhos! %s é seu melhor amigo para sempre. História completa!",
	}
	var template: String = String(memories.get(level, ""))
	if template.is_empty():
		return ""
	var name: String = ContentDB.pet_name(pet_id)
	return template % name

static func result_thanks(profile: Dictionary, quality: StringName) -> String:
	var temperament: StringName = StringName(profile.get("temperament", "happy"))
	var name: String = String(profile.get("name", "Pet"))
	var thanks: Dictionary = {
		&"happy": "%s abana o rabo: 'Au au! Perfeito!'",
		&"calm": "%s fecha os olhos: 'Prrrr... perfeito.'",
		&"playful": "%s pula: 'De novo! De novo!'",
		&"anxious": "%s suspira aliviado: 'Ufa, consegui!'",
		&"fearful": "%s se aninha: 'Obrigado por ser gentil...'",
		&"irritated": "%s: 'Tá... até que ficou bom.'",
	}
	var template: String = String(thanks.get(temperament, "%s: 'Obrigado!'"))
	var text: String = template % name
	if quality == &"perfect":
		text += " ★ Perfeito!"
	return text

static func _pick(options: Array, profile: Dictionary) -> String:
	if options.is_empty():
		return ""
	var id: String = String(profile.get("id", "caramelo"))
	var idx: int = int(id.hash()) % options.size()
	return String(options[idx])
