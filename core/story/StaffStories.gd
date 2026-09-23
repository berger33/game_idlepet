class_name StaffStories
extends RefCounted
## Diálogos da equipe por tier — sem alterar JSON, gera vínculo com staff
## Usado em coleção equipe para storytelling profissional

const DIALOGUES: Dictionary = {
	"player": {
		1: "Você começou com um balde no quintal. O bairro ainda não te conhece.",
		10: "Nível 10! Você já sabe a diferença entre pelo embaraçado e pelo molhado.",
		30: "Nível 30! Banheira dupla — seu pet preferido agora atende junto. Rede de verdade.",
		60: "Nível 60! Metade do caminho para império. O bairro te chama de referência.",
		120: "Nível 120! De balde a império. O que vem agora é legado.",
	},
	"bia": {
		1: "Bia: 'Te ajudei a abrir o petshop — agora quero trabalhar aqui! Me contrata, sócio?'",
		8: "Bia entrou! Ela trouxe tesoura emprestada e rende sozinha enquanto você atende.",
		20: "Bia: 'Já atendi 20 clientes sozinha! Posso ensinar tosa?'",
	},
	"teo": {
		15: "Téo: 'Secar é dançar com o pet, não lutar. Deixa comigo o sopro.'",
		30: "Téo inventou a secagem com dança — secagem 10% mais rápida.",
	},
	"dra_luna": {
		12: "Dra. Luna: 'Pet limpo mas sem perfume é pet pela metade. Vamos perfumar?'",
		25: "Dra. Luna trouxe vacinas e perfume — gorjetas +15% quando ela está.",
	},
	"seu_ze": {
		20: "Seu Zé: 'Pet esperando é cliente perdido. Vamos acalmar a fila com petisco.'",
		40: "Seu Zé organizou a gestão — paciência +10% para todos.",
	},
	"maya": {
		35: "Maya, lendária: 'Calma na mão, perfeito vem. Olha só a faixa.'",
		60: "Maya alargou a faixa do perfeito só com olhar — janela +20%.",
	},
}

static func dialogue_for(staff_id: String, level: int) -> String:
	var staff_dialogs: Dictionary = DIALOGUES.get(staff_id, {})
	if staff_dialogs.is_empty():
		return ""
	var best_level: int = -1
	var best_text: String = ""
	for lvl: Variant in staff_dialogs.keys():
		var ilvl: int = int(lvl)
		if ilvl <= level and ilvl > best_level:
			best_level = ilvl
			best_text = String(staff_dialogs[lvl])
	return best_text

static func all_dialogues(staff_id: String) -> Array[String]:
	var result: Array[String] = []
	var staff_dialogs: Dictionary = DIALOGUES.get(staff_id, {})
	var levels: Array = staff_dialogs.keys()
	levels.sort()
	for lvl: Variant in levels:
		result.append("%s — %s" % [str(lvl), String(staff_dialogs[lvl])])
	return result
