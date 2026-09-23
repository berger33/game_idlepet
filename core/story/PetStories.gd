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

const PET_MEMORIES: Dictionary = {
	"caramelo": [
		"Primeiro carinho! %s ainda te cheira desconfiado, mas já abana o rabo.",
		"%s te trouxe uma bolinha do quintal! Vocês são amigos de verdade agora.",
		"%s dormiu na sua banheira e te considera família para sempre. 50 carinhos!",
	],
	"luna_shih_tzu": [
		"Luna chegou tímida, mas seu perfume acalmou ela no primeiro banho.",
		"Luna agora pede colo toda vez que te vê — 15 carinhos de confiança.",
		"Luna te deu um lacinho que ela mesma escolheu. Amizade eterna!",
	],
	"mingau_srd": [
		"Primeiro encontro! %s deitou tranquilo da vila, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Cheio de folhas do quintal e virou querido da vizinhança.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Gato SRD branco feliz!",
	],
	"thor_pinscher": [
		"Thor rosnou no primeiro encontro, mas seu carinho quebrou o gelo.",
		"Thor te protege na rua — 20 carinhos e ele late se alguém chega perto.",
		"Thor é seu guardião oficial do pet shop. 50 carinhos de lealdade!",
	],
	"mel_golden": [
		"Mel te encontrou no Dia 7 e nunca mais saiu do seu lado.",
		"Mel nada no quintal e te traz folhas como presente — 25 carinhos.",
		"Mel é a mascote lendária do seu império. História completa!",
	],
	"frajola": [
		"Primeiro encontro! %s pulou na banheira do subúrbio, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou querido da vizinhança.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Gato frajola feliz!",
	],
	"fred_poodle": [
		"Primeiro encontro! %s precisava de carinho do subúrbio, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Pelos embaraçados precisando de tosa e virou conhecido no bairro.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Poodle feliz!",
	],
	"amora_siames": [
		"Primeiro encontro! %s olhar de diva do subúrbio, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou conhecido no bairro.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Siamês feliz!",
	],
	"nina_yorkshire": [
		"Primeiro encontro! %s tremia um pouquinho do centro, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Pelos embaraçados precisando de tosa e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Yorkshire feliz!",
	],
	"tigrinho_tabby": [
		"Primeiro encontro! %s trouxe bolinha do centro, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Voltou da chuva todo sujo e virou conhecido no bairro.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Gato tigrado feliz!",
	],
	"bob_bulldog": [
		"Bob chegou pulando sem parar, quase derrubou a banheira.",
		"Bob agora senta e espera o banho — 20 carinhos de disciplina.",
		"Bob te considera seu humano favorito. 50 carinhos de energia infinita!",
	],
	"neve_angora": [
		"Primeiro encontro! %s deitou tranquilo do centro, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Angorá feliz!",
	],
	"sol_border": [
		"Primeiro encontro! %s pulou de alegria da metrópole, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Queria ficar elegante e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da metrópole conhecem!",
	],
	"cafe_bombay": [
		"Primeiro encontro! %s cheirava tudo curioso da metrópole, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Bombaim feliz!",
	],
	"jade_spitz": [
		"Primeiro encontro! %s precisava de carinho da metrópole, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da metrópole conhecem!",
	],
	"pitanga_abissinio": [
		"Primeiro encontro! %s correu pelo quintal da praia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Voltou da chuva todo sujo e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Abissínio feliz!",
	],
	"bento_beagle": [
		"Primeiro encontro! %s trouxe bolinha da praia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Cheio de folhas do quintal e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Beagle feliz!",
	],
	"azul_russian": [
		"Primeiro encontro! %s respirou fundo zen da praia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da praia conhecem!",
	],
	"paçoca_dachshund": [
		"Primeiro encontro! %s fuçava o salão da serra, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Cheio de folhas do quintal e virou conhecido no bairro.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Dachshund feliz!",
	],
	"lua_maine_coon": [
		"Primeiro encontro! %s pediu carinho gentil da serra, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da serra conhecem!",
	],
	"kiko_pug": [
		"Primeiro encontro! %s chegou abanando o rabo da serra, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Voltou da chuva todo sujo e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Pug feliz!",
	],
	"sushi_japanese": [
		"Primeiro encontro! %s trouxe bolinha da serra, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da serra conhecem!",
	],
	"cacau_labrador": [
		"Primeiro encontro! %s é um doce da Amazônia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Cheio de folhas do quintal e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da Amazônia conhecem!",
	],
	"onca_bengal": [
		"Primeiro encontro! %s late animado da Amazônia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da Amazônia conhecem!",
	],
	"tupa_mane_wolf": [
		"Primeiro encontro! %s chegou calmo observando da Amazônia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou lendário, mascote do império.",
		"%s dormiu na sua banheira e te considera família para sempre! 50 carinhos, lenda viva do seu império!",
	],
	"aurora_ragdoll": [
		"Primeiro encontro! %s pediu carinho gentil exótico, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Queria ficar elegante e virou lendário, mascote do império.",
		"%s dormiu na sua banheira e te considera família para sempre! 50 carinhos, lenda viva do seu império!",
	],
	"gaia_samoyed": [
		"Primeiro encontro! %s sorriu com os olhos exótico, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou lendário, mascote do império.",
		"%s dormiu na sua banheira e te considera família para sempre! 50 carinhos, lenda viva do seu império!",
	],
	"nox_sphynx": [
		"Primeiro encontro! %s explorou cada canto exótico, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Voltou da chuva todo sujo e virou lendário, mascote do império.",
		"%s dormiu na sua banheira e te considera família para sempre! 50 carinhos, lenda viva do seu império!",
	],
	"rio_savannah": [
		"Primeiro encontro! %s não parava quieto exótico, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Pelos embaraçados precisando de tosa e virou lendário, mascote do império.",
		"%s dormiu na sua banheira e te considera família para sempre! 50 carinhos, lenda viva do seu império!",
	],
	"estrela_khao": [
		"Primeiro encontro! %s entrou como modelo exótico, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou lendário, mascote do império.",
		"%s dormiu na sua banheira e te considera família para sempre! 50 carinhos, lenda viva do seu império!",
	],
	"pipoca_corgi": [
		"Primeiro encontro! %s queria brincar sem parar da vila, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou conhecido no bairro.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Welsh Corgi feliz!",
	],
	"zeca_schnauzer": [
		"Primeiro encontro! %s cheirava tudo curioso do subúrbio, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Queria ficar elegante e virou conhecido no bairro.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Schnauzer miniatura feliz!",
	],
	"belinha_maltes": [
		"Primeiro encontro! %s encostou a cabeça suave do subúrbio, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou conhecido no bairro.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Maltês feliz!",
	],
	"duke_husky": [
		"Primeiro encontro! %s late animado do centro, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Husky Siberiano feliz!",
	],
	"lola_boxer": [
		"Primeiro encontro! %s chegou abanando o rabo do centro, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou conhecido no bairro.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Boxer feliz!",
	],
	"nico_aussie": [
		"Primeiro encontro! %s correu pelo quintal da metrópole, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Queria ficar elegante e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Pastor Australiano feliz!",
	],
	"maya_akita": [
		"Primeiro encontro! %s chegou calmo observando da metrópole, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Cheio de folhas do quintal e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Akita Inu feliz!",
	],
	"otto_basset": [
		"Primeiro encontro! %s encostou a cabeça suave da praia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da praia conhecem!",
	],
	"kiara_doberman": [
		"Primeiro encontro! %s pose de capa da serra, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Queria ficar elegante e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da serra conhecem!",
	],
	"apolo_bernese": [
		"Primeiro encontro! %s pediu carinho gentil da Amazônia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Queria ficar elegante e virou lendário, mascote do império.",
		"%s dormiu na sua banheira e te considera família para sempre! 50 carinhos, lenda viva do seu império!",
	],
	"mimi_persa": [
		"Mimi te olhou de cima a baixo antes de aceitar o carinho.",
		"Mimi ronrona só para você agora — 15 carinhos de aprovação felina.",
		"Mimi trouxe um ratinho de brinquedo. Presente raro de gato!",
	],
	"yuki_scottish": [
		"Primeiro encontro! %s encostou a cabeça suave do subúrbio, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou conhecido no bairro.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Scottish Fold feliz!",
	],
	"olivia_calico": [
		"Primeiro encontro! %s queria brincar sem parar do subúrbio, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Voltou da chuva todo sujo e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Calico feliz!",
	],
	"simba_noruegues": [
		"Primeiro encontro! %s late animado do centro, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Pelos embaraçados precisando de tosa e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Norueguês da Floresta feliz!",
	],
	"lilo_munchkin": [
		"Primeiro encontro! %s explorou cada canto do centro, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Cheio de folhas do quintal e virou raro e especial.",
		"%s te considera melhor amigo! 50 carinhos, história completa de amizade e Munchkin feliz!",
	],
	"zara_oriental": [
		"Primeiro encontro! %s olhar de diva da metrópole, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Tosa atrasada, pelo nos olhos e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da metrópole conhecem!",
	],
	"cosmo_birman": [
		"Primeiro encontro! %s pediu carinho gentil da praia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Queria ficar elegante e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da praia conhecem!",
	],
	"iris_cornish": [
		"Primeiro encontro! %s não parava quieto da serra, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou épico, todos admiram.",
		"%s te trouxe um presente raro! 50 carinhos, amigo épico que todos no da serra conhecem!",
	],
	"odin_nebelung": [
		"Primeiro encontro! %s respirou fundo zen da Amazônia, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Queria ficar elegante e virou lendário, mascote do império.",
		"%s dormiu na sua banheira e te considera família para sempre! 50 carinhos, lenda viva do seu império!",
	],
	"cleo_egyptian": [
		"Primeiro encontro! %s pose de capa exótico, ainda desconfiado.",
		"%s já te espera na porta — 15 carinhos! Precisava de banho urgente, rolou na lama e virou lendário, mascote do império.",
		"%s dormiu na sua banheira e te considera família para sempre! 50 carinhos, lenda viva do seu império!",
	],
}


const GENERIC_MEMORIES_PT: Array[String] = [
	"Primeiro carinho! %s ainda te cheira desconfiado.",
	"%s já te espera na porta — 15 carinhos de amizade crescendo.",
	"%s te considera família! 50 carinhos, melhor amigo para sempre!",
]

const GENERIC_MEMORIES_EN: Array[String] = [
	"First pet! %s still sniffs you suspiciously.",
	"%s waits at the door now — 15 pets, friendship growing.",
	"%s considers you family! 50 pets, best friend forever!",
]

static func affection_memory(pet_id: String, level: int) -> String:
	if level <= 0: return ""
	var is_en: bool = _is_en()
	var mems: Array = PET_MEMORIES.get(pet_id, [])
	if mems.is_empty():
		mems = GENERIC_MEMORIES_EN if is_en else GENERIC_MEMORIES_PT
	var idx: int = 0
	if level >= 25: idx = 2
	elif level >= 10: idx = 1
	var template: String = String(mems[mini(idx, mems.size() - 1)])
	var name: String = ContentDB.pet_name(pet_id)
	return template % name

static func all_memories(pet_id: String) -> Array[String]:
	var is_en: bool = _is_en()
	var mems: Array = PET_MEMORIES.get(pet_id, [])
	if mems.is_empty():
		mems = GENERIC_MEMORIES_EN if is_en else GENERIC_MEMORIES_PT
	var name: String = ContentDB.pet_name(pet_id)
	var result: Array[String] = []
	for m in mems:
		result.append(String(m) % name)
	return result

static func diary_progress(pet_id: String, level: int) -> String:
	var total: int = 3
	var unlocked: int = 0
	if level >= 1: unlocked += 1
	if level >= 10: unlocked += 1
	if level >= 25: unlocked += 1
	return "%d/%d memórias" % [unlocked, total] if not _is_en() else "%d/%d memories" % [unlocked, total]

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
