extends Node
## Localização runtime: parseia data/localization/*.csv em memória (sem
## depender do TranslationServer). Em build exportado o CSV some do pacote — o
## importador de tradução deixa só o .translation — e a busca passa a ser feita
## nesse recurso. Idiomas trocáveis em Ajustes.

const LANGS: Array[String] = ["pt_BR", "en_US", "es_ES"]

signal language_changed(code: String)

var lang: String = "pt_BR"
var tables: Dictionary = {}
## Build exportado não tem o CSV bruto: guarda o Translation importado por
## idioma e consulta com get_message() (OptimizedTranslation não expõe a
## lista de chaves, só a busca direta).
var translations: Dictionary = {}


func _ready() -> void:
	for code: String in LANGS:
		_load_csv(code)
	_sync_language()
	# O save é carregado DEPOIS deste autoload (ordem do project.godot) e o
	# GameState avisa via settings_changed — sem este gancho o idioma salvo só
	# valia quando o jogador abria Ajustes (auditoria universal v2, B10).
	EventBus.settings_changed.connect(_sync_language)


func _sync_language() -> void:
	# Nunca deixa o idioma num valor inválido vindo de save antigo/editado.
	var saved: String = String(GameState.settings.get("language", "pt_BR"))
	_apply_language(saved if LANGS.has(saved) else "pt_BR")


func _apply_language(code: String) -> void:
	if lang == code:
		return
	lang = code
	language_changed.emit(code)


func t(key: String) -> String:
	var text: String = _lookup(lang, key)
	if not text.is_empty():
		return text
	if lang != "pt_BR":
		text = _lookup("pt_BR", key)
		if not text.is_empty():
			return text
	return key


func _lookup(code: String, key: String) -> String:
	var table: Dictionary = tables.get(code, {})
	if table.has(key):
		return String(table[key])
	var translation: Translation = translations.get(code)
	if translation != null:
		return translation.get_message(key)
	return ""


func set_language(code: String) -> void:
	if not LANGS.has(code):
		return
	GameState.settings["language"] = code
	_apply_language(code)
	SaveManager.request_save()


func _load_csv(code: String) -> void:
	var path: String = "res://data/localization/%s.csv" % code
	if FileAccess.file_exists(path):
		tables[code] = parse_csv(FileAccess.get_file_as_string(path))
		return
	# Em build exportado o CSV não sobrevive: o importador de tradução substitui
	# a fonte pelo .translation correspondente (o .pck traz só *.translation e
	# *.csv.import). Sem este caminho a UI inteira caía para chaves cruas e os
	# textos com %d/%s geravam "String formatting error" no runtime.
	var tres_path: String = "res://data/localization/%s.%s.translation" % [code, code]
	if ResourceLoader.exists(tres_path):
		translations[code] = load(tres_path)
		return
	push_error("Localização ausente: " + path)


## Parser CSV mínimo (RFC 4180) — campos entre aspas podem conter VÍRGULA,
## quebra de linha e aspas escapadas (""). O split ingênuo por vírgula
## truncava qualquer valor com vírgula (bug B5 das auditorias v1/v2) e agora
## é testado em tests/DomainTests.gd.
static func parse_csv(text: String) -> Dictionary:
	var parsed: Dictionary = {}
	var fields: Array[String] = []
	var current: String = ""
	var in_quotes: bool = false
	var index: int = 0
	while index < text.length():
		var ch: String = text[index]
		if in_quotes:
			if ch == "\"":
				if index + 1 < text.length() and text[index + 1] == "\"":
					current += "\""
					index += 1
				else:
					in_quotes = false
			else:
				current += ch
		elif ch == "\"":
			in_quotes = true
		elif ch == ",":
			fields.append(current)
			current = ""
		elif ch == "\n":
			fields.append(current)
			current = ""
			_commit_row(parsed, fields)
			fields = []
		elif ch != "\r":
			current += ch
		index += 1
	fields.append(current)
	_commit_row(parsed, fields)
	return parsed


static func _commit_row(parsed: Dictionary, fields: Array[String]) -> void:
	if fields.size() < 2:
		return
	var key: String = fields[0].strip_edges()
	if key.is_empty() or key == "key":
		return
	# CSV malformado (vírgula sem aspas): preserva o texto inteiro em vez de
	# truncar silenciosamente.
	var value: String = fields[1] if fields.size() == 2 else ",".join(fields.slice(1))
	parsed[key] = value.strip_edges().replace("\\n", "\n")
