class_name MetaPanel
extends Node
## Controlador das telas meta (Fase 2/.tscn): instancia meta_screen.tscn e
## preenche o conteúdo com os templates info_row/slider_row/pet_card.
## Missões com claim individual, coleção em grid, equipe contratável, loja
## (brasas + IAP honesto + rewarded ads), mapa e ajustes com sliders.
## Tudo emerge do painel (pivot na origem + cascata scale-in).

const GREEN: Color = Color("2e7d32") # WCAG AA 5.13:1 com branco (antes 43a047 3.30:1)
const BLUE: Color = Color("4fc3f7")
const PINK: Color = Color("ff8fb1")
const CHARCOAL: Color = Color("263238")

const META_SCREEN: PackedScene = preload("res://scenes/ui/meta_screen.tscn")
const INFO_ROW: PackedScene = preload("res://scenes/ui/info_row.tscn")
const SLIDER_ROW: PackedScene = preload("res://scenes/ui/slider_row.tscn")
const PET_CARD: PackedScene = preload("res://scenes/ui/pet_card.tscn")
const MISSION_CARD: PackedScene = preload("res://scenes/ui/mission_card.tscn")

var screen: MetaScreen
## Main injeta aqui o refresh de economia (evita acoplamento direto).
var refresh_callback: Callable
## T-02: Main injeta o restart do tutorial (Ajustes → Rever tutorial).
var replay_tutorial_callback: Callable
var _section: StringName = &""


func is_open() -> bool:
	return is_instance_valid(screen) and screen.panel.visible


func build(root: Control) -> void:
	screen = META_SCREEN.instantiate()
	root.add_child(screen)
	screen.panel.hide()
	screen.backdrop.hide()
	screen.close_button.pressed.connect(close)
	if not Loc.language_changed.is_connected(_on_language_changed):
		Loc.language_changed.connect(_on_language_changed)
	_style_button(screen.close_button, PINK)
	# Scrollbar visível + safe area bottom
	var scroll: ScrollContainer = screen.get_node("Panel/Column/Scroll") as ScrollContainer
	if is_instance_valid(scroll):
		# Mostra barra e adiciona fade no bottom via StyleBox
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Safe area bottom para gesture navigation Android
	var safe_bottom: float = 0.0
	if OS.has_feature("mobile") or OS.has_feature("web"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window_h: int = DisplayServer.window_get_size().y
		if window_h > 0 and safe.end.y < window_h:
			safe_bottom = clampf(float(window_h - safe.end.y) * 0.5, 0.0, 80.0)
	screen.panel.offset_bottom = 1240.0 - safe_bottom
	# Close agora é ✕ 84×84 mais legível


func close() -> void:
	screen.panel.hide()
	screen.backdrop.hide()
	AudioManager.play(&"tap")


func _on_language_changed(_code: String) -> void:
	if is_open() and not _section.is_empty():
		_rebuild(_section)


## origin = controle que abriu a tela: o painel cresce a partir dele.
func open(section: StringName, origin: Control = null) -> void:
	screen.backdrop.show()
	screen.backdrop.pivot_offset = screen.backdrop.size * 0.5
	screen.backdrop.scale = Vector2(1.035, 1.035)
	screen.backdrop.create_tween().tween_property( screen.backdrop, "scale", Vector2.ONE, 3.5
	).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(origin):
		screen.panel.pivot_offset = ( origin.global_position + origin.size * 0.5 - screen.panel.position
		)
	else:
		screen.panel.pivot_offset = screen.panel.size * 0.5
	_pop_panel(screen.panel)
	AudioManager.play(&"panel_open")
	_rebuild(section)


func _rebuild(section: StringName) -> void:
	_section = section
	var icon_path: String = "res://art/ui/icons/%s.png" % String(section)
	if ResourceLoader.exists(icon_path):
		screen.section_icon.texture = load(icon_path) as Texture2D
		screen.section_icon.visible = true
	else:
		screen.section_icon.texture = null
		screen.section_icon.visible = false
	for child: Node in screen.content_box.get_children():
		child.queue_free()
	match section:
		&"missions":
			screen.title_label.text = Loc.t("MISSIONS_TITLE")
			_build_missions()
		&"collection":
			screen.title_label.text = Loc.t("COLLECTION_TITLE")
			_build_collection()
		&"album":
			screen.title_label.text = Loc.t("ALBUM_TITLE") if Loc.t("ALBUM_TITLE") != "ALBUM_TITLE" else "ÁLBUM"
			_build_album()
		&"staff":
			screen.title_label.text = Loc.t("STAFF_TITLE")
			_build_staff()
		&"upgrades":
			screen.title_label.text = Loc.t("UPGRADES_TITLE")
			_build_upgrades()
		&"shop":
			screen.title_label.text = Loc.t("SHOP_TITLE")
			_build_shop()
		&"map":
			screen.title_label.text = Loc.t("MAP_TITLE")
			_build_map()
		_:
			screen.title_label.text = Loc.t("SETTINGS_TITLE")
			_build_settings()
	_emerge()


## Linhas/cards surgem escalando do painel, em cascata.
func _emerge() -> void:
	for i: int in screen.content_box.get_child_count():
		var child: Control = screen.content_box.get_child(i)
		child.modulate.a = 0.0
		child.scale = Vector2(0.94, 0.94)
		child.pivot_offset = child.size * 0.5
		var tween: Tween = child.create_tween()
		tween.set_parallel(true)
		tween.tween_property(child, "modulate:a", 1.0, 0.16).set_delay(i * 0.03)
		tween.tween_property(child, "scale", Vector2.ONE, 0.16).set_delay(i * 0.03)


var _mission_tab: StringName = &"daily"


func _build_missions() -> void:
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	screen.content_box.add_child(tabs)
	for option: Dictionary in [
		{"id": &"daily", "key": "MISSIONS_TAB_TODAY"},
		{"id": &"weekly", "key": "MISSIONS_TAB_WEEKLY"},
	]:
		var tab_id: StringName = StringName(option["id"])
		var tab_button: Button = Button.new()
		tab_button.name = "MissionsTab_%s" % String(tab_id)
		tab_button.text = Loc.t(String(option["key"]))
		tab_button.custom_minimum_size = Vector2(300, 68)
		_style_button(tab_button, PINK if _mission_tab == tab_id else Color("b0bec5"))
		tab_button.set_meta("game_action_connected", true)
		tab_button.pressed.connect(func(next_tab: StringName = tab_id) -> void:
			_mission_tab = next_tab
			_rebuild(&"missions")
		)
		tabs.add_child(tab_button)
	if _mission_tab == &"weekly":
		_build_weekly_missions()
	else:
		_build_daily_missions()


func _build_daily_missions() -> void:
	# ── Retenção P0: roleta diária (recompensa variável) + streak + perda ── localizados
	var can_spin: bool = DailySpin.can_spin()
	_info_row( "🎡 %s" % Loc.t("DAILY_SPIN_TITLE"), Loc.t("DAILY_SPIN_DESC"),
		Loc.t("SPIN_ACTION") if can_spin else Loc.t("SPIN_DONE"),
		Color("ffd54f") if can_spin else Color("b0bec5"),
		can_spin,
		func() -> void:
			var reward: Dictionary = DailySpin.spin()
			if not reward.is_empty():
				AudioManager.play(&"coin")
				EventBus.toast_requested.emit(DailySpin.label_for(reward), Color("ffd54f"))
	)
	_note("── " + Loc.t("STREAK_SECTION") + " ──", 26, PINK, false)
	var claimed_today: bool = GameState.is_daily_claimed_today()
	var next_day: int = GameState.daily_streak % 7 + 1
	var streak_coins: int = Rewards.scaled( float(Rewards.SECONDS[&"streak_day"]) * next_day, 25 * next_day
	)
	var streak_note: String = Loc.t("STREAK_LINE") % [GameState.daily_streak, GameState.streak_freezes]
	if not claimed_today:
		streak_note += " • " + Loc.t("STREAK_LOSS_NOTE")
	_info_row( Loc.t("DAILY_LOGIN") % (GameState.daily_streak if claimed_today else next_day),
		"%s %d • %s" % [Loc.t("COINS"), streak_coins, streak_note],
		Loc.t("CLAIMED") if claimed_today else Loc.t("CLAIM"),
		GREEN,
		not claimed_today,
		func() -> void:
			GameState.claim_daily_reward()
			AudioManager.play(&"coin")
	)
	# Meta do dia do evento (LiveOps): o evento vira motivo de sessão.
	if LiveOps.event_goal_target() > 0:
		var goal_ready: bool = ( GameState.event_goal_count >= LiveOps.event_goal_target()
			and not GameState.event_goal_claimed
		)
		_info_row( "%s • %s" % [Loc.t("EVENT_GOAL_TITLE"), LiveOps.current_event_name()], "%s\n%s" % [ LiveOps.event_goal_text(),
				Loc.t("EVENT_GOAL_REWARD") % [ Rewards.for_kind(&"event_goal", 300), LiveOps.EVENT_GOAL_EMBERS
				],
			],
			Loc.t("CLAIMED") if GameState.event_goal_claimed else Loc.t("CLAIM"),
			Color("4fc3f7"),
			goal_ready,
			func() -> void:
				if GameState.claim_event_goal():
					AudioManager.play(&"pass_claim")
		)
	# Grade visual: métrica, barra de progresso e prêmio substituem descrições repetidas.
	var daily_grid: GridContainer = GridContainer.new()
	daily_grid.columns = 2
	daily_grid.add_theme_constant_override("h_separation", 12)
	daily_grid.add_theme_constant_override("v_separation", 12)
	screen.content_box.add_child(daily_grid)
	for mission: Dictionary in Missions.today():
		var mission_id: String = String(mission["id"])
		var claimed: bool = GameState.claimed_missions.has(mission_id)
		var ready: bool = Missions.is_ready(mission)
		var epic: bool = Missions.is_epic(mission)
		var target: int = Missions.target(mission)
		var value: int = Missions.value(mission)
		_add_mission_card(
			daily_grid, ("★ " if epic else "") + Missions.label(mission), value, target,
			Missions.reward_text(mission), String(mission.get("metric", "services")), ready, claimed, epic,
			func(mid: String = mission_id) -> void:
				if GameState.claim_mission(mid):
					AudioManager.play(&"coin")
		)
	# Gancho de retorno: o jogador vê o amanhã (evento + streak) antes de sair.
	var tomorrow: int = (LiveOps.weekday() + 1) % 7
	_info_row( Loc.t("TOMORROW"), "%s — %s" % [LiveOps.event_name_for(tomorrow), LiveOps.event_description_for(tomorrow)],
		"%d/7" % GameState.daily_streak,
		Color("4fc3f7"),
		false,
		Callable()
	)
	var pass_ready: bool = GameState.pass_day_claimed < GameState.pass_day_unlocked
	var pass_reward: Dictionary = ContentDB.pass_day(GameState.pass_day_claimed + 1)
	var pass_line: String = Loc.t("PASS_DONE")
	if not pass_reward.is_empty():
		pass_line = "%s • %s %d" % [ Loc.t("PASS_DESC"), Loc.t("COINS"), Rewards.pass_day_coins(GameState.pass_day_claimed + 1),
		]
	_info_row( Loc.t("PASS_TITLE") + " %d/28" % (GameState.pass_day_claimed + 1), pass_line,
		Loc.t("CLAIM") if pass_ready else "%d/28" % GameState.pass_day_unlocked,
		GREEN if pass_ready else Color("b0bec5"),
		pass_ready,
		func() -> void:
			if GameState.claim_pass_day():
				AudioManager.play(&"coin")
	)
	_note(Loc.t("MISSIONS_NO_ADS"))



func _build_weekly_missions() -> void:
	# Urgência curta no último dia; o progresso abaixo substitui o parágrafo explicativo.
	if LiveOps.weekly_is_last_day():
		var summary: Dictionary = LiveOps.weekly_progress_summary() if LiveOps.has_method("weekly_progress_summary") else {}
		var done_last: int = int(summary.get("done", 0))
		var total_last: int = int(summary.get("total", 7))
		var hours_left: int = int(summary.get("hours_left", 24))
		if done_last < total_last:
			var urgent_text: String = Loc.t("WEEKLY_LAST_DAY") % [done_last, total_last, hours_left] if not Loc.t("WEEKLY_LAST_DAY").begins_with("WEEKLY") else "⏰ ÚLTIMO DIA! %d/%d missões • %dh restantes" % [done_last, total_last, hours_left]
			_note(urgent_text, 26, Color("ef5350"), true)

	var weekly_done_count: int = 0
	for weekly_entry: Dictionary in ContentDB.weekly_missions:
		if GameState.claimed_weeklies.has(String(weekly_entry.get("id", ""))):
			weekly_done_count += 1
	var weekly_total: int = maxi(1, ContentDB.weekly_missions.size())
	var weekly_percent: int = int(float(weekly_done_count) / float(weekly_total) * 100.0)
	var reset_in: String = LiveOps.weekly_reset_label()
	_add_weekly_progress_card(weekly_done_count, weekly_total, weekly_percent, reset_in)

	var weekly_grid: GridContainer = GridContainer.new()
	weekly_grid.name = "WeeklyMissionGrid"
	weekly_grid.columns = 2
	weekly_grid.add_theme_constant_override("h_separation", 12)
	weekly_grid.add_theme_constant_override("v_separation", 12)
	screen.content_box.add_child(weekly_grid)
	for weekly: Dictionary in ContentDB.weekly_missions:
		var weekly_id: String = String(weekly["id"])
		var target: int = int(weekly["target"])
		var value: int = mini(GameState.weekly_value(String(weekly["metric"])), target)
		var weekly_done: bool = GameState.claimed_weeklies.has(weekly_id)
		var weekly_ready: bool = value >= target and not weekly_done
		var reward: Dictionary = weekly.get("reward", {})
		var reward_text: String = (
			"%s %d" % [Loc.t("COINS"), Rewards.for_kind(&"weekly_mission", int(reward.get("coins", 0)))]
			if reward.has("coins")
			else "%d %s" % [int(reward.get("embers", 0)), Loc.t("EMBERS")]
		)
		_add_mission_card(
			weekly_grid, Loc.t(String(weekly["label_key"])) % value, value, target, reward_text,
			String(weekly.get("metric", "services")), weekly_ready, weekly_done, false,
			func(claimed_id: String = weekly_id) -> void:
				if GameState.claim_weekly(claimed_id):
					AudioManager.play(&"coin")
					GameState.check_weekly_chest()
		)


func _add_weekly_progress_card(done: int, total: int, percent: int, reset_in: String) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.name = "WeeklyProgressCard"
	card.custom_minimum_size = Vector2(0, 104)
	card.tooltip_text = Loc.t("WEEKLY_PROGRESS_PILL") % [done, total, percent, done, reset_in]
	card.add_theme_stylebox_override("panel", StyleFactory.box(Color("ffffff", 0.94), 24, 16, Color("4fc3f7"), 3))
	screen.content_box.add_child(card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(70, 70)
	icon.texture = load("res://art/ui/icons/missions.png") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)
	var summary_row: HBoxContainer = HBoxContainer.new()
	info.add_child(summary_row)
	var count_label: Label = _label_node("🏆 %d/%d" % [done, total], 30, CHARCOAL)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_child(count_label)
	var timer_label: Label = _label_node("⏳ " + reset_in, 22, Color("546e7a"))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary_row.add_child(timer_label)
	var progress: ProgressBar = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 16)
	progress.min_value = 0.0
	progress.max_value = total
	progress.value = done
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", StyleFactory.box(Color("eceff1"), 10, 0))
	progress.add_theme_stylebox_override("fill", StyleFactory.box(Color("4fc3f7"), 10, 0))
	info.add_child(progress)


func _mission_icon_path(metric: String) -> String:
	var path: String = "res://art/ui/icons/missions.png"
	match metric:
		"services": path = "res://art/props/tool_soap.png"
		"style": path = "res://art/props/tool_bow.png"
		"upgrades": path = "res://art/ui/icons/upgrades.png"
		"four_plus_reviews", "tips": path = "res://art/ui/icons/album.png"
		"vip": path = "res://art/ui/icons/staff.png"
		"spend": path = "res://art/ui/icons/shop.png"
	return path if ResourceLoader.exists(path) else "res://art/ui/icons/missions.png"


func _add_mission_card(
	parent: GridContainer,
	title: String,
	value: int,
	target: int,
	reward_text: String,
	metric: String,
	ready: bool,
	claimed: bool,
	epic: bool,
	on_claim: Callable,
) -> void:
	var card: PanelContainer = MISSION_CARD.instantiate() as PanelContainer
	card.name = "MissionCard_%s" % str(parent.get_child_count() + 1)
	var accent: Color = Color("b0bec5") if claimed else (Color("ce93d8") if epic else (GREEN if ready else BLUE))
	var surface: Color = Color("f5f5f5") if claimed else (Color("fff8ff") if epic else (Color("f1f8e9") if ready else Color("ffffff", 0.96)))
	card.add_theme_stylebox_override("panel", StyleFactory.box(surface, 22, 12, accent, 3))
	card.tooltip_text = "%s\n🎁 %s" % [title, reward_text]
	parent.add_child(card)

	var icon_frame: PanelContainer = card.get_node("Row/IconFrame") as PanelContainer
	icon_frame.add_theme_stylebox_override("panel", StyleFactory.box(Color(accent, 0.14), 18, 5))
	var icon: TextureRect = card.get_node("Row/IconFrame/Icon") as TextureRect
	icon.texture = load(_mission_icon_path(metric)) as Texture2D

	var title_label: Label = card.get_node("Row/Details/Title") as Label
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", int(22 * float(GameState.settings.get("font_scale", 1.0))))
	title_label.add_theme_color_override("font_color", CHARCOAL)
	title_label.tooltip_text = title
	var progress: ProgressBar = card.get_node("Row/Details/Progress") as ProgressBar
	progress.min_value = 0.0
	progress.max_value = maxi(1, target)
	progress.value = clampi(value, 0, maxi(1, target))
	progress.add_theme_stylebox_override("background", StyleFactory.box(Color("eceff1"), 9, 0))
	progress.add_theme_stylebox_override("fill", StyleFactory.box(accent, 9, 0))
	var reward: Label = card.get_node("Row/Details/Footer/Reward") as Label
	reward.text = "🎁 " + reward_text
	reward.add_theme_font_size_override("font_size", int(18 * float(GameState.settings.get("font_scale", 1.0))))
	reward.add_theme_color_override("font_color", Color("546e7a"))
	var action: Button = card.get_node("Row/Details/Footer/Action") as Button
	action.visible = ready or claimed
	action.text = "✓" if claimed else Loc.t("CLAIM")
	action.disabled = claimed or not ready
	action.custom_minimum_size = Vector2(64 if claimed else 108, 64)
	action.set_meta("game_action_connected", ready and not claimed and on_claim.is_valid())
	action.tooltip_text = Loc.t("CLAIMED") if claimed else (Loc.t("CLAIM") if ready else "")
	_style_button(action, Color("b0bec5") if claimed else accent)
	action.add_theme_font_size_override("font_size", int(18 * float(GameState.settings.get("font_scale", 1.0))))
	if ready and not claimed and on_claim.is_valid():
		action.pressed.connect(func() -> void:
			on_claim.call()
			if refresh_callback.is_valid():
				refresh_callback.call()
			_rebuild(_current_section())
		)


var _collection_filter: StringName = &"all"

func _build_collection() -> void:
	# Filtros rápidos: Todos / Cães / Gatos / Lendários (UX de coleção grande) — agora localizados
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 10)
	screen.content_box.add_child(filter_row)
	for f: Dictionary in [ {"id": &"all", "label_key": "FILTER_ALL"}, {"id": &"dog", "label_key": "FILTER_DOGS"},
		{"id": &"cat", "label_key": "FILTER_CATS"},
		{"id": &"legendary", "label_key": "FILTER_LEGENDARY"},
	]:
		var fid: StringName = f["id"]
		var active: bool = _collection_filter == fid
		var btn: Button = Button.new()
		btn.name = "CollectionFilter_%s" % String(fid)
		btn.set_meta("game_action_connected", true)
		btn.text = Loc.t(String(f["label_key"]))
		btn.custom_minimum_size = Vector2(150, 64)
		_style_button(btn, PINK if active else Color("b0bec5"))
		btn.pressed.connect( func(id: StringName = fid) -> void:
				_collection_filter = id
				_rebuild(&"collection")
		)
		filter_row.add_child(btn)

	_add_collection_stat_strip()

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	screen.content_box.add_child(grid)
	var filtered: Array[Dictionary] = []
	for pet_entry: Dictionary in ContentDB.pets:
		if _collection_filter == &"dog" and String(pet_entry.get("species", "")) != "dog":
			continue
		if _collection_filter == &"cat" and String(pet_entry.get("species", "")) != "cat":
			continue
		if _collection_filter == &"legendary" and String(pet_entry.get("rarity", "")) != "legendary":
			continue
		filtered.append(pet_entry)
	for pet: Dictionary in filtered:
		var pet_id: String = String(pet.get("id", ""))
		var unlocked: bool = GameState.unlocked_pets.has(pet_id)
		var card: PanelContainer = PET_CARD.instantiate()
		var card_alpha: float = 0.94 if unlocked else 0.74
		var card_border: Color = PINK if unlocked else Color("90a4ae")
		card.add_theme_stylebox_override("panel", StyleFactory.box(Color("ffffff", card_alpha), 22, 10, card_border, 3))
		grid.add_child(card)
		var portrait: TextureRect = card.get_node("VBox/Portrait") as TextureRect
		var path: String = "res://art/pets/%s.png" % pet_id
		if ResourceLoader.exists(path):
			portrait.texture = load(path) as Texture2D
		portrait.modulate = Color.WHITE if unlocked else Color("455a64", 0.60)
		var name_label: Label = card.get_node("VBox/Name") as Label
		name_label.text = ("★ " if GameState.favorite_pet == pet_id else "") + (ContentDB.pet_name(pet_id) if unlocked else "🔒")
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", CHARCOAL)
		name_label.clip_text = true
		var sub: Label = card.get_node("VBox/Sub") as Label
		var aff: int = int(GameState.pet_affection.get(pet_id, 0))
		var all_mems: Array[String] = PetStories.all_memories(pet_id) if unlocked else []
		var memories_unlocked: int = 0
		if aff >= 1 and all_mems.size() > 0: memories_unlocked += 1
		if aff >= 10 and all_mems.size() > 1: memories_unlocked += 1
		if aff >= 25 and all_mems.size() > 2: memories_unlocked += 1
		if unlocked:
			sub.text = "♥ %d/50  •  📖 %d/3" % [aff, memories_unlocked]
		elif Discovery.progress(pet_id) > 0:
			sub.text = "🐾 %d/%d" % [Discovery.progress(pet_id), Discovery.VISITS_TO_ADOPT]
		else:
			sub.text = "%s %d" % [Loc.t("HUD_LEVEL_ABBR"), int(pet.get("unlock_level", 1))]
		sub.add_theme_font_size_override("font_size", 17)
		sub.add_theme_color_override("font_color", PINK if unlocked else Color("546e7a"))
		if unlocked:
			var bio_text: String = PetStories.bio(pet)
			var visible_memories: Array[String] = []
			if memories_unlocked > 0: visible_memories.assign(all_mems.slice(0, memories_unlocked))
			var diary_full: String = "\n".join(visible_memories)
			card.tooltip_text = "%s\n%s\n%s" % [Loc.t("FAVORITE_HINT"), bio_text, diary_full] if not bio_text.is_empty() else "%s\n%s" % [Loc.t("FAVORITE_HINT"), diary_full]
			# Feedback visual P1: hover scale + pressed
			card.pivot_offset = card.custom_minimum_size * 0.5
			card.mouse_entered.connect(func(): card.create_tween().tween_property(card, "scale", Vector2(1.05, 1.05), 0.12))
			card.mouse_exited.connect(func(): card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.12))
			card.gui_input.connect(func(event: InputEvent, pid: String = pet_id) -> void:
				var pointer_pressed: bool = false
				var pointer_released: bool = false
				if event is InputEventScreenTouch:
					pointer_pressed = event.pressed
					pointer_released = not event.pressed
				elif event is InputEventMouseButton:
					if event.button_index != MOUSE_BUTTON_LEFT:
						return
					pointer_pressed = event.pressed
					pointer_released = not event.pressed
				else:
					return
				if pointer_pressed:
					card.create_tween().tween_property(card, "scale", Vector2(0.95, 0.95), 0.08)
				elif pointer_released:
					if GameState.set_favorite_pet(pid):
						AudioManager.play(&"tap")
						HapticsManager.light()
						EventBus.toast_requested.emit(Loc.t("FAVORITE_SET"), GREEN)
						_rebuild(&"collection")
					else:
						card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.12)
			)

	# Conquistas com card compartilhável (viralização de progresso)
	var ach_count: String = "(%d/%d)" % [ GameState.achievement_ids.size(), ContentDB.achievements.size()
	]
	_note(Loc.t("COLLECTION_STAT_ACHIEVEMENTS") + " " + ach_count, 26, CHARCOAL)
	for achievement: Dictionary in ContentDB.achievements:
		var aid: String = String(achievement.get("id", ""))
		var unlocked: bool = GameState.achievement_ids.has(aid)
		var reward: Dictionary = achievement.get("reward", {})
		var reward_text: String = ""
		if reward.has("coins"):
			var c: int = Rewards.for_kind(&"achievement", int(reward.get("coins", 0)))
			reward_text = "%s %d" % [Loc.t("COINS"), c]
		elif reward.has("embers"):
			reward_text = "%d %s" % [int(reward.get("embers", 0)), Loc.t("EMBERS")]
		var action: String = Loc.t("SHARE_ACHIEVEMENT_BUTTON") if unlocked else Loc.t("LOCKED") % 1
		var desc_base: String = String(achievement.get("description", ""))
		var desc_full: String = desc_base
		if not reward_text.is_empty():
			desc_full += " • " + reward_text
		_info_row( ContentDB.achievement_name(aid), desc_full, action, Color("ffd54f") if unlocked else Color("b0bec5"), unlocked,
			func(aid_inner: String = aid) -> void:
				var saved_path: String = await ShareManager.share_achievement(aid_inner)
				if not saved_path.is_empty():
					var channel: StringName = ShareManager.share_last()
					if channel == &"web_share":
						EventBus.toast_requested.emit(Loc.t("SHARE_WEB"), BLUE)
					else:
						EventBus.toast_requested.emit(Loc.t("SHARE_SAVED_GALLERY"), BLUE)
		)


func _add_collection_stat_strip() -> void:
	var pets_count: String = "%d/%d" % [GameState.unlocked_pets.size(), ContentDB.pets.size()]
	var achievements_count: String = "%d/%d" % [GameState.achievement_ids.size(), ContentDB.achievements.size()]
	var cosmetics_count: String = "%d/%d" % [GameState.unlocked_cosmetics.size(), ContentDB.cosmetics.size()]
	var summary_text: String = Loc.t("COLLECTION_SUMMARY") % [
		GameState.unlocked_pets.size(), ContentDB.pets.size(), GameState.achievement_ids.size(),
		ContentDB.achievements.size(), GameState.unlocked_cosmetics.size(),
	]
	var stats: Array[Dictionary] = [
		{"icon": "collection", "value": pets_count, "hint": Loc.t("COLLECTION_STAT_PETS")},
		{"icon": "missions", "value": achievements_count, "hint": Loc.t("COLLECTION_STAT_ACHIEVEMENTS")},
		{"icon": "shop", "value": cosmetics_count, "hint": Loc.t("COLLECTION_STAT_COSMETICS")},
	]
	var strip: HBoxContainer = HBoxContainer.new()
	strip.name = "CollectionStatStrip"
	strip.add_theme_constant_override("separation", 10)
	screen.content_box.add_child(strip)
	for stat: Dictionary in stats:
		var tile: PanelContainer = PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(0, 76)
		tile.tooltip_text = "%s\n%s" % [String(stat["hint"]), summary_text]
		tile.add_theme_stylebox_override("panel", StyleFactory.box(Color("ffffff", 0.94), 20, 8, Color("ff8fb1"), 2))
		strip.add_child(tile)
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		tile.add_child(row)
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(42, 42)
		icon.texture = load("res://art/ui/icons/%s.png" % String(stat["icon"])) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var count: Label = _label_node(String(stat["value"]), 22, CHARCOAL)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count)


func _build_album() -> void:
	# harden: GameState/Loc podem não estar prontos no editor headless ou primeiro frame
	if GameState == null or not is_instance_valid(screen) or screen.content_box == null:
		_note(Loc.t("LOADING_ALBUM"), 22, Color("90a4ae"))
		return
	_build_contest()
	# Grid de fotos
	if GameState.park_photos.is_empty():
		_note(Loc.t("ALBUM_EMPTY"), 24, Color("90a4ae"), true)
		return
	_note(Loc.t("ALBUM_GRID_TITLE"), 26, CHARCOAL)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	screen.content_box.add_child(grid)
	# mostra mais recentes primeiro, max 18
	var photos: Array[Dictionary] = GameState.park_photos.duplicate()
	photos.reverse()
	var shown: int = 0
	for photo: Dictionary in photos:
		if shown >= 18:
			break
		shown += 1
		var pets_raw: Variant = photo.get("pets", [])
		var pets: Array = pets_raw if pets_raw is Array else []
		var names: PackedStringArray = PackedStringArray()
		for pid: Variant in pets:
			var spid: String = String(pid)
			names.append(ContentDB.pet_name(spid) if ContentDB.has_pet(spid) else spid.capitalize())
		var names_text: String = ", ".join(names)
		var date: String = String(photo.get("date", ""))
		var perfect: bool = bool(photo.get("perfect", false))
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(260, 250)
		card.add_theme_stylebox_override("panel", StyleFactory.box(Color.WHITE, 18, 8, Color("ffd54f") if perfect else Color("b0bec5"), 3))
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		# Thumb 4:3 (240×150) COVER + clip 12px — evita letterbox e preserva rosto do pet
		var thumb_wrap: PanelContainer = PanelContainer.new()
		thumb_wrap.custom_minimum_size = Vector2(240, 150)
		thumb_wrap.clip_contents = true
		thumb_wrap.add_theme_stylebox_override("panel", StyleFactory.box(Color("f5f5f5"), 12, 0))
		vbox.add_child(thumb_wrap)
		var thumb: TextureRect = TextureRect.new()
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.custom_minimum_size = Vector2(240, 150)
		thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# primeiro pet da foto — id validado pelo ContentDB (sem path traversal)
		var first_pet: String = "caramelo"
		if pets.size() > 0 and ContentDB.has_pet(String(pets[0])):
			first_pet = String(pets[0])
		var tpath: String = "res://art/pets/%s.png" % first_pet
		if ResourceLoader.exists(tpath):
			thumb.texture = load(tpath) as Texture2D
		thumb.modulate = Color.WHITE if perfect else Color("ffffff", 0.96)
		thumb_wrap.add_child(thumb)
		var nlabel: Label = Label.new()
		nlabel.text = names_text if not names_text.is_empty() else Loc.t("ALBUM_PHOTO_FALLBACK")
		nlabel.add_theme_font_size_override("font_size", 18)
		nlabel.add_theme_color_override("font_color", CHARCOAL)
		nlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(nlabel)
		var dlabel: Label = Label.new()
		dlabel.text = "%s • %s" % [date, Loc.t("ALBUM_BADGE_PERFECT") if perfect else Loc.t("ALBUM_BADGE_GOOD")]
		dlabel.add_theme_font_size_override("font_size", 16)
		dlabel.add_theme_color_override("font_color", PINK if perfect else Color("90a4ae"))
		vbox.add_child(dlabel)
		var share_btn: Button = Button.new()
		share_btn.text = Loc.t("ALBUM_SHARE")
		share_btn.custom_minimum_size = Vector2(240, 44)
		_style_button(share_btn, BLUE if perfect else Color("b0bec5"))
		# captura por valor (default args) para não compartilhar a última iteração do loop
		share_btn.pressed.connect(func(n: String = names_text, d: String = date) -> void:
			DisplayServer.clipboard_set(Loc.t("ALBUM_SHARE_CAPTION") % [d, n])
			EventBus.toast_requested.emit(Loc.t("SHARE_SAVED_GALLERY"), BLUE)
		)
		vbox.add_child(share_btn)
		grid.add_child(card)
	_note(Loc.t("ALBUM_FOOTER"), 22, Color("90a4ae"), true)


## Concurso da Capa: prêmio pendente, placar você × 3 rivais, dica e histórico.
func _build_contest() -> void:
	var st: Dictionary = Contest.status()
	var points: int = int(st.get("points", 0))
	var placement: int = int(st.get("rank", 4))
	if bool(st.get("pending", false)):
		var pending: Dictionary = GameState.park_contest_pending
		var pending_rank: int = clampi(int(pending.get("rank", 4)), 1, 4)
		_info_row(
			Loc.t("CONTEST_RESULT_TITLE_%d" % pending_rank),
			Loc.t("CONTEST_PENDING_ROW") % [Contest.placement_label(pending_rank), int(pending.get("points", 0))],
			Loc.t("CONTEST_CLAIM"), GREEN, true,
			func() -> void:
				var result: Dictionary = Contest.claim()
				if result.is_empty():
					return
				AudioManager.play(&"perfect")
				HapticsManager.success()
				EventBus.toast_requested.emit(Loc.t("CONTEST_CLAIM_TOAST") % [int(result.get("coins", 0)), int(result.get("embers", 0))], Color("ffd54f"))
		)
	_info_row(Loc.t("CONTEST_TITLE"), Loc.t("CONTEST_DESC"), "⏱ " + Contest.format_time_left(int(st.get("seconds_left", 0))), Color("ffd54f"), false, Callable())
	if bool(st.get("saturday", false)):
		_note(Loc.t("CONTEST_SATURDAY_TAG"), 24, Color("f9a825"))
	# Placar: você + 3 rivais, ordenado por votos (empate favorece o jogador)
	var shop_name: String = String(GameState.settings.get("shop_name", "")).strip_edges()
	var rows: Array[Dictionary] = [{"name": shop_name if not shop_name.is_empty() else Loc.t("CONTEST_YOUR_SHOP"), "emoji": "🏠", "score": points, "you": true}]
	for rival: Dictionary in st.get("rivals", []):
		rows.append({"name": String(rival["name"]), "emoji": String(rival["emoji"]), "score": int(rival["score"]), "you": false})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return bool(a["you"])
	)
	var board: VBoxContainer = VBoxContainer.new()
	board.add_theme_constant_override("separation", 8)
	screen.content_box.add_child(board)
	var medals: Array[String] = ["🥇", "🥈", "🥉", "4º"]
	var best_score: int = int(rows[0]["score"])
	for i: int in rows.size():
		var entry: Dictionary = rows[i]
		var you: bool = bool(entry["you"])
		var line: PanelContainer = PanelContainer.new()
		line.add_theme_stylebox_override("panel", StyleFactory.box(Color("fff8e1") if you else Color("ffffff", 0.9), 18, 12, Color("ffd54f") if you else Color("eceff1"), 3 if you else 2))
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		line.add_child(column)
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		column.add_child(hbox)
		var name_label: Label = _label_node("%s  %s %s" % [medals[mini(i, 3)], String(entry["emoji"]), String(entry["name"])], 24, CHARCOAL)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hbox.add_child(name_label)
		hbox.add_child(_label_node(Loc.t("CONTEST_VOTES") % int(entry["score"]), 24, GREEN if you else Color("546e7a")))
		var bar_bg: ColorRect = ColorRect.new()
		bar_bg.color = Color("eceff1")
		bar_bg.custom_minimum_size = Vector2(0, 8)
		column.add_child(bar_bg)
		var bar: ColorRect = ColorRect.new()
		bar.color = Color("ffd54f") if you else Color("b0bec5")
		bar.anchor_right = clampf(float(entry["score"]) / float(maxi(1, best_score)), 0.0, 1.0)
		bar.anchor_bottom = 1.0
		bar_bg.add_child(bar)
		board.add_child(line)
	var hint: String = Loc.t("CONTEST_NOT_ENTERED")
	if points > 0:
		hint = Loc.t("CONTEST_LEADING") if placement == 1 else Loc.t("CONTEST_TO_FIRST") % int(st.get("to_first", 0))
	_note(hint, 22, PINK if points > 0 and placement > 1 else Color("558b2f"), true)
	_note(Loc.t("CONTEST_RULE_SHORT"), 20, Color("90a4ae"), true)
	var summary: String = Loc.t("CONTEST_TROPHIES") % GameState.park_trophies
	var best: int = Contest.best_rank()
	if best > 0:
		summary += "  •  " + Loc.t("CONTEST_BEST") % Contest.placement_label(best)
	_note(summary, 22, CHARCOAL)
	if not GameState.park_contest_history.is_empty():
		_note(Loc.t("CONTEST_HISTORY_TITLE"), 22, Color("90a4ae"))
		var history: Array[Dictionary] = GameState.park_contest_history.duplicate()
		history.reverse()
		for entry: Dictionary in history.slice(0, 4):
			var monday: String = Time.get_date_string_from_unix_time(int(String(entry.get("week", "0"))) * 86400)
			_note(Loc.t("CONTEST_HISTORY_ROW") % [monday, Contest.placement_label(int(entry.get("rank", 4))), int(entry.get("points", 0))], 20, Color("546e7a"), true)
	Contest.mark_seen()

## Painel de melhorias: estação + os cinco utensílios. Tudo que era botão
## grande no HUD de ação agora vive aqui, comprável com moedas.
func _build_upgrades() -> void:
	_note("%s: %d" % [Loc.t("COINS"), int(GameState.coins)], 30, CHARCOAL)
	var station_level: int = GameState.bath_upgrade_level
	var station_icon: String = "res://art/props/tool_soap.png"
	if station_level >= GameState.MAX_CAREER_LEVEL:
		var bonus: float = (Economy.income_multiplier(station_level) - 1.0) * 100.0
		_info_row_with_icon(
			Loc.t("UPGRADES_STATION"),
			"Nv.%d  •  +%.0f%% %s" % [station_level, bonus, Loc.t("UPGRADES_REWARD")],
			Loc.t("UPGRADES_MAXED"), Color("b0bec5"), false, station_icon, Callable()
		)
	else:
		var cost: float = Economy.upgrade_cost(station_level)
		_info_row_with_icon(
			Loc.t("UPGRADES_STATION"),
			"Nv.%d  •  +7,5%% %s  •  %s %d" % [station_level, Loc.t("UPGRADES_PER_LEVEL"), Loc.t("COINS"), int(cost)],
			Loc.t("UPGRADES_UPGRADE"), GREEN, cost <= GameState.coins, station_icon,
			func() -> void:
				if GameState.buy_bath_upgrade():
					AudioManager.play(&"upgrade")
					HapticsManager.success()
					EventBus.toast_requested.emit(Loc.t("UPGRADES_STATION_LEVEL") % GameState.bath_upgrade_level, GREEN)
				else:
					_upgrades_missing_toast(cost)
		)

	var tools: Array = [
		{"id": &"soap", "key": "TOOL_SOAP", "level": 1},
		{"id": &"clipper", "key": "TOOL_CLIPPER", "level": 3},
		{"id": &"dryer", "key": "TOOL_DRYER", "level": 5},
		{"id": &"perfume", "key": "TOOL_PERFUME", "level": 7},
		{"id": &"bow", "key": "TOOL_BOW", "level": 10},
	]
	for tool: Dictionary in tools:
		var tool_id: StringName = StringName(tool["id"])
		var level: int = int(GameState.tool_upgrade_levels.get(String(tool_id), 0))
		var locked: bool = GameState.player_level < int(tool["level"])
		var tool_cost: float = GameState.tool_upgrade_cost(tool_id)
		var tool_icon_path: String = "res://art/props/tool_%s.png" % String(tool_id)
		if locked:
			_info_row_with_icon(
				Loc.t(String(tool["key"])), Loc.t("UPGRADES_LOCKED") % int(tool["level"]), "",
				Color("b0bec5"), false, tool_icon_path, Callable()
			)
		elif level >= 30:
			_info_row_with_icon(
				Loc.t(String(tool["key"])), "Nv.%d/30  •  +%d%%" % [level, level * 4],
				Loc.t("UPGRADES_MAXED"), Color("b0bec5"), false, tool_icon_path, Callable()
			)
		else:
			_info_row_with_icon(
				Loc.t(String(tool["key"])),
				"Nv.%d/30  •  +4%% %s  •  %s %d" % [level, Loc.t("UPGRADES_PER_LEVEL"), Loc.t("COINS"), int(tool_cost)],
				Loc.t("UPGRADES_UPGRADE"), BLUE, tool_cost <= GameState.coins, tool_icon_path,
				func() -> void:
					if GameState.buy_tool_upgrade(tool_id):
						AudioManager.play(&"upgrade")
						HapticsManager.success()
						EventBus.toast_requested.emit(Loc.t("UPGRADES_TOOL_UP") % Loc.t(String(tool["key"])), GREEN)
					else:
						_upgrades_missing_toast(tool_cost)
			)


func _upgrades_missing_toast(cost: float) -> void:
	EventBus.toast_requested.emit( Loc.t("UPGRADES_MISSING") % maxi(0, int(cost - GameState.coins)), Color("ef5350")
	)


func _build_staff() -> void:
	for member: Dictionary in ContentDB.staff_members:
		var staff_id: String = String(member.get("id", ""))
		var hired: bool = GameState.hired_staff.has(staff_id)
		var passive: Dictionary = member.get("passive", {})
		var passive_key: String = "PASSIVE_" + String(passive.get("type", "speed")).to_upper()
		var cost: int = GameState.hire_cost(staff_id)
		var automation: int = int(roundf(float(member.get("automation", 0.0)) * 100.0))
		var dialogue: String = StaffStories.dialogue_for(staff_id, GameState.player_level)
		var desc: String = "%s • %s" % [Loc.t(GameState.staff_vocation(staff_id)), Loc.t(passive_key)]
		if automation > 0:
			desc += "\n" + Loc.t("STAFF_AUTOMATION") % automation
		if not dialogue.is_empty():
			desc += "\n💬 %s" % dialogue
		var portrait_path: String = "res://art/characters/bia_hello.png" if staff_id == "bia" else "res://art/ui/icons/staff.png"
		_info_row_with_icon(
			ContentDB.staff_name(staff_id), desc,
			Loc.t("HIRED") if (hired or staff_id == "player") else "%s • %s %d" % [Loc.t("HIRE"), Loc.t("COINS"), cost],
			Color("b0bec5") if (hired or staff_id == "player") else BLUE,
			not hired and staff_id != "player" and GameState.coins >= float(cost), portrait_path,
			func(sid: String = staff_id) -> void:
				if GameState.hire_staff(sid):
					AudioManager.play(&"upgrade")
					EventBus.toast_requested.emit("%s: %s" % [ContentDB.staff_name(sid), Loc.t("HIRED")], GREEN)
		)


var _shop_filter: StringName = &"all"

func _cosmetic_icon_path(cosmetic_id: String) -> String:
	var accessory_path: String = "res://art/cosmetics/%s.png" % cosmetic_id
	if ResourceLoader.exists(accessory_path):
		return accessory_path
	var slot: String = String(ContentDB.cosmetic(cosmetic_id).get("slot", ""))
	if slot == "bath":
		return "res://art/stations/station_bathtub_rustic.png"
	return "res://art/ui/icons/shop.png"


func _apply_cosmetic_action(cosmetic_id: String) -> void:
	if GameState.unlocked_cosmetics.has(cosmetic_id):
		var slot: String = String(ContentDB.cosmetic(cosmetic_id).get("slot", ""))
		var was_active: bool = not slot.is_empty() and GameState.active_cosmetic(slot) == cosmetic_id
		if not GameState.equip_cosmetic(cosmetic_id):
			AudioManager.play(&"error_soft")
			return
		AudioManager.play(&"equip")
		if was_active:
			EventBus.toast_requested.emit(Loc.t("COSMETIC_UNEQUIPPED") % ContentDB.cosmetic_name(cosmetic_id), BLUE)
		else:
			EventBus.toast_requested.emit("%s ✓" % ContentDB.cosmetic_name(cosmetic_id), GREEN)
	elif GameState.buy_cosmetic(cosmetic_id):
		if GameState.equip_cosmetic(cosmetic_id):
			AudioManager.play(&"coin")
			EventBus.toast_requested.emit("%s ✓" % ContentDB.cosmetic_name(cosmetic_id), GREEN)
	else:
		AudioManager.play(&"error_soft")


func _build_shop() -> void:
	# Abas: Destaque / Banheiras / Paredes / Acessórios / Tudo — agora localizadas + 64px altura mínima
	var shop_filter_row: HBoxContainer = HBoxContainer.new()
	shop_filter_row.add_theme_constant_override("separation", 10)
	screen.content_box.add_child(shop_filter_row)
	for sf: Dictionary in [ {"id": &"all", "label_key": "FILTER_ALL_COSMETICS"}, {"id": &"bath", "label_key": "FILTER_BATH"},
		{"id": &"wall", "label_key": "FILTER_WALL"},
		{"id": &"pet_accessory", "label_key": "FILTER_ACCESSORY"},
	]:
		var fid: StringName = sf["id"]
		var active: bool = _shop_filter == fid
		var btn: Button = Button.new()
		btn.name = "ShopFilter_%s" % String(fid)
		btn.set_meta("game_action_connected", true)
		btn.text = Loc.t(String(sf["label_key"]))
		btn.custom_minimum_size = Vector2(150, 64)
		_style_button(btn, Color("ffd54f") if active else Color("b0bec5"))
		btn.pressed.connect( func(id: StringName = fid) -> void:
				_shop_filter = id
				_rebuild(&"shop")
		)
		shop_filter_row.add_child(btn)

	# Rotativo semanal + diário (LiveOps sem build): Nota10 P1-8 rotação diária além da semanal
	var featured_id: String = ContentDB.weekly_featured_cosmetic()
	var daily_id: String = ContentDB.daily_featured_cosmetic() if ContentDB.has_method("daily_featured_cosmetic") else ""
	if not daily_id.is_empty() and daily_id != featured_id:
		var daily_feat: Dictionary = ContentDB.cosmetic(daily_id)
		if not daily_feat.is_empty():
			var d_price: Dictionary = daily_feat.get("price", {})
			var daily_coin_cost: int = Rewards.cosmetic_price(daily_id) if d_price.has("coins") else 0
			var daily_ember_cost: int = int(d_price.get("embers", 0))
			var d_price_text: String = "%s %d" % [Loc.t("COINS"), daily_coin_cost] if d_price.has("coins") else "%d %s" % [daily_ember_cost, Loc.t("EMBERS")]
			var daily_owned: bool = GameState.unlocked_cosmetics.has(daily_id)
			var daily_active: bool = GameState.active_cosmetic(String(daily_feat.get("slot", ""))) == daily_id
			var daily_action: String = Loc.t("UNEQUIP") if daily_active else (Loc.t("EQUIP") if daily_owned else d_price_text)
			var daily_affordable: bool = GameState.coins >= daily_coin_cost and GameState.embers >= daily_ember_cost
			var daily_enabled: bool = daily_owned or (daily_affordable and not d_price.is_empty())
			_info_row_with_icon(
				"☀️ %s • %s" % [Loc.t("DAILY_FEATURED"), ContentDB.cosmetic_name(daily_id)],
				Loc.t("DAILY_FEATURED_DESC"), daily_action,
				Color("b0bec5") if daily_active else (PINK if daily_owned else Color("4fc3f7")),
				daily_enabled, _cosmetic_icon_path(daily_id),
				func(fid: String = daily_id) -> void:
					_apply_cosmetic_action(fid)
			)

	if not featured_id.is_empty():
		var featured: Dictionary = ContentDB.cosmetic(featured_id)
		if not featured.is_empty():
			var feat_price: Dictionary = featured.get("price", {})
			var featured_coin_cost: int = Rewards.cosmetic_price(featured_id) if feat_price.has("coins") else 0
			var featured_ember_cost: int = int(feat_price.get("embers", 0))
			var feat_price_text: String = "%s %d" % [Loc.t("COINS"), featured_coin_cost] if feat_price.has("coins") else "%d %s" % [featured_ember_cost, Loc.t("EMBERS")]
			var featured_owned: bool = GameState.unlocked_cosmetics.has(featured_id)
			var featured_active: bool = GameState.active_cosmetic(String(featured.get("slot", ""))) == featured_id
			var featured_action: String = Loc.t("UNEQUIP") if featured_active else (Loc.t("EQUIP") if featured_owned else feat_price_text)
			var featured_affordable: bool = GameState.coins >= featured_coin_cost and GameState.embers >= featured_ember_cost
			var featured_enabled: bool = featured_owned or (featured_affordable and not feat_price.is_empty())
			_info_row_with_icon(
				"%s • %s" % [Loc.t("WEEKLY_FEATURED"), ContentDB.cosmetic_name(featured_id)],
				Loc.t("WEEKLY_FEATURED_DESC"), featured_action,
				Color("b0bec5") if featured_active else (PINK if featured_owned else Color("ffd54f")),
				featured_enabled, _cosmetic_icon_path(featured_id),
				func(fid: String = featured_id) -> void:
					_apply_cosmetic_action(fid)
			)

	for look: Dictionary in ContentDB.cosmetics:
		var slot: String = String(look.get("slot", ""))
		if _shop_filter != &"all" and slot != String(_shop_filter):
			continue
		var look_id: String = String(look.get("id", ""))
		var owned: bool = GameState.unlocked_cosmetics.has(look_id)
		var price: Dictionary = look.get("price", {})
		var source: String = String(look.get("source", ""))
		var seasonal: bool = not ContentDB.seasonal(source).is_empty()
		var price_text: String
		if price.has("coins"):
			price_text = "%s %d" % [Loc.t("COINS"), Rewards.cosmetic_price(look_id)]
		elif price.has("embers"):
			price_text = "%d %s" % [int(price["embers"]), Loc.t("EMBERS")]
		else:
			# Sem preço: a origem (temporada com período ou conquista) é legível.
			price_text = LiveOps.source_label(source)
		var is_active: bool = GameState.active_cosmetic(String(look.get("slot", ""))) == look_id
		var action_text: String
		var action_color: Color = PINK
		var coin_cost: int = Rewards.cosmetic_price(look_id) if price.has("coins") else 0
		var ember_cost: int = int(price.get("embers", 0))
		var can_afford: bool = GameState.coins >= coin_cost and GameState.embers >= ember_cost
		var enabled: bool = owned or (not price.is_empty() and can_afford)
		if owned:
			action_text = Loc.t("UNEQUIP") if is_active else Loc.t("EQUIP")
			action_color = GREEN if is_active else PINK
		elif price.is_empty():
			action_text = Loc.t("SOURCE_BTN_SEASON" if seasonal else "SOURCE_BTN_ACHIEVEMENT")
			action_color = Color("b0bec5")
		else:
			action_text = Loc.t("BUY")
		_info_row_with_icon(
			ContentDB.cosmetic_name(look_id), price_text, action_text, action_color, enabled,
			_cosmetic_icon_path(look_id),
			func(lid: String = look_id) -> void:
					_apply_cosmetic_action(lid)
		)
	# Sink de prestígio: token de franquia (ganho no prestige) vira brasas.
	_info_row( Loc.t("FRANCHISE_EXCHANGE"), Loc.t("FRANCHISE_DESC") % GameState.franchise_tokens, "1 → 5 %s" % Loc.t("EMBERS"),
		GREEN if GameState.franchise_tokens > 0 else Color("b0bec5"),
		GameState.franchise_tokens > 0,
		func() -> void:
			if GameState.convert_franchise_token():
				AudioManager.play(&"coin")
				_rebuild(&"shop")
	)
	# Rewarded honesto: explica benefício + limite, com fallback brasa.
	# Sem adapter/provider o botão fica desabilitado (antes parecia clicável e
	# só devolvia o toast de indisponível — auditoria 2026-09-27, 2ª passada).
	var rewarded_ready: bool = AdsManager.is_rewarded_available()
	_info_row( Loc.t("REWARDED_EMBER_TITLE"), Loc.t("REWARDED_EMBER_DESC"), Loc.t("REWARDED_EMBER_ACTION"), BLUE, rewarded_ready, func() -> void:
			AdsManager.request_rewarded(&"ember_shop", _grant_ember)
	)
	for sku: String in IAPManager.PRODUCTS:
		var rew: Dictionary = IAPManager.MOCK_REWARDS.get(StringName(sku), {})
		var em: int = int(rew.get("embers", 0))
		var ent: String = String(rew.get("entitlement", ""))
		var desc: String = Loc.t("PREMIUM_BUNDLE") if sku in ["starter_pack","no_ads"] else Loc.t("PREMIUM_MOCK_ROW") % [em, Loc.t("EMBERS")] if em>0 else Loc.t("PREMIUM_BUNDLE")
		if not ent.is_empty():
			desc += " • %s" % ent
		var has_ent: bool = IAPManager.has_entitlement(StringName(ent)) if not ent.is_empty() else false
		var btn_label: String = Loc.t("OWNED") if has_ent else "%s • %s" % [Loc.t("BUY"), Loc.t("MOCK_TAG") if not IAPManager.provider_ready else ""]
		_info_row( "%s%s" % [sku, " (mock)" if not IAPManager.provider_ready else ""], desc, btn_label, Color("b0bec5") if has_ent else Color("ffd54f"),
			not has_ent,
			func(s: String = sku) -> void:
				if IAPManager.purchase(StringName(s)):
					AudioManager.play(&"coin")
					_rebuild(&"shop")
		)
	_note(Loc.t("COSMETIC_NO_FX"))
	_note(Loc.t("IAP_NOTE"))


func _grant_ember() -> void:
	GameState.embers += 1
	EventBus.currency_changed.emit(&"embers", float(GameState.embers))
	SaveManager.request_save()
	AudioManager.play(&"coin")
	_rebuild(&"shop")


func _build_map() -> void:
	var rep: int = GameState.reviews_sum
	var tier: int = Economy.neighborhood_tier(rep)
	var next_at: int = ( Economy.NEIGHBORHOOD_TIERS[tier + 1]
		if tier + 1 < Economy.NEIGHBORHOOD_TIERS.size()
		else -1
	)
	var rep_line: String = "%s: %s • %d⭐ %s" % [ Loc.t("NEIGHBORHOOD"), Loc.t("NEIGHBORHOOD_%d" % tier), rep,
		"(%d)" % next_at if next_at > 0 else "(MAX)",
	]
	var text: String = ( "EVENTO: %s — %s\n"
		% [LiveOps.current_event_name(), LiveOps.event_description_for(LiveOps.weekday())]
	)
	if LiveOps.event_goal_target() > 0:
		text += Loc.t("EVENT_GOAL_TITLE") + ": " + LiveOps.event_goal_text() + "\n"
	var season: Dictionary = LiveOps.active_seasonal()
	if not season.is_empty():
		var season_id: String = String(season.get("id", ""))
		var gift: Dictionary = ContentDB.cosmetic(String(season.get("cosmetic", "")))
		text += ( Loc.t("SEASON_ACTIVE")
			% [LiveOps.seasonal_name(season_id), String(gift.get("name", Loc.t("SEASON_NO_GIFT")))]
			+ "\n"
		)
	text += ( "CARREIRA: nível %d/120 • %.1fh ativas\n%s\n\n"
		% [GameState.player_level, GameState.active_play_seconds / 3600.0, rep_line]
	)
	for entry: Dictionary in ContentDB.career.get("establishments", []):
		var unlock_level: int = int(entry.get("unlock_level", 1))
		var tier_id: int = int(entry.get("tier", 1))
		var marker: String = "✓" if GameState.player_level >= unlock_level else "□"
		var story: Dictionary = ChapterStories.intro(tier_id)
		var act: String = String(story.get("act", ""))
		var char_name: String = String(story.get("char", ""))
		var snippet: String = String(story.get("text", "")).left(90)
		text += "%s %s — nível %d\n  %s • %s: %s...\n" % [marker, entry.get("name", "Petshop"), unlock_level, act, char_name, snippet]
	text += "\nA jornada foi balanceada para 50+ horas, sem bloquear ações ou compras."
	_note(text, 28, CHARCOAL, true)
	# Ato atual
	var current_tier: int = ContentDB.establishment_for_level(GameState.player_level)
	var current_story: String = ChapterStories.narrative_for_reveal(current_tier)
	_note("📖 %s" % current_story, 24, Color("5d4037"), true)
	var tokens: int = GameState.prestige_tokens_available()
	var bonus_percent: float = ( (Economy.prestige_coin_multiplier(GameState.prestige_level) - 1.0) * 100.0
	)
	var kept_station: int = int(GameState.bath_upgrade_level * GameState.PRESTIGE_KEEP_RATIO)
	_info_row( "%s Nv.%d" % [Loc.t("PRESTIGE_TITLE"), GameState.prestige_level], ( Loc.t("PRESTIGE_DESC") % [tokens, bonus_percent]
			+ "\n"
			+ Loc.t("PRESTIGE_PREVIEW") % [kept_station, GameState.PRESTIGE_START_LEVEL]
		),
		Loc.t("PRESTIGE_GO") if GameState.can_prestige() else Loc.t("PRESTIGE_LOCKED"),
		Color("ce93d8") if GameState.can_prestige() else Color("b0bec5"),
		GameState.can_prestige(),
		func() -> void:
			if GameState.perform_prestige():
				AudioManager.play(&"prestige")
				EventBus.toast_requested.emit( Loc.t("PRESTIGE_DONE") % GameState.prestige_level, Color("ce93d8")
				)
				_rebuild(&"map")
	)
	_note(Loc.t("PRESTIGE_KEEP"))
	_note(Loc.t("PRESTIGE_LOST"))
	_build_research()


## Pesquisa da franquia: sink dos tokens de prestígio com efeito permanente
## (research.json). Cada nó mostra efeito, custo e o que ainda falta pesquisar.
func _build_research() -> void:
	_note( "%s • %s" % [ Loc.t("RESEARCH_TITLE"), Loc.t("RESEARCH_DESC") % [Research.owned_count(), ContentDB.research_nodes.size()], ], 26, CHARCOAL
	)
	_note(Loc.t("FRANCHISE_DESC") % GameState.franchise_tokens)
	for node: Dictionary in ContentDB.research_nodes:
		var node_id: String = String(node.get("id", ""))
		var owned: bool = Research.owned(node_id)
		var can_buy: bool = Research.can_buy(node_id)
		var missing: String = Research.missing_requirements(node_id)
		var action_text: String = Loc.t("RESEARCH_COST") % Research.cost(node_id)
		var desc_text: String = Research.effect_text(node_id)
		if owned:
			action_text = Loc.t("RESEARCH_DONE")
		elif not missing.is_empty():
			desc_text += "\n" + Loc.t("RESEARCH_LOCKED") % missing
		_info_row( "T%d • %s" % [int(node.get("tier", 1)), ContentDB.research_name(node_id)], desc_text, action_text,
			GREEN if owned else (Color("ce93d8") if can_buy else Color("b0bec5")),
			can_buy,
			func(nid: String = node_id) -> void:
				if Research.buy(nid):
					AudioManager.play(&"prestige")
				else:
					AudioManager.play(&"error_soft")
		)
	_note(Loc.t("RESEARCH_NOTE"))


func _build_settings() -> void:
	_add_slider(Loc.t("SFX_VOLUME"), "sfx", 0.9)
	_add_slider(Loc.t("MUSIC_VOLUME"), "music", 0.7)
	_add_toggle(Loc.t("HAPTICS"), "haptics", true)
	_add_toggle(Loc.t("REDUCED_FX") + " / " + Loc.t("ECO_MODE"), "eco_mode", false)
	_add_toggle(Loc.t("NOTIFICATIONS"), "notifications", false)
	# Acessibilidade: tamanho de fonte (pequena/normal/grande) — 0.8 / 1.0 / 1.2
	_note(Loc.t("FONT_SCALE"), 26, CHARCOAL)
	var font_row: HBoxContainer = HBoxContainer.new()
	font_row.add_theme_constant_override("separation", 12)
	screen.content_box.add_child(font_row)
	for option: Dictionary in [ {"label": "FONT_SCALE_SMALL", "value": 0.8}, {"label": "FONT_SCALE_NORMAL", "value": 1.0},
		{"label": "FONT_SCALE_LARGE", "value": 1.2},
	]:
		var current: float = float(GameState.settings.get("font_scale", 1.0))
		var is_active: bool = is_equal_approx(current, float(option["value"]))
		var font_btn: Button = Button.new()
		font_btn.name = "FontScale_%s" % str(int(float(option["value"]) * 10.0))
		font_btn.set_meta("game_action_connected", true)
		_style_button(font_btn, GREEN if is_active else Color("b0bec5"))
		font_btn.text = Loc.t(String(option["label"]))
		font_btn.custom_minimum_size = Vector2(200, 60)
		font_btn.pressed.connect( func(v: float = float(option["value"])) -> void:
				GameState.settings["font_scale"] = v
				SaveManager.request_save()
				EventBus.settings_changed.emit()
				_rebuild(&"settings")
		)
		font_row.add_child(font_btn)
	# Nome do pet shop (personalização): placa da sala e cartão de share.
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	screen.content_box.add_child(name_row)
	name_row.add_child(_label_node(Loc.t("SHOP_NAME") + ":", 28, CHARCOAL))
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = String(GameState.settings.get("shop_name", ""))
	name_edit.placeholder_text = Loc.t("SHOP_NAME_HINT")
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(480, 64)
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.text_changed.connect( func(value: String) -> void:
			GameState.settings["shop_name"] = value.strip_edges().left(18)
			SaveManager.request_save()
			EventBus.settings_changed.emit()
	)
	name_row.add_child(name_edit)
	# Acessibilidade: paleta daltônica, assistência motora, mão esquerda e modo treino fantasma.
	_add_toggle(Loc.t("COLORBLIND_MODE"), "colorblind", false)
	_add_toggle(Loc.t("ASSIST_WINDOW"), "assist_window", false)
	_add_toggle(Loc.t("LEFT_HANDED_MODE"), "left_handed", false)
	_add_toggle(Loc.t("TRAINING_GHOST"), "training_ghost", false)
	# Modo criança: uma chave só deixa tudo largo, lento e com HUD simplificado (7 anos).
	var kids_on: bool = bool(GameState.settings.get("kids_mode", false))
	var kids_title: String = Loc.t("KIDS_MODE_TITLE") if not kids_on else Loc.t("KIDS_MODE_TITLE_ON")
	var kids_desc: String = Loc.t("KIDS_MODE_DESC") if not kids_on else Loc.t("KIDS_MODE_ACTIVE") if Loc.has_method("t") and Loc.t("KIDS_MODE_ACTIVE") != "KIDS_MODE_ACTIVE" else "Ativo: gestos 30% mais fáceis, tempo +35% e alvo maior"
	_info_row(kids_title, kids_desc, Loc.t("ON") if kids_on else Loc.t("OFF"), GREEN if kids_on else Color("b0bec5"), true, func() -> void:
		GameState.settings["kids_mode"] = not bool(GameState.settings.get("kids_mode", false))
		SaveManager.request_save()
		EventBus.settings_changed.emit()
		_rebuild(&"settings")
		AudioManager.play(&"tap")
		if bool(GameState.settings.get("kids_mode", false)):
			EventBus.toast_requested.emit(Loc.t("KIDS_MODE_ON") if Loc.has_method("t") and Loc.t("KIDS_MODE_ON") != "KIDS_MODE_ON" else "Modo Criança ativado! ✨ Mais fácil e divertido", GREEN)
		else:
			EventBus.toast_requested.emit(Loc.t("KIDS_MODE_OFF") if Loc.has_method("t") and Loc.t("KIDS_MODE_OFF") != "KIDS_MODE_OFF" else "Modo Criança desativado", Color("90a4ae"))
	)
	# T-02: saída de emergência do skip — rever o tutorial sem resetar o save.
	_info_row(
		Loc.t("REPLAY_TUTORIAL"),
		Loc.t("REPLAY_TUTORIAL_DESC"),
		Loc.t("REPLAY_TUTORIAL_GO"),
		BLUE,
		true,
		func() -> void:
			if replay_tutorial_callback.is_valid():
				replay_tutorial_callback.call()
			else:
				EventBus.toast_requested.emit(Loc.t("TUTORIAL_REPLAYED"), BLUE)
			AudioManager.play(&"tap")
	)
	# Consentimento de dados de uso (nada é gravado sem isto).
	_add_toggle(Loc.t("ANALYTICS_CONSENT"), "analytics_consent", false)
	# Transferência de progresso sem cloud save: código assinado no clipboard.
	_info_row( Loc.t("TRANSFER_TITLE"), Loc.t("TRANSFER_EXPORT_DESC"), Loc.t("TRANSFER_COPY"), BLUE, true, func() -> void:
			DisplayServer.clipboard_set(SaveManager.export_code())
			EventBus.toast_requested.emit(Loc.t("TRANSFER_COPIED"), BLUE)
	)
	_info_row( Loc.t("TRANSFER_IMPORT"), Loc.t("TRANSFER_IMPORT_DESC"), Loc.t("TRANSFER_PASTE"), Color("ce93d8"), true, func() -> void:
			if SaveManager.import_code(DisplayServer.clipboard_get()):
				EventBus.toast_requested.emit(Loc.t("TRANSFER_DONE"), GREEN)
				if refresh_callback.is_valid():
					refresh_callback.call()
			else:
				EventBus.toast_requested.emit(Loc.t("TRANSFER_INVALID"), Color("ef5350"))
				AudioManager.play(&"error_soft")
	)
	var lang_row: HBoxContainer = HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 10)
	screen.content_box.add_child(lang_row)
	var caption: Label = _label_node(Loc.t("LANGUAGE") + ":", 28, CHARCOAL)
	lang_row.add_child(caption)
	var lang_names: Dictionary = {"pt_BR": Loc.t("LANG_PT"), "en_US": Loc.t("LANG_EN"), "es_ES": Loc.t("LANG_ES")}
	for code: String in Loc.LANGS:
		var lang_button: Button = Button.new()
		lang_button.name = "Language_%s" % code
		lang_button.set_meta("game_action_connected", true)
		_style_button(lang_button, BLUE if code == Loc.lang else Color("b0bec5"))
		lang_button.text = String(lang_names.get(code, code))
		lang_button.custom_minimum_size = Vector2(180, 60)
		lang_button.pressed.connect(func(c: String = code) -> void:
			Loc.set_language(c)
		)
		lang_row.add_child(lang_button)


func _add_slider(caption: String, setting_key: String, default_value: float) -> void:
	var row: HBoxContainer = SLIDER_ROW.instantiate()
	screen.content_box.add_child(row)
	var caption_label: Label = row.get_node("Caption")
	caption_label.text = caption + ":"
	caption_label.add_theme_font_size_override("font_size", 28)
	caption_label.add_theme_color_override("font_color", CHARCOAL)
	# P1: labels min/max para acessibilidade — antes só % atual
	var min_label: Label = Label.new()
	min_label.name = "MinLabel"
	min_label.text = "0%"
	min_label.add_theme_font_size_override("font_size", 18)
	min_label.add_theme_color_override("font_color", Color("90a4ae"))
	min_label.custom_minimum_size = Vector2(40, 0)
	min_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(min_label)
	row.move_child(min_label, 1)
	var max_label: Label = Label.new()
	max_label.name = "MaxLabel"
	max_label.text = "100%"
	max_label.add_theme_font_size_override("font_size", 18)
	max_label.add_theme_color_override("font_color", Color("90a4ae"))
	max_label.custom_minimum_size = Vector2(50, 0)
	max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var value_label: Label = row.get_node_or_null("Value") as Label
	if value_label == null:
		value_label = Label.new()
		value_label.name = "Value"
		value_label.custom_minimum_size = Vector2(70, 0)
		value_label.add_theme_font_size_override("font_size", 26)
		value_label.add_theme_color_override("font_color", CHARCOAL)
		row.add_child(value_label)
	# posiciona 100% antes do valor atual para ordem: Caption | 0% | Slider | 100% | 42%
	var v_idx: int = row.get_children().find(value_label)
	if v_idx != -1:
		row.add_child(max_label)
		row.move_child(max_label, v_idx)
	else:
		row.add_child(max_label)
	var slider: HSlider = row.get_node("Slider")
	slider.name = "Setting_%s" % setting_key
	slider.tooltip_text = "0% — 100%"
	slider.value = float(GameState.settings.get(setting_key, default_value))
	value_label.text = "%d%%" % int(slider.value * 100.0)
	slider.value_changed.connect( func(v: float) -> void:
			GameState.settings[setting_key] = v
			SaveManager.request_save()
			AudioManager.apply_volumes()
			value_label.text = "%d%%" % int(v * 100.0)
	)
	# Preview sonoro ao soltar o slider
	slider.drag_ended.connect( func(_v_changed: bool) -> void:
			if setting_key == "sfx":
				AudioManager.play(&"tap")
			elif setting_key == "music":
				AudioManager.play(&"coin")
	)


func _add_toggle(caption: String, setting_key: String, default_value: bool) -> void:
	var enabled: bool = bool(GameState.settings.get(setting_key, default_value))
	var toggle_text: String = Loc.t("ON") if enabled else Loc.t("OFF")
	var toggle_color: Color = GREEN if enabled else Color("b0bec5")
	_info_row(caption, "", toggle_text, toggle_color, true, func() -> void:
		var now: bool = not bool(GameState.settings.get(setting_key, default_value))
		GameState.settings[setting_key] = now
		if setting_key == "eco_mode":
			GameState.settings["reduced_particles"] = now
		if setting_key == "notifications":
			# Retenção: liga o gatilho externo que já existia mas nunca era armado.
			NotificationManager.permission_granted = now
			if now:
				NotificationManager.schedule_return_reminders(GameState.last_seen_unix)
		SaveManager.request_save()
		_rebuild(&"settings")
	)


func _info_row( name_text: String, desc_text: String, action_text: String, action_color: Color, enabled: bool, on_action: Callable,
) -> void:
	var row: PanelContainer = INFO_ROW.instantiate()
	screen.content_box.add_child(row)
	row.add_theme_stylebox_override( "panel", StyleFactory.box(Color("ffffff", 0.9), 24, 16, PINK, 3)
	)
	var box: HBoxContainer = row.get_node("Box")
	var icon: TextureRect = row.get_node("Box/Icon") as TextureRect
	icon.texture = null
	icon.hide()
	var info_vbox: VBoxContainer = row.get_node("Box/Info")
	var name_label: Label = row.get_node("Box/Info/Name")
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", CHARCOAL)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desc_label: Label = row.get_node("Box/Info/Desc")
	desc_label.add_theme_font_size_override("font_size", 24)
	desc_label.add_theme_color_override("font_color", Color("37474f"))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# ── Dinâmico: progressive disclosure ──
	# Descrições longas (>75 chars ou multi-linha) começam colapsadas com preview + botão ⓘ
	var is_long: bool = desc_text.length() > 75 or desc_text.contains("\n")
	var preview_text: String = desc_text
	if is_long:
		if desc_text.contains("\n"):
			preview_text = desc_text.split("\n")[0] + " …"
		elif desc_text.length() > 75:
			preview_text = desc_text.substr(0, 72).strip_edges() + "…"
		# quando há preview, mostra só preview colapsado
		desc_label.text = preview_text
		desc_label.tooltip_text = desc_text  # acessível via long-press
	else:
		desc_label.text = desc_text
	var button: Button = row.get_node("Box/Action")
	button.set_meta("game_action_connected", enabled and on_action.is_valid())
	button.set_meta("row_title", name_text)
	_style_button(button, action_color)
	button.text = action_text
	button.disabled = not enabled
	# botão de detalhe dinâmico só quando há conteúdo extra
	var expand_btn: Button = null
	if is_long:
		expand_btn = Button.new()
		expand_btn.text = "ⓘ"
		expand_btn.custom_minimum_size = Vector2(56, 56)
		expand_btn.tooltip_text = Loc.t("VIEW_DETAILS")
		# estilo compacto, circular
		expand_btn.add_theme_font_size_override("font_size", 22)
		expand_btn.add_theme_color_override("font_color", Color("546e7a"))
		expand_btn.add_theme_color_override("font_hover_color", CHARCOAL)
		expand_btn.add_theme_stylebox_override("normal", StyleFactory.box(Color("eceff1"), 28, 6))
		expand_btn.add_theme_stylebox_override("hover", StyleFactory.box(Color("cfd8dc"), 28, 6, Color.WHITE, 1))
		expand_btn.add_theme_stylebox_override("pressed", StyleFactory.box(Color("b0bec5"), 28, 6))
		expand_btn.add_theme_stylebox_override("focus", StyleFactory.box(Color("eceff1"), 28, 6, PINK, 2))
		InteractionFX.bind_button(expand_btn)
		# insere antes do botão de ação para hierarquia visual: [ⓘ][Ação]
		var idx: int = box.get_children().find(button)
		box.add_child(expand_btn)
		box.move_child(expand_btn, maxi(0, idx))
		var expanded: bool = false
		expand_btn.pressed.connect(func() -> void:
			expanded = not expanded
			if expanded:
				desc_label.text = desc_text
				expand_btn.text = "▴"
				expand_btn.tooltip_text = Loc.t("COLLAPSE")
				# feedback suave
				desc_label.modulate.a = 0.0
				var t: Tween = desc_label.create_tween()
				t.tween_property(desc_label, "modulate:a", 1.0, 0.14)
				AudioManager.play(&"tap")
			else:
				desc_label.text = preview_text
				expand_btn.text = "ⓘ"
				expand_btn.tooltip_text = Loc.t("VIEW_DETAILS")
				AudioManager.play(&"tap")
		)
		# toque longo na linha toda também expande
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventScreenTouch and event.pressed and event is InputEventScreenTouch:
				# duplo toque rápido não, só feedback
				pass
		)
	if enabled and on_action.is_valid():
		button.pressed.connect( func() -> void:
				on_action.call()
				if refresh_callback.is_valid():
					refresh_callback.call()
				_rebuild(_current_section())
		)


func _info_row_with_icon(
	name_text: String,
	desc_text: String,
	action_text: String,
	action_color: Color,
	enabled: bool,
	icon_path: String,
	on_action: Callable,
) -> void:
	_info_row(name_text, desc_text, action_text, action_color, enabled, on_action)
	var row: PanelContainer = screen.content_box.get_child(screen.content_box.get_child_count() - 1) as PanelContainer
	var icon: TextureRect = row.get_node("Box/Icon") as TextureRect
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
		icon.show()


func _current_section() -> StringName:
	return _section


func _note( text: String, size: int = 24, color: Color = Color("90a4ae"), wrap_text: bool = false
) -> void:
	var note: Label = _label_node(text, size, color)
	if wrap_text:
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.content_box.add_child(note)


func _label_node(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
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
func _style_button(button: Button, color: Color) -> void:
	# Unificado com Main._button: radius 30 consistente, altura mínima 64, contraste WCAG (escolhe maior ratio)
	var fs: float = float(GameState.settings.get("font_scale", 1.0))
	button.add_theme_font_size_override("font_size", int(26 * fs))
	var text_color: Color = _ideal_text_color(color)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color("eceff1"))
	button.add_theme_color_override("font_hover_color", text_color)
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, 64.0), maxf(button.custom_minimum_size.y, 64.0))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_stylebox_override("normal", StyleFactory.box(color, 30, 10))
	button.add_theme_stylebox_override("hover", StyleFactory.box(color.lightened(0.10), 30, 10, Color.WHITE, 2))
	button.add_theme_stylebox_override("pressed", StyleFactory.box(color.darkened(0.15), 30, 10))
	button.add_theme_stylebox_override("disabled", StyleFactory.box(Color("90a4ae"), 30, 10))
	button.add_theme_stylebox_override("focus", StyleFactory.box(color, 30, 10, Color.WHITE, 3))
	InteractionFX.bind_button(button)


func _pop_panel(panel: Control) -> void:
	panel.show()
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
