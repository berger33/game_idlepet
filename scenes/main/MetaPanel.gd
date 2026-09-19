class_name MetaPanel
extends Node
## Telas meta reais (Fase 2): missões com claim individual, coleção em grid,
## equipe contratável, loja (brasas + IAP honesto), mapa e ajustes com sliders.
## Tudo emerge do painel (stagger scale-in) — nada "popa do vazio".

const MENU_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_perfume.png")
const PINK: Color = Color("ff8fb1")
const GREEN: Color = Color("7ed957")
const BLUE: Color = Color("4fc3f7")
const AMBER: Color = Color("ffd54f")
const CHARCOAL: Color = Color("263238")

var meta_backdrop: TextureRect
var meta_panel: PanelContainer
var meta_title: Label
var scroll: ScrollContainer
var content_box: VBoxContainer
var close_button: Button
## Main injeta aqui o refresh de economia (evita acoplamento direto).
var refresh_callback: Callable


func is_open() -> bool:
	return is_instance_valid(meta_panel) and meta_panel.visible


func build(root: Control) -> void:
	meta_backdrop = TextureRect.new()
	meta_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	meta_backdrop.texture = MENU_BACKGROUND
	meta_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meta_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	meta_backdrop.modulate = Color(0.42, 0.35, 0.48, 0.92)
	meta_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(meta_backdrop)
	meta_panel = PanelContainer.new()
	meta_panel.position = Vector2(80, 290)
	meta_panel.size = Vector2(920, 950)
	meta_panel.add_theme_stylebox_override("panel", _style(Color("fffaf3", 0.98), 50, 42, PINK, 7))
	root.add_child(meta_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	meta_panel.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	meta_title = Label.new()
	meta_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_title.add_theme_font_size_override("font_size", 46)
	meta_title.add_theme_color_override("font_color", CHARCOAL)
	header.add_child(meta_title)
	close_button = _button("↙", PINK, 84, 70)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 14)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_box)
	meta_panel.hide()
	meta_backdrop.hide()


func close() -> void:
	meta_panel.hide()
	meta_backdrop.hide()
	AudioManager.play(&"tap")


## origin = controle que abriu a tela: o painel cresce a partir dele
## (princípio de emergência: nada aparece do vazio).
func open(section: StringName, origin: Control = null) -> void:
	meta_backdrop.show()
	meta_backdrop.pivot_offset = meta_backdrop.size * 0.5
	meta_backdrop.scale = Vector2(1.035, 1.035)
	meta_backdrop.create_tween().tween_property(meta_backdrop, "scale", Vector2.ONE, 3.5).set_trans(
		Tween.TRANS_SINE
	)
	if is_instance_valid(origin):
		meta_panel.pivot_offset = origin.global_position + origin.size * 0.5 - meta_panel.position
	else:
		meta_panel.pivot_offset = meta_panel.size * 0.5
	_pop_panel(meta_panel)
	AudioManager.play(&"panel_open")
	_rebuild(section)


func _rebuild(section: StringName) -> void:
	for child: Node in content_box.get_children():
		child.queue_free()
	match section:
		&"missions":
			meta_title.text = Loc.t("MISSIONS_TITLE")
			_build_missions()
		&"collection":
			meta_title.text = Loc.t("COLLECTION_TITLE")
			_build_collection()
		&"staff":
			meta_title.text = Loc.t("STAFF_TITLE")
			_build_staff()
		&"shop":
			meta_title.text = Loc.t("SHOP_TITLE")
			_build_shop()
		&"map":
			meta_title.text = Loc.t("MAP_TITLE")
			_build_map()
		_:
			meta_title.text = Loc.t("SETTINGS_TITLE")
			_build_settings()
	_emerge()


## Linhas/cards surgem escalando do painel, em cascata.
func _emerge() -> void:
	for i: int in content_box.get_child_count():
		var child: Control = content_box.get_child(i)
		child.modulate.a = 0.0
		child.scale = Vector2(0.94, 0.94)
		child.pivot_offset = child.size * 0.5
		var tween: Tween = child.create_tween()
		tween.set_parallel(true)
		tween.tween_property(child, "modulate:a", 1.0, 0.16).set_delay(i * 0.03)
		tween.tween_property(child, "scale", Vector2.ONE, 0.16).set_delay(i * 0.03)


func _build_missions() -> void:
	var claimed_today: bool = GameState.is_daily_claimed_today()
	var next_day: int = GameState.daily_streak % 7 + 1
	var daily_ready: bool = not claimed_today
	_add_claim_row(
		Loc.t("DAILY_LOGIN") % (GameState.daily_streak if claimed_today else next_day),
		"25×dia",
		daily_ready,
		claimed_today,
		func() -> void:
			GameState.claim_daily_reward()
	)
	var missions: Array[Dictionary] = [
		{
			"id": &"daily_bath_5",
			"label": Loc.t("MISSION_SERVICES") % mini(int(GameState.mission_progress.get("services", 0)), 5),
			"done": int(GameState.mission_progress.get("services", 0)) >= 5,
		},
		{
			"id": &"daily_perfect_3",
			"label": Loc.t("MISSION_PERFECT") % mini(int(GameState.mission_progress.get("perfect", 0)), 3),
			"done": int(GameState.mission_progress.get("perfect", 0)) >= 3,
		},
		{
			"id": &"daily_upgrade_1",
			"label": Loc.t("MISSION_UPGRADE") % mini(int(GameState.mission_progress.get("upgrades", 0)), 1),
			"done": int(GameState.mission_progress.get("upgrades", 0)) >= 1,
		},
	]
	for mission: Dictionary in missions:
		var claimed: bool = GameState.claimed_missions.has(String(mission["id"]))
		_add_claim_row(
			String(mission["label"]) + " • 75",
			"75",
			bool(mission["done"]) and not claimed,
			claimed,
			func(mission_id: StringName = mission["id"]) -> void:
				GameState.claim_mission(mission_id)
		)
	var note: Label = _label("Missões nunca exigem anúncio ou compra.", 26, Color("546e7a"))
	content_box.add_child(note)


func _add_claim_row(
	title: String, reward_text: String, ready: bool, claimed: bool, claimer: Callable
) -> void:
	var row: PanelContainer = _card()
	var box: HBoxContainer = _row_box(row)
	var name_label: Label = _label(title, 28, CHARCOAL)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(name_label)
	var button: Button
	if claimed:
		button = _button(Loc.t("CLAIMED"), Color("b0bec5"), 190, 64)
		button.disabled = true
	else:
		button = _button("%s +%s" % [Loc.t("CLAIM"), reward_text], GREEN, 190, 64)
		button.disabled = not ready
		button.pressed.connect(
			func() -> void:
				claimer.call()
				AudioManager.play(&"coin")
				EventBus.toast_requested.emit("+%s" % reward_text, GREEN)
				if refresh_callback.is_valid():
					refresh_callback.call()
				_rebuild(&"missions")
		)
	box.add_child(button)


func _build_collection() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content_box.add_child(grid)
	for pet: Dictionary in ContentDB.pets:
		var pet_id: String = String(pet.get("id", ""))
		var unlocked: bool = GameState.unlocked_pets.has(pet_id)
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(196, 240)
		var card_alpha: float = 0.9 if unlocked else 0.45
		var card_border: Color = PINK if unlocked else Color("90a4ae")
		card.add_theme_stylebox_override(
			"panel", _style(Color("ffffff", card_alpha), 22, 10, card_border, 3)
		)
		grid.add_child(card)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)
		var portrait: TextureRect = TextureRect.new()
		portrait.custom_minimum_size = Vector2(150, 150)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if unlocked:
			var path: String = "res://art/pets/%s.png" % pet_id
			if ResourceLoader.exists(path):
				portrait.texture = load(path)
		else:
			portrait.modulate.a = 0.0
		box.add_child(portrait)
		var name_label: Label = _label(
			String(pet.get("name", pet_id)) if unlocked else "???", 24, CHARCOAL
		)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var sub: Label = _label(
			"♥ %d/50" % int(GameState.pet_affection.get(pet_id, 0))
			if unlocked
			else Loc.t("LOCKED") % int(pet.get("unlock_level", 1)),
			22,
			PINK if unlocked else Color("78909c"),
		)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	var summary: Label = _label(
		"PETS %d/%d • CONQUISTAS %d/%d • COSMÉTICOS %d"
		% [
			GameState.unlocked_pets.size(),
			ContentDB.pets.size(),
			GameState.achievement_ids.size(),
			ContentDB.achievements.size(),
			GameState.unlocked_cosmetics.size(),
		],
		26,
		Color("546e7a"),
	)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_box.add_child(summary)


func _build_staff() -> void:
	for member: Dictionary in ContentDB.staff:
		var staff_id: String = String(member.get("id", ""))
		var hired: bool = GameState.hired_staff.has(staff_id)
		var row: PanelContainer = _card()
		var box: HBoxContainer = _row_box(row)
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(info)
		var passive: Dictionary = member.get("passive", {})
		var passive_key: String = "PASSIVE_" + String(passive.get("type", "speed")).to_upper()
		info.add_child(_label(String(member.get("name", staff_id)), 30, CHARCOAL))
		info.add_child(
			_label(
				"%s • %s" % [String(member.get("specialty", "")), Loc.t(passive_key)],
				24,
				Color("546e7a"),
			)
		)
		var button: Button
		if staff_id == "player" or hired:
			button = _button(Loc.t("HIRED"), Color("b0bec5"), 220, 64)
			button.disabled = true
		else:
			var cost: int = GameState.hire_cost(staff_id)
			button = _button("%s • %d" % [Loc.t("HIRE"), cost], BLUE, 220, 64)
			button.disabled = GameState.coins < float(cost)
			button.pressed.connect(
				func(sid: String = staff_id) -> void:
					if GameState.hire_staff(sid):
						AudioManager.play(&"upgrade")
						EventBus.toast_requested.emit(
							"%s: %s" % [ContentDB.staff_name(sid), Loc.t("HIRED")], GREEN
						)
					_rebuild(&"staff")
					if refresh_callback.is_valid():
						refresh_callback.call()
			)
		box.add_child(button)


func _build_shop() -> void:
	for look: Dictionary in ContentDB.cosmetics:
		var look_id: String = String(look.get("id", ""))
		var owned: bool = GameState.unlocked_cosmetics.has(look_id)
		var price: Dictionary = look.get("price", {})
		var row: PanelContainer = _card()
		var box: HBoxContainer = _row_box(row)
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(info)
		info.add_child(_label(String(look.get("name", look_id)), 28, CHARCOAL))
		var price_text: String
		if price.has("coins"):
			price_text = "%d moedas" % int(price["coins"])
		elif price.has("embers"):
			price_text = "%d %s" % [int(price["embers"]), Loc.t("EMBERS")]
		else:
			price_text = String(look.get("source", "evento"))
		info.add_child(_label(price_text, 24, Color("546e7a")))
		var button: Button
		if owned:
			button = _button(Loc.t("OWNED"), Color("b0bec5"), 200, 64)
			button.disabled = true
		elif price.is_empty():
			button = _button(Loc.t("LOCKED") % 0, Color("b0bec5"), 200, 64)
			button.disabled = true
		else:
			button = _button(Loc.t("BUY"), PINK, 200, 64)
			button.pressed.connect(
				func(lid: String = look_id) -> void:
					if GameState.buy_cosmetic(lid):
						AudioManager.play(&"coin")
						EventBus.toast_requested.emit("%s ✓" % ContentDB.cosmetic(lid).get("name", lid), GREEN)
					else:
						AudioManager.play(&"error_soft")
					_rebuild(&"shop")
					if refresh_callback.is_valid():
						refresh_callback.call()
			)
		box.add_child(button)
	content_box.add_child(_label(Loc.t("COSMETIC_NO_FX"), 24, Color("90a4ae")))
	content_box.add_child(_label(Loc.t("IAP_NOTE"), 24, Color("90a4ae")))


func _build_map() -> void:
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
	text += "\nA jornada foi balanceada para 50+ horas, sem bloquear ações ou compras."
	var map_label: Label = _label(text, 28, CHARCOAL)
	map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_box.add_child(map_label)


func _build_settings() -> void:
	_add_slider(Loc.t("SFX_VOLUME"), "sfx", 0.9)
	_add_slider(Loc.t("MUSIC_VOLUME"), "music", 0.7)
	_add_toggle(Loc.t("HAPTICS"), "haptics", true)
	_add_toggle(Loc.t("REDUCED_FX") + " / " + Loc.t("ECO_MODE"), "eco_mode", false)
	var lang_row: HBoxContainer = HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	content_box.add_child(lang_row)
	lang_row.add_child(_label(Loc.t("LANGUAGE") + ":", 28, CHARCOAL))
	for code: String in Loc.LANGS:
		var lang_button: Button = _button(code, BLUE if code == Loc.lang else Color("b0bec5"), 150, 60)
		lang_button.pressed.connect(
			func(c: String = code) -> void:
				Loc.set_language(c)
				_rebuild(&"settings")
		)
		lang_row.add_child(lang_button)


func _add_slider(caption: String, setting_key: String, default_value: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content_box.add_child(row)
	row.add_child(_label(caption + ":", 28, CHARCOAL))
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(GameState.settings.get(setting_key, default_value))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(420, 40)
	slider.value_changed.connect(
		func(v: float) -> void:
			GameState.settings[setting_key] = v
			SaveManager.request_save()
			AudioManager.apply_volumes()
	)
	row.add_child(slider)


func _add_toggle(caption: String, setting_key: String, default_value: bool) -> void:
	var row: PanelContainer = _card()
	var box: HBoxContainer = _row_box(row)
	var name_label: Label = _label(caption, 28, CHARCOAL)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(name_label)
	var enabled: bool = bool(GameState.settings.get(setting_key, default_value))
	var toggle_text: String = Loc.t("ON") if enabled else Loc.t("OFF")
	var toggle_color: Color = GREEN if enabled else Color("b0bec5")
	var button: Button = _button(toggle_text, toggle_color, 170, 60)
	button.pressed.connect(
		func() -> void:
			var now: bool = not bool(GameState.settings.get(setting_key, default_value))
			GameState.settings[setting_key] = now
			if setting_key == "eco_mode":
				GameState.settings["reduced_particles"] = now
			SaveManager.request_save()
			_rebuild(&"settings")
	)
	box.add_child(button)


func _card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color("ffffff", 0.9), 24, 16, PINK, 3))
	content_box.add_child(card)
	return card


func _row_box(parent: PanelContainer) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	return box


func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _pop_panel(panel: Control) -> void:
	panel.show()
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)


func _button(text: String, color: Color, width: float, height: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(color, 30, 10))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.08), 30, 10))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.12), 26, 14))
	button.add_theme_stylebox_override("disabled", _style(Color("b0bec5"), 30, 10))
	InteractionFX.bind_button(button)
	return button


func _style(
	color: Color,
	radius: int,
	content_margin: int,
	border_color: Color = Color(0, 0, 0, 0),
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
