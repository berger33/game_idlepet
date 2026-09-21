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
	lang = String(GameState.settings.get("language", "pt_BR"))
	if not LANGS.has(lang):
		lang = "pt_BR"


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
	var parsed: Dictionary = {}
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for line: String in lines:
		line = line.strip_edges()
		if line.is_empty() or line.begins_with("key,"):
			continue
		var separator: int = line.find(",")
		if separator <= 0:
			continue
		var key: String = line.substr(0, separator)
		var value: String = line.substr(separator + 1).strip_edges()
		if value.begins_with("\"") and value.ends_with("\"") and value.length() >= 2:
			value = value.substr(1, value.length() - 2).replace("\"\"", "\"")
		value = value.replace("\\n", "\n")
		parsed[key] = value
	tables[code] = parsed
