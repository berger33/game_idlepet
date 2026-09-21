class_name ChapterStories
extends RefCounted
## Narrativa dos capítulos (quintal → império) com personagem e conflito,
## sem alterar JSON. Usado em mapa e revelação de capítulo para arco de 3 atos.

const STORIES: Dictionary = {
	1: {"title": "Quintal Humilde", "char": "Você", "text": "Tudo começou com um balde, um sabonete e o Caramelo sujo de lama. O bairro ainda não te conhece, mas os latidos já se espalham.", "act": "Ato 1 — Sobrevivência"},
	2: {"title": "Pet Shop de Bairro", "char": "Bia", "text": "Bia chegou com tesoura emprestada: 'Deixa a tosa comigo! Você cuida do banho.' A fila dobrou.", "act": "Ato 1 — Sobrevivência"},
	3: {"title": "Clínica Pequena", "char": "Dra. Luna", "text": "Dra. Luna trouxe cheirinho de perfume e vacinas: 'Pet limpo, mas cheiroso e saudável fica.' Clientes começaram a pedir spa.", "act": "Ato 2 — Equipe"},
	4: {"title": "Clínica Moderna", "char": "Téo", "text": "Téo, tosador rápido, inventou a secagem com dança: 'Secar é acompanhar o pet, não lutar com ele.'", "act": "Ato 2 — Equipe"},
	5: {"title": "Centro Veterinário", "char": "Seu Zé", "text": "Seu Zé, da gestão, disse: 'Pet esperando é cliente perdido. Vamos acalmar a fila com petisco.'", "act": "Ato 2 — Equipe"},
	6: {"title": "Hospital Animal", "char": "Maya", "text": "Maya, lendária, alargou a faixa do perfeito só com olhar: 'Calma na mão, perfeito vem.'", "act": "Ato 2 — Equipe"},
	7: {"title": "Rede Regional", "char": "Você", "text": "Duas banheiras lado a lado. Seu pet preferido agora atende junto — +40% sem esforço extra. O bairro virou rede.", "act": "Ato 3 — Legado"},
	8: {"title": "Rede Nacional", "char": "Rede", "text": "Pedidos de franquia chegam por carta. Cada atendimento vira token de pesquisa que sobrevive ao recomeço.", "act": "Ato 3 — Legado"},
	9: {"title": "Instituto de Pesquisa", "char": "Instituto", "text": "Água purificada, fórmula suave, clínica móvel — pesquisa que fica para sempre, mesmo se recomeçar.", "act": "Ato 3 — Legado"},
	10: {"title": "Império Pet Brasil", "char": "Império", "text": "De balde a império. 50 focinhos, 6 humanos, 120 níveis. O bairro te chama de lenda. O que vem depois é legado.", "act": "Ato 3 — Legado"},
}

static func intro(tier: int) -> Dictionary:
	return STORIES.get(tier, {"title": "Petshop", "char": "Você", "text": "O bairro te espera.", "act": ""})

static func act_for_level(level: int) -> String:
	var tier: int = ContentDB.establishment_for_level(level)
	var story: Dictionary = intro(tier)
	return String(story.get("act", ""))

static func narrative_for_reveal(tier: int) -> String:
	var s: Dictionary = intro(tier)
	return "%s\n%s: \"%s\"" % [String(s.get("act", "")), String(s.get("char", "")), String(s.get("text", ""))]
