extends Node
## Localização runtime: parseia data/localization/*.csv em memória (sem
## depender de .import/TranslationServer para funcionar em qualquer build).
## A chave é o texto pt_BR; idiomas trocáveis em Ajustes.

const LANGS: Array[String] = ["pt_BR", "en_US", "es_ES"]

var lang: String = "pt_BR"
var tables: Dictionary = {}


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
	var saved: String = String(GameState.settings.get("language", ""))
	lang = saved if LANGS.has(saved) else "pt_BR"


func t(key: String) -> String:
	var current: Dictionary = tables.get(lang, {})
	if current.has(key):
		return String(current[key])
	var fallback: Dictionary = tables.get("pt_BR", {})
	return String(fallback.get(key, key))


func set_language(code: String) -> void:
	if not LANGS.has(code):
		return
	lang = code
	GameState.settings["language"] = code
	SaveManager.request_save()


func _load_csv(code: String) -> void:
	var path: String = "res://data/localization/%s.csv" % code
	if not FileAccess.file_exists(path):
		push_error("Localização ausente: " + path)
		return
	tables[code] = parse_csv(FileAccess.get_file_as_string(path))


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
