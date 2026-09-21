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

const TEMPERAMENT_BIOS_EN: Dictionary = {
	&"happy": ["loves cuddles", "wags tail nonstop", "came running"],
	&"calm": ["watches calmly", "breathes deep", "so zen"],
	&"playful": ["brought a ball", "wants to play", "jumped in the tub"],
	&"active": ["can't stay still", "full of energy", "barks excitedly"],
	&"anxious": ["feels nervous", "needs affection", "trembles a bit"],
	&"fearful": ["hides behind owner", "wide eyes", "needs calm"],
	&"irritated": ["growled on street", "in a bad mood", "owner asks patience"],
	&"curious": ["sniffs everything", "explored the yard", "noses around"],
	&"gentle": ["leans head", "such a sweetie", "asks soft petting"],
	&"elegant": ["walks like model", "cover pose", "diva stare"],
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

const CITY_FLAVOR_EN: Dictionary = {
	"vila_pacata": "from the village",
	"suburbio": "from suburb",
	"centro": "from downtown",
	"metropole": "from metropolis",
	"litoral": "from beach",
	"serra": "from mountains",
	"capital": "from capital",
}

const SERVICE_NEED: Dictionary = {
	&"bath": ["rolou na lama", "cheio de folhas", "precisa de banho urgente"],
	&"groom": ["pelos embaraçados", "tosa atrasada", "pelo nos olhos"],
	&"dry": ["voltou da chuva", "molhado da praia", "pingando"],
	&"perfume": ["vai para festa", "encontro marcado", "quer cheirar bem"],
	&"style": ["aniversário hoje", "foto para Instagram", "quer lacinho novo"],
}

const SERVICE_NEED_EN: Dictionary = {
	&"bath": ["rolled in mud", "full of leaves", "needs urgent bath"],
	&"groom": ["tangled fur", "overdue grooming", "hair in eyes"],
	&"dry": ["came from rain", "wet from beach", "dripping"],
	&"perfume": ["going to party", "has a date", "wants to smell nice"],
	&"style": ["birthday today", "Instagram photo", "wants new bow"],
}

static func _is_en() -> bool:
	return Loc.lang != "pt_BR"

static func bio(profile: Dictionary) -> String:
	var temperament: StringName = StringName(profile.get("temperament", "happy"))
	var service: StringName = StringName(profile.get("preferred_service", "bath"))
	var city: String = String(profile.get("city", "vila_pacata"))
	var breed: String = String(profile.get("breed", "pet"))
	var bios: Dictionary = TEMPERAMENT_BIOS_EN if _is_en() else TEMPERAMENT_BIOS
	var needs: Dictionary = SERVICE_NEED_EN if _is_en() else SERVICE_NEED
	var cities: Dictionary = CITY_FLAVOR_EN if _is_en() else CITY_FLAVOR
	var bio_temper: String = _pick(bios.get(temperament, bios[&"happy"]), profile)
	var need: String = _pick(needs.get(service, needs[&"bath"]), profile)
	var city_text: String = String(cities.get(city, "do bairro" if not _is_en() else "from neighborhood"))
	return "%s %s %s — %s." % [breed, city_text, bio_temper, need]

static func queue_story(profile: Dictionary, service: String = "") -> String:
	var patience: int = int(profile.get("patience", 42))
	var tip: float = float(profile.get("base_tip", 1.0))
	var en: bool = _is_en()
	var patience_text: String = ("short patience" if patience < 32 else ("calm" if patience > 46 else "medium patience")) if en else ("paciência curta" if patience < 32 else ("tranquilo" if patience > 46 else "paciência média"))
	var pay_text: String = ("pays well" if tip >= 2.0 else ("pays +" if tip >= 1.4 else "normal pay")) if en else ("paga bem" if tip >= 2.0 else ("paga +" if tip >= 1.4 else "pagamento normal"))
	var need: String = ""
	if not service.is_empty():
		var svc: StringName = StringName(service)
		var dict: Dictionary = SERVICE_NEED_EN if en else SERVICE_NEED
		var arr: Array = dict.get(svc, [])
		if not arr.is_empty():
			need = " • %s" % _pick(arr, profile)
	return "%s • %s%s" % [patience_text, pay_text, need]

static func affection_memory(pet_id: String, level: int) -> String:
	var memories_pt: Dictionary = {
		1: "Primeiro carinho! %s ainda te cheira desconfiado.",
		5: "%s te trouxe uma bolinha! Laço de amizade nível 5.",
		10: "10 carinhos! %s dormiu na sua banheira ontem.",
		20: "%s te considera família! 20 carinhos, ele te espera na porta.",
		25: "25! %s te deu um presente — bandana improvisada com pelo.",
		50: "50 carinhos! %s é seu melhor amigo para sempre. História completa!",
	}
	var memories_en: Dictionary = {
		1: "First pet! %s still sniffs you suspiciously.",
		5: "%s brought a ball! Friendship level 5.",
		10: "10 pets! %s slept in your tub yesterday.",
		20: "%s considers you family! 20 pets, waits at the door.",
		25: "25! %s gave a gift — improvised bandana.",
		50: "50 pets! %s is your best friend forever. Full story!",
	}
	var dict: Dictionary = memories_en if _is_en() else memories_pt
	var template: String = String(dict.get(level, ""))
	if template.is_empty():
		return ""
	var name: String = ContentDB.pet_name(pet_id)
	return template % name

static func result_thanks(profile: Dictionary, quality: StringName) -> String:
	var temperament: StringName = StringName(profile.get("temperament", "happy"))
	var name: String = String(profile.get("name", "Pet"))
	var thanks_pt: Dictionary = {
		&"happy": "%s abana o rabo: 'Au au! Perfeito!'",
		&"calm": "%s fecha os olhos: 'Prrrr... perfeito.'",
		&"playful": "%s pula: 'De novo! De novo!'",
		&"anxious": "%s suspira aliviado: 'Ufa, consegui!'",
		&"fearful": "%s se aninha: 'Obrigado por ser gentil...'",
		&"irritated": "%s: 'Tá... até que ficou bom.'",
	}
	var thanks_en: Dictionary = {
		&"happy": "%s wags tail: 'Woof! Perfect!'",
		&"calm": "%s closes eyes: 'Purrr... perfect.'",
		&"playful": "%s jumps: 'Again! Again!'",
		&"anxious": "%s sighs relieved: 'Phew!'",
		&"fearful": "%s cuddles: 'Thanks for being gentle...'",
		&"irritated": "%s: 'Ok... not bad.'",
	}
	var dict: Dictionary = thanks_en if _is_en() else thanks_pt
	var template: String = String(dict.get(temperament, "%s: 'Obrigado!'"))
	var text: String = template % name
	if quality == &"perfect":
		text += " ★ %s!" % Loc.t("PERFECT")
	return text

static func _pick(options: Array, profile: Dictionary) -> String:
	if options.is_empty():
		return ""
	var id: String = String(profile.get("id", "caramelo"))
	var idx: int = int(id.hash()) % options.size()
	return String(options[idx])
