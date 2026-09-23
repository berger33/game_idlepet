extends Control
const BathServiceScript: Script = preload("res://core/gameplay/BathService.gd")
const PetShopCanvasScript: Script = preload("res://core/gameplay/PetShopCanvas.gd")
const MENU_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_perfume.png")
const NAV_ICONS: Dictionary = {
	&"missions": preload("res://art/ui/icons/missions.png"),
	&"collection": preload("res://art/ui/icons/collection.png"),
	&"album": preload("res://art/ui/icons/album.png"),
	&"staff": preload("res://art/ui/icons/staff.png"),
	&"shop": preload("res://art/ui/icons/shop.png"),
	&"map": preload("res://art/ui/icons/map.png"),
	&"settings": preload("res://art/ui/icons/settings.png"),
}
const PINK: Color = Color("ff8fb1")
const BLUE: Color = Color("4fc3f7")
const GREEN: Color = Color("2e7d32") # WCAG AA 5.13:1 com branco (antes 43a047 3.30:1)
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
	&"bath": "SERVICE_VERB_BATH",
	&"groom": "SERVICE_VERB_GROOM",
	&"dry": "SERVICE_VERB_DRY",
	&"perfume": "SERVICE_VERB_PERFUME",
	&"style": "SERVICE_VERB_STYLE"
}
func _service_verb(service: StringName) -> String:
	return Loc.t(String(SERVICE_LABELS.get(service, "SERVICE_VERB_BATH")))
const TutorialOverlayScript: Script = preload("res://scenes/main/TutorialOverlay.gd")
const UPGRADES_ICON: Texture2D = preload("res://art/ui/icons/upgrades.png")
const ParkServiceScript: Script = preload("res://core/gameplay/ParkService.gd")
const ParkCanvasScript: Script = preload("res://core/gameplay/ParkCanvas.gd")
const PARK_ICON: Texture2D = preload("res://art/backgrounds/petshop_quintal.png")
var bath: BathService
var world: PetShopCanvas
var coin_label: Label
var combo_label: Label
var goal_label: Label
var review_label: Label
var instruction_label: Label
var primary_button: Button
var share_button: Button
var upgrades_button: Button
var upgrades_pulse_time: float = 0.0
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var result_detail_extra: Label
var result_expand_btn: Button
var result_expanded: bool = false
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
var queue: Array[Dictionary] = [{}, {}, {}]
var selected_slot: int = -1
var refill_timers: Array[float] = [0.0, 0.0, 0.0]
var queue_row: HBoxContainer
var queue_cards: Array[Button] = []
var queue_name_labels: Array[Label] = []
var queue_service_labels: Array[Label] = []
var queue_info_labels: Array[Label] = []
var queue_bars: Array[ColorRect] = []
var current_vip: bool = false
var current_visitor: bool = false
var last_tip_percent: int = 0
var tutorial_overlay: Control
var tutorial_skip_button: Button
var missions_button: Button
var album_button: Button
var tutorial := TutorialFlow.new()
var recovery_penalty: bool = false
var consecutive_perfects: int = 0
var consecutive_fails: int = 0
var mood_buff_clients: int = 0
var assistance_clients: int = 0
var rush_cooldown: float = 240.0
var rush_left: float = 0.0
var rush_active: bool = false
var rush_label: Label
var rush_bar: ProgressBar
var proof_label: Label
var proof_timer: float = 0.0
var top_bar_scroll: ScrollContainer
var top_bar_hbox: HBoxContainer
var goal_collapsed: bool = true
var goal_expand_btn: Button
var goal_full_text: String = ""
var goal_preview_text: String = ""
var pending_special: StringName = &""
var special_active: bool = false
var special_multiplier: float = 1.0
var upsell_panel: PanelContainer
var upsell_label: Label
var upsell_accept: Button
var upsell_decline: Button
var petting_count: int = 0
var pending_special_result: Dictionary = {}
var last_stroke_index: int = 0
var last_zone_inside: bool = false
var perfume_hold_time: float = 0.0
var splash: Dictionary = {}
var splash_progress: float = 0.0
var splash_done: bool = false
# Cache de estilos da instruction_label (evita alocar StyleBoxFlat 60×/s)
var _instr_styles: Dictionary = {}
var _last_instr_key: StringName = &""
# ── Parquinho / Creche ──
var park_service: ParkService
var park_canvas: Control
var park_button: Button
var park_overlay: PanelContainer
var park_active: bool = false
var park_choose_panel: PanelContainer
var park_timer_label: Label
var park_dragging_ball: bool = false
var park_cooldown_tick: float = 0.0
func _ready() -> void:
	splash = SplashArt.make_splash(self)
	splash["root"].visible = false
	splash_progress = 0.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bath = BathServiceScript.new()
	park_service = ParkServiceScript.new()
	_configure_current_service()
	_build_interface()
	_setup_park()
	world.clear_room()
	if ResourceLoader.exists("res://art/pets/caramelo.png"): var _pc: Texture2D = load("res://art/pets/caramelo.png") as Texture2D
	queue[0] = SalonTuning.make_client_for_pet("caramelo", _available_services())
	for slot: int in [1, 2]: queue[slot] = SalonTuning.make_client(_available_services())
	_update_queue_ui()
	_connect_events()
	_refresh_economy()
	_refresh_proof_social()
	proof_timer = randf_range(8.0, 12.0)
	rush_cooldown = RemoteConfig.get_float("rush_interval_seconds")
	if GameState.services_completed > 0:
		SessionFeedback.show_offline_card(self)
		SessionFeedback.show_comeback(self)
	if GameState.tutorial_complete:
		LiveOps.claim_seasonal_gift()
	NotificationManager.permission_granted = bool(GameState.settings.get("notifications", false))
	NotificationManager.schedule_return_reminders(GameState.last_seen_unix)
	if GameState.tutorial_complete and GameState.unlocked_pets.has(GameState.favorite_pet):
		var buddy_name: String = String(ContentDB.pet(GameState.favorite_pet).get("name", "Pet"))
		_show_toast(Loc.t("BUDDY_VISIT") % buddy_name, PINK)
	if GameState.tutorial_complete:
		var deep_section: StringName = NotificationManager.deep_link_section()
		if deep_section != &"":
			meta.open(deep_section)
	tutorial.attach(self)
	tutorial.setup()
	if GameState.services_completed == 0 and not GameState.tutorial_complete:
		var intro: Dictionary = ChapterStories.intro(1)
		RevealCard.enqueue(self, {
			"title": "%s — %s" % [String(intro.get("title", "Quintal")), String(intro.get("act", ""))],
			"body": "%s\n\n%s" % [String(intro.get("text", "")), Loc.t("FIRST_PET_READY")],
			"color": GREEN,
			"primary": Loc.t("REVEAL_OK"),
			"sound": &"level_up"
		})
		if GameState.streak_freezes == 0:
			GameState.streak_freezes = 1
	Analytics.track(&"first_open" if GameState.services_completed == 0 else &"session_resume")
func _process(delta: float) -> void:
	# Splash barra progresso se carregamento >1s (P1)
	if not splash_done:
		splash_progress = minf(1.0, splash_progress + delta * 0.85)
		var still: bool = SplashArt.update_splash(splash, delta, splash_progress)
		if splash_progress >= 1.0:
			SplashArt.hide_splash(splash)
			splash_done = true
		if not still:
			splash_done = true
	bubble_sound_gate = maxf(0.0, bubble_sound_gate - delta)
	pet_touch_gate = maxf(0.0, pet_touch_gate - delta)
	wrong_tool_gate = maxf(0.0, wrong_tool_gate - delta)
	upgrades_pulse_time += delta
	if is_instance_valid(upgrades_button):
		var affordable_count: int = 0 if not GameState.tutorial_complete else SalonTuning.affordable_upgrades_count()
		if affordable_count > 0:
			var pulse: float = 0.5 + 0.5 * sin(upgrades_pulse_time * 3.2)
			upgrades_button.modulate = Color.WHITE.lerp(Color("d7ffb8"), pulse * 0.6)
			var badge: Label = upgrades_button.get_node_or_null("Badge") as Label
			if badge == null:
				badge = Label.new()
				badge.name = "Badge"
				badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				badge.add_theme_font_size_override("font_size", 28)
				badge.add_theme_color_override("font_color", Color.WHITE)
				badge.add_theme_stylebox_override("normal", _style(Color("ef5350"), 20, 6))
				badge.custom_minimum_size = Vector2(44, 44)
				badge.position = Vector2(52, -12)
				upgrades_button.add_child(badge)
			badge.text = str(affordable_count)
			badge.visible = true
		else:
			upgrades_button.modulate = Color.WHITE
			var badge: Label = upgrades_button.get_node_or_null("Badge") as Label
			if is_instance_valid(badge):
				badge.visible = false
		D1Retention.update_missions_badge(self, upgrades_pulse_time)
	# Álbum badge quando concurso liberado (sábado + 1 perfect)
	if is_instance_valid(album_button) and not album_button.disabled:
		if GameState.park_can_claim_contest():
			var pulse: float = 0.5 + 0.5 * sin(upgrades_pulse_time * 3.0)
			album_button.modulate = Color.WHITE.lerp(Color("ffd54f"), pulse * 0.45)
			var abadge: Label = album_button.get_node_or_null("Badge") as Label
			if abadge == null:
				abadge = Label.new()
				abadge.name = "Badge"
				abadge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				abadge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				abadge.add_theme_font_size_override("font_size", 26)
				abadge.add_theme_color_override("font_color", Color.WHITE)
				abadge.add_theme_stylebox_override("normal", _style(Color("ef5350"), 18, 6))
				abadge.custom_minimum_size = Vector2(38, 38)
				abadge.position = Vector2(44, -10)
				album_button.add_child(abadge)
			abadge.text = "★"
			abadge.visible = true
		else:
			album_button.modulate = Color.WHITE
			var abadge: Label = album_button.get_node_or_null("Badge") as Label
			if is_instance_valid(abadge):
				abadge.visible = false
	var left_handed: bool = bool(GameState.settings.get("left_handed", false))
	upgrades_button.position = Vector2(120, 150) if left_handed else Vector2(952, 150)
	if is_instance_valid(park_button):
		park_button.position = Vector2(952, 250) if not left_handed else Vector2(120, 250)
		_update_park_button()
	# ── Parquinho tick ──
	if park_active and park_service != null and park_service.state == ParkService.State.ACTIVE:
		if park_service.tick(delta):
			_finish_park(true) # timeout → fail
			return
		park_canvas.set_state(park_service.progress, park_service.time_left / park_service.duration if park_service.duration > 0 else 0.0, park_service.score)
		# sync ball pos para canvas
		if park_service.activity == ParkService.Activity.BALL:
			park_canvas.ball_pos = park_service.ball_pos
			park_canvas.playful_hop = park_service.playful_hop
		elif park_service.activity == ParkService.Activity.PHOTO:
			park_canvas.photo_align = park_service.photo_align
		park_canvas.treat_hidden_slot = park_service.treat_hidden_slot
		park_canvas.treat_choice = park_service.treat_choice
		park_canvas.treat_revealed = park_service.treat_revealed
		instruction_label.text = _park_instruction()
		# timeout visual já; progress bar em ParkCanvas
	if bath.state == BathService.State.ACTIVE:
		if bath.tick(delta):
			_fail(&"timeout")
			return
		world.progress = bath.progress
		world.service_time_ratio = bath.time_left / bath.duration_seconds if bath.duration_seconds > 0.0 else 0.0
		world.gesture_ui = GestureArt.gesture_snapshot(bath)
		world.playful_hop = bath.hopping
		# Estilo cacheado: 3 estados (perfect / over / hint) — sem alocar StyleBox a cada frame
		if _instr_styles.is_empty():
			_instr_styles[&"perfect"] = _style(Color(GREEN, 0.92), 34, 14, Color.WHITE, 4)
			_instr_styles[&"over"] = _style(Color("ef5350", 0.88), 34, 14, Color.WHITE, 3)
			_instr_styles[&"hint"] = _style(Color("263238", 0.82), 34, 14, Color("ffffff", 0.42), 2)
		if bath.progress >= bath.target_minimum and bath.progress <= bath.target_maximum:
			if _last_instr_key != &"perfect":
				_last_instr_key = &"perfect"
				instruction_label.text = "✓ SOLTE PARA PERFEITO!"
				instruction_label.add_theme_stylebox_override("normal", _instr_styles[&"perfect"] as StyleBoxFlat)
		elif bath.progress > bath.target_maximum:
			if _last_instr_key != &"over":
				_last_instr_key = &"over"
				instruction_label.text = "⚠ PASSOU! SOLTE E TENTE DE NOVO"
				instruction_label.add_theme_stylebox_override("normal", _instr_styles[&"over"] as StyleBoxFlat)
		elif bath.progress > 0.05 and bath.progress < bath.target_minimum:
			if _last_instr_key != &"hint":
				var hint_text: String = SalonTuning.hint(current_service)
				_last_instr_key = &"hint"
				instruction_label.text = hint_text
				instruction_label.add_theme_stylebox_override("normal", _instr_styles[&"hint"] as StyleBoxFlat)
		if bath.fill_mode == &"stroke":
			if bath.stroke_index != last_stroke_index and bath.stroke_index > 0:
				AudioManager.play(&"tool_pickup")
				HapticsManager.light()
				world.spawn_bubble(world.pet_focus() + Vector2(randf_range(-40, 40), -20))
			last_stroke_index = bath.stroke_index
		elif bath.fill_mode == &"zone":
			if bath.zone_inside != last_zone_inside:
				if bath.zone_inside:
					AudioManager.play(&"window")
					HapticsManager.light()
				last_zone_inside = bath.zone_inside
		elif bath.fill_mode == &"pulse":
			if world.tool_contact_valid and bath.pulse_bright():
				perfume_hold_time += delta
				if perfume_hold_time >= 0.32:
					perfume_hold_time = 0.0
					var spray: StringName = bath.pulse_contact()
					if spray == &"hit":
						AudioManager.play(StringName("spray_%d" % maxi(0, bath.pulses_hit - 1)))
						HapticsManager.light()
						world.spawn_bubble(world.pet_focus())
			else:
				perfume_hold_time = 0.0
	else:
		world.gesture_ui = {}
		world.playful_hop = false
		last_stroke_index = 0
		last_zone_inside = false
		perfume_hold_time = 0.0
		_last_instr_key = &""
	world.tool_levels = GameState.tool_upgrade_levels
	world.rush_active = rush_active
	world.vip_active = current_vip
	_update_rush(delta)
	_process_queue(delta)
func _input(event: InputEvent) -> void:
	if (
		meta.is_open()
		or (is_instance_valid(result_panel) and result_panel.visible)
		or (is_instance_valid(upsell_panel) and upsell_panel.visible)
	):
		return
	if park_active:
		if event is InputEventScreenTouch:
			var t: InputEventScreenTouch = event
			if t.pressed:
				_park_begin_pointer(t.position)
			else:
				_park_end_pointer()
			return
		elif event is InputEventScreenDrag:
			_park_move_pointer((event as InputEventScreenDrag).position)
			return
		elif event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_park_begin_pointer(mb.position)
				else:
					_park_end_pointer()
			return
		elif event is InputEventMouseMotion and park_dragging_ball:
			_park_move_pointer((event as InputEventMouseMotion).position)
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
			wrong_tool_gate = 1.2
			_show_toast("Use %s neste pedido" % SalonTuning.tool_display_name(required_tool), Color("ffd54f"))
			AudioManager.play(&"error_soft")
			var correct_pos: Vector2 = world.tool_shelf_position(required_tool)
			tutorial_overlay.show_step(Rect2(correct_pos - Vector2(80, 80), Vector2(160, 160)), "👉 Use %s aqui!" % SalonTuning.tool_display_name(required_tool))
			var timer: SceneTreeTimer = get_tree().create_timer(1.2)
			timer.timeout.connect(func() -> void:
				if tutorial_overlay.active:
					tutorial_overlay.finish()
			)
		return
	var contact_resumed: bool = not world.tool_contact_valid
	world.set_tool_contact(true)
	if bath.state == BathService.State.WAITING:
		_start_bath()
	if bath.state == BathService.State.ACTIVE and contact_resumed and bath.fill_mode == &"pulse":
		perfume_hold_time = 0.0
		var spray: StringName = bath.pulse_contact()
		if spray == &"hit":
			AudioManager.play(StringName("spray_%d" % maxi(0, bath.pulses_hit - 1)))
			HapticsManager.light()
			world.spawn_bubble(point)
		elif spray == &"miss":
			AudioManager.play(&"error_soft")
	_rub(point)
func _end_pointer() -> void:
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
	return point.distance_to(world.pet_focus()) < 245.0
func _react_to_pet_touch() -> void:
	if pet_touch_gate > 0.35:
		return
	if petting_count >= int(RemoteConfig.get_float("petting_max_per_client")):
		if pet_touch_gate <= 0.0:
			pet_touch_gate = 0.6
			world.react_to_touch()
			_show_toast(Loc.t("PETTING_LIMIT") % current_pet_name, PINK)
		return
	pet_touch_gate = 0.35
	petting_count += 1
	var message: String = world.react_to_touch()
	var affection: int = GameState.register_pet_interaction(current_pet_id)
	world.affection_level = affection
	AudioManager.play(&"pet_happy")
	HapticsManager.light()
	_show_toast("%s  •  %s" % [message, Loc.t("PETTING_COUNT") % affection], PINK)
	if GameState.services_completed == 0 and affection >= 3:
		instruction_label.text = Loc.t("FIRST_PET_READY")
	Analytics.track(&"pet_interacted", {"pet_id": current_pet_id, "kind": "pet"})
func _rub(point: Vector2) -> void:
	bath.rub(point)
	world.react_to_service(bath.progress)
	world.spawn_bubble(point)
	if bubble_sound_gate <= 0.0:
		AudioManager.play_gesture(current_service, bath)
		bubble_sound_gate = 0.16
	EventBus.service_progress.emit(bath.progress)
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if park_active:
		_close_park()
		return
	if meta.is_open():
		meta.close()
	elif is_instance_valid(result_panel) and result_panel.visible:
		_on_primary_pressed()
func _on_primary_pressed() -> void:
	if bath.state == BathService.State.COMPLETE or bath.state == BathService.State.FAILED:
		_dismiss_result()
	elif is_instance_valid(result_panel) and result_panel.visible:
		# Parquinho também usa o mesmo painel de resultado
		result_panel.hide()
		primary_button.hide()
		world.visible = true
		queue_row.visible = true
		park_canvas.visible = false
		instruction_label.text = Loc.t("CHOOSE_CLIENT")
		if _instr_styles.has(&"hint"):
			instruction_label.add_theme_stylebox_override("normal", _instr_styles[&"hint"] as StyleBoxFlat)
		_last_instr_key = &""
		_update_queue_ui()
func _start_bath() -> void:
	bath.start_service()
	tutorial.stop_teaching()
	world.begin_service()
	ShareManager.begin_snapshot(get_viewport(), world.pet_focus())
	instruction_label.text = SalonTuning.hint(current_service)
	AudioManager.play(&"service_start")
	Analytics.track(&"service_start", {"type": String(current_service)})
	EventBus.service_started.emit(current_service)
	if tutorial.step == 1:
		tutorial.advance()
func _finish_bath() -> void:
	var quality: StringName = bath.finish()
	if quality == &"perfect" or quality == &"good":
		world.complete_service()
		var used_tool: StringName = StringName(SERVICE_TOOLS[current_service])
		var mastery: Dictionary = GameState.register_tool_use(used_tool)
		var reward_result: Dictionary = SalonTuning.compute_reward({
			"service": current_service,
			"quality": quality,
			"pet_id": current_pet_id,
			"vip": current_vip,
			"buddy": world.buddy_active,
			"rush": rush_active,
			"special": special_multiplier,
			"mastery": SalonTuning.mastery_bonus(int(GameState.tool_uses.get(String(used_tool), 0))),
			"tool_level": int(GameState.tool_upgrade_levels.get(String(used_tool), 0)),
			"rand": randf(),
		})
		var reward: float = float(reward_result["reward"])
		last_tip_percent = int(reward_result["tip_percent"])
		if mastery.has("milestone"):
			_show_toast(
				Loc.t("MASTERY_TOAST") % [
					SalonTuning.tool_display_name(used_tool).strip_edges(), "★".repeat(int(mastery["milestone"]))
				],
				Color("ffd54f")
			)
			Analytics.track(
				&"tool_milestone", {"tool": String(used_tool), "milestone": int(mastery["milestone"])}
			)
		var stars: int = 5 if quality == &"perfect" else 4
		var reputation_before: int = GameState.reviews_sum
		GameState.register_review(stars)
		if Economy.neighborhood_tier(GameState.reviews_sum) > Economy.neighborhood_tier(
			reputation_before
		):
			EventBus.toast_requested.emit(Loc.t("REP_UP"), Color("ffd54f"))
			Analytics.track(
				&"neighborhood_tier_up", {"tier": Economy.neighborhood_tier(GameState.reviews_sum)}
			)
		if last_tip_percent > 0:
			GameState.register_weekly_event(&"tips")
		if current_vip:
			GameState.register_weekly_event(&"vip")
		if current_service == &"style":
			GameState.register_weekly_event(&"style")
		if current_visitor:
			Discovery.register_service(current_pet_id)
		EventBus.service_completed.emit(current_service, quality, reward)
		Analytics.track(
			&"service_complete",
			{"type": String(current_service), "quality": String(quality), "reward": reward}
		)
		if quality == &"perfect":
			Analytics.track(&"perfect_service")
		recovery_penalty = false
		if quality == &"perfect":
			consecutive_perfects += 1
			if consecutive_perfects >= 2:
				mood_buff_clients = 3
				world.forced_state = &"happy_squash"
				world.forced_state_time = 2.0
				_show_toast(Loc.t("MOOD_BUFF_TOAST"), GREEN)
				Analytics.track(&"mood_buff", {"streak": consecutive_perfects})
		else:
			consecutive_perfects = 0
		var client: Dictionary = queue[selected_slot] if selected_slot >= 0 else {}
		var offered: StringName = StringName(client.get("special", &""))
		if not special_active and offered != &"" and offered != current_service:
			_offer_special(offered, quality, reward, stars)
			return
		_show_success(quality, reward, stars)
	else:
		_fail(quality)
func _show_success(quality: StringName, reward: float, stars: int) -> void:
	world.celebrate(quality == &"perfect" or GameState.combo >= 5)
	AudioManager.play(&"perfect" if quality == &"perfect" else &"coin")
	HapticsManager.success()
	result_title.text = Loc.t("PERFECT_RESULT") if quality == &"perfect" else Loc.t("GOOD_RESULT")
	if current_vip:
		result_title.text = "👑 " + Loc.t("VIP_TAG") + "! " + result_title.text
	if tutorial.step == 2:
		tutorial.advance()
	if GameState.combo >= 5:
		result_title.text = Loc.t("RESULT_RHYTHM") % GameState.combo
		Analytics.track(&"combo_reached", {"level": GameState.combo})
	result_title.modulate = Color("ffd54f") if quality == &"perfect" else GREEN
	var xp_reward: int = 15 if quality == &"perfect" else 10
	xp_reward = int(xp_reward * (1.0 + GameState.staff_bonus(&"veterinary_xp")))
	var tip_line: String = Loc.t("TIP_LINE") % last_tip_percent if last_tip_percent > 0 else Loc.t("NO_TIP")
	if current_vip:
		tip_line = "👑 " + Loc.t("VIP_TAG") + " ×2 · " + tip_line
	var extra_line: String = ""
	if special_active:
		extra_line += "\n⭐ " + Loc.t("RESULT_SPECIAL")
	if world.buddy_active:
		extra_line += "\n🐾 " + Loc.t("RESULT_BUDDY")
	var coins_word: String = Loc.t("COINS") # agora "R$" / "$"
	var stars_text: String = "★".repeat(stars) + "☆".repeat(5 - stars)
	var thanks: String = PetStories.result_thanks(ContentDB.pet(current_pet_id), quality)
	var aff: int = int(GameState.pet_affection.get(current_pet_id, 0))
	var mem: String = PetStories.affection_memory(current_pet_id, aff)
	var proof: String = "💬 %s acabou de avaliar: %s" % [current_pet_name, stars_text]
	if not mem.is_empty():
		proof += "\n%s" % mem
	if GameState.services_completed == 0 and quality == &"perfect":
		GameState.embers += 1
		EventBus.currency_changed.emit(&"coins", GameState.coins)
		extra_line += "\n" + Loc.t("FIRST_BONUS")
		_show_toast(Loc.t("FIRST_BONUS"), Color("ffd54f"))
		world.celebration = 3.2
		world.special_reward_active = true
		_animate_first_confetti()
	# ── Resultado dinâmico: resumo sempre visível, história colapsável em ⓘ ──
	# Economia realista: exibe como R$ 88 (antes 🪙 12 Moedas)
	result_detail.text = "%s\n%s +%d  •  ✨ +%d XP\n%s" % [stars_text, coins_word, int(reward), xp_reward, tip_line]
	result_detail.tooltip_text = ""
	var extra_text: String = "%s\n%s%s" % [thanks, proof, extra_line]
	extra_text = extra_text.strip_edges()
	if is_instance_valid(result_detail_extra):
		if not extra_text.is_empty():
			result_detail_extra.text = extra_text
			result_detail_extra.tooltip_text = extra_text
			result_detail_extra.visible = false
			result_expanded = false
			if is_instance_valid(result_expand_btn):
				result_expand_btn.text = "ⓘ  Ver história"
				result_expand_btn.visible = true
		else:
			result_detail_extra.text = ""
			result_detail_extra.visible = false
			if is_instance_valid(result_expand_btn):
				result_expand_btn.visible = false
				result_expanded = false
	consecutive_fails = 0
	assistance_clients = 0
	if result_panel.has_meta("xp_bar"):
		var xp_bar: ColorRect = result_panel.get_meta("xp_bar") as ColorRect
		if is_instance_valid(xp_bar):
			var before_ratio: float = clampf(float(GameState.player_xp) / maxf(1.0, GameState.xp_to_next_level()), 0.0, 1.0)
			var after_xp: int = GameState.player_xp + xp_reward
			var after_ratio: float = clampf(float(after_xp) / maxf(1.0, GameState.xp_to_next_level()), 0.0, 1.0)
			xp_bar.color = Color("263238", 0.35)
			var fill: ColorRect = xp_bar.get_node_or_null("Fill") as ColorRect
			if fill == null:
				fill = ColorRect.new()
				fill.name = "Fill"
				fill.color = Color("4fc3f7")
				fill.custom_minimum_size = Vector2(0, 14)
				xp_bar.add_child(fill)
			fill.custom_minimum_size.x = xp_bar.custom_minimum_size.x * before_ratio
			var tween: Tween = xp_bar.create_tween()
			tween.tween_property(fill, "custom_minimum_size:x", xp_bar.custom_minimum_size.x * after_ratio, 0.6).set_trans(Tween.TRANS_QUAD)
	# Nota10 P2-12: share race fix — botão disabled até path pronto, await snapshot
	share_button.visible = false
	share_button.disabled = true
	_pop_panel(result_panel)
	primary_button.text = "✓  " + Loc.t("REVEAL_OK")
	primary_button.disabled = false
	primary_button.show()
	_animate_coin_fly(int(reward))
	_refresh_economy()
	# Aguarda snapshot assíncrono (frame_post_draw) e só então habilita share
	var saved_path: String = await ShareManager.finish_snapshot(get_viewport(), String(current_service), {"pet_id": current_pet_id, "stars": stars})
	if not saved_path.is_empty() and is_instance_valid(share_button):
		share_button.visible = true
		share_button.disabled = false
	else:
		if is_instance_valid(share_button):
			share_button.visible = false
func _fail(reason: StringName) -> void:
	bath.state = BathService.State.FAILED
	dragging = false
	dragged_tool = &""
	world.gesture_ui = {}
	world.playful_hop = false
	if reason == &"overwashed":
		world.forced_state = &"dizzy"
		world.forced_state_time = 3.0
		recovery_penalty = true
	elif reason == &"timeout":
		world.forced_state = &"sad"
		world.forced_state_time = 2.5
	consecutive_perfects = 0
	consecutive_fails += 1
	if consecutive_fails >= 3:
		assistance_clients = 3
		_show_toast(Loc.t("ASSIST_TOAST"), BLUE)
		consecutive_fails = 0
	EventBus.service_failed.emit(current_service, reason)
	Analytics.track(&"service_fail", {"type": String(current_service), "reason": String(reason), "streak": consecutive_fails})
	world.react_to_failure()
	AudioManager.play(&"error_soft" if reason == &"timeout" else &"error")
	HapticsManager.light()
	instruction_label.text = "💔 " + Loc.t("RESULT_ALMOST")
	instruction_label.add_theme_stylebox_override("normal", _style(Color("ef5350", 0.9), 34, 14, Color.WHITE, 4))
	result_title.text = Loc.t("RESULT_ALMOST")
	result_title.modulate = Color("ef5350")
	var action_name: String = _service_verb(current_service)
	var hint: String
	if reason == &"timeout":
		hint = Loc.t("FAIL_TIMEOUT")
	elif reason == &"overwashed":
		hint = Loc.t("FAIL_OVERWASHED") % action_name.capitalize()
	else:
		hint = Loc.t("FAIL_TOO_SOON") % action_name
	var assistance_line: String = ""
	if assistance_clients > 0:
		assistance_line = "\n" + Loc.t("ASSIST_ACTIVE") % assistance_clients
	# ── Fail dinâmico: dica curta + detalhe colapsável ──
	result_detail.text = "★★☆☆☆\n%s" % hint
	result_detail.tooltip_text = hint
	var fail_extra: String = "%s%s" % [Loc.t("FAIL_NO_PENALTY"), assistance_line]
	fail_extra = fail_extra.strip_edges()
	if is_instance_valid(result_detail_extra):
		if not fail_extra.is_empty():
			result_detail_extra.text = fail_extra
			result_detail_extra.tooltip_text = fail_extra
			result_detail_extra.visible = false
			result_expanded = false
			if is_instance_valid(result_expand_btn):
				result_expand_btn.text = "ⓘ  Ver dica"
				result_expand_btn.visible = true
		else:
			result_detail_extra.text = ""
			result_detail_extra.visible = false
			if is_instance_valid(result_expand_btn):
				result_expand_btn.visible = false
				result_expanded = false
	share_button.visible = false
	_pop_panel(result_panel)
	primary_button.text = "↻  " + Loc.t("TRY_AGAIN")
	primary_button.disabled = false
	primary_button.show()
	if tutorial.step == 2:
		tutorial.advance()
func _dismiss_result() -> void:
	result_panel.hide()
	world.reset_pet()
	world.depart()
	world.clear_room()
	world.gesture_ui = {}
	world.buddy_active = false
	bath = BathServiceScript.new()
	if selected_slot >= 0:
		queue[selected_slot] = {}
		refill_timers[selected_slot] = _refill_delay()
	selected_slot = -1
	current_vip = false
	special_active = false
	pending_special = &""
	pending_special_result = {}
	special_multiplier = 1.0
	mood_buff_clients = maxi(0, mood_buff_clients - 1)
	if assistance_clients > 0: assistance_clients -= 1
	instruction_label.text = Loc.t("CHOOSE_CLIENT")
	if _instr_styles.has(&"hint"):
		instruction_label.add_theme_stylebox_override("normal", _instr_styles[&"hint"] as StyleBoxFlat)
	_last_instr_key = &""
	primary_button.hide()
	_update_queue_ui()
	if GameState.services_completed == 1: D1Retention.show_daily_login(self)
	if GameState.services_completed == 2: D1Retention.show_tomorrow_card(self)
	if GameState.services_completed == 3: D1Retention.show_notif_prompt(self)
	if GameState.services_completed == 1 and String(GameState.settings.get("shop_name", "")).is_empty():
		var daily_shown: bool = GameState.settings.get("daily_popup_shown_today", "") == Time.get_date_string_from_system()
		_show_toast("🏷️ " + Loc.t("SHOP_NAME") + "? " + Loc.t("SHOP_NAME_HINT"), BLUE)
		if not daily_shown:
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				if not meta.is_open() and not result_panel.visible and not upsell_panel.visible:
					meta.open(&"settings")
			, CONNECT_ONE_SHOT)
func _refill_delay() -> float:
	# Respiro na fila: 3.8s normal (antes 1.1s), 1.4s no rush (antes 0.35s) — pet fica visível
	var base: float = 1.4 if rush_active else 3.8
	if GameState.establishment_tier >= 6:
		base *= 0.6 # segunda sala ainda ajuda, mas 40% menos frênetica (antes 0.5)
	return base
func _update_rush(delta: float) -> void:
	if rush_active:
		rush_left -= delta
		if rush_left <= 0.0: _end_rush()
	else:
		if bool(GameState.tutorial_complete) and not result_panel.visible and not upsell_panel.visible:
			rush_cooldown -= delta
			if rush_cooldown <= 0.0: _start_rush()
	RushTuning.update_rush_labels(rush_active, rush_left, rush_cooldown, rush_label, rush_bar)
	proof_timer -= delta
	if proof_timer <= 0.0:
		proof_timer = randf_range(8.0, 12.0)
		_refresh_proof_social()
func _start_rush() -> void:
	rush_active = true
	rush_left = RemoteConfig.get_float("rush_duration")
	GameState.rush_combo_protection = true
	_show_toast(Loc.t("RUSH_TOAST"), Color("ffb300"))
	Analytics.track(&"rush_started", {})
	for slot: int in 3:
		if queue[slot].is_empty():
			refill_timers[slot] = minf(refill_timers[slot], 1.2) # respiro rush (antes 0.5)
func _end_rush() -> void:
	rush_active = false
	GameState.rush_combo_protection = false
	rush_cooldown = RemoteConfig.get_float("rush_interval_seconds")
	if is_instance_valid(rush_label):
		rush_label.text = ""
func _offer_special(
	offered: StringName, quality: StringName, reward: float, stars: int
) -> void:
	pending_special = offered
	pending_special_result = {"quality": quality, "reward": reward, "stars": stars}
	var service_name: String = _service_verb(offered).capitalize()
	upsell_label.text = (
		"%s adoraria também um %s!\nAceitar o pedido?" % [current_pet_name, service_name]
	)
	world.forced_state = &"happy_squash"
	world.forced_state_time = 1.6
	Analytics.track(&"upsell_offered", {"service": String(offered)})
	_pop_panel(upsell_panel)
func _on_upsell_accept() -> void:
	upsell_panel.hide()
	special_active = true
	special_multiplier = RemoteConfig.get_float("upsell_tip_mult")
	current_service = pending_special
	bath = BathServiceScript.new()
	world.progress = 0.0
	world.forced_state = &""
	_configure_current_service()
	instruction_label.text = SalonTuning.hint(current_service)
	Analytics.track(&"upsell_accepted", {"service": String(current_service)})
func _on_upsell_decline() -> void:
	upsell_panel.hide()
	var result: Dictionary = pending_special_result
	pending_special = &""
	pending_special_result = {}
	Analytics.track(&"upsell_declined", {"service": String(current_service)})
	_show_success(
		StringName(result.get("quality", &"good")),
		float(result.get("reward", 0.0)),
		int(result.get("stars", 4)),
	)
func _on_queue_pressed(slot: int) -> void:
	if not _can_select(slot):
		return
	if queue[slot].is_empty():
		refill_timers[slot] = minf(refill_timers[slot], 0.80) # toque acelera mas ainda respirável (antes 0.25)
		_show_toast("⏩ " + Loc.t("QUEUE_SPEEDUP"), GREEN)
		AudioManager.play(&"tap")
		HapticsManager.light()
		Analytics.track(&"queue_sped_up", {"slot": slot})
		_update_queue_ui()
		return
	selected_slot = slot
	var client: Dictionary = queue[slot]
	current_vip = bool(client.get("vip", false))
	current_visitor = bool(client.get("visitor", false))
	current_pet_id = String(client["pet"])
	current_service = StringName(client["service"])
	petting_count = 0
	special_active = false
	special_multiplier = 1.0
	pending_special = StringName(client.get("special", &""))
	var profile: Dictionary = ContentDB.pet(current_pet_id)
	current_pet_name = ContentDB.pet_name(current_pet_id)
	_configure_current_service()
	world.set_service_layout(current_service)
	world.set_pet_profile(profile)
	world.affection_level = int(GameState.pet_affection.get(current_pet_id, 0))
	world.buddy_active = (
		GameState.bath_upgrade_level >= 30
		and GameState.favorite_pet != current_pet_id
		and GameState.unlocked_pets.has(GameState.favorite_pet)
	)
	world.buddy_pet_id = GameState.favorite_pet
	world.vip_active = current_vip
	world.arrive()
	_refresh_economy()
	var required_tool: StringName = StringName(SERVICE_TOOLS[current_service])
	instruction_label.text = (
		Loc.t("DRAG_TOOL_TO") % [SalonTuning.tool_display_name(required_tool), current_pet_name]
	)
	tutorial.teach_service(current_service)
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
	if tutorial.step == 0:
		tutorial.advance()
func _can_select(slot: int) -> bool:
	if park_active: return false
	if selected_slot != -1: return false
	if is_instance_valid(result_panel) and result_panel.visible: return false
	if meta.is_open(): return false
	if queue[slot].is_empty(): return refill_timers[slot] > 0.15
	return true
func _process_queue(delta: float) -> void:
	for slot: int in 3:
		if refill_timers[slot] > 0.0:
			refill_timers[slot] -= delta
			if refill_timers[slot] <= 0.0:
				queue[slot] = SalonTuning.make_client(_available_services())
				_update_queue_ui()
		elif (
			not queue[slot].is_empty()
			and slot != selected_slot
			and bool(GameState.tutorial_complete)
		):
			var patience_drain: float = delta * 0.65 * (1.0 - Research.bonus(&"patience")) # 35% mais lento base
			if rush_active:
				patience_drain *= 0.45 # rush mais humano (antes 0.5)
			if mood_buff_clients > 0:
				patience_drain *= 0.9
			if GameState.establishment_tier >= 6:
				patience_drain *= 0.85 # Nota10: segunda sala funcional
			queue[slot]["wait_left"] = float(queue[slot]["wait_left"]) - patience_drain
			if float(queue[slot]["wait_left"]) <= 0.0:
				_client_left(slot)
	for slot: int in 3:
		var client: Dictionary = queue[slot]
		if client.is_empty():
			queue_bars[slot].custom_minimum_size.x = 0.0
		else:
			var ratio: float = clampf(float(client["wait_left"]) / float(client["wait_total"]), 0.0, 1.0)
			var bg: Control = queue_bars[slot].get_parent() as Control
			var total_w: float = bg.custom_minimum_size.x if is_instance_valid(bg) else 296.0
			queue_bars[slot].custom_minimum_size.x = total_w * ratio
			queue_bars[slot].color = Color("ef5350") if ratio <= 0.25 else (Color("ffd54f") if ratio <= 0.5 else GREEN)
		queue_cards[slot].disabled = not _can_select(slot)
func _client_left(slot: int) -> void:
	var client: Dictionary = queue[slot]
	var leaver_id: String = String(client["pet"])
	var leaver_name: String = ContentDB.pet_name(leaver_id) if ContentDB.has_pet(leaver_id) else String(ContentDB.pet(leaver_id).get("name", "Alguém"))
	var profile: Dictionary = ContentDB.pet(leaver_id) if ContentDB.has_pet(leaver_id) else {}
	var base: float = SalonTuning.base_reward(StringName(client.get("service", &"bath")))
	var lost: int = int(base * float(profile.get("base_tip", 1.0)) * 1.2)
	_show_toast(Loc.t("CLIENT_LEFT_COINS") % [leaver_name, lost], Color("ef5350"))
	world.forced_state = &"sad"; world.forced_state_time = 1.2
	Analytics.track(&"client_left", {"pet_id": String(client["pet"]), "lost_coins": lost})
	queue[slot] = {}; refill_timers[slot] = 3.5 if not rush_active else 1.2 # cliente foi embora: respiro maior (antes 2.0/0.6)
	_update_queue_ui()
func _update_queue_ui() -> void:
	for slot: int in 3:
		var client: Dictionary = queue[slot]
		if client.is_empty():
			var dots: String = ".".repeat(int(fmod(upgrades_pulse_time * 2.0, 3.0)) + 1)
			queue_name_labels[slot].text = "%s%s" % [Loc.t("QUEUE_ARRIVING"), dots]
			queue_service_labels[slot].text = "🐾 " + Loc.t("QUEUE_WAITING")
			var reload_txt: String = Loc.t("QUEUE_RELOAD") % refill_timers[slot] if refill_timers[slot] > 0.0 else ""
			queue_info_labels[slot].text = "%s\n👆 %s" % [reload_txt, Loc.t("QUEUE_SPEEDUP")] if not reload_txt.is_empty() else "👆 %s" % Loc.t("QUEUE_SPEEDUP")
			queue_cards[slot].modulate.a = 0.75 + 0.20 * sin(upgrades_pulse_time * 3.0 + slot)
			queue_cards[slot].add_theme_stylebox_override("panel", _style(Color("ffffff", 0.92), 26, 16, Color("4fc3f7"), 3))
		else:
			var pet_id_q: String = String(client["pet"])
			var profile: Dictionary = ContentDB.pet(pet_id_q)
			var client_name: String = ContentDB.pet_name(pet_id_q)
			if bool(client["vip"]):
				client_name = "👑 VIP " + client_name
			if bool(client.get("visitor", false)):
				client_name = "✦ " + client_name
			if String(client["pet"]) == GameState.favorite_pet:
				client_name += " • " + Loc.t("BUDDY_TAG")
			# D0: primeiro slot com Caramelo mostra RECOMENDADO
			if slot == 0 and GameState.services_completed == 0:
				client_name = "⭐ " + client_name
			queue_name_labels[slot].text = client_name
			var service_text: String = _service_verb(StringName(client["service"])).capitalize()
			if StringName(client.get("special", &"")) != &"":
				service_text += " + ★"
			if slot == 0 and GameState.services_completed == 0:
				service_text += " • %s" % Loc.t("RECOMMENDED_TAG")
			queue_service_labels[slot].text = service_text
			var base_info: String = (
				Loc.t("VISITOR_TAG") % [Discovery.progress(String(client["pet"])), Discovery.VISITS_TO_ADOPT]
				if bool(client.get("visitor", false))
				else SalonTuning.queue_info_text(profile)
			)
			var story_line: String = PetStories.queue_story(profile, String(client.get("service", "bath")))
			# ── Fila dinâmica: compacta 1 linha + ⓘ para história ──
			if not story_line.is_empty():
				# mostra só trade-off essencial, história vira detalhe sob demanda
				queue_info_labels[slot].text = base_info + "  ⓘ"
				queue_info_labels[slot].tooltip_text = story_line
				queue_cards[slot].tooltip_text = story_line + "\n" + base_info
			else:
				queue_info_labels[slot].text = base_info
				queue_info_labels[slot].tooltip_text = ""
				queue_cards[slot].tooltip_text = base_info
			var border: Dictionary = SalonTuning.queue_border(profile)
			# D0: borda verde no recomendado
			var border_color: Color = GREEN if slot == 0 and GameState.services_completed == 0 else border["color"]
			var border_w: int = 4 if slot == 0 and GameState.services_completed == 0 else int(border["width"])
			queue_cards[slot].add_theme_stylebox_override(
				"panel",
				_style(Color("ffffff", 0.96), 26, 16, border_color, border_w)
			)
			queue_cards[slot].modulate.a = 1.0
			queue_cards[slot].disabled = not _can_select(slot)
func _configure_current_service() -> void:
	# Ritmo confortável: serviços 40% mais longos para o pet respirar em cena
	var duration: float = {&"bath": 14.0, &"groom": 16.0, &"dry": 13.0, &"perfume": 12.0, &"style": 12.0}.get(current_service, 14.0)
	var required_distance: float = {&"bath": 2100.0, &"groom": 2400.0, &"dry": 1800.0, &"perfume": 1050.0, &"style": 1500.0}.get(current_service, 2100.0)
	var patience: float = float(ContentDB.pet(current_pet_id).get("patience", 42))
	var pf: float = clampf(patience / 42.0, 0.6, 1.25) + GameState.staff_bonus(&"patience")
	pf = RushTuning.patience_factor(pf, assistance_clients)
	if GameState.services_completed == 0: pf *= 1.15; required_distance *= 0.85 # tutorial mais curto que antes 1.3/0.8 para não disparar
	if current_service == &"bath": required_distance *= 1.0 - GameState.staff_bonus(&"bath_speed") * 0.7 # staff acelera 30% menos
	var wb: float = GameState.staff_bonus(&"perfect_window")
	if current_service == &"groom": wb += GameState.staff_bonus(&"groom_quality")
	wb = RushTuning.window_bonus(wb, assistance_clients)
	if GameState.services_completed == 0: wb += 0.15
	var t_min: float = RemoteConfig.get_float("bath_target_min")
	var t_max: float = minf(RemoteConfig.get_float("bath_target_max") + wb, 1.0)
	if current_service == &"perfume": t_min = 0.95; t_max = 1.0
	bath.configure(duration * pf, t_min, t_max, required_distance)
	var gesture: Dictionary = SalonTuning.GESTURES.get(current_service, SalonTuning.GESTURES[&"bath"])
	bath.configure_gesture(gesture["axis"], gesture["mode"], gesture["cap"], gesture["rate"])
	SalonTuning.apply(bath, current_service, ContentDB.pet(current_pet_id), GameState.tool_upgrade_levels, recovery_penalty, world.pet_focus() if is_instance_valid(world) else Vector2(540, 990))
	if is_instance_valid(world):
		world.set_service_layout(current_service)
		world.player_level = GameState.player_level
		world.establishment_tier = GameState.establishment_tier
func _available_services() -> Array[StringName]:
	var result: Array[StringName] = []
	for service: StringName in SERVICE_UNLOCK_LEVELS:
		if GameState.player_level >= int(SERVICE_UNLOCK_LEVELS[service]):
			result.append(service)
	return result if not result.is_empty() else [&"bath"]

# ── Parquinho helpers ──
func _setup_park() -> void:
	# Canvas do parquinho (quintal) — oculto até abrir — harden contra dupla chamada / godot headless
	if is_instance_valid(park_canvas) and park_canvas.is_inside_tree():
		return
	park_canvas = ParkCanvasScript.new()
	park_canvas.visible = false
	park_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(park_canvas)
	move_child(park_canvas, 1) # atrás do HUD mas à frente do mundo
	# Botão Parquinho — ao lado do botão Upgrades, com cooldown visual
	var safe_top: float = 0.0
	if SalonTuning != null and SalonTuning.has_method("safe_area_top"):
		safe_top = SalonTuning.safe_area_top()
	# safe_top atualmente não usado no posicionamento, mas guard para compat
	park_button = _button("🌳", Color("8bc34a", 0.96), 86, 86)
	park_button.position = Vector2(952, 250 + safe_top * 0.5)
	park_button.tooltip_text = Loc.t("PARK_BUTTON") if Loc.has_method("t") and Loc.t("PARK_BUTTON") != "PARK_BUTTON" else "Parquinho"
	park_button.add_theme_stylebox_override("normal", _style(Color("8bc34a", 0.96), 43, 6, Color.WHITE, 4))
	park_button.add_theme_stylebox_override("hover", _style(Color("9ccc65", 0.98), 43, 6, Color.WHITE, 5))
	park_button.add_theme_stylebox_override("pressed", _style(Color("689f38", 1.0), 43, 8, Color.WHITE, 4))
	park_button.pressed.connect(_on_park_button)
	add_child(park_button)
	# Painel de escolha de atividade (3 botões) — 560h evita sobrepor instruction_label em 1350
	park_choose_panel = PanelContainer.new()
	park_choose_panel.visible = false
	park_choose_panel.position = Vector2(60, 740)
	park_choose_panel.size = Vector2(960, 560)
	park_choose_panel.add_theme_stylebox_override("panel", _style(Color.WHITE, 28, 18, Color("8bc34a"), 4))
	add_child(park_choose_panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	park_choose_panel.add_child(vbox)
	var title: Label = Label.new()
	title.text = Loc.t("PARK_TITLE") if Loc.t("PARK_TITLE") != "PARK_TITLE" else "🌳  Parquinho  —  escolha a brincadeira"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("33691e"))
	title.add_theme_stylebox_override("normal", _style(Color("f1f8e9"), 18, 10))
	vbox.add_child(title)
	var pets_line: Label = Label.new()
	pets_line.name = "ParkPetsLine"
	pets_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pets_line.add_theme_font_size_override("font_size", 22)
	pets_line.add_theme_color_override("font_color", Color("558b2f"))
	vbox.add_child(pets_line)
	for act: Dictionary in [
		{"id": &"ball", "emoji": "🎾", "key": "PARK_BALL"},
		{"id": &"treat", "emoji": "🦴", "key": "PARK_TREAT"},
		{"id": &"photo", "emoji": "📸", "key": "PARK_PHOTO"},
	]:
		var btn: Button = _button("%s  %s" % [act["emoji"], Loc.t(String(act["key"])) if Loc.t(String(act["key"])) != String(act["key"]) else String(act["key"])], Color("fff3e0"), 900, 78)
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", Color("3e2723"))
		btn.add_theme_stylebox_override("normal", _style(Color("fff3e0"), 22, 10, Color("ffcc80"), 3))
		btn.add_theme_stylebox_override("hover", _style(Color("ffe0b2"), 22, 10, Color.WHITE, 3))
		btn.pressed.connect(_start_park_activity.bind(StringName(act["id"])))
		vbox.add_child(btn)
	var album_btn: Button = _button("📖  %s (%d)" % [(Loc.t("ALBUM_TITLE") if Loc.t("ALBUM_TITLE") != "ALBUM_TITLE" else "Álbum"), GameState.park_photos.size()], Color("e1bee7"), 900, 68)
	album_btn.add_theme_font_size_override("font_size", 24)
	album_btn.add_theme_color_override("font_color", Color("4a148c"))
	album_btn.tooltip_text = Loc.t("ALBUM_TROPHIES") % GameState.park_trophies if Loc.t("ALBUM_TROPHIES") != "ALBUM_TROPHIES" else "Troféus: %d" % GameState.park_trophies
	album_btn.pressed.connect(func() -> void:
		_close_park()
		meta.open(&"album")
	)
	vbox.add_child(album_btn)
	var close_btn: Button = _button(Loc.t("PARK_CLOSE") if Loc.t("PARK_CLOSE") != "PARK_CLOSE" else "✕  Fechar", Color("90a4ae"), 900, 56)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(_close_park)
	vbox.add_child(close_btn)
	park_timer_label = Label.new()
	park_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	park_timer_label.add_theme_font_size_override("font_size", 18)
	park_timer_label.add_theme_color_override("font_color", Color("689f38"))
	vbox.add_child(park_timer_label)
	_update_park_button()

func _park_format_cooldown(sec: int) -> String:
	if sec <= 0:
		return Loc.t("PARK_READY") if Loc.has_method("t") and Loc.t("PARK_READY") != "PARK_READY" else "Pronto!"
	if sec < 60:
		return "%ds" % sec
	var m: int = sec / 60
	var s: int = sec % 60
	if sec < 3600:
		return "%d:%02d" % [m, s]
	var h: int = sec / 3600
	m = (sec % 3600) / 60
	return "%dh %02dm" % [h, m]

func _update_park_button() -> void:
	if not is_instance_valid(park_button):
		return
	# harden: GameState pode ainda não ter sido preenchido no primeiro frame
	if GameState == null:
		return
	# Progressive disclosure: parquinho libera após 1 atendimento (tutorial feito) — não sobrecarrega D0
	var locked: bool = GameState.services_completed == 0 and GameState.player_level < 2
	if locked and not park_active:
		park_button.text = "🔒"
		park_button.tooltip_text = Loc.t("PARK_LOCKED") if Loc.has_method("t") and Loc.t("PARK_LOCKED") != "PARK_LOCKED" else "Desbloqueia após o 1º atendimento"
		park_button.disabled = false
		park_button.modulate = Color("ffffff", 0.85)
		park_button.add_theme_stylebox_override("normal", _style(Color("90a4ae", 0.96), 43, 6, Color.WHITE, 3))
		return
	else:
		# só reaplica style se já tem um válido (evita flood de StyleBoxFlat no GC)
		if park_button.has_theme_stylebox_override("normal"):
			park_button.add_theme_stylebox_override("normal", _style(Color("8bc34a", 0.96), 43, 6, Color.WHITE, 4))
	var remain: int = GameState.park_remaining_seconds()
	if park_active:
		park_button.text = "✕"
		park_button.tooltip_text = Loc.t("PARK_CLOSE") if Loc.t("PARK_CLOSE") != "PARK_CLOSE" else "Sair do parquinho"
		park_button.disabled = false
		park_button.modulate = Color.WHITE
		return
	if remain > 0:
		park_button.text = "⏳ %s" % _park_format_cooldown(remain)
		park_button.add_theme_font_size_override("font_size", 18)
		park_button.tooltip_text = (Loc.t("PARK_COOLDOWN") % _park_format_cooldown(remain)) if Loc.has_method("t") and Loc.t("PARK_COOLDOWN") != "PARK_COOLDOWN" else "Volta em %s" % _park_format_cooldown(remain)
		park_button.disabled = false
		park_button.modulate = Color("ffffff", 0.88)
		# quando em cooldown, leve pulse cinza
		var badge: Label = park_button.get_node_or_null("Badge") as Label
		if badge != null:
			badge.visible = false
	else:
		park_button.text = "🌳"
		park_button.add_theme_font_size_override("font_size", 34)
		var streak: int = GameState.park_streak if GameState != null else 0
		var tip: String = Loc.t("PARK_BUTTON") if Loc.has_method("t") and Loc.t("PARK_BUTTON") != "PARK_BUTTON" else "Parquinho"
		if streak > 1:
			tip += " • 🔥%d" % streak
		park_button.tooltip_text = tip
		park_button.disabled = false
		# brilho quando pronto
		if not GameState.park_plays_total == 0:
			var pulse: float = 0.5 + 0.5 * sin(upgrades_pulse_time * 2.6)
			park_button.modulate = Color.WHITE.lerp(Color("dcedc8"), pulse * 0.5)
		else:
			park_button.modulate = Color.WHITE
		# badge "!" na primeira vez
		if GameState.park_plays_total == 0:
			var badge: Label = park_button.get_node_or_null("Badge") as Label
			if badge == null:
				badge = Label.new()
				badge.name = "Badge"
				badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				badge.add_theme_font_size_override("font_size", 28)
				badge.add_theme_color_override("font_color", Color.WHITE)
				badge.add_theme_stylebox_override("normal", _style(Color("ef5350"), 20, 6))
				badge.custom_minimum_size = Vector2(44, 44)
				badge.position = Vector2(52, -12)
				park_button.add_child(badge)
			badge.text = "!"
			badge.visible = true
		else:
			var badge: Label = park_button.get_node_or_null("Badge") as Label
			if is_instance_valid(badge):
				badge.visible = false

func _on_park_button() -> void:
	if not is_inside_tree() or GameState == null:
		return
	if park_active:
		_close_park()
		return
	var locked: bool = GameState.services_completed == 0 and GameState.player_level < 2
	if locked:
		_show_toast(Loc.t("PARK_LOCKED_TOAST") if Loc.has_method("t") and Loc.t("PARK_LOCKED_TOAST") != "PARK_LOCKED_TOAST" else "Termine seu primeiro atendimento para liberar o Parquinho!", Color("90a4ae"))
		if AudioManager != null and AudioManager.has_method("play"):
			AudioManager.play(&"error_soft")
		return
	if not GameState.park_can_play():
		var remain: int = GameState.park_remaining_seconds()
		_show_toast((Loc.t("PARK_COOLDOWN_TOAST") % _park_format_cooldown(remain)) if Loc.has_method("t") and Loc.t("PARK_COOLDOWN_TOAST") != "PARK_COOLDOWN_TOAST" else "Parquinho volta em %s — os pets estão tirando uma soneca!" % _park_format_cooldown(remain), Color("90a4ae"))
		if AudioManager != null and AudioManager.has_method("play"):
			AudioManager.play(&"error_soft")
		return
	_open_park_choose()

func _open_park_choose() -> void:
	if not is_inside_tree() or not is_instance_valid(park_choose_panel) or not is_instance_valid(park_canvas):
		return
	park_active = true
	if GameState != null:
		GameState.park_ensure_pets()
	var ids: Array[String] = GameState.park_pets if GameState != null else ["caramelo", "caramelo", "caramelo"]
	if ids.size() != 3:
		ids = ["caramelo", "caramelo", "caramelo"]
	park_canvas.set_pets(ids)
	park_canvas.visible = true
	if is_instance_valid(world):
		world.visible = false
	if is_instance_valid(queue_row):
		queue_row.visible = false
	# atualiza linha de pets no painel de escolha
	var pets_line: Label = park_choose_panel.get_node_or_null("VBoxContainer/ParkPetsLine") as Label
	if pets_line == null:
		# fallback busca recursiva
		pets_line = park_choose_panel.find_child("ParkPetsLine", true, false) as Label
	if is_instance_valid(pets_line):
		var names: Array[String] = []
		for pid: String in ids:
			var nm: String = "?"
			if ContentDB != null and ContentDB.has_method("pet_name"):
				nm = ContentDB.pet_name(pid)
				if nm.is_empty():
					nm = pid.capitalize()
			else:
				nm = pid.capitalize()
			names.append(nm)
		pets_line.text = "🐾  %s, %s & %s" % [names[0] if names.size() > 0 else "?", names[1] if names.size() > 1 else "?", names[2] if names.size() > 2 else "?"]
	park_choose_panel.visible = true
	park_choose_panel.modulate.a = 0.0
	park_choose_panel.scale = Vector2(0.92, 0.92)
	if is_inside_tree():
		var tw: Tween = park_choose_panel.create_tween().set_parallel(true)
		tw.tween_property(park_choose_panel, "modulate:a", 1.0, 0.18)
		tw.tween_property(park_choose_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	if is_instance_valid(instruction_label):
		instruction_label.text = Loc.t("PARK_CHOOSE") if Loc.has_method("t") and Loc.t("PARK_CHOOSE") != "PARK_CHOOSE" else "Escolha como cuidar dos 3 no quintal"
		instruction_label.add_theme_stylebox_override("normal", _style(Color("33691e", 0.88), 34, 14, Color.WHITE, 3))
	if is_instance_valid(park_timer_label) and GameState != null:
		var streak_txt: String = ""
		if GameState.park_streak > 0:
			streak_txt = (Loc.t("PARK_STREAK") % GameState.park_streak) if Loc.has_method("t") and Loc.t("PARK_STREAK") != "PARK_STREAK" else "🔥 %d dias seguidos no parquinho" % GameState.park_streak
		park_timer_label.text = streak_txt
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"window")
	if Analytics != null and Analytics.has_method("track"):
		Analytics.track(&"park_opened", {"pets": ids})

func _start_park_activity(id: StringName) -> void:
	if not is_instance_valid(park_choose_panel) or park_service == null or not is_instance_valid(park_canvas):
		return
	park_choose_panel.visible = false
	var activity_str: String = String(id)
	park_service.configure(id)
	park_service.start()
	if GameState != null and GameState.has_method("park_start_session"):
		GameState.park_start_session(activity_str)
	park_canvas.set_activity(id)
	park_canvas.visible = true
	park_dragging_ball = false
	# esconde nav fantasiado? mantém HUD
	if is_instance_valid(instruction_label):
		instruction_label.text = _park_instruction()
		instruction_label.add_theme_stylebox_override("normal", _style(Color("33691e", 0.88), 34, 14, Color.WHITE, 3))
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"service_start")
	if HapticsManager != null and HapticsManager.has_method("light"):
		HapticsManager.light()

func _park_instruction() -> String:
	if park_service == null:
		return ""
	if Loc == null or not Loc.has_method("t"):
		match park_service.activity:
			ParkService.Activity.BALL: return "🎾 Arraste a bolinha até o pet do meio!"
			ParkService.Activity.TREAT: return "🦴 Toque no pote com o petisco escondido!"
			ParkService.Activity.PHOTO: return "📸 Espere o alinhamento e toque em FOTO!"
			_: return ""
	match park_service.activity:
		ParkService.Activity.BALL:
			return Loc.t("PARK_HINT_BALL") if Loc.t("PARK_HINT_BALL") != "PARK_HINT_BALL" else "🎾 Arraste a bolinha até o pet do meio!"
		ParkService.Activity.TREAT:
			return Loc.t("PARK_HINT_TREAT") if Loc.t("PARK_HINT_TREAT") != "PARK_HINT_TREAT" else "🦴 Toque no pote com o petisco escondido!"
		ParkService.Activity.PHOTO:
			return Loc.t("PARK_HINT_PHOTO") if Loc.t("PARK_HINT_PHOTO") != "PARK_HINT_PHOTO" else "📸 Espere o alinhamento e toque em FOTO!"
		_:
			return ""

func _park_begin_pointer(pos: Vector2) -> void:
	if park_service == null or park_service.state != ParkService.State.ACTIVE or not is_instance_valid(park_canvas) or not is_inside_tree():
		return
	match park_service.activity:
		ParkService.Activity.BALL:
			if park_canvas.has_method("ball_hit") and park_canvas.ball_hit(pos):
				park_dragging_ball = true
				if AudioManager != null and AudioManager.has_method("play"):
					AudioManager.play(&"tool_pickup")
				if HapticsManager != null and HapticsManager.has_method("light"):
					HapticsManager.light()
			else:
				# arrasto direto também move
				park_dragging_ball = true
				if park_canvas.has_method("pet_focus"):
					park_service.drag_ball(pos, park_canvas.pet_focus(1))
				if is_instance_valid(park_canvas):
					park_canvas.ball_pos = pos
		ParkService.Activity.TREAT:
			if not park_canvas.has_method("treat_slot_at"):
				return
			var slot: int = park_canvas.treat_slot_at(pos)
			if slot >= 0 and not park_service.treat_revealed:
				park_service.pick_treat(slot)
				park_canvas.treat_choice = slot
				park_canvas.treat_revealed = true
				park_canvas.treat_hidden_slot = park_service.treat_hidden_slot
				if AudioManager != null and AudioManager.has_method("play"):
					AudioManager.play(&"tap")
				if HapticsManager != null and HapticsManager.has_method("light"):
					HapticsManager.light()
				park_canvas.spawn_bubble(pos)
				# auto-finaliza após escolha — guard get_tree + is_inside_tree para não travar se cena já saiu
				if is_inside_tree() and get_tree() != null:
					get_tree().create_timer(0.9).timeout.connect(func(): if is_inside_tree() and park_active and is_instance_valid(park_service) and park_service.state == ParkService.State.ACTIVE: _finish_park(false))
		ParkService.Activity.PHOTO:
			if not park_canvas.has_method("photo_hit") or not park_canvas.photo_hit(pos):
				return
			var ok: bool = park_service.try_photo()
			park_canvas.photo_align = park_service.photo_align
			park_canvas.spawn_bubble(pos)
			if AudioManager != null and AudioManager.has_method("play"):
				AudioManager.play(&"window" if ok else &"error_soft")
			if HapticsManager != null and HapticsManager.has_method("light"):
				HapticsManager.light()
			if park_service.progress >= 0.92:
				if is_inside_tree() and get_tree() != null:
					get_tree().create_timer(0.4).timeout.connect(func(): if is_inside_tree() and park_active and is_instance_valid(park_service) and park_service.state == ParkService.State.ACTIVE: _finish_park(false))
			elif park_service.photo_shots >= 4:
				if is_inside_tree() and get_tree() != null:
					get_tree().create_timer(0.6).timeout.connect(func(): if is_inside_tree() and park_active and is_instance_valid(park_service) and park_service.state == ParkService.State.ACTIVE: _finish_park(false))

func _park_move_pointer(pos: Vector2) -> void:
	if park_service == null or park_service.state != ParkService.State.ACTIVE or not is_instance_valid(park_canvas) or not is_inside_tree():
		return
	if park_service.activity == ParkService.Activity.BALL and park_dragging_ball:
		if park_canvas.has_method("pet_focus"):
			park_service.drag_ball(pos, park_canvas.pet_focus(1))
		if is_instance_valid(park_canvas):
			park_canvas.ball_pos = pos
		if park_service.fetch_count > 0 and park_service.progress > 0.85 and is_instance_valid(park_canvas):
			park_canvas.spawn_bubble(pos)

func _park_end_pointer() -> void:
	if park_service == null or not is_inside_tree():
		return
	if park_service.activity == ParkService.Activity.BALL and park_dragging_ball:
		park_dragging_ball = false
		# se já fez progresso bom, permite finalizar cedo com toque duplo? mantém tempo
		if park_service.progress >= 0.88 and park_service.fetch_count >= 3:
			# brilha e auto-finaliza
			if is_instance_valid(park_canvas) and park_canvas.has_method("celebrate"):
				park_canvas.celebrate(true)
			if is_inside_tree() and get_tree() != null:
				get_tree().create_timer(0.5).timeout.connect(func(): if is_inside_tree() and park_active and is_instance_valid(park_service) and park_service.state == ParkService.State.ACTIVE: _finish_park(false))

func _finish_park(timeout: bool) -> void:
	if park_service == null or park_service.state != ParkService.State.ACTIVE or GameState == null:
		return
	var quality: StringName = &"fail" if timeout else park_service.finish()
	var success: bool = quality == &"perfect" or quality == &"good"
	var perfect: bool = quality == &"perfect"
	var activity_str: String = String(ParkService.ACTIVITY_NAMES.get(park_service.activity, &"ball")) if ParkService.ACTIVITY_NAMES.has(park_service.activity) else "ball"
	var reward: Dictionary = {}
	if GameState.has_method("park_complete"):
		reward = GameState.park_complete(activity_str, success, perfect)
	park_active = false
	park_dragging_ball = false
	if is_instance_valid(park_canvas):
		park_canvas.visible = false
	if is_instance_valid(world):
		world.visible = true
	if is_instance_valid(queue_row):
		queue_row.visible = true
	if is_instance_valid(park_choose_panel):
		park_choose_panel.visible = false
	_update_park_button()
	_refresh_economy()
	if success:
		_show_park_success(quality, reward)
	else:
		_show_park_fail()
	if Analytics != null and Analytics.has_method("track"):
		Analytics.track(&"park_finished", {"quality": String(quality), "activity": activity_str})

func _show_park_success(quality: StringName, reward: Dictionary) -> void:
	if not is_inside_tree():
		return
	var coins: int = int(reward.get("coins", 0))
	var aff: int = int(reward.get("affection", 0))
	var embers: int = int(reward.get("embers", 0))
	var streak: int = int(reward.get("streak", 0))
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"perfect" if quality == &"perfect" else &"coin")
	if HapticsManager != null and HapticsManager.has_method("success"):
		HapticsManager.success()
	if is_instance_valid(park_canvas) and park_canvas.has_method("celebrate"):
		park_canvas.celebrate(true)
	if is_instance_valid(result_title):
		result_title.text = Loc.t("PARK_PERFECT") if Loc.has_method("t") and quality == &"perfect" and Loc.t("PARK_PERFECT") != "PARK_PERFECT" else ("⭐ Perfeito no parquinho!" if quality == &"perfect" else "✓ Ótimo cuidado!")
		result_title.modulate = Color("ffd54f") if quality == &"perfect" else Color("2e7d32")
	var coins_word: String = Loc.t("COINS") if Loc.has_method("t") else "R$"
	var names: String = ""
	if GameState != null:
		for pid: String in GameState.park_pets:
			var nm: String = pid.capitalize()
			if ContentDB != null and ContentDB.has_method("pet_name"):
				var tmp: String = ContentDB.pet_name(pid)
				if not tmp.is_empty():
					nm = tmp
			names += nm + ", "
		names = names.trim_suffix(", ")
	var streak_line: String = ""
	if streak >= 2:
		streak_line = (Loc.t("PARK_STREAK_BONUS") % streak) if Loc.has_method("t") and Loc.t("PARK_STREAK_BONUS") != "PARK_STREAK_BONUS" else "🔥 %d dias seguidos!" % streak
	if is_instance_valid(result_detail):
		result_detail.text = "%s\n%s +%d  •  💗 +%d afeto%s%s" % ["★★★★★" if quality == &"perfect" else "★★★★☆", coins_word, coins, aff, "  •  🔥 +%d" % embers if embers > 0 else "", "\n" + streak_line if not streak_line.is_empty() else ""]
	var extra: String = (Loc.t("PARK_SUCCESS_EXTRA") % names) if Loc.has_method("t") and Loc.t("PARK_SUCCESS_EXTRA") != "PARK_SUCCESS_EXTRA" else "%s adoraram o quintal com você!" % names
	if quality == &"perfect":
		extra += "\n" + (Loc.t("PARK_PERFECT_EXTRA") if Loc.has_method("t") and Loc.t("PARK_PERFECT_EXTRA") != "PARK_PERFECT_EXTRA" else "Foto perfeita! As memórias vão para a coleção.")
	if is_instance_valid(result_detail_extra):
		result_detail_extra.text = extra
		result_detail_extra.visible = false
		result_expanded = false
		if is_instance_valid(result_expand_btn):
			result_expand_btn.text = "ⓘ  Ver"
			result_expand_btn.visible = true
	if is_instance_valid(share_button):
		share_button.visible = false
	if is_instance_valid(result_panel):
		_pop_panel(result_panel)
	if is_instance_valid(primary_button):
		primary_button.text = "✓  " + (Loc.t("REVEAL_OK") if Loc.has_method("t") else "OK")
		primary_button.disabled = false
		primary_button.show()
	_animate_coin_fly(coins)
	if EventBus != null and EventBus.has_signal("reveal_requested"):
		EventBus.reveal_requested.emit(&"park", {"quality": String(quality), "coins": coins})

func _show_park_fail() -> void:
	if not is_inside_tree():
		return
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"error_soft")
	if is_instance_valid(park_canvas):
		park_canvas.forced_state = &"sad"
	if is_instance_valid(result_title):
		result_title.text = Loc.t("PARK_FAIL") if Loc.has_method("t") and Loc.t("PARK_FAIL") != "PARK_FAIL" else "Quase! Tente de novo"
		result_title.modulate = Color("ef5350")
	if is_instance_valid(result_detail):
		result_detail.text = "★★☆☆☆\n" + (Loc.t("PARK_FAIL_HINT") if Loc.has_method("t") and Loc.t("PARK_FAIL_HINT") != "PARK_FAIL_HINT" else "Os pets se distraíram — tente outra brincadeira!")
	if is_instance_valid(result_detail_extra):
		result_detail_extra.text = Loc.t("PARK_FAIL_EXTRA") if Loc.has_method("t") and Loc.t("PARK_FAIL_EXTRA") != "PARK_FAIL_EXTRA" else "Sem penalidade na fila. Volta quando o cooldown acabar!"
		result_detail_extra.visible = false
		result_expanded = false
		if is_instance_valid(result_expand_btn):
			result_expand_btn.visible = true
			result_expand_btn.text = "ⓘ  Dica"
	if is_instance_valid(share_button):
		share_button.visible = false
	if is_instance_valid(result_panel):
		_pop_panel(result_panel)
	if is_instance_valid(primary_button):
		primary_button.text = "↻  " + (Loc.t("TRY_AGAIN") if Loc.has_method("t") else "Tentar novamente")
		primary_button.disabled = false
		primary_button.show()

func _close_park() -> void:
	if not park_active:
		# mesmo fechado, garante hidden se foi chamado por _input back
		if is_instance_valid(park_canvas):
			park_canvas.visible = false
		if is_instance_valid(park_choose_panel):
			park_choose_panel.visible = false
		return
	park_active = false
	park_dragging_ball = false
	if is_instance_valid(park_canvas):
		park_canvas.visible = false
	if is_instance_valid(world):
		world.visible = true
	if is_instance_valid(queue_row):
		queue_row.visible = true
	if is_instance_valid(park_choose_panel):
		park_choose_panel.visible = false
	if park_service != null:
		park_service.state = ParkService.State.IDLE
	if is_instance_valid(instruction_label):
		instruction_label.text = Loc.t("CHOOSE_CLIENT") if Loc.has_method("t") else "Escolha um cliente"
		if _instr_styles != null and _instr_styles.has(&"hint"):
			instruction_label.add_theme_stylebox_override("normal", _instr_styles[&"hint"] as StyleBoxFlat)
	_update_park_button()
	instruction_label.text = Loc.t("CHOOSE_CLIENT")
	if _instr_styles.has(&"hint"):
		instruction_label.add_theme_stylebox_override("normal", _instr_styles[&"hint"] as StyleBoxFlat)
	else:
		instruction_label.add_theme_stylebox_override("normal", _style(Color("263238", 0.82), 34, 14, Color("ffffff", 0.42), 2))
	_last_instr_key = &""
	_update_park_button()
	AudioManager.play(&"tap")

func _toggle_goal_expand() -> void:
	goal_collapsed = not goal_collapsed
	_refresh_economy()
	AudioManager.play(&"tap")
	HapticsManager.light()

func _toggle_result_detail() -> void:
	result_expanded = not result_expanded
	if is_instance_valid(result_detail_extra):
		result_detail_extra.visible = result_expanded
		# quando expandido muda texto do botão para recolher
		if is_instance_valid(result_expand_btn):
			result_expand_btn.text = "▴  Recolher" if result_expanded else "ⓘ  Ver história"
			result_expand_btn.visible = true
		result_detail_extra.modulate.a = 0.0 if result_expanded else 1.0
		if result_expanded:
			var tw: Tween = result_detail_extra.create_tween()
			tw.tween_property(result_detail_extra, "modulate:a", 1.0, 0.18)
	AudioManager.play(&"tap")
	HapticsManager.light()

func _refresh_economy(_currency: StringName = &"coins", _amount: float = 0.0) -> void:
	coin_label.text = "%s %d" % [Loc.t("COINS"), int(GameState.coins)]
	var xp_percent: int = int(100.0 * GameState.player_xp / GameState.xp_to_next_level())
	combo_label.text = "NV.%d %d%% ×%d" % [GameState.player_level, xp_percent, maxi(1, GameState.combo)]
	if GameState.reviews_total == 0:
		review_label.text = "★ %s" % Loc.t("NEW_TAG") if Loc.t("NEW_TAG") != "NEW_TAG" else "★ Novo!"
	else:
		review_label.text = "★ %.1f" % GameState.review_average()
	# ── Top bar dinâmico: esconde pílulas secundárias quando vazias ──
	if is_instance_valid(proof_label) and is_instance_valid(rush_label):
		var show_rush: bool = rush_active or rush_cooldown < 30.0
		if rush_label.text.is_empty() and not show_rush:
			rush_label.visible = false
			rush_bar.visible = false
		else:
			rush_label.visible = true
		proof_label.visible = not proof_label.text.is_empty()
	if is_instance_valid(goal_label):
		goal_full_text = Goals.hud_line()
		if GameState.player_level >= 3:
			goal_full_text += " • " + SalonTuning.tip_odds_text()
		# progressive disclosure: preview colapsado + botão ⓘ
		if goal_full_text.length() > 54 or goal_full_text.contains("•"):
			var parts: PackedStringArray = goal_full_text.split(" • ")
			goal_preview_text = parts[0]
			if parts.size() > 1:
				goal_preview_text += " • " + parts[1].left(18).strip_edges() + ("…" if parts[1].length() > 18 else "")
				if parts.size() > 2:
					goal_preview_text += " …"
			goal_label.text = goal_preview_text if goal_collapsed else goal_full_text
			goal_label.tooltip_text = goal_full_text
			if is_instance_valid(goal_expand_btn):
				goal_expand_btn.visible = true
				goal_expand_btn.text = "ⓘ" if goal_collapsed else "▴"
				goal_expand_btn.tooltip_text = "Ver detalhes" if goal_collapsed else "Recolher"
		else:
			goal_label.text = goal_full_text
			goal_label.tooltip_text = ""
			if is_instance_valid(goal_expand_btn):
				goal_expand_btn.visible = false
	if is_instance_valid(world):
		world.upgrade_level = GameState.bath_upgrade_level
		world.player_level = GameState.player_level
		world.set_cosmetics(GameState.active_cosmetics)
	if is_instance_valid(world) and world.service_active:
		world.service_time_ratio = bath.time_left / bath.duration_seconds if bath.duration_seconds > 0.0 else 0.0
func _refresh_proof_social() -> void:
	if not is_instance_valid(proof_label): return
	proof_label.text = RushTuning.proof_text()
	proof_label.modulate.a = 0.0
	proof_label.create_tween().tween_property(proof_label, "modulate:a", 1.0, 0.25)
func _animate_coin_fly(amount: int) -> void:
	CelebrationFX.coin_fly(self, amount)

func _animate_first_confetti() -> void:
	CelebrationFX.first_perfect(self)

func _show_toast(message: String, color: Color) -> void:
	SessionFeedback.toast(self, message, color)
func _connect_events() -> void:
	EventBus.currency_changed.connect(_refresh_economy)
	EventBus.combo_changed.connect(func(_value: int) -> void: _refresh_economy())
	EventBus.toast_requested.connect(_show_toast)
	EventBus.reveal_requested.connect(
		func(kind: StringName, payload: Dictionary) -> void:
			RevealCard.enqueue_kind(self, kind, payload)
	)
func _build_interface() -> void:
	world = PetShopCanvasScript.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(world)
	var safe_top: float = SalonTuning.safe_area_top()
	var font_scale: float = SalonTuning.font_scale()
	# ── Top bar dinâmico: Scroll horizontal com prioridade visual ──
	top_bar_scroll = ScrollContainer.new()
	top_bar_scroll.position = Vector2(30, 32 + safe_top)
	top_bar_scroll.size = Vector2(1020, 96)
	top_bar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	top_bar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_bar_scroll.clip_contents = true
	add_child(top_bar_scroll)
	top_bar_hbox = HBoxContainer.new()
	top_bar_hbox.add_theme_constant_override("separation", 12)
	# largura permite overflow swipe (conteúdo não corta sensação)
	top_bar_hbox.custom_minimum_size = Vector2(1020, 96)
	top_bar_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar_scroll.add_child(top_bar_hbox)
	coin_label = _pill(top_bar_hbox, "%s 0" % Loc.t("COINS"), Color("ffd54f"), 210)
	coin_label.tooltip_text = Loc.t("COINS")
	review_label = _pill(top_bar_hbox, "★ 5.0", PINK, 175)
	review_label.tooltip_text = "Reputação do bairro"
	combo_label = _pill(top_bar_hbox, "×1", GREEN, 185)
	combo_label.tooltip_text = "Combo e nível"
	rush_label = _pill(top_bar_hbox, "", Color("ff8f00"), 165)
	rush_label.tooltip_text = "Evento rush"
	rush_bar = ProgressBar.new()
	rush_bar.custom_minimum_size = Vector2(165, 14)
	rush_bar.max_value = 100.0
	rush_bar.show_percentage = false
	rush_bar.visible = false
	rush_bar.add_theme_stylebox_override("background", _style(Color("000000", 0.2), 7, 0))
	rush_bar.add_theme_stylebox_override("fill", _style(Color("ffd54f"), 7, 0))
	top_bar_hbox.add_child(rush_bar)
	proof_label = _pill(top_bar_hbox, "", Color("4fc3f7"), 210)
	proof_label.tooltip_text = "Prova social do bairro"
	proof_label.add_theme_font_size_override("font_size", 18)
	var goal_row: HBoxContainer = HBoxContainer.new()
	goal_row.position = Vector2(30, 505 + safe_top)
	goal_row.add_theme_constant_override("separation", 8)
	add_child(goal_row)
	goal_label = _pill(goal_row, "", Color("ce93d8"), 620)
	goal_label.custom_minimum_size = Vector2(620, 52)
	goal_label.add_theme_font_size_override("font_size", int(20 * font_scale))
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.tooltip_text = ""
	goal_expand_btn = _button("ⓘ", Color("f3e5f5"), 52, 52)
	goal_expand_btn.tooltip_text = "Ver meta completa"
	goal_expand_btn.add_theme_font_size_override("font_size", 20)
	goal_expand_btn.add_theme_color_override("font_color", Color("6a1b9a"))
	goal_expand_btn.add_theme_stylebox_override("normal", _style(Color("f3e5f5"), 26, 6))
	goal_expand_btn.add_theme_stylebox_override("hover", _style(Color("e1bee7"), 26, 6, Color.WHITE, 1))
	goal_expand_btn.add_theme_stylebox_override("pressed", _style(Color("ce93d8"), 26, 6))
	goal_expand_btn.pressed.connect(_toggle_goal_expand)
	goal_row.add_child(goal_expand_btn)
	goal_expand_btn.visible = false
	queue_row = HBoxContainer.new()
	queue_row.position = Vector2(45, 310 + safe_top)
	queue_row.size = Vector2(990, 175)
	queue_row.add_theme_constant_override("separation", 15)
	add_child(queue_row)
	for slot: int in 3:
		var card_ui: Dictionary = SalonPanels.build_queue_card(_style, _button)
		card_ui["card"].pressed.connect(_on_queue_pressed.bind(slot))
		queue_row.add_child(card_ui["card"])
		queue_cards.append(card_ui["card"])
		queue_name_labels.append(card_ui["name"])
		queue_service_labels.append(card_ui["service"])
		queue_info_labels.append(card_ui["info"])
		queue_bars.append(card_ui["bar"])
	var nav: HBoxContainer = HBoxContainer.new()
	nav.position = Vector2(30, 145 + safe_top)
	nav.add_theme_constant_override("separation", 10)
	add_child(nav)
	# Progressive disclosure P1: reduz sobrecarga D0, libera gradualmente
	var nav_unlocks: Dictionary = {&"missions": 1, &"collection": 1, &"album": 2, &"staff": 2, &"shop": 2, &"map": 3, &"settings": 1}
	for item: Dictionary in [
		{"id": "missions", "tip_key": "NAV_MISSIONS"},
		{"id": "collection", "tip_key": "NAV_COLLECTION"},
		{"id": "album", "tip_key": "NAV_ALBUM"},
		{"id": "staff", "tip_key": "NAV_STAFF"},
		{"id": "shop", "tip_key": "NAV_SHOP"},
		{"id": "map", "tip_key": "NAV_MAP"},
		{"id": "settings", "tip_key": "NAV_SETTINGS"}
	]:
		var sid: StringName = StringName(item["id"])
		var tip: String = Loc.t(String(item["tip_key"]))
		var unlock_lv: int = int(nav_unlocks.get(sid, 1))
		var locked: bool = GameState.player_level < unlock_lv and not GameState.tutorial_complete
		var col: VBoxContainer = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		nav.add_child(col)
		var nav_button: Button = _button("🔒" if locked else "", CHARCOAL if not locked else Color("90a4ae"), 72, 72)
		nav_button.name = "Nav_%s" % String(sid)
		if sid == &"missions":
			missions_button = nav_button
		if sid == &"album":
			album_button = nav_button
		if not locked:
			nav_button.icon = NAV_ICONS[sid]
		nav_button.tooltip_text = tip if not locked else "%s • %s" % [tip, Loc.t("NAV_LOCKED") % unlock_lv]
		nav_button.disabled = locked
		nav_button.add_theme_stylebox_override("normal", _style(Color("263238", 0.88) if not locked else Color("90a4ae", 0.88), 36, 6, Color("ffffff", 0.72), 3))
		nav_button.add_theme_stylebox_override("hover", _style(PINK, 36, 6, Color.WHITE, 3))
		if not locked:
			nav_button.pressed.connect(SessionFeedback.open_meta.bind(self, sid, nav_button))
		else:
			nav_button.pressed.connect(func(): _show_toast(Loc.t("UPGRADES_LOCKED") % unlock_lv, Color("b0bec5")))
		col.add_child(nav_button)
		if sid == &"missions" and not locked:
			D1Retention.ensure_missions_badge(self)
		var nav_label: Label = Label.new()
		nav_label.text = tip if not locked else "🔒 %s" % tip
		nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nav_label.add_theme_font_size_override("font_size", int(16 * font_scale))
		nav_label.add_theme_color_override("font_color", Color("263238", 0.85) if not locked else Color("90a4ae"))
		nav_label.add_theme_stylebox_override("normal", _style(Color("ffffff", 0.82), 12, 4))
		col.add_child(nav_label)
	var event_pill: Label = _pill(nav, LiveOps.current_event_name(), Color("4fc3f7"), 210)
	event_pill.add_theme_font_size_override("font_size", 20)
	event_pill.custom_minimum_size = Vector2(210, 56)
	var action_hud: VBoxContainer = VBoxContainer.new()
	action_hud.position = Vector2(45, 1350)
	action_hud.size = Vector2(990, 260)
	action_hud.add_theme_constant_override("separation", 16)
	add_child(action_hud)
	instruction_label = Label.new()
	instruction_label.text = (
		Loc.t("DRAG_TOOL_TO") % [SalonTuning.tool_display_name(&"soap"), "Caramelo"]
	)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 33)
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_label.add_theme_stylebox_override(
		"normal", _style(Color("263238", 0.82), 34, 14, Color("ffffff", 0.42), 2)
	)
	instruction_label.custom_minimum_size = Vector2(990, 72)
	action_hud.add_child(instruction_label)
	upgrades_button = _button("", Color(GREEN, 0.96), 86, 86)
	upgrades_button.position = Vector2(952, 150)
	upgrades_button.icon = UPGRADES_ICON
	upgrades_button.expand_icon = true
	upgrades_button.tooltip_text = Loc.t("UPGRADES_TITLE")
	upgrades_button.add_theme_stylebox_override(
		"normal", _style(Color(GREEN, 0.96), 43, 6, Color.WHITE, 4)
	)
	upgrades_button.add_theme_stylebox_override(
		"hover", _style(Color("66bb6a", 0.98), 43, 6, Color.WHITE, 5)
	)
	upgrades_button.add_theme_stylebox_override(
		"pressed", _style(Color("5fae43", 1.0), 43, 8, Color.WHITE, 4)
	)
	add_child(upgrades_button)
	upgrades_button.pressed.connect(
		SessionFeedback.open_meta.bind(self, &"upgrades", upgrades_button)
	)
	meta = MetaPanel.new()
	meta.refresh_callback = _refresh_economy
	meta.build(self)
	var result_ui: Dictionary = SalonPanels.build_result_panel(
		self, _style, _button, _on_primary_pressed, SessionFeedback.on_share_pressed.bind(self)
	)
	result_panel = result_ui["panel"]
	result_title = result_ui["title"]
	result_detail = result_ui["detail"]
	result_detail_extra = result_ui.get("detail_extra", null)
	result_expand_btn = result_ui.get("expand_btn", null)
	if is_instance_valid(result_expand_btn):
		result_expand_btn.pressed.connect(_toggle_result_detail)
	primary_button = result_ui["primary"]
	share_button = result_ui["share"]
	if result_ui.has("xp_bar"):
		result_panel.set_meta("xp_bar", result_ui["xp_bar"])
	var upsell_ui: Dictionary = SalonPanels.build_upsell_panel(
		self, _style, _button, _on_upsell_accept, _on_upsell_decline
	)
	upsell_panel = upsell_ui["panel"]
	upsell_label = upsell_ui["body"]
	upsell_accept = upsell_ui["accept"]
	upsell_decline = upsell_ui["decline"]
	toast_layer = Control.new()
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(toast_layer)
	tutorial_overlay = TutorialOverlayScript.new()
	tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_overlay.visible = false
	add_child(tutorial_overlay)
	tutorial_skip_button = _button(Loc.t("SKIP_TUTORIAL"), Color("263238", 0.88), 220, 56)
	tutorial_skip_button.position = Vector2(750, 145 + safe_top) # Nota10: reposicionado direita para não sobrepor nav (30,145)
	tutorial_skip_button.add_theme_stylebox_override("normal", _style(Color("263238", 0.88), 34, 12, Color("ffffff", 0.6), 2))
	tutorial_skip_button.pressed.connect(tutorial.skip)
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
	label.custom_minimum_size = Vector2(width, 64)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	var fs: float = SalonTuning.font_scale()
	label.add_theme_font_size_override("font_size", int(28 * fs))
	label.add_theme_color_override("font_color", CHARCOAL)
	label.add_theme_stylebox_override(
		"normal", _style(Color("ffffff", 0.97), 32, 12, color, 4)
	)
	parent.add_child(label)
	return label
func _relative_luminance(c: Color) -> float:
	var rs: float = c.r; var gs: float = c.g; var bs: float = c.b
	rs = rs / 12.92 if rs <= 0.04045 else pow((rs + 0.055) / 1.055, 2.4)
	gs = gs / 12.92 if gs <= 0.04045 else pow((gs + 0.055) / 1.055, 2.4)
	bs = bs / 12.92 if bs <= 0.04045 else pow((bs + 0.055) / 1.055, 2.4)
	return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs
func _ideal_text_color(bg: Color) -> Color:
	var lb: float = _relative_luminance(bg); var lw: float = 1.0; var lc: float = _relative_luminance(CHARCOAL)
	var cr_white: float = (maxf(lb, lw) + 0.05) / (minf(lb, lw) + 0.05)
	var cr_char: float = (maxf(lb, lc) + 0.05) / (minf(lb, lc) + 0.05)
	return CHARCOAL if cr_char > cr_white else Color.WHITE
func _button(text: String, color: Color, width: float, height: float) -> Button:
	var button: Button = Button.new(); button.text = text
	button.custom_minimum_size = Vector2(width if width>0 else 0, maxf(height,64.0) if height>0 else 64.0)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; button.clip_text=false
	var fs: float = SalonTuning.font_scale(); button.add_theme_font_size_override("font_size", int(30*fs))
	var tc: Color = _ideal_text_color(color)
	for k: String in ["font_color","font_pressed_color","font_hover_color"]: button.add_theme_color_override(k, tc)
	button.add_theme_color_override("font_disabled_color", Color("eceff1"))
	button.add_theme_stylebox_override("normal", _style(color,32,14)); button.add_theme_stylebox_override("hover", _style(color.lightened(0.10),32,14,Color.WHITE,2))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.15),32,14)); button.add_theme_stylebox_override("disabled", _style(Color("90a4ae"),32,14))
	button.add_theme_stylebox_override("focus", _style(color,32,14,Color.WHITE,3)); InteractionFX.bind_button(button); return button
func _style(c: Color, r: int, m: int, bc: Color=Color.TRANSPARENT, bw: int=0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new(); s.bg_color=c; s.corner_radius_top_left=r; s.corner_radius_top_right=r; s.corner_radius_bottom_left=r; s.corner_radius_bottom_right=r
	s.content_margin_left=m; s.content_margin_right=m; s.content_margin_top=m; s.content_margin_bottom=m; s.border_color=bc; s.border_width_left=bw; s.border_width_right=bw; s.border_width_top=bw; s.border_width_bottom=bw
	if r>=20: s.shadow_color=Color("263238",0.16); s.shadow_size=8; s.shadow_offset=Vector2(0,6)
	return s
