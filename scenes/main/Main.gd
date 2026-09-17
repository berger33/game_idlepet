extends Control
## Playable Core: chegada → servir → esfregar → timing → moedas/review/save.

const BathServiceScript: Script = preload("res://core/gameplay/BathService.gd")
const PetShopCanvasScript: Script = preload("res://core/gameplay/PetShopCanvas.gd")
const PINK: Color = Color("ff8fb1")
const BLUE: Color = Color("4fc3f7")
const GREEN: Color = Color("7ed957")
const CREAM: Color = Color("fff3e0")
const CHARCOAL: Color = Color("263238")

var bath: BathService
var world: PetShopCanvas
var coin_label: Label
var combo_label: Label
var review_label: Label
var order_card: PanelContainer
var order_label: Label
var instruction_label: Label
var progress_bar: ProgressBar
var timer_label: Label
var primary_button: Button
var upgrade_button: Button
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
var meta_panel: PanelContainer
var meta_title: Label
var meta_content: Label
var meta_action_button: Button
var perfect_zone: ColorRect


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
	if bath.state == BathService.State.ACTIVE:
		if bath.tick(delta):
			_fail(&"timeout")
			return
		progress_bar.value = bath.progress * 100.0
		timer_label.text = "%.1fs" % bath.time_left
		world.progress = bath.progress
		primary_button.disabled = bath.progress < 0.35
		if bath.progress >= bath.target_minimum and bath.progress <= bath.target_maximum:
			progress_bar.modulate = GREEN
			instruction_label.text = "PERFEITO! Finalize agora!"
		elif bath.progress > bath.target_maximum:
			progress_bar.modulate = Color("ef5350")
			instruction_label.text = "Espuma demais! Finalize!"
		else:
			progress_bar.modulate = Color.WHITE
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
	if bath.state != BathService.State.ACTIVE:
		if event is InputEventScreenTouch:
			var idle_touch: InputEventScreenTouch = event
			if idle_touch.pressed and _pet_hit(idle_touch.position):
				_react_to_pet_touch()
		elif event is InputEventMouseButton:
			var idle_mouse: InputEventMouseButton = event
			if idle_mouse.pressed and idle_mouse.button_index == MOUSE_BUTTON_LEFT:
				if _pet_hit(idle_mouse.position):
					_react_to_pet_touch()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		dragging = touch.pressed and _pet_hit(touch.position)
		if not touch.pressed:
			bath.release_pointer()
			world.release_tool()
	elif event is InputEventScreenDrag and dragging:
		_rub((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			dragging = mouse_button.pressed and _pet_hit(mouse_button.position)
			if not mouse_button.pressed:
				bath.release_pointer()
				world.release_tool()
	elif event is InputEventMouseMotion and dragging:
		_rub((event as InputEventMouseMotion).position)


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
	_show_toast("%s  •  carinho %d" % [message, affection], PINK)
	Analytics.track(&"pet_interacted", {"pet_id": current_pet_id, "kind": "pet"})


func _rub(point: Vector2) -> void:
	bath.rub(point)
	world.react_to_service(bath.progress)
	world.spawn_bubble(point)
	if bubble_sound_gate <= 0.0:
		AudioManager.play(&"bubble" if current_service == &"bath" else &"clipper")
		bubble_sound_gate = 0.12
	EventBus.service_progress.emit(bath.progress)


func _on_primary_pressed() -> void:
	if bath.state == BathService.State.WAITING:
		_start_bath()
	elif bath.state == BathService.State.ACTIVE:
		_finish_bath()
	elif bath.state == BathService.State.COMPLETE or bath.state == BathService.State.FAILED:
		_dismiss_result()


func _start_bath() -> void:
	bath.start_service()
	world.pet_wet = current_service == &"bath"
	world.service_mode = current_service
	instruction_label.text = (
		"Esfregue em círculos e pare na faixa verde"
		if current_service == &"bath"
		else "Deslize a máquina pelo pelo e pare na faixa verde"
	)
	primary_button.text = "FINALIZAR BANHO" if current_service == &"bath" else "FINALIZAR TOSA"
	primary_button.disabled = true
	progress_bar.value = 0
	progress_bar.show()
	timer_label.show()
	order_card.hide()
	Analytics.track(&"service_start", {"type": String(current_service)})
	EventBus.service_started.emit(current_service)


func _finish_bath() -> void:
	var quality: StringName = bath.finish()
	if quality == &"perfect" or quality == &"good":
		var base_reward: float = (
			RemoteConfig.get_float("bath_base_reward") if current_service == &"bath" else 20.0
		)
		var affection: int = int(GameState.pet_affection.get(current_pet_id, 0))
		var affection_multiplier: float = 1.0 + minf(50.0, affection) * 0.005
		var reward: float = (
			Economy.service_reward(
				base_reward, quality, GameState.bath_upgrade_level, GameState.combo
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
		"saiu limpinho!" if current_service == &"bath" else "ganhou um visual novo!"
	)
	result_detail.text = (
		"%s\n+%d moedas  •  %d estrelas\n%s %s"
		% ["★".repeat(stars), int(reward), stars, current_pet_name, outcome]
	)
	_pop_panel(result_panel)
	primary_button.text = "PRÓXIMO CLIENTE"
	primary_button.disabled = false
	progress_bar.hide()
	timer_label.hide()
	_refresh_economy()


func _fail(reason: StringName) -> void:
	bath.state = BathService.State.FAILED
	dragging = false
	EventBus.service_failed.emit(current_service, reason)
	Analytics.track(&"service_fail", {"type": String(current_service), "reason": String(reason)})
	world.react_to_failure()
	AudioManager.play(&"error")
	HapticsManager.error()
	result_title.text = "QUASE LÁ!"
	result_title.modulate = Color("ef5350")
	var action_name: String = "espuma" if current_service == &"bath" else "tosa"
	var hint: String
	if reason == &"timeout":
		hint = "O tempo acabou. Faça o movimento com mais ritmo!"
	elif reason == &"overwashed":
		hint = "%s demais. Pare assim que entrar na faixa verde." % action_name.capitalize()
	else:
		hint = "Leve a %s até a faixa verde antes de finalizar." % action_name
	result_detail.text = "★★☆☆☆\n%s\nSem punição — tente de novo." % hint
	_pop_panel(result_panel)
	primary_button.text = "TENTAR NOVAMENTE"
	primary_button.disabled = false
	progress_bar.hide()
	timer_label.hide()


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
	current_service = StringName(profile.get("preferred_service", "bath"))
	if GameState.services_completed % 5 == 4:
		current_service = &"groom"
	_configure_current_service()
	world.service_mode = current_service
	order_card.hide()
	instruction_label.text = "Novo cliente chegando..."
	primary_button.text = "SERVIR %s" % current_pet_name
	primary_button.disabled = true
	next_client_timer = 1.1


func _new_client() -> void:
	order_card.show()
	var service_name: String = "Banho simples" if current_service == &"bath" else "Tosa higiênica"
	var profile: Dictionary = ContentDB.pet(current_pet_id)
	order_label.text = (
		"%s\n%s • %s\n%d+ moedas"
		% [
			current_pet_name.to_upper(),
			profile.get("breed", "Pet especial"),
			service_name,
			12 if current_service == &"bath" else 20,
		]
	)
	primary_button.text = "SERVIR %s" % current_pet_name.to_upper()
	primary_button.disabled = false
	instruction_label.text = (
		"Faça carinho em %s ou toque em SERVIR para %s."
		% [current_pet_name, "dar banho" if current_service == &"bath" else "tosar"]
	)
	world.set_pet_profile(profile)
	world.arrive()
	var arrival_params: Dictionary = {
		"rarity": profile.get("rarity", "common"),
		"pet_id": current_pet_id,
		"species": profile.get("species", "dog"),
	}
	Analytics.track(&"pet_arrived", arrival_params)


func _configure_current_service() -> void:
	if current_service == &"groom":
		bath.configure(7.0, 0.78, 0.93, 1650.0)
	else:
		bath.configure(
			RemoteConfig.get_float("bath_duration"),
			RemoteConfig.get_float("bath_target_min"),
			RemoteConfig.get_float("bath_target_max"),
			1450.0
		)
	if is_instance_valid(perfect_zone):
		perfect_zone.anchor_left = bath.target_minimum
		perfect_zone.anchor_right = bath.target_maximum


func _on_upgrade_pressed() -> void:
	var cost: float = Economy.upgrade_cost(GameState.bath_upgrade_level)
	if GameState.buy_bath_upgrade():
		AudioManager.play(&"coin")
		HapticsManager.success()
		EventBus.toast_requested.emit(
			"Estação nível %d! Recompensa maior." % GameState.bath_upgrade_level, GREEN
		)
	else:
		EventBus.toast_requested.emit(
			"Faltam %d moedas" % int(cost - GameState.coins), Color("ef5350")
		)
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
	var cost: float = Economy.upgrade_cost(GameState.bath_upgrade_level)
	if GameState.bath_upgrade_level >= GameState.MAX_CAREER_LEVEL:
		upgrade_button.text = "ESTAÇÃO NO NÍVEL MÁXIMO"
		upgrade_button.disabled = true
	else:
		upgrade_button.disabled = false
		upgrade_button.text = (
			"MELHORAR ESTAÇÃO  Nv.%d\n%d moedas" % [GameState.bath_upgrade_level, int(cost)]
		)


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
	var record: Button = _button("● MOMENTO", Color("ef5350"), 155, 74)
	record.tooltip_text = "Exportação de clipe entra no Vertical Slice"
	record.pressed.connect(
		func() -> void:
			_show_toast("Momento marcado! Export no Vertical Slice.", PINK)
			Analytics.track(&"clip_marker", {"type": "bath"})
	)
	top_bar.add_child(record)

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
	bottom.size.y = 570
	bottom.position.y = 1350
	bottom.add_theme_stylebox_override("panel", _style(Color("fffaf3"), 54, 42, Color("e6cbb5"), 4))
	add_child(bottom)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	bottom.add_child(column)
	instruction_label = Label.new()
	instruction_label.text = "Faça carinho no Caramelo ou toque em SERVIR."
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 34)
	instruction_label.add_theme_color_override("font_color", CHARCOAL)
	instruction_label.custom_minimum_size.y = 52
	column.add_child(instruction_label)
	var progress_row: HBoxContainer = HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 20)
	column.add_child(progress_row)
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(790, 55)
	progress_bar.add_theme_stylebox_override("background", _style(Color("dbe6e8"), 25, 0))
	progress_bar.add_theme_stylebox_override("fill", _style(BLUE, 25, 0))
	perfect_zone = ColorRect.new()
	perfect_zone.color = Color("7ed957", 0.42)
	perfect_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	perfect_zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	perfect_zone.anchor_left = 0.82
	perfect_zone.anchor_right = 0.96
	perfect_zone.offset_left = 0.0
	perfect_zone.offset_right = 0.0
	progress_bar.add_child(perfect_zone)
	progress_row.add_child(progress_bar)
	timer_label = Label.new()
	timer_label.text = "6.0s"
	timer_label.add_theme_font_size_override("font_size", 34)
	timer_label.add_theme_color_override("font_color", CHARCOAL)
	timer_label.custom_minimum_size = Vector2(110, 55)
	progress_row.add_child(timer_label)
	progress_bar.hide()
	timer_label.hide()
	primary_button = _button("SERVIR CARAMELO", PINK, 0, 105)
	primary_button.pressed.connect(_on_primary_pressed)
	column.add_child(primary_button)
	upgrade_button = _button("MELHORAR BANHEIRA", BLUE, 0, 98)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	column.add_child(upgrade_button)
	var nav: HBoxContainer = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	column.add_child(nav)
	for item: Dictionary in [
		{"id": "missions", "label": "MISSÕES"},
		{"id": "collection", "label": "COLEÇÃO"},
		{"id": "map", "label": "MAPA"},
		{"id": "settings", "label": "AJUSTES"}
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
	result_panel.hide()

	toast_layer = Control.new()
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(toast_layer)


func _build_meta_panel() -> void:
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
	var close: Button = _button("VOLTAR AO PETSHOP", PINK, 0, 90)
	close.pressed.connect(func() -> void: meta_panel.hide())
	column.add_child(close)
	meta_panel.hide()


func _open_meta(section: StringName) -> void:
	_pop_panel(meta_panel)
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
	return style
