extends SceneTree
## Interação headless: reproduz o fluxo do jogador — boot, seleção de cliente
## na fila e ciclo abrir/fechar do painel meta. Pega estados de UI morta que
## não geram SCRIPT ERROR (ex.: cartões desabilitados por is_open() falso-
## -positivo). Execute: godot --headless --script tools/smoke_interact.gd

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("INTERACT: boot")
	# extends SceneTree: self É a tree — get_tree() não existe aqui.
	var watchdog: SceneTreeTimer = create_timer(120.0)
	watchdog.timeout.connect(
		func() -> void:
			push_error("smoke_interact TIMEOUT: coroutine morreu sem _finish (erro de runtime acima?)")
			quit(96)
	)
	var packed: PackedScene = load("res://scenes/main/Main.tscn")
	if packed == null:
		_fail("cena principal não carrega")
		_finish()
		return
	var main: Control = packed.instantiate()
	root.add_child(main)
	for i: int in 3:
		await process_frame

	print("INTERACT: step1 boot limpo")
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

	print("INTERACT: step2 ciclo meta")
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

	print("INTERACT: step3 seleção de cliente")
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

	print("INTERACT: step4 contrato espacial")
	# 4) Contrato espacial: pés ancorados + prateleiras uniformes (HUD V2).
	if abs(main.world.pet_position.x - 540.0) > 0.5 or abs(main.world.pet_position.y - 1160.0) > 0.5:
		_fail("pet_position != (540,1160): %s" % [main.world.pet_position])
	var shelves: Array[float] = main.world.service_shelf_levels
	if shelves.size() != 5:
		_fail("service_shelf_levels tamanho %d != 5" % shelves.size())
	for i: int in 5:
		if abs(shelves[i] - [679.0, 801.0, 923.0, 1045.0, 1167.0][i]) > 0.5:
			_fail("shelf_y[%d]=%f fora do contrato" % [i, shelves[i]])
	var tool_names: Array[String] = ["soap", "clipper", "dryer", "perfume", "bow"]
	for i: int in 5:
		var tool_pos: Vector2 = main.world._tool_position(StringName(tool_names[i]))
		if abs(tool_pos.y - shelves[i]) > 0.5 or abs(tool_pos.x - 910.0) > 0.5:
			_fail("utensílio %d fora da prancha: %s" % [i, tool_pos])

	print("INTERACT: step5 painel de melhorias")
	# 5) Botão redondo de melhorias abre o painel de melhorias.
	if not is_instance_valid(main.upgrades_button):
		_fail("upgrades_button não existe")
	else:
		# Sem referência estática a classes que usam autoloads: no contexto --script
		# elas compilam antes do registro dos singletons e envenenam o Main.
		main.meta.open(&"upgrades", main.upgrades_button)
		for i: int in 2:
			await process_frame
		if not main.meta.is_open():
			_fail("painel de melhorias não abriu")
		elif not main.meta.screen.panel.is_visible_in_tree():
			_fail("painel de melhorias aberto mas invisível em árvore")
		main.meta.close()
		await process_frame
		if main.meta.is_open():
			_fail("painel de melhorias não fechou")
	print("INTERACT: step6 gestos por serviço (BathService v2)")
	# 6) Gestos com mecânica própria (Onda 1): traçado direcionado, zona que
	# deriva, borrifadas no ritmo e encaixe de precisão — simulados por
	# ponteiro direto no BathService, sem autoload (determinístico).
	var bath_script: GDScript = load("res://core/gameplay/BathService.gd")
	var gesture_bath: Object = bath_script.new()

	# Tosa (stroke): movimento no eixo certo pontua; no eixo errado, não.
	gesture_bath.configure(10.0, 0.82, 0.96, 600.0)
	gesture_bath.configure_gesture(&"vertical", &"stroke", 70.0, 0.0)
	gesture_bath.configure_strokes([&"vertical", &"horizontal", &"vertical"], 520.0)
	gesture_bath.start_service()
	gesture_bath.rub(Vector2(500, 900))
	for i: int in 12:
		gesture_bath.rub(Vector2(500, 900 + (i + 1) * 60.0))
	if gesture_bath.progress <= 0.0:
		_fail("stroke: movimento vertical não pontuou (progress=%f)" % gesture_bath.progress)
	var before_cross: float = gesture_bath.progress
	gesture_bath.rub(Vector2(820, 1620))
	if gesture_bath.progress != before_cross:
		_fail("stroke: movimento no eixo errado pontuou")
	if gesture_bath.stroke_index != 1:
		_fail("stroke: passo 1 não concluído após cota no eixo (index=%d)" % gesture_bath.stroke_index)

	# Secagem (zone): dentro do círculo enche; fora, drena.
	gesture_bath = bath_script.new()
	gesture_bath.configure(10.0, 0.82, 0.96, 600.0)
	gesture_bath.configure_gesture(&"any", &"zone", 70.0, 0.30)
	var zone_home: Vector2 = Vector2(540, 1000.0)
	gesture_bath.configure_zone(zone_home, 112.0, 0.5)
	gesture_bath.start_service()
	gesture_bath.rub(zone_home)
	var zone_progress: float = 0.0
	for i: int in 30:
		gesture_bath.tick(1.0 / 30.0)
		gesture_bath.rub(zone_home + Vector2(0.0, 60.0))
		zone_progress = gesture_bath.progress
	if zone_progress <= 0.0:
		_fail("zone: dentro do círculo não encheu (progress=%f)" % zone_progress)
	gesture_bath.rub(zone_home + Vector2(800.0, 0.0))
	gesture_bath.tick(1.0)
	if gesture_bath.zone_inside:
		_fail("zone: fora do círculo marcado como dentro")
	var outside_progress: float = gesture_bath.progress
	gesture_bath.rub(zone_home + Vector2(800.0, 0.0))
	gesture_bath.tick(1.0)
	if gesture_bath.progress >= outside_progress and outside_progress > 0.0:
		_fail("zone: fora do círculo não drenou (progress=%f)" % gesture_bath.progress)

	# Perfume (pulse): 3 borrifadas na janela acesa = perfect; apagada = miss.
	gesture_bath = bath_script.new()
	gesture_bath.configure(10.0, 0.95, 1.0, 600.0)
	gesture_bath.configure_gesture(&"any", &"pulse", 90.0, 0.0)
	gesture_bath.configure_pulses(3, 1.35, 0.45)
	gesture_bath.start_service()
	for i: int in 3:
		gesture_bath.tick(0.05)
		if gesture_bath.pulse_contact() != &"hit":
			_fail("pulse: borrifada na janela acesa não acertou")
	if gesture_bath.progress < 0.99:
		_fail("pulse: 3 acertos não fecharam o progresso (progress=%f)" % gesture_bath.progress)
	var pulse_quality: StringName = gesture_bath.finish()
	if pulse_quality != &"perfect":
		_fail("pulse: 3 acertos deram %s, esperado perfect" % pulse_quality)
	gesture_bath = bath_script.new()
	gesture_bath.configure(10.0, 0.95, 1.0, 600.0)
	gesture_bath.configure_gesture(&"any", &"pulse", 90.0, 0.0)
	gesture_bath.configure_pulses(3, 1.35, 0.45)
	gesture_bath.start_service()
	gesture_bath.tick(0.9)
	if gesture_bath.pulse_contact() != &"miss":
		_fail("pulse: borrifada fora da janela não registrou miss")
	if gesture_bath.progress > 0.0:
		_fail("pulse: miss não deveria pontuar (progress=%f)" % gesture_bath.progress)

	# Laço (drop): perto da marca enche; longe, não.
	gesture_bath = bath_script.new()
	gesture_bath.configure(10.0, 0.82, 0.96, 600.0)
	gesture_bath.configure_gesture(&"any", &"drop", 90.0, 0.0)
	var drop_target: Vector2 = Vector2(540, 920.0)
	gesture_bath.configure_drop(drop_target, 112.0, 0.5)
	gesture_bath.start_service()
	gesture_bath.rub(drop_target + Vector2(20.0, 10.0))
	var drop_progress: float = 0.0
	for i: int in 30:
		gesture_bath.tick(1.0 / 30.0)
		drop_progress = gesture_bath.progress
	if drop_progress <= 0.0:
		_fail("drop: perto da marca não encheu (progress=%f)" % drop_progress)
	gesture_bath.rub(drop_target + Vector2(600.0, 0.0))
	gesture_bath.tick(1.0)
	if gesture_bath.progress > drop_progress:
		_fail("drop: longe da marca o progresso subiu")
	print("INTERACT: fim, failures=%d" % failures)
	_finish()


func _fail(message: String) -> void:
	failures += 1
	push_error("SMOKE_INTERACT FAIL: " + message)


func _finish() -> void:
	# quit() SEMPRE: sem ele o SceneTree headless roda para sempre e o CI trava
	# justamente quando todos os checks passam (failures == 0).
	if failures == 0:
		print("smoke_interact: PASS (fila selecionável, meta abre/fecha)")
	else:
		push_error("smoke_interact: %d falha(s)" % failures)
	quit(failures)
