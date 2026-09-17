extends Control
## Playable Core: chegada → servir → esfregar → timing → moedas/review/save.

const BathServiceScript: Script = preload("res://core/gameplay/BathService.gd")
const PetShopCanvasScript: Script = preload("res://core/gameplay/PetShopCanvas.gd")
const MENU_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_perfume.png")
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

var bath: BathService
var world: PetShopCanvas
var coin_label: Label
var combo_label: Label
var review_label: Label
var order_card: PanelContainer
var order_label: Label
var instruction_label: Label
var primary_button: Button
var upgrade_button: Button
var tool_upgrade_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var dragging: bool = false
var next_client_timer: float = 0.0
var bubble_sound_gate: float = 0.0
var toast_layer: Control
var current_service: StringName = &"bath"
var current_pet_id: String = "caramelo"
var current_pet_name: String = "Caramelo"
var pet_touch_gate: float = 0.0
var meta_backdrop: TextureRect
var meta_panel: PanelContainer
var meta_title: Label
var meta_content: Label
var meta_action_button: Button
var dragged_tool: StringName = &""
var wrong_tool_gate: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bath = BathServiceScript.new()
	_configure_current_service()
	_build_interface()
	world.set_pet_profile(ContentDB.pet(current_pet_id))
	world.arrive()
	_connect_events()
	_refresh_economy()
	_show_pending_offline_reward()
	Analytics.track(&"first_open" if GameState.services_completed == 0 else &"session_resume")
	Analytics.track(&"pet_arrived", {"rarity": "common", "pet_id": "caramelo"})
	EventBus.pet_arrived.emit(&"caramelo")


func _process(delta: float) -> void:
	bubble_sound_gate = maxf(0.0, bubble_sound_gate - delta)
	pet_touch_gate = maxf(0.0, pet_touch_gate - delta)
	wrong_tool_gate = maxf(0.0, wrong_tool_gate - delta)
	if bath.state == BathService.State.ACTIVE:
		if bath.tick(delta):
			_fail(&"timeout")
			return
		# O único progresso visual é o aro que acompanha o utensílio arrastado.
		world.progress = clampf(bath.progress / bath.target_minimum, 0.0, 1.0)
	elif next_client_timer > 0.0:
		next_client_timer -= delta
		if next_client_timer <= 0.0:
			_new_client()


func _input(event: InputEvent) -> void:
	if (
		(is_instance_valid(meta_panel) and meta_panel.visible)
		or (is_instance_valid(result_panel) and result_panel.visible)
	):
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
		bath.release_pointer()
		return
	var required_tool: StringName = StringName(SERVICE_TOOLS[current_service])
	if dragged_tool != required_tool:
		if wrong_tool_gate <= 0.0:
			wrong_tool_gate = 0.8
			_show_toast("Use %s neste pedido" % _tool_display_name(required_tool), Color("ffd54f"))
			AudioManager.play(&"error_soft")
		return
	if bath.state == BathService.State.WAITING:
		_start_bath()
	if bath.state == BathService.State.ACTIVE:
		_rub(point)


func _end_pointer() -> void:
	dragging = false
	dragged_tool = &""
	bath.release_pointer()
	world.release_tool()


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
	if bath.progress >= bath.target_minimum:
		_finish_bath()


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
	world.pet_wet = current_service == &"bath"
	world.service_mode = current_service
	instruction_label.text = (
		"%s sobre o pet • o aro completa sozinho"
		% String(SERVICE_LABELS[current_service]).capitalize()
	)
	order_card.hide()
	AudioManager.play(&"service_start")
	Analytics.track(&"service_start", {"type": String(current_service)})
	EventBus.service_started.emit(current_service)


func _finish_bath() -> void:
	var quality: StringName = bath.finish()
	_end_pointer()
	if quality == &"perfect" or quality == &"good":
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
				)
			)
			* LiveOps.multiplier_for(current_service)
			* affection_multiplier
		)
		var stars: int = 5 if quality == &"perfect" else 4
		GameState.register_review(stars)
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
	world.celebrate()
	AudioManager.play(&"perfect" if quality == &"perfect" else &"coin")
	HapticsManager.success()
	result_title.text = "PERFEITO!" if quality == &"perfect" else "MUITO BOM!"
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
	result_detail.text = (
		"%s\n+%d moedas  •  +%d XP\n%s %s"
		% ["★".repeat(stars), int(reward), xp_reward, current_pet_name, outcome]
	)
	_pop_panel(result_panel)
	primary_button.text = "✓  PRÓXIMO CLIENTE"
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
		hint = "%s demais. Pare assim que entrar na faixa verde." % action_name.capitalize()
	else:
		hint = "Leve a %s até a faixa verde antes de finalizar." % action_name
	result_detail.text = "★★☆☆☆\n%s\nSem punição — tente de novo." % hint
	_pop_panel(result_panel)
	primary_button.text = "↻  TENTAR NOVAMENTE"
	primary_button.disabled = false
	primary_button.show()


func _dismiss_result() -> void:
	result_panel.hide()
	world.reset_pet()
	bath = BathServiceScript.new()
	var available_pets: Array[String] = GameState.unlocked_pets
	if available_pets.is_empty():
		available_pets = ["caramelo"]
	current_pet_id = available_pets[GameState.services_completed % available_pets.size()]
	var profile: Dictionary = ContentDB.pet(current_pet_id)
	current_pet_name = String(profile.get("name", "Caramelo"))
	var available_services: Array[StringName] = _available_services()
	current_service = available_services[GameState.services_completed % available_services.size()]
	_configure_current_service()
	world.service_mode = current_service
	order_card.hide()
	instruction_label.text = "Novo cliente chegando..."
	primary_button.hide()
	next_client_timer = 1.1


func _new_client() -> void:
	order_card.show()
	var service_name: String = (
		{
			&"bath": "Banho com espuma",
			&"groom": "Tosa higiênica",
			&"dry": "Secagem macia",
			&"perfume": "Perfume delicado",
			&"style": "Laço especial",
		}
		. get(current_service, "Cuidado especial")
	)
	var profile: Dictionary = ContentDB.pet(current_pet_id)
	order_label.text = (
		"%s\n%s • %s\n%d+ moedas"
		% [
			current_pet_name.to_upper(),
			profile.get("breed", "Pet especial"),
			service_name,
			int(
				{&"bath": 12, &"groom": 20, &"dry": 24, &"perfume": 30, &"style": 38}.get(
					current_service, 12
				)
			),
		]
	)
	primary_button.hide()
	var required_tool: StringName = StringName(SERVICE_TOOLS[current_service])
	instruction_label.text = (
		"Arraste %s da prateleira até %s" % [_tool_display_name(required_tool), current_pet_name]
	)
	world.set_pet_profile(profile)
	world.arrive()
	_refresh_economy()
	var arrival_params: Dictionary = {
		"rarity": profile.get("rarity", "common"),
		"pet_id": current_pet_id,
		"species": profile.get("species", "dog"),
	}
	Analytics.track(&"pet_arrived", arrival_params)


func _configure_current_service() -> void:
	var duration: float = (
		{&"bath": 10.0, &"groom": 11.0, &"dry": 9.0, &"perfume": 8.0, &"style": 8.0}
		. get(current_service, 10.0)
	)
	var required_distance: float = (
		{&"bath": 1350.0, &"groom": 1550.0, &"dry": 1250.0, &"perfume": 1050.0, &"style": 900.0}
		. get(current_service, 1350.0)
	)
	bath.configure(duration, 0.86, 1.0, required_distance)
	if is_instance_valid(world):
		world.service_mode = current_service
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
	world.offset_bottom = -540
	add_child(world)

	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.position = Vector2(45, 35)
	top_bar.size = Vector2(990, 100)
	top_bar.add_theme_constant_override("separation", 18)
	add_child(top_bar)
	coin_label = _pill(top_bar, "0", Color("ffd54f"), 280)
	review_label = _pill(top_bar, "★ 5.0", PINK, 235)
	combo_label = _pill(top_bar, "COMBO ×1", GREEN, 300)

	order_card = PanelContainer.new()
	order_card.position = Vector2(65, 310)
	order_card.size = Vector2(560, 175)
	order_card.add_theme_stylebox_override(
		"panel", _style(Color("ffffff", 0.94), 36, 24, Color("ff8fb1"), 6)
	)
	add_child(order_card)
	order_label = Label.new()
	order_label.text = "CARAMELO\nVira-lata caramelo • Banho simples\n12+ moedas"
	order_label.add_theme_font_size_override("font_size", 32)
	order_label.add_theme_color_override("font_color", CHARCOAL)
	order_card.add_child(order_label)

	var bottom: PanelContainer = PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Sheet abaixo da prateleira: o cenário e todos os utensílios continuam arrastáveis.
	bottom.offset_top = -680.0
	bottom.offset_bottom = 0.0
	bottom.add_theme_stylebox_override("panel", _style(Color("fffaf3"), 54, 42, Color("e6cbb5"), 4))
	add_child(bottom)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	bottom.add_child(column)
	instruction_label = Label.new()
	instruction_label.text = "Arraste o sabonete da prateleira até Caramelo"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 34)
	instruction_label.add_theme_color_override("font_color", CHARCOAL)
	instruction_label.custom_minimum_size.y = 52
	column.add_child(instruction_label)
	var upgrades_row: HBoxContainer = HBoxContainer.new()
	upgrades_row.add_theme_constant_override("separation", 16)
	column.add_child(upgrades_row)
	upgrade_button = _button("ESTAÇÃO", BLUE, 480, 106)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	upgrades_row.add_child(upgrade_button)
	tool_upgrade_button = _button("UTENSÍLIO", Color("ce93d8"), 480, 106)
	tool_upgrade_button.pressed.connect(_on_tool_upgrade_pressed)
	upgrades_row.add_child(tool_upgrade_button)
	var nav: HBoxContainer = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	column.add_child(nav)
	for item: Dictionary in [
		{"id": "missions", "label": "★ MISSÕES"},
		{"id": "collection", "label": "♥ PETS"},
		{"id": "map", "label": "⌂ MAPA"},
		{"id": "settings", "label": "⚙ AJUSTES"}
	]:
		var nav_button: Button = _button(String(item["label"]), CHARCOAL, 220, 66)
		nav_button.add_theme_font_size_override("font_size", 24)
		nav_button.pressed.connect(_open_meta.bind(StringName(item["id"])))
		nav.add_child(nav_button)

	_build_meta_panel()

	result_panel = PanelContainer.new()
	result_panel.position = Vector2(130, 505)
	result_panel.size = Vector2(820, 510)
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
	primary_button = _button("✓  PRÓXIMO CLIENTE", GREEN, 0, 105)
	primary_button.pressed.connect(_on_primary_pressed)
	result_column.add_child(primary_button)
	result_panel.hide()

	toast_layer = Control.new()
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(toast_layer)


func _build_meta_panel() -> void:
	meta_backdrop = TextureRect.new()
	meta_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	meta_backdrop.texture = MENU_BACKGROUND
	meta_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meta_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	meta_backdrop.modulate = Color(0.42, 0.35, 0.48, 0.92)
	meta_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(meta_backdrop)
	meta_panel = PanelContainer.new()
	meta_panel.position = Vector2(80, 290)
	meta_panel.size = Vector2(920, 950)
	meta_panel.add_theme_stylebox_override("panel", _style(Color("fffaf3", 0.98), 50, 42, PINK, 7))
	add_child(meta_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	meta_panel.add_child(column)
	meta_title = Label.new()
	meta_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_title.add_theme_font_size_override("font_size", 54)
	meta_title.add_theme_color_override("font_color", CHARCOAL)
	column.add_child(meta_title)
	meta_content = Label.new()
	meta_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_content.add_theme_font_size_override("font_size", 32)
	meta_content.add_theme_color_override("font_color", CHARCOAL)
	meta_content.custom_minimum_size = Vector2(820, 610)
	column.add_child(meta_content)
	meta_action_button = _button("COLETAR RECOMPENSAS", GREEN, 0, 90)
	meta_action_button.pressed.connect(_claim_available_rewards)
	column.add_child(meta_action_button)
	var close: Button = _button("↙  VOLTAR AO PETSHOP", PINK, 0, 90)
	close.pressed.connect(_close_meta)
	column.add_child(close)
	meta_panel.hide()
	meta_backdrop.hide()


func _close_meta() -> void:
	meta_panel.hide()
	meta_backdrop.hide()
	AudioManager.play(&"tap")


func _open_meta(section: StringName) -> void:
	meta_backdrop.show()
	meta_backdrop.pivot_offset = meta_backdrop.size * 0.5
	meta_backdrop.scale = Vector2(1.035, 1.035)
	meta_backdrop.create_tween().tween_property(meta_backdrop, "scale", Vector2.ONE, 3.5).set_trans(
		Tween.TRANS_SINE
	)
	_pop_panel(meta_panel)
	AudioManager.play(&"panel_open")
	meta_action_button.show()
	meta_action_button.text = "COLETAR RECOMPENSAS"
	if section == &"missions":
		meta_title.text = "MISSÕES DO DIA"
		meta_content.text = _mission_text()
	elif section == &"collection":
		meta_action_button.hide()
		meta_title.text = "COLEÇÃO"
		meta_content.text = (
			(
				"PETS  %d / %d\n%s\n\nEQUIPE  %d / 6\n%s\n\n"
				+ "CONQUISTAS  %d / 10\n%s\n\nCOSMÉTICOS  %d\nBRASAS  %d"
			)
			% [
				GameState.unlocked_pets.size(),
				ContentDB.pets.size(),
				_pet_names(),
				GameState.hired_staff.size(),
				_list_text(GameState.hired_staff),
				GameState.achievement_ids.size(),
				_list_text(GameState.achievement_ids),
				GameState.unlocked_cosmetics.size(),
				GameState.embers,
			]
		)
	elif section == &"map":
		meta_action_button.hide()
		meta_title.text = "DO BALDE AO IMPÉRIO"
		meta_content.text = _career_text()
	else:
		meta_action_button.text = "ALTERNAR MODO ECONÔMICO"
		meta_title.text = "AJUSTES E ACESSIBILIDADE"
		meta_content.text = (
			(
				"Som: %s\nVibração: %s\nPartículas reduzidas: %s\nModo econômico: %s\n\n"
				+ "Use o botão abaixo para alternar o modo econômico e reduzir partículas. "
				+ "O gameplay permanece idêntico."
			)
			% [
				"ligado" if float(GameState.settings.get("sfx", 0.9)) > 0 else "desligado",
				"ligada" if bool(GameState.settings.get("haptics", true)) else "desligada",
				"sim" if bool(GameState.settings.get("reduced_particles", false)) else "não",
				"sim" if bool(GameState.settings.get("eco_mode", false)) else "não"
			]
		)
		meta_panel.set_meta("settings_mode", true)
		return
	meta_panel.set_meta("settings_mode", false)


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


func _list_text(values: Array[String]) -> String:
	var result: String = ""
	for value: String in values:
		result += ("" if result.is_empty() else ", ") + value
	return result


func _pet_names() -> String:
	var result: String = ""
	for pet_id: String in GameState.unlocked_pets:
		var pet_name: String = String(ContentDB.pet(pet_id).get("name", pet_id))
		result += ("" if result.is_empty() else ", ") + pet_name
	return result


func _career_text() -> String:
	var text: String = (
		"EVENTO: %s\nCARREIRA: nível %d/120 • %.1fh ativas\n\n"
		% [
			LiveOps.current_event_name(),
			GameState.player_level,
			GameState.active_play_seconds / 3600.0,
		]
	)
	for entry: Dictionary in ContentDB.career.get("establishments", []):
		var unlock_level: int = int(entry.get("unlock_level", 1))
		var marker: String = "✓" if GameState.player_level >= unlock_level else "□"
		text += "%s %s — nível %d\n" % [marker, entry.get("name", "Petshop"), unlock_level]
	return text + "\nA jornada foi balanceada para 50+ horas, sem bloquear ações ou compras."


func _mission_text() -> String:
	var claimed_today: bool = GameState.is_daily_claimed_today()
	var service_count: int = int(GameState.mission_progress.get("services", 0))
	var perfect_count: int = int(GameState.mission_progress.get("perfect", 0))
	var upgrade_count: int = int(GameState.mission_progress.get("upgrades", 0))
	var next_day: int = GameState.daily_streak % 7 + 1
	var display_day: int = GameState.daily_streak if claimed_today else next_day
	var daily_status: String = (
		"Coletado hoje" if claimed_today else "%d moedas disponíveis" % (25 * next_day)
	)
	return (
		(
			"LOGIN DIÁRIO  Dia %d/7\n%s\n\n"
			+ "BANHOS E TOSAS  %d/5\nFaça 5 serviços • 75 moedas\n\n"
			+ "NA MEDIDA  %d/3\nConsiga 3 Perfect • 75 moedas\n\n"
			+ "TUDO NOVINHO  %d/1\nCompre 1 upgrade • 75 moedas\n\n"
			+ "Missões nunca exigem anúncio ou compra."
		)
		% [
			display_day,
			daily_status,
			mini(service_count, 5),
			mini(perfect_count, 3),
			mini(upgrade_count, 1)
		]
	)


func _claim_available_rewards() -> void:
	if bool(meta_panel.get_meta("settings_mode", false)):
		var enabled: bool = not bool(GameState.settings.get("eco_mode", false))
		GameState.settings["eco_mode"] = enabled
		GameState.settings["reduced_particles"] = enabled
		SaveManager.request_save()
		_open_meta(&"settings")
		_show_toast("Modo econômico %s" % ("ativado" if enabled else "desativado"), BLUE)
		return
	var total_claimed: int = GameState.claim_daily_reward()
	for mission_id: StringName in [&"daily_bath_5", &"daily_perfect_3", &"daily_upgrade_1"]:
		if GameState.claim_mission(mission_id):
			total_claimed += 75
	_open_meta(&"missions")
	_show_toast(
		(
			"Recompensas coletadas: +%d" % total_claimed
			if total_claimed > 0
			else "Nada pronto para coletar ainda"
		),
		GREEN if total_claimed > 0 else Color("b0bec5")
	)
	_refresh_economy()


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
