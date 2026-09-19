extends Control
## Playable Core: chegada → servir → esfregar → timing → moedas/review/save.

const BathServiceScript: Script = preload("res://core/gameplay/BathService.gd")
const PetShopCanvasScript: Script = preload("res://core/gameplay/PetShopCanvas.gd")
const MENU_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_perfume.png")
const NAV_ICONS: Dictionary = {
	&"missions": preload("res://art/ui/icons/missions.png"),
	&"collection": preload("res://art/ui/icons/collection.png"),
	&"staff": preload("res://art/ui/icons/staff.png"),
	&"shop": preload("res://art/ui/icons/shop.png"),
	&"map": preload("res://art/ui/icons/map.png"),
	&"settings": preload("res://art/ui/icons/settings.png"),
}
const PINK: Color = Color("ff8fb1")
const BLUE: Color = Color("4fc3f7")
const GREEN: Color = Color("7ed957")
const CREAM: Color = Color("fff3e0")
const CHARCOAL: Color = Color("263238")
const SERVICE_TOOLS: Dictionary = {
	&"bath": &"soap",
	&"groom": &"clipper",
	&"dry": &"dryer",
	&"perfume": &"perfume",
	&"style": &"bow"
}
const SERVICE_UNLOCK_LEVELS: Dictionary = {
	&"bath": 1, &"groom": 3, &"dry": 5, &"perfume": 7, &"style": 10
}
const SERVICE_LABELS: Dictionary = {
	&"bath": "ensaboar",
	&"groom": "tosar",
	&"dry": "secar",
	&"perfume": "perfumar",
	&"style": "colocar lacinho"
}
## Gestos distintos por serviço: eixo da esfregada, modo de preenchimento,
## teto de distância por evento e taxa de preenchimento por tempo (hold).
const GESTURES: Dictionary = {
	&"bath": {"axis": &"any", "mode": &"rub", "cap": 90.0, "rate": 0.0},
	&"groom": {"axis": &"vertical", "mode": &"rub", "cap": 70.0, "rate": 0.0},
	&"dry": {"axis": &"horizontal", "mode": &"rub", "cap": 70.0, "rate": 0.0},
	&"perfume": {"axis": &"any", "mode": &"hold", "cap": 90.0, "rate": 0.22},
	&"style": {"axis": &"any", "mode": &"rub", "cap": 20.0, "rate": 0.0},
}
const GESTURE_HINTS: Dictionary = {
	&"bath": "HINT_BATH",
	&"groom": "HINT_GROOM",
	&"dry": "HINT_DRY",
	&"perfume": "HINT_PERFUME",
	&"style": "HINT_STYLE",
}
const TutorialOverlayScript: Script = preload("res://scenes/main/TutorialOverlay.gd")

var bath: BathService
var world: PetShopCanvas
var coin_label: Label
var combo_label: Label
var review_label: Label
var instruction_label: Label
var primary_button: Button
var share_button: Button
var upgrade_button: Button
var tool_upgrade_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var dragging: bool = false
var bubble_sound_gate: float = 0.0
var toast_layer: Control
var current_service: StringName = &"bath"
var current_pet_id: String = "caramelo"
var current_pet_name: String = "Caramelo"
var pet_touch_gate: float = 0.0
var meta: MetaPanel
var dragged_tool: StringName = &""
var wrong_tool_gate: float = 0.0
## Fila de clientes (até 3): o jogador escolhe quem atender — decisão real.
var queue: Array[Dictionary] = [{}, {}, {}]
var selected_slot: int = -1
var refill_timers: Array[float] = [0.0, 0.0, 0.0]
var queue_row: HBoxContainer
var queue_cards: Array[Button] = []
var queue_name_labels: Array[Label] = []
var queue_service_labels: Array[Label] = []
var queue_bars: Array[ColorRect] = []
var current_vip: bool = false
var last_tip_percent: int = 0
var tutorial_overlay: Control
var tutorial_skip_button: Button
var tutorial_step: int = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bath = BathServiceScript.new()
	_configure_current_service()
	_build_interface()
	world.clear_room()
	for slot: int in 3:
		queue[slot] = _make_client()
	_update_queue_ui()
	_connect_events()
	_refresh_economy()
	_show_pending_offline_reward()
	_show_comeback()
	NotificationManager.schedule_return_reminders(GameState.last_seen_unix)
	if GameState.tutorial_complete:
		var deep_section: StringName = NotificationManager.deep_link_section()
		if deep_section != &"":
			meta.open(deep_section)
	_setup_tutorial()
	Analytics.track(&"first_open" if GameState.services_completed == 0 else &"session_resume")


func _process(delta: float) -> void:
	bubble_sound_gate = maxf(0.0, bubble_sound_gate - delta)
	pet_touch_gate = maxf(0.0, pet_touch_gate - delta)
	wrong_tool_gate = maxf(0.0, wrong_tool_gate - delta)
	if bath.state == BathService.State.ACTIVE:
		if bath.tick(delta):
			_fail(&"timeout")
			return
		# Aro de dosagem (progresso cru) + barra de paciência no topo da cena.
		world.progress = bath.progress
		world.service_time_ratio = (
			bath.time_left / bath.duration_seconds if bath.duration_seconds > 0.0 else 0.0
		)
	_process_queue(delta)


func _input(event: InputEvent) -> void:
	if meta.is_open() or (is_instance_valid(result_panel) and result_panel.visible):
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_begin_pointer(touch.position)
		else:
			_end_pointer()
	elif event is InputEventScreenDrag:
		_move_pointer((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_begin_pointer(mouse_button.position)
			else:
				_end_pointer()
	elif event is InputEventMouseMotion:
		_move_pointer((event as InputEventMouseMotion).position)


func _begin_pointer(point: Vector2) -> void:
	dragged_tool = world.tool_at(point)
	if not dragged_tool.is_empty():
		dragging = true
		world.grab_tool(dragged_tool, point)
		AudioManager.play(&"tool_pickup")
		HapticsManager.light()
	elif bath.state == BathService.State.WAITING and _pet_hit(point):
		_react_to_pet_touch()


func _move_pointer(point: Vector2) -> void:
	if not dragging or dragged_tool.is_empty():
		return
	world.move_tool(point)
	if not _pet_hit(point):
		world.set_tool_contact(false)
		bath.release_pointer()
		return
	var required_tool: StringName = StringName(SERVICE_TOOLS[current_service])
	if dragged_tool != required_tool:
		world.set_tool_contact(false)
		if wrong_tool_gate <= 0.0:
			wrong_tool_gate = 0.8
			_show_toast("Use %s neste pedido" % _tool_display_name(required_tool), Color("ffd54f"))
			AudioManager.play(&"error_soft")
		return
	world.set_tool_contact(true)
	if bath.state == BathService.State.WAITING:
		_start_bath()
	if bath.state == BathService.State.ACTIVE:
		_rub(point)


func _end_pointer() -> void:
	# Soltar a ferramenta com o serviço em andamento entrega o resultado:
	# o jogador dosa a espuma e solta dentro da faixa verde (sem auto-complete).
	var finalize_now: bool = (
		bath.state == BathService.State.ACTIVE and bath.progress >= BathService.GOOD_FLOOR
	)
	dragging = false
	dragged_tool = &""
	bath.release_pointer()
	world.release_tool()
	if finalize_now:
		_finish_bath()


func _pet_hit(point: Vector2) -> bool:
	return point.distance_to(world.pet_position) < 245.0


func _react_to_pet_touch() -> void:
	if pet_touch_gate > 0.0:
		return
	pet_touch_gate = 0.35
	var message: String = world.react_to_touch()
	var affection: int = GameState.register_pet_interaction(current_pet_id)
	AudioManager.play(&"pet_happy")
	HapticsManager.light()
	_show_toast("%s  •  carinho %d/50" % [message, affection], PINK)
	if GameState.services_completed == 0 and affection >= 3:
		instruction_label.text = "Caramelo está pronto! Arraste o sabonete até ele."
	Analytics.track(&"pet_interacted", {"pet_id": current_pet_id, "kind": "pet"})


func _rub(point: Vector2) -> void:
	bath.rub(point)
	world.react_to_service(bath.progress)
	world.spawn_bubble(point)
	if bubble_sound_gate <= 0.0:
		AudioManager.play(_service_sound())
		bubble_sound_gate = 0.11
	EventBus.service_progress.emit(bath.progress)


func _service_sound() -> StringName:
	return (
		{
			&"bath": &"bubble",
			&"groom": &"clipper",
			&"dry": &"dryer",
			&"perfume": &"spray",
			&"style": &"bow",
		}
		. get(current_service, &"bubble")
	)


func _tool_display_name(tool: StringName) -> String:
	return (
		{
			&"soap": "o sabonete",
			&"clipper": "a máquina de tosa",
			&"dryer": "o secador",
			&"perfume": "o perfume",
			&"bow": "o lacinho",
		}
		. get(tool, "o utensílio")
	)


func _on_primary_pressed() -> void:
	if bath.state == BathService.State.COMPLETE or bath.state == BathService.State.FAILED:
		_dismiss_result()


func _start_bath() -> void:
	bath.start_service()
	world.begin_service()
	ShareManager.begin_snapshot(get_viewport())
	instruction_label.text = _gesture_hint()
	AudioManager.play(&"service_start")
	Analytics.track(&"service_start", {"type": String(current_service)})
	EventBus.service_started.emit(current_service)
	if tutorial_step == 1:
		_tutorial_advance()


func _finish_bath() -> void:
	var quality: StringName = bath.finish()
	if quality == &"perfect" or quality == &"good":
		world.complete_service()
		var base_reward: float = (
			{
				&"bath": RemoteConfig.get_float("bath_base_reward"),
				&"groom": 20.0,
				&"dry": 24.0,
				&"perfume": 30.0,
				&"style": 38.0,
			}
			. get(current_service, 12.0)
		)
		var affection: int = int(GameState.pet_affection.get(current_pet_id, 0))
		var affection_multiplier: float = 1.0 + minf(50.0, affection) * 0.005
		# Gorjeta variável (odds publicadas) e bônus VIP: variabilidade real de
		# recompensa — o mesmo serviço rende diferente a cada atendimento.
		var tip_multiplier: float = Economy.tip_multiplier(randf())
		last_tip_percent = int(roundf((tip_multiplier - 1.0) * 100.0))
		var vip_multiplier: float = Economy.VIP_REWARD_MULTIPLIER if current_vip else 1.0
		var reward: float = (
			(
				Economy
				. service_reward(
					base_reward,
					quality,
					GameState.bath_upgrade_level,
					GameState.combo,
				int(
					GameState.tool_upgrade_levels.get(String(SERVICE_TOOLS[current_service]), 0)
				),
				GameState.prestige_level,
			)
			)
			* LiveOps.multiplier_for(current_service)
			* LiveOps.bonus_for_quality(quality)
			* affection_multiplier
			* tip_multiplier
			* vip_multiplier
		)
		var stars: int = 5 if quality == &"perfect" else 4
		GameState.register_review(stars)
		if last_tip_percent > 0:
			GameState.register_weekly_event(&"tips")
		if current_vip:
			GameState.register_weekly_event(&"vip")
		if current_service == &"style":
			GameState.register_weekly_event(&"style")
		EventBus.service_completed.emit(current_service, quality, reward)
		Analytics.track(
			&"service_complete",
			{"type": String(current_service), "quality": String(quality), "reward": reward}
		)
		if quality == &"perfect":
			Analytics.track(&"perfect_service")
		_show_success(quality, reward, stars)
	else:
		_fail(quality)


func _show_success(quality: StringName, reward: float, stars: int) -> void:
	# Perfect and long-combo outcomes are genuinely special; ordinary good service has no stars VFX.
	world.celebrate(quality == &"perfect" or GameState.combo >= 5)
	AudioManager.play(&"perfect" if quality == &"perfect" else &"coin")
	HapticsManager.success()
	result_title.text = (
		Loc.t("PERFECT_RESULT") if quality == &"perfect" else Loc.t("GOOD_RESULT")
	)
	if current_vip:
		result_title.text = Loc.t("VIP_TAG") + "! " + result_title.text
	if tutorial_step == 2:
		_tutorial_advance()
	if GameState.combo >= 5:
		result_title.text = "RITMO PERFEITO ×%d" % GameState.combo
		Analytics.track(&"combo_reached", {"level": GameState.combo})
	result_title.modulate = Color("ffd54f") if quality == &"perfect" else GREEN
	var outcome: String = (
		{
			&"bath": "saiu limpinho!",
			&"groom": "ganhou um corte novo!",
			&"dry": "ficou sequinho e fofo!",
			&"perfume": "ficou muito cheiroso!",
			&"style": "amou o novo lacinho!",
		}
		. get(current_service, "recebeu cuidado especial!")
	)
	var xp_reward: int = 15 if quality == &"perfect" else 10
	xp_reward = int(xp_reward * (1.0 + GameState.staff_bonus(&"veterinary_xp")))
	var tip_line: String = (
		Loc.t("TIP_LINE") % last_tip_percent if last_tip_percent > 0 else Loc.t("NO_TIP")
	)
	if current_vip:
		tip_line = Loc.t("VIP_TAG") + " ×2 · " + tip_line
	result_detail.text = (
		"%s\n+%d moedas  •  +%d XP\n%s\n%s %s"
		% ["★".repeat(stars), int(reward), xp_reward, tip_line, current_pet_name, outcome]
	)
	ShareManager.finish_snapshot(get_viewport(), String(current_service))
	share_button.visible = true
	_pop_panel(result_panel)
	primary_button.text = "✓  CONTINUAR"
	primary_button.disabled = false
	primary_button.show()
	_refresh_economy()


func _fail(reason: StringName) -> void:
	bath.state = BathService.State.FAILED
	dragging = false
	dragged_tool = &""
	EventBus.service_failed.emit(current_service, reason)
	Analytics.track(&"service_fail", {"type": String(current_service), "reason": String(reason)})
	world.react_to_failure()
	AudioManager.play(&"error")
	HapticsManager.error()
	result_title.text = "QUASE LÁ!"
	result_title.modulate = Color("ef5350")
	var action_name: String = String(SERVICE_LABELS.get(current_service, "cuidado"))
	var hint: String
	if reason == &"timeout":
		hint = "O tempo acabou. Faça o movimento com mais ritmo!"
	elif reason == &"overwashed":
		hint = (
			"%s demais. Solte assim que o aro entrar na faixa verde."
			% action_name.capitalize()
		)
	else:
		hint = "Leve a %s até a faixa verde antes de finalizar." % action_name
	result_detail.text = "★★☆☆☆\n%s\nSem punição — tente de novo." % hint
	share_button.visible = false
	_pop_panel(result_panel)
	primary_button.text = "↻  TENTAR NOVAMENTE"
	primary_button.disabled = false
	primary_button.show()
	if tutorial_step == 2:
		_tutorial_advance()


func _dismiss_result() -> void:
	result_panel.hide()
	world.reset_pet()
	world.depart()
	world.clear_room()
	bath = BathServiceScript.new()
	if selected_slot >= 0:
		queue[selected_slot] = {}
		refill_timers[selected_slot] = 1.1
	selected_slot = -1
	current_vip = false
	instruction_label.text = Loc.t("CHOOSE_CLIENT")
	primary_button.hide()
	_update_queue_ui()


func _make_client() -> Dictionary:
	var unlocked: Array[String] = GameState.unlocked_pets
	if unlocked.is_empty():
		unlocked = ["caramelo"]
	var pet_id: String = unlocked[randi() % unlocked.size()]
	# O pet preferido (buddy) visita com prioridade: 40% de chance de vir.
	if pet_id != GameState.favorite_pet and randf() < 0.4:
		pet_id = GameState.favorite_pet
		Analytics.track(&"buddy_spawned", {"pet_id": pet_id})
	var services: Array[StringName] = _available_services()
	var service: StringName = services[randi() % services.size()]
	# A fila segue o evento do dia: no dia temático, metade dos clientes
	# chega com o serviço em destaque — o evento se sente andando pela porta.
	var featured: StringName = LiveOps.featured_service()
	if featured != &"" and featured in services and service != featured and randf() < 0.5:
		service = featured
		Analytics.track(&"event_client", {"service": String(service)})
	var vip: bool = randf() < Economy.VIP_CHANCE
	var wait_total: float = randf_range(60.0, 90.0) * (0.7 if vip else 1.0)
	return {
		"pet": pet_id,
		"service": service,
		"vip": vip,
		"wait_total": wait_total,
		"wait_left": wait_total,
	}


func _on_queue_pressed(slot: int) -> void:
	if not _can_select(slot):
		return
	selected_slot = slot
	var client: Dictionary = queue[slot]
	current_vip = bool(client.get("vip", false))
	current_pet_id = String(client["pet"])
	current_service = StringName(client["service"])
	var profile: Dictionary = ContentDB.pet(current_pet_id)
	current_pet_name = String(profile.get("name", "Pet"))
	_configure_current_service()
	world.set_service_layout(current_service)
	world.set_pet_profile(profile)
	world.arrive()
	_refresh_economy()
	var required_tool: StringName = StringName(SERVICE_TOOLS[current_service])
	instruction_label.text = (
		"Arraste %s da prateleira até %s" % [_tool_display_name(required_tool), current_pet_name]
	)
	_update_queue_ui()
	Analytics.track(
		&"client_selected",
		{
			"pet_id": current_pet_id,
			"service": String(current_service),
			"vip": current_vip,
			"rarity": profile.get("rarity", "common"),
		}
	)
	EventBus.pet_arrived.emit(StringName(current_pet_id))
	if tutorial_step == 0:
		_tutorial_advance()


func _can_select(slot: int) -> bool:
	if queue[slot].is_empty() or selected_slot != -1:
		return false
	if is_instance_valid(result_panel) and result_panel.visible:
		return false
	if meta.is_open():
		return false
	return true


func _process_queue(delta: float) -> void:
	for slot: int in 3:
		if refill_timers[slot] > 0.0:
			refill_timers[slot] -= delta
			if refill_timers[slot] <= 0.0:
				queue[slot] = _make_client()
				_update_queue_ui()
		elif (
			not queue[slot].is_empty()
			and slot != selected_slot
			and bool(GameState.tutorial_complete)
		):
			queue[slot]["wait_left"] = float(queue[slot]["wait_left"]) - delta
			if float(queue[slot]["wait_left"]) <= 0.0:
				_client_left(slot)
	# Barras de paciência e habilitação dos cartões (estado muda todo frame).
	for slot: int in 3:
		var client: Dictionary = queue[slot]
		if client.is_empty():
			queue_bars[slot].custom_minimum_size.x = 0.0
		else:
			var ratio: float = clampf(
				float(client["wait_left"]) / float(client["wait_total"]), 0.0, 1.0
			)
			var bar_width: float = queue_bars[slot].get_parent().size.x * ratio
			queue_bars[slot].custom_minimum_size.x = bar_width
			queue_bars[slot].color = (
				Color("ef5350") if ratio <= 0.25 else Color("7ed957")
			)
		queue_cards[slot].disabled = not _can_select(slot)


func _client_left(slot: int) -> void:
	var client: Dictionary = queue[slot]
	var leaver_name: String = String(
		ContentDB.pet(String(client["pet"])).get("name", "Alguém")
	)
	_show_toast("%s cansou de esperar e foi embora." % leaver_name, Color("ef5350"))
	GameState.register_review(3)
	Analytics.track(&"client_left", {"pet_id": String(client["pet"])})
	queue[slot] = {}
	refill_timers[slot] = 2.0
	_update_queue_ui()


func _setup_tutorial() -> void:
	if bool(GameState.tutorial_complete):
		return
	tutorial_step = 0
	tutorial_skip_button.visible = true
	_tutorial_apply()


func _tutorial_apply() -> void:
	if tutorial_step == 0:
		tutorial_overlay.show_step(
			Rect2(queue_row.position - Vector2(10, 10), queue_row.size + Vector2(20, 20)),
			"1/3 · Toque em um cliente da fila para atender",
		)
	elif tutorial_step == 1:
		var tool: StringName = StringName(SERVICE_TOOLS[current_service])
		tutorial_overlay.show_step(
			_tool_spot_rect(),
			"2/3 · Arraste %s até %s" % [_tool_display_name(tool), current_pet_name],
		)
	elif tutorial_step == 2:
		tutorial_overlay.show_step(
			Rect2(world.pet_position - Vector2(250, 250), Vector2(500, 560)),
			"3/3 · " + _gesture_hint(),
		)


func _gesture_hint() -> String:
	return Loc.t(String(GESTURE_HINTS.get(current_service, GESTURE_HINTS[&"bath"])))


func _tool_spot_rect() -> Rect2:
	var tool: StringName = StringName(SERVICE_TOOLS[current_service])
	var shelf: Vector2 = world.tool_shelf_position(tool)
	return Rect2(shelf - Vector2(80, 80), Vector2(160, 160))


func _tutorial_advance() -> void:
	tutorial_step += 1
	if tutorial_step >= 3:
		_finish_tutorial()
		Analytics.track(&"tutorial_complete")
	else:
		_tutorial_apply()


func _finish_tutorial() -> void:
	tutorial_step = -1
	tutorial_overlay.finish()
	tutorial_skip_button.visible = false
	GameState.tutorial_complete = true


func _skip_tutorial() -> void:
	_finish_tutorial()
	Analytics.track(&"tutorial_skipped")


func _update_queue_ui() -> void:
	for slot: int in 3:
		var client: Dictionary = queue[slot]
		if client.is_empty():
			queue_name_labels[slot].text = "· · ·"
			queue_service_labels[slot].text = "aguardando cliente"
			queue_cards[slot].modulate.a = 0.45
		else:
			var client_name: String = String(
				ContentDB.pet(String(client["pet"])).get("name", "Pet")
			)
			if bool(client["vip"]):
				client_name = "VIP " + client_name
			queue_name_labels[slot].text = client_name
			queue_service_labels[slot].text = String(
				SERVICE_LABELS.get(StringName(client["service"]), "cuidado")
			).capitalize()
			queue_cards[slot].modulate.a = 1.0
		queue_cards[slot].disabled = not _can_select(slot)


func _configure_current_service() -> void:
	var duration: float = (
		{&"bath": 10.0, &"groom": 11.0, &"dry": 9.0, &"perfume": 8.0, &"style": 8.0}
		. get(current_service, 10.0)
	)
	var required_distance: float = (
		{&"bath": 1350.0, &"groom": 1550.0, &"dry": 1250.0, &"perfume": 1050.0, &"style": 900.0}
		. get(current_service, 1350.0)
	)
	# A paciência do pet modula o tempo real do atendimento (27–50 no catálogo);
	# passivos de equipe contratada (staff.json) ajustam tempo, distância e janela.
	var patience: float = float(ContentDB.pet(current_pet_id).get("patience", 42))
	var patience_factor: float = clampf(patience / 42.0, 0.6, 1.25)
	patience_factor += GameState.staff_bonus(&"patience")
	if current_service == &"bath":
		required_distance *= 1.0 - GameState.staff_bonus(&"bath_speed")
	var window_bonus: float = GameState.staff_bonus(&"perfect_window")
	if current_service == &"groom":
		window_bonus += GameState.staff_bonus(&"groom_quality")
	bath.configure(
		duration * patience_factor,
		RemoteConfig.get_float("bath_target_min"),
		minf(RemoteConfig.get_float("bath_target_max") + window_bonus, 1.0),
		required_distance,
	)
	var gesture: Dictionary = GESTURES.get(current_service, GESTURES[&"bath"])
	bath.configure_gesture(
		gesture["axis"], gesture["mode"], gesture["cap"], gesture["rate"]
	)
	if is_instance_valid(world):
		world.set_service_layout(current_service)
		world.player_level = GameState.player_level


func _available_services() -> Array[StringName]:
	var result: Array[StringName] = []
	for service: StringName in SERVICE_UNLOCK_LEVELS:
		if GameState.player_level >= int(SERVICE_UNLOCK_LEVELS[service]):
			result.append(service)
	return result if not result.is_empty() else [&"bath"]


func _on_upgrade_pressed() -> void:
	var cost: float = Economy.upgrade_cost(GameState.bath_upgrade_level)
	if GameState.buy_bath_upgrade():
		AudioManager.play(&"upgrade")
		HapticsManager.success()
		EventBus.toast_requested.emit(
			"Estação nível %d! Recompensa maior." % GameState.bath_upgrade_level, GREEN
		)
	else:
		EventBus.toast_requested.emit(
			"Faltam %d moedas" % int(cost - GameState.coins), Color("ef5350")
		)
	_refresh_economy()


func _on_tool_upgrade_pressed() -> void:
	var tool_id: StringName = StringName(SERVICE_TOOLS[current_service])
	var cost: float = GameState.tool_upgrade_cost(tool_id)
	if GameState.buy_tool_upgrade(tool_id):
		AudioManager.play(&"upgrade")
		HapticsManager.success()
		_show_toast("%s melhorado! +4%% de bônus" % _tool_display_name(tool_id).capitalize(), GREEN)
	else:
		_show_toast("Faltam %d moedas" % maxi(0, int(cost - GameState.coins)), Color("ef5350"))
	_refresh_economy()


func _refresh_economy(_currency: StringName = &"coins", _amount: float = 0.0) -> void:
	coin_label.text = "%d" % int(GameState.coins)
	var xp_percent: int = int(100.0 * GameState.player_xp / GameState.xp_to_next_level())
	combo_label.text = (
		"NV.%d %d%% • ×%d" % [GameState.player_level, xp_percent, maxi(1, GameState.combo)]
	)
	review_label.text = "★ %.1f" % GameState.review_average()
	if is_instance_valid(world):
		world.upgrade_level = GameState.bath_upgrade_level
		world.player_level = GameState.player_level
		world.set_cosmetics(GameState.active_cosmetics)
	var cost: float = Economy.upgrade_cost(GameState.bath_upgrade_level)
	var station_bonus: float = (
		(Economy.income_multiplier(GameState.bath_upgrade_level) - 1.0) * 100.0
	)
	if GameState.bath_upgrade_level >= GameState.MAX_CAREER_LEVEL:
		upgrade_button.text = "ESTAÇÃO MÁXIMA\n+%.0f%%" % station_bonus
		upgrade_button.disabled = true
	else:
		upgrade_button.disabled = false
		upgrade_button.text = (
			"ESTAÇÃO Nv.%d  +%.1f%%\n⬆ +7,5%% • %d moedas"
			% [GameState.bath_upgrade_level, station_bonus, int(cost)]
		)
	var tool_id: StringName = StringName(SERVICE_TOOLS[current_service])
	var tool_level: int = int(GameState.tool_upgrade_levels.get(String(tool_id), 0))
	var tool_cost: float = GameState.tool_upgrade_cost(tool_id)
	tool_upgrade_button.text = (
		"%s Nv.%d  +%d%%\n⬆ +4%% • %d moedas"
		% [_tool_display_name(tool_id).capitalize(), tool_level, tool_level * 4, int(tool_cost)]
	)
	tool_upgrade_button.disabled = tool_level >= 30


func _show_pending_offline_reward() -> void:
	var offline: Dictionary = SaveManager.consume_pending_offline_reward()
	if offline.is_empty():
		return
	var minutes: int = int(float(offline["seconds"]) / 60.0)
	_show_toast(
		"Cofre offline (%d min): +%d moedas" % [minutes, int(offline["reward"])],
		Color("ffd54f"),
	)
	AudioManager.play(&"coin")


func _show_toast(message: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_stylebox_override("normal", _style(color, 24, 16))
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-360, 120)
	label.size = Vector2(720, 78)
	toast_layer.add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", 165.0, 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


func _connect_events() -> void:
	EventBus.currency_changed.connect(_refresh_economy)
	EventBus.combo_changed.connect(func(_value: int) -> void: _refresh_economy())
	EventBus.toast_requested.connect(_show_toast)


func _build_interface() -> void:
	world = PetShopCanvasScript.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(world)

	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.position = Vector2(45, 35)
	top_bar.size = Vector2(990, 100)
	top_bar.add_theme_constant_override("separation", 18)
	add_child(top_bar)
	coin_label = _pill(top_bar, "0", Color("ffd54f"), 280)
	review_label = _pill(top_bar, "★ 5.0", PINK, 235)
	combo_label = _pill(top_bar, "COMBO ×1", GREEN, 300)

	# Fila de clientes: 3 cartões tocáveis com nome, pedido, paciência e VIP.
	queue_row = HBoxContainer.new()
	queue_row.position = Vector2(45, 310)
	queue_row.size = Vector2(990, 175)
	queue_row.add_theme_constant_override("separation", 15)
	add_child(queue_row)
	for slot: int in 3:
		var card: Button = _button("", Color("ffffff", 0.94), 320, 175)
		card.add_theme_stylebox_override("panel", _style(Color("ffffff", 0.94), 26, 16, PINK, 4))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 14.0
		column.offset_right = -14.0
		column.offset_top = 12.0
		column.offset_bottom = -12.0
		card.add_child(column)
		var name_label: Label = Label.new()
		name_label.add_theme_font_size_override("font_size", 27)
		name_label.add_theme_color_override("font_color", CHARCOAL)
		column.add_child(name_label)
		var service_label: Label = Label.new()
		service_label.add_theme_font_size_override("font_size", 22)
		service_label.add_theme_color_override("font_color", Color("546e7a"))
		column.add_child(service_label)
		var bar: ColorRect = ColorRect.new()
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.color = Color("7ed957")
		column.add_child(bar)
		card.pressed.connect(_on_queue_pressed.bind(slot))
		queue_row.add_child(card)
		queue_cards.append(card)
		queue_name_labels.append(name_label)
		queue_service_labels.append(service_label)
		queue_bars.append(bar)

	# Navegação superior compacta: ícones flutuantes preservam o cenário e a área de trabalho.
	var nav: HBoxContainer = HBoxContainer.new()
	nav.position = Vector2(45, 155)
	nav.add_theme_constant_override("separation", 14)
	add_child(nav)
	# Ícones desenhados (PNG) em vez de glifos Unicode: renderização idêntica
	# em qualquer plataforma, sem depender da cobertura da fonte do dispositivo.
	for item: Dictionary in [
		{"id": "missions", "tip": "Missões"},
		{"id": "collection", "tip": "Pets"},
		{"id": "staff", "tip": "Equipe"},
		{"id": "shop", "tip": "Loja"},
		{"id": "map", "tip": "Mapa"},
		{"id": "settings", "tip": "Ajustes"}
	]:
		var nav_button: Button = _button("", CHARCOAL, 82, 82)
		nav_button.icon = NAV_ICONS[StringName(item["id"])]
		nav_button.tooltip_text = String(item["tip"])
		nav_button.add_theme_stylebox_override(
			"normal", _style(Color("263238", 0.88), 41, 8, Color("ffffff", 0.72), 3)
		)
		nav_button.add_theme_stylebox_override("hover", _style(PINK, 41, 8, Color.WHITE, 3))
		nav_button.pressed.connect(meta.open.bind(StringName(item["id"]), nav_button))
		nav.add_child(nav_button)

	# HUD flutuante sem rodapé sólido: cenário continua visível até a borda inferior.
	var action_hud: VBoxContainer = VBoxContainer.new()
	action_hud.position = Vector2(45, 1350)
	action_hud.size = Vector2(990, 260)
	action_hud.add_theme_constant_override("separation", 16)
	add_child(action_hud)
	instruction_label = Label.new()
	instruction_label.text = "Arraste o sabonete da prateleira até Caramelo"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 33)
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_label.add_theme_stylebox_override(
		"normal", _style(Color("263238", 0.82), 34, 14, Color("ffffff", 0.42), 2)
	)
	instruction_label.custom_minimum_size = Vector2(990, 72)
	action_hud.add_child(instruction_label)
	var upgrades_row: HBoxContainer = HBoxContainer.new()
	upgrades_row.add_theme_constant_override("separation", 16)
	action_hud.add_child(upgrades_row)
	upgrade_button = _button("ESTAÇÃO", Color("29b6d8", 0.94), 487, 112)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	upgrades_row.add_child(upgrade_button)
	tool_upgrade_button = _button("UTENSÍLIO", Color("b86ad1", 0.94), 487, 112)
	tool_upgrade_button.pressed.connect(_on_tool_upgrade_pressed)
	upgrades_row.add_child(tool_upgrade_button)

	meta = MetaPanel.new()
	meta.refresh_callback = _refresh_economy
	meta.build(self)

	result_panel = PanelContainer.new()
	result_panel.position = Vector2(110, 430)
	result_panel.size = Vector2(860, 720)
	result_panel.add_theme_stylebox_override(
		"panel", _style(Color("263238", 0.96), 52, 42, PINK, 7)
	)
	add_child(result_panel)
	var result_column: VBoxContainer = VBoxContainer.new()
	result_column.alignment = BoxContainer.ALIGNMENT_CENTER
	result_column.add_theme_constant_override("separation", 25)
	result_panel.add_child(result_column)
	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 72)
	result_column.add_child(result_title)
	result_detail = Label.new()
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.add_theme_font_size_override("font_size", 39)
	result_detail.add_theme_color_override("font_color", Color.WHITE)
	result_column.add_child(result_detail)
	var result_actions: VBoxContainer = VBoxContainer.new()
	result_actions.add_theme_constant_override("separation", 16)
	result_column.add_child(result_actions)
	primary_button = _button("✓  CONTINUAR", GREEN, 0, 105)
	primary_button.pressed.connect(_on_primary_pressed)
	result_actions.add_child(primary_button)
	share_button = _button(Loc.t("SHARE_BUTTON"), BLUE, 0, 88)
	share_button.pressed.connect(_on_share_pressed)
	result_actions.add_child(share_button)
	result_panel.hide()

	toast_layer = Control.new()
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(toast_layer)

	# Spotlight por cima de tudo (input passa direto: guia não-bloqueante).
	tutorial_overlay = TutorialOverlayScript.new()
	tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_overlay.visible = false
	add_child(tutorial_overlay)
	tutorial_skip_button = _button(Loc.t("SKIP_TUTORIAL"), Color("7f8c8d", 0.9), 300, 64)
	tutorial_skip_button.position = Vector2(390, 1830)
	tutorial_skip_button.pressed.connect(_skip_tutorial)
	tutorial_skip_button.visible = false
	add_child(tutorial_skip_button)


func _pop_panel(panel: Control) -> void:
	panel.show()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)


func _pill(parent: Container, text: String, color: Color, width: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(width, 82)
	label.add_theme_font_size_override("font_size", 33)
	label.add_theme_color_override("font_color", CHARCOAL)
	label.add_theme_stylebox_override("normal", _style(Color("ffffff", 0.95), 35, 12, color, 5))
	parent.add_child(label)
	return label


func _button(text: String, color: Color, width: float, height: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(color, 34, 14))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.08), 34, 14))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.12), 30, 18))
	button.add_theme_stylebox_override("disabled", _style(Color("b0bec5"), 34, 14))
	InteractionFX.bind_button(button)
	return button


func _style(
	color: Color,
	radius: int,
	content_margin: int,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	if radius >= 20:
		style.shadow_color = Color("263238", 0.16)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 6)
	return style
