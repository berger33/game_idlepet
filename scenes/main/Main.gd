extends Control

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
const TutorialOverlayScript: Script = preload("res://scenes/main/TutorialOverlay.gd")
const UPGRADES_ICON: Texture2D = preload("res://art/ui/icons/upgrades.png")

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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bath = BathServiceScript.new()
	_configure_current_service()
	_build_interface()
	world.clear_room()
	for slot: int in 3:
		queue[slot] = SalonTuning.make_client(_available_services())
	_update_queue_ui()
	_connect_events()
	_refresh_economy()
	rush_cooldown = RemoteConfig.get_float("rush_interval_seconds")
	SessionFeedback.show_offline_card(self)
	SessionFeedback.show_comeback(self)
	if GameState.tutorial_complete:
		LiveOps.claim_seasonal_gift()  # Temporada do mês presenteia seu cosmético.
	NotificationManager.permission_granted = bool(
		GameState.settings.get("notifications", false)
	)
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
	Analytics.track(&"first_open" if GameState.services_completed == 0 else &"session_resume")

func _process(delta: float) -> void:
	bubble_sound_gate = maxf(0.0, bubble_sound_gate - delta)
	pet_touch_gate = maxf(0.0, pet_touch_gate - delta)
	wrong_tool_gate = maxf(0.0, wrong_tool_gate - delta)
	upgrades_pulse_time += delta
	if is_instance_valid(upgrades_button):
		var affordable_count: int = SalonTuning.affordable_upgrades_count()
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
		var left_handed: bool = bool(GameState.settings.get("left_handed", false))
		upgrades_button.position = Vector2(120, 150) if left_handed else Vector2(952, 150)
	if bath.state == BathService.State.ACTIVE:
		if bath.tick(delta):
			_fail(&"timeout")
			return
		world.progress = bath.progress
		world.service_time_ratio = bath.time_left / bath.duration_seconds if bath.duration_seconds > 0.0 else 0.0
		world.gesture_ui = GestureArt.gesture_snapshot(bath)
		world.playful_hop = bath.hopping
		if bath.progress >= bath.target_minimum and bath.progress <= bath.target_maximum:
			if not instruction_label.text.begins_with("✓"):
				instruction_label.text = "✓ SOLTE PARA PERFEITO!"
				instruction_label.add_theme_stylebox_override("normal", _style(Color("7ed957", 0.92), 34, 14, Color.WHITE, 4))
		elif bath.progress > bath.target_maximum:
			instruction_label.text = "⚠ PASSOU! SOLTE E TENTE DE NOVO"
			instruction_label.add_theme_stylebox_override("normal", _style(Color("ef5350", 0.88), 34, 14, Color.WHITE, 3))
		elif bath.progress > 0.05 and bath.progress < bath.target_minimum:
			var hint_text: String = SalonTuning.hint(current_service)
			if instruction_label.text != hint_text and not instruction_label.text.begins_with("⚠"):
				instruction_label.text = hint_text
				instruction_label.add_theme_stylebox_override("normal", _style(Color("263238", 0.82), 34, 14, Color("ffffff", 0.42), 2))
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
	world.tool_levels = GameState.tool_upgrade_levels
	world.rush_active = rush_active
	_update_rush(delta)
	_process_queue(delta)

func _input(event: InputEvent) -> void:
	if (
		meta.is_open()
		or (is_instance_valid(result_panel) and result_panel.visible)
		or (is_instance_valid(upsell_panel) and upsell_panel.visible)
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
			timer.timeout.connect(func() -> void: if tutorial_overlay.active: tutorial_overlay.finish())
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
	if meta.is_open():
		meta.close()
	elif is_instance_valid(result_panel) and result_panel.visible:
		_on_primary_pressed()

func _on_primary_pressed() -> void:
	if bath.state == BathService.State.COMPLETE or bath.state == BathService.State.FAILED:
		_dismiss_result()

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
	var coins_word: String = Loc.t("COINS")
	var stars_text: String = "★".repeat(stars) + "☆".repeat(5 - stars)
	var thanks: String = PetStories.result_thanks(ContentDB.pet(current_pet_id), quality == &"perfect")
	var aff: int = int(GameState.pet_affection.get(current_pet_id, 0))
	var mem: String = PetStories.affection_memory(current_pet_id, aff)
	var proof: String = "💬 %s acabou de avaliar: %s" % [current_pet_name, stars_text]
	if not mem.is_empty():
		proof += "\n%s" % mem
	result_detail.text = "%s\n🪙 +%d %s  •  ✨ +%d XP\n%s\n%s\n%s%s" % [stars_text, int(reward), coins_word, xp_reward, tip_line, thanks, proof, extra_line]
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
	ShareManager.finish_snapshot(get_viewport(), String(current_service), {"pet_id": current_pet_id, "stars": stars})
	share_button.visible = true
	_pop_panel(result_panel)
	primary_button.text = "✓  " + Loc.t("REVEAL_OK")
	primary_button.disabled = false
	primary_button.show()
	_refresh_economy()

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
	var action_name: String = String(SERVICE_LABELS.get(current_service, "cuidado"))
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
	result_detail.text = "★★☆☆☆\n%s\n%s%s" % [hint, Loc.t("FAIL_NO_PENALTY"), assistance_line]
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
	if assistance_clients > 0:
		assistance_clients -= 1
	instruction_label.text = Loc.t("CHOOSE_CLIENT")
	primary_button.hide()
	_update_queue_ui()

func _refill_delay() -> float:
	return 0.35 if rush_active else 1.1

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
			refill_timers[slot] = minf(refill_timers[slot], 0.5)

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
	var service_name: String = String(SERVICE_LABELS.get(offered, "cuidado")).capitalize()
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
				queue[slot] = SalonTuning.make_client(_available_services())
				_update_queue_ui()
		elif (
			not queue[slot].is_empty()
			and slot != selected_slot
			and bool(GameState.tutorial_complete)
		):
			var patience_drain: float = delta * (1.0 - Research.bonus(&"patience"))
			if rush_active:
				patience_drain *= 0.5
			if mood_buff_clients > 0:
				patience_drain *= 0.9
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
			queue_bars[slot].color = Color("ef5350") if ratio <= 0.25 else (Color("ffd54f") if ratio <= 0.5 else Color("7ed957"))
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
	queue[slot] = {}; refill_timers[slot] = 2.0 if not rush_active else 0.6
	_update_queue_ui()

func _update_queue_ui() -> void:
	for slot: int in 3:
		var client: Dictionary = queue[slot]
		if client.is_empty():
			var dots: String = ".".repeat(int(fmod(upgrades_pulse_time * 2.0, 3.0)) + 1)
			queue_name_labels[slot].text = "%s%s" % [Loc.t("QUEUE_ARRIVING"), dots]
			queue_service_labels[slot].text = "🐾 " + Loc.t("QUEUE_WAITING")
			queue_info_labels[slot].text = Loc.t("QUEUE_RELOAD") % refill_timers[slot] if refill_timers[slot] > 0.0 else ""
			queue_cards[slot].modulate.a = 0.55 + 0.15 * sin(upgrades_pulse_time * 3.0 + slot)
			queue_cards[slot].add_theme_stylebox_override(
				"panel", _style(Color("ffffff", 0.88), 26, 16, Color("b0bec5"), 3)
			)
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
			queue_name_labels[slot].text = client_name
			var service_text: String = String(SERVICE_LABELS.get(StringName(client["service"]), "cuidado")).capitalize()
			if StringName(client.get("special", &"")) != &"":
				service_text += " + ★"
			queue_service_labels[slot].text = service_text
			var base_info: String = (
				Loc.t("VISITOR_TAG") % [Discovery.progress(String(client["pet"])), Discovery.VISITS_TO_ADOPT]
				if bool(client.get("visitor", false))
				else SalonTuning.queue_info_text(profile)
			)
			var story_line: String = PetStories.queue_story(profile, String(client.get("service", "bath")))
			queue_info_labels[slot].text = "%s\n%s" % [base_info, story_line] if not story_line.is_empty() else base_info
			var border: Dictionary = SalonTuning.queue_border(profile)
			queue_cards[slot].add_theme_stylebox_override(
				"panel",
				_style(Color("ffffff", 0.96), 26, 16, border["color"], int(border["width"]))
			)
			queue_cards[slot].modulate.a = 1.0
			queue_cards[slot].disabled = not _can_select(slot)

func _configure_current_service() -> void:
	var duration: float = {&"bath": 10.0, &"groom": 11.0, &"dry": 9.0, &"perfume": 8.0, &"style": 8.0}.get(current_service, 10.0)
	var required_distance: float = {&"bath": 1350.0, &"groom": 1550.0, &"dry": 1250.0, &"perfume": 1050.0, &"style": 900.0}.get(current_service, 1350.0)
	var patience: float = float(ContentDB.pet(current_pet_id).get("patience", 42))
	var pf: float = clampf(patience / 42.0, 0.6, 1.25) + GameState.staff_bonus(&"patience")
	pf = RushTuning.patience_factor(pf, assistance_clients)
	if current_service == &"bath": required_distance *= 1.0 - GameState.staff_bonus(&"bath_speed")
	var wb: float = GameState.staff_bonus(&"perfect_window")
	if current_service == &"groom": wb += GameState.staff_bonus(&"groom_quality")
	wb = RushTuning.window_bonus(wb, assistance_clients)
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

func _refresh_economy(_currency: StringName = &"coins", _amount: float = 0.0) -> void:
	coin_label.text = "🪙 %d" % int(GameState.coins)
	var xp_percent: int = int(100.0 * GameState.player_xp / GameState.xp_to_next_level())
	combo_label.text = "NV.%d %d%% ×%d" % [GameState.player_level, xp_percent, maxi(1, GameState.combo)]
	review_label.text = "★ %.1f" % GameState.review_average()
	if is_instance_valid(goal_label):
		goal_label.text = Goals.hud_line()
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
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.position = Vector2(30, 32 + safe_top)
	top_bar.size = Vector2(1020, 96)
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)
	coin_label = _pill(top_bar, "🪙 0", Color("ffd54f"), 210)
	review_label = _pill(top_bar, "★ 5.0", PINK, 175)
	combo_label = _pill(top_bar, "×1", GREEN, 185)
	rush_label = _pill(top_bar, "", Color("ff8f00"), 165)
	rush_bar = ProgressBar.new()
	rush_bar.custom_minimum_size = Vector2(165, 14)
	rush_bar.max_value = 100.0
	rush_bar.show_percentage = false
	rush_bar.visible = false
	rush_bar.add_theme_stylebox_override("background", _style(Color("000000", 0.2), 7, 0))
	rush_bar.add_theme_stylebox_override("fill", _style(Color("ffd54f"), 7, 0))
	top_bar.add_child(rush_bar)
	proof_label = _pill(top_bar, "", Color("4fc3f7"), 210)
	proof_label.add_theme_font_size_override("font_size", 18)

	var goal_row: HBoxContainer = HBoxContainer.new()
	goal_row.position = Vector2(30, 505 + safe_top)
	add_child(goal_row)
	goal_label = _pill(goal_row, "", Color("ce93d8"), 620)
	goal_label.custom_minimum_size = Vector2(620, 52)
	goal_label.add_theme_font_size_override("font_size", int(20 * font_scale))
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
	for item: Dictionary in [
		{"id": "missions", "tip": "Missões"},
		{"id": "collection", "tip": "Pets"},
		{"id": "staff", "tip": "Equipe"},
		{"id": "shop", "tip": "Loja"},
		{"id": "map", "tip": "Mapa"},
		{"id": "settings", "tip": "Ajustes"}
	]:
		var col: VBoxContainer = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		nav.add_child(col)
		var nav_button: Button = _button("", CHARCOAL, 72, 72)
		nav_button.icon = NAV_ICONS[StringName(item["id"])]
		nav_button.tooltip_text = String(item["tip"])
		nav_button.add_theme_stylebox_override("normal", _style(Color("263238", 0.88), 36, 6, Color("ffffff", 0.72), 3))
		nav_button.add_theme_stylebox_override("hover", _style(PINK, 36, 6, Color.WHITE, 3))
		nav_button.pressed.connect(SessionFeedback.open_meta.bind(self, StringName(item["id"]), nav_button))
		col.add_child(nav_button)
		var nav_label: Label = Label.new()
		nav_label.text = String(item["tip"])
		nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nav_label.add_theme_font_size_override("font_size", int(16 * font_scale))
		nav_label.add_theme_color_override("font_color", Color("263238", 0.85))
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
	upgrades_button = _button("", Color("7ed957", 0.96), 86, 86)
	upgrades_button.position = Vector2(952, 150)
	upgrades_button.icon = UPGRADES_ICON
	upgrades_button.expand_icon = true
	upgrades_button.tooltip_text = Loc.t("UPGRADES_TITLE")
	upgrades_button.add_theme_stylebox_override(
		"normal", _style(Color("7ed957", 0.96), 43, 6, Color.WHITE, 4)
	)
	upgrades_button.add_theme_stylebox_override(
		"hover", _style(Color("8fe46b", 0.98), 43, 6, Color.WHITE, 5)
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
	tutorial_skip_button = _button(Loc.t("SKIP_TUTORIAL"), Color("263238", 0.88), 300, 68)
	tutorial_skip_button.position = Vector2(45, 145 + safe_top)
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
	# Altura mínima 64px (acessibilidade) + autowrap para textos longos como prova social
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

func _button(text: String, color: Color, width: float, height: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	var min_h: float = maxf(height, 64.0) if height > 0.0 else 64.0
	var min_w: float = width if width > 0.0 else 0.0
	button.custom_minimum_size = Vector2(min_w, min_h)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = false
	var fs: float = SalonTuning.font_scale()
	button.add_theme_font_size_override("font_size", int(30 * fs))
	var is_light: bool = color.get_luminance() > 0.65 or color == Color("ffd54f")
	var tc: Color = CHARCOAL if is_light else Color.WHITE
	button.add_theme_color_override("font_color", tc)
	button.add_theme_color_override("font_pressed_color", tc)
	button.add_theme_color_override("font_hover_color", tc)
	button.add_theme_color_override("font_disabled_color", Color("eceff1"))
	button.add_theme_stylebox_override("normal", _style(color, 32, 14))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.10), 32, 14, Color.WHITE, 2))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.15), 32, 14))
	button.add_theme_stylebox_override("disabled", _style(Color("90a4ae"), 32, 14))
	button.add_theme_stylebox_override("focus", _style(color, 32, 14, Color.WHITE, 3))
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
