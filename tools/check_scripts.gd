extends SceneTree
## Verificação de compilação/análise de TODOS os scripts em contexto de
## projeto (autoloads registrados) — o mesmo analisador do editor, sem os
## falsos positivos do --check-only isolado (que não resolve autoloads).
## Execute: godot --headless --path . --script tools/check_scripts.gd
## A lista de scripts vem de res://script_list.txt (um caminho por linha).


var failed: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not FileAccess.file_exists("res://script_list.txt"):
		push_error("check_scripts: res://script_list.txt ausente")
		quit(1)
		return
	var file: FileAccess = FileAccess.open("res://script_list.txt", FileAccess.READ)
	var checked: int = 0
	while not file.eof_reached():
		var path: String = file.get_line().strip_edges()
		if path.is_empty() or path == "res://tools/check_scripts.gd":
			continue
		checked += 1
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed.append(path)
	if failed.is_empty():
		print("check_scripts: %d scripts analisados, 0 falhas" % checked)
		quit(0)
	else:
		push_error("check_scripts FALHARAM (%d): %s" % [failed.size(), " ".join(failed)])
		quit(1)
