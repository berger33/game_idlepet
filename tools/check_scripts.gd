extends SceneTree
## Verificação de compilação/análise de TODOS os scripts em contexto de
## projeto (autoloads registrados) — o mesmo analisador do editor, sem os
## falsos positivos do --check-only isolado (que não resolve autoloads).
## Execute: godot --headless --path . --script tools/check_scripts.gd -- <caminhos>
## Os caminhos dos scripts entram pela linha de usuário (após "--").


var failed: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	if paths.is_empty():
		push_error("check_scripts: passe os caminhos dos scripts após '--' na linha de comando")
		quit(1)
		return
	var checked: int = 0
	for path: String in paths:
		var clean: String = path.strip_edges()
		if clean.is_empty() or clean == "res://tools/check_scripts.gd":
			continue
		checked += 1
		var script: GDScript = load(clean) as GDScript
		if script == null or not script.can_instantiate():
			failed.append(clean)
	if failed.is_empty():
		print("check_scripts: %d scripts analisados, 0 falhas" % checked)
		quit(0)
	else:
		push_error("check_scripts FALHARAM (%d): %s" % [failed.size(), " ".join(failed)])
		quit(1)
