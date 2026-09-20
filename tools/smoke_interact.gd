extends SceneTree
## Interação headless: reproduz o fluxo do jogador — boot, seleção de cliente
## na fila e ciclo abrir/fechar do painel meta. Pega estados de UI morta que
## não geram SCRIPT ERROR (ex.: cartões desabilitados por is_open() falso-
## -positivo). Execute: godot --headless --script tools/smoke_interact.gd

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn")
	if packed == null:
		_fail("cena principal não carrega")
		_finish()
		return
	var main: Control = packed.instantiate()
	root.add_child(main)
	for i: int in 3:
		await process_frame

	# 1) Boot limpo: painel meta fechado e os três cartões da fila habilitados.
	if main.meta.is_open():
		_fail("meta.is_open() true no boot — cartões da fila ficam desabilitados")
	if main.meta.screen.panel.is_visible_in_tree():
		_fail("painel meta visível em árvore no boot")
	for slot: int in 3:
		if main.queue_cards[slot].disabled:
			_fail("cartão %d desabilitado no boot" % slot)
		if not main._can_select(slot):
			_fail("_can_select(%d) false no boot" % slot)

	# 2) Ciclo do painel meta: abre, renderiza de verdade e bloqueia seleção.
	main.meta.open(&"missions")
	for i: int in 2:
		await process_frame
	if not main.meta.is_open():
		_fail("meta.open não abriu (is_open false)")
	elif not main.meta.screen.panel.is_visible_in_tree():
		_fail("meta aberto mas o painel não está visível em árvore (raiz escondida)")
	if main._can_select(0):
		_fail("_can_select permitido com o painel aberto")
	main.meta.close()
	await process_frame
	if main.meta.is_open():
		_fail("meta.close não fechou (is_open true)")
	if not main._can_select(0):
		_fail("_can_select(0) false após fechar o painel")

	# 3) Seleção de cliente: o passo que travava o jogador.
	main._on_queue_pressed(0)
	await process_frame
	if main.selected_slot != 0:
		_fail("seleção não registrou (selected_slot=%d)" % main.selected_slot)
	if main.world.room_empty:
		_fail("pet não chegou à estação (room_empty)")
	if String(main.current_pet_id).is_empty():
		_fail("cliente selecionado sem pet")
	if String(main.current_pet_name).is_empty():
		_fail("cliente selecionado sem nome")
	_finish()


func _fail(message: String) -> void:
	failures += 1
	push_error("SMOKE_INTERACT FAIL: " + message)


func _finish() -> void:
	if failures == 0:
		print("smoke_interact: PASS (fila selecionável, meta abre/fecha)")
	else:
		push_error("smoke_interact: %d falha(s)" % failures)
	quit(failures)
