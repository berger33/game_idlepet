class_name MetaPanel
extends Node
## Controlador das telas meta (Fase 2/.tscn): instancia meta_screen.tscn e
## preenche o conteúdo com os templates info_row/slider_row/pet_card.
## Missões com claim individual, coleção em grid, equipe contratável, loja
## (brasas + IAP honesto + rewarded ads), mapa e ajustes com sliders.
## Tudo emerge do painel (pivot na origem + cascata scale-in).

const GREEN: Color = Color("7ed957")
const BLUE: Color = Color("4fc3f7")
const PINK: Color = Color("ff8fb1")
const CHARCOAL: Color = Color("263238")

const META_SCREEN: PackedScene = preload("res://scenes/ui/meta_screen.tscn")
const INFO_ROW: PackedScene = preload("res://scenes/ui/info_row.tscn")
const SLIDER_ROW: PackedScene = preload("res://scenes/ui/slider_row.tscn")
const PET_CARD: PackedScene = preload("res://scenes/ui/pet_card.tscn")

var screen: MetaScreen
## Main injeta aqui o refresh de economia (evita acoplamento direto).
var refresh_callback: Callable
var _section: StringName = &""


func is_open() -> bool:
	return is_instance_valid(screen) and screen.panel.visible


func build(root: Control) -> void:
	screen = META_SCREEN.instantiate()
	root.add_child(screen)
	screen.close_button.pressed.connect(close)
	_style_button(screen.close_button, PINK)


func close() -> void:
	screen.panel.hide()
	screen.backdrop.hide()
	AudioManager.play(&"tap")


## origin = controle que abriu a tela: o painel cresce a partir dele.
func open(section: StringName, origin: Control = null) -> void:
	screen.backdrop.show()
	screen.backdrop.pivot_offset = screen.backdrop.size * 0.5
	screen.backdrop.scale = Vector2(1.035, 1.035)
	screen.backdrop.create_tween().tween_property(
		screen.backdrop, "scale", Vector2.ONE, 3.5
	).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(origin):
		screen.panel.pivot_offset = (
			origin.global_position + origin.size * 0.5 - screen.panel.position
		)
	else:
		screen.panel.pivot_offset = screen.panel.size * 0.5
	_pop_panel(screen.panel)
	AudioManager.play(&"panel_open")
	_rebuild(section)


func _rebuild(section: StringName) -> void:
	_section = section
	for child: Node in screen.content_box.get_children():
		child.queue_free()
	match section:
		&"missions":
			screen.title_label.text = Loc.t("MISSIONS_TITLE")
			_build_missions()
		&"collection":
			screen.title_label.text = Loc.t("COLLECTION_TITLE")
			_build_collection()
		&"staff":
			screen.title_label.text = Loc.t("STAFF_TITLE")
			_build_staff()
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


func _build_missions() -> void:
	var claimed_today: bool = GameState.is_daily_claimed_today()
	var next_day: int = GameState.daily_streak % 7 + 1
	_info_row(
		Loc.t("DAILY_LOGIN") % (GameState.daily_streak if claimed_today else next_day),
		"25×dia",
		Loc.t("CLAIMED") if claimed_today else Loc.t("CLAIM"),
		GREEN,
		not claimed_today,
		func() -> void:
			GameState.claim_daily_reward()
			AudioManager.play(&"coin")
	)
	var services: int = int(GameState.mission_progress.get("services", 0))
	var perfects: int = int(GameState.mission_progress.get("perfect", 0))
	var upgrades: int = int(GameState.mission_progress.get("upgrades", 0))
	var missions: Array[Dictionary] = [
		{
			"id": &"daily_bath_5",
			"label": Loc.t("MISSION_SERVICES") % mini(services, 5),
			"done": services >= 5,
		},
		{
			"id": &"daily_perfect_3",
			"label": Loc.t("MISSION_PERFECT") % mini(perfects, 3),
			"done": perfects >= 3,
		},
		{
			"id": &"daily_upgrade_1",
			"label": Loc.t("MISSION_UPGRADE") % mini(upgrades, 1),
			"done": upgrades >= 1,
		},
	]
	for mission: Dictionary in missions:
		var claimed: bool = GameState.claimed_missions.has(String(mission["id"]))
		_info_row(
			String(mission["label"]) + " • 75",
			"moedas",
			Loc.t("CLAIMED") if claimed else Loc.t("CLAIM"),
			GREEN,
			bool(mission["done"]) and not claimed,
			func(mission_id: StringName = mission["id"]) -> void:
				GameState.claim_mission(mission_id)
				AudioManager.play(&"coin")
		)
	_note(
		Loc.t("STREAK_LINE") % [GameState.daily_streak, GameState.streak_freezes],
		26,
		CHARCOAL
	)
	var pass_ready: bool = GameState.pass_day_claimed < GameState.pass_day_unlocked
	var pass_reward: Dictionary = ContentDB.pass_day(GameState.pass_day_claimed + 1)
	_info_row(
		Loc.t("PASS_TITLE") + " %d/28" % (GameState.pass_day_claimed + 1),
		Loc.t("PASS_DESC") if not pass_reward.is_empty() else Loc.t("PASS_DONE"),
		Loc.t("CLAIM") if pass_ready else "%d/28" % GameState.pass_day_unlocked,
		GREEN if pass_ready else Color("b0bec5"),
		pass_ready,
		func() -> void:
			if GameState.claim_pass_day():
				AudioManager.play(&"coin")
	)
	_note("Missões nunca exigem anúncio ou compra.")
	_note(Loc.t("WEEKLY_TITLE"), 28, CHARCOAL, true)
	for weekly: Dictionary in ContentDB.weekly_missions:
		var weekly_id: String = String(weekly["id"])
		var target: int = int(weekly["target"])
		var value: int = mini(GameState.weekly_value(String(weekly["metric"])), target)
		var weekly_done: bool = GameState.claimed_weeklies.has(weekly_id)
		var weekly_ready: bool = value >= target and not weekly_done
		var reward: Dictionary = weekly.get("reward", {})
		var reward_text: String = (
			"%d moedas" % int(reward.get("coins", 0))
			if reward.has("coins")
			else "%d %s" % [int(reward.get("embers", 0)), Loc.t("EMBERS")]
		)
		var action_label: String = (
			Loc.t("CLAIMED") if weekly_done else (
				Loc.t("CLAIM") if weekly_ready else "%d/%d" % [value, target]
			)
		)
		_info_row(
			Loc.t(String(weekly["label_key"])) % value,
			"%s • %s" % [Loc.t("WEEKLY_NOTE_SHORT"), reward_text],
			action_label,
			GREEN if weekly_ready else (Color("b0bec5") if weekly_done else Color("4fc3f7")),
			weekly_ready,
			func(claimed_id: String = weekly_id) -> void:
				if GameState.claim_weekly(claimed_id):
					AudioManager.play(&"coin")
					_rebuild(_current_section())
	)
	_note(Loc.t("WEEKLY_NOTE"))
	_note(Loc.t("MISSION_NOTE"))


func _build_collection() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	screen.content_box.add_child(grid)
	for pet: Dictionary in ContentDB.pets:
		var pet_id: String = String(pet.get("id", ""))
		var unlocked: bool = GameState.unlocked_pets.has(pet_id)
		var card: PanelContainer = PET_CARD.instantiate()
		var card_alpha: float = 0.9 if unlocked else 0.45
		var card_border: Color = PINK if unlocked else Color("90a4ae")
		card.add_theme_stylebox_override(
			"panel", StyleFactory.box(Color("ffffff", card_alpha), 22, 10, card_border, 3)
		)
		grid.add_child(card)
		var portrait: TextureRect = card.get_node("VBox/Portrait")
		if unlocked:
			var path: String = "res://art/pets/%s.png" % pet_id
			if ResourceLoader.exists(path):
				portrait.texture = load(path)
		else:
			portrait.modulate.a = 0.0
		var name_label: Label = card.get_node("VBox/Name")
		name_label.text = String(pet.get("name", pet_id)) if unlocked else "???"
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", CHARCOAL)
		var sub: Label = card.get_node("VBox/Sub")
		sub.text = (
			(
				("★ " if GameState.favorite_pet == pet_id else "")
				+ "♥ %d/50" % int(GameState.pet_affection.get(pet_id, 0))
			)
			if unlocked
			else Loc.t("LOCKED") % int(pet.get("unlock_level", 1))
		)
		sub.add_theme_font_size_override("font_size", 22)
		sub.add_theme_color_override("font_color", PINK if unlocked else Color("78909c"))
		if unlocked:
			card.tooltip_text = Loc.t("FAVORITE_HINT")
			card.gui_input.connect(
				func(event: InputEvent, pid: String = pet_id) -> void:
					if event is InputEventScreenTouch and event.pressed:
						if GameState.set_favorite_pet(pid):
							AudioManager.play(&"tap")
							EventBus.toast_requested.emit(Loc.t("FAVORITE_SET"), GREEN)
							_rebuild(&"collection")
			)
	_note(
		"PETS %d/%d • CONQUISTAS %d/%d • COSMÉTICOS %d"
		% [
			GameState.unlocked_pets.size(),
			ContentDB.pets.size(),
			GameState.achievement_ids.size(),
			ContentDB.achievements.size(),
			GameState.unlocked_cosmetics.size(),
		]
	)


func _build_staff() -> void:
	for member: Dictionary in ContentDB.staff_members:
		var staff_id: String = String(member.get("id", ""))
		var hired: bool = GameState.hired_staff.has(staff_id)
		var passive: Dictionary = member.get("passive", {})
		var passive_key: String = "PASSIVE_" + String(passive.get("type", "speed")).to_upper()
		var cost: int = GameState.hire_cost(staff_id)
		_info_row(
			String(member.get("name", staff_id)),
			"%s • %s • %s"
				% [
					String(member.get("specialty", "")),
					Loc.t(GameState.staff_vocation(staff_id)),
					Loc.t(passive_key)
				],
			Loc.t("HIRED") if (hired or staff_id == "player") else "%s • %d" % [Loc.t("HIRE"), cost],
			Color("b0bec5") if (hired or staff_id == "player") else BLUE,
			not hired and staff_id != "player" and GameState.coins >= float(cost),
			func(sid: String = staff_id) -> void:
				if GameState.hire_staff(sid):
					AudioManager.play(&"upgrade")
					EventBus.toast_requested.emit(
						"%s: %s" % [ContentDB.staff_name(sid), Loc.t("HIRED")], GREEN
					)
		)


func _build_shop() -> void:
	for look: Dictionary in ContentDB.cosmetics:
		var look_id: String = String(look.get("id", ""))
		var owned: bool = GameState.unlocked_cosmetics.has(look_id)
		var price: Dictionary = look.get("price", {})
		var price_text: String
		if price.has("coins"):
			price_text = "%d moedas" % int(price["coins"])
		elif price.has("embers"):
			price_text = "%d %s" % [int(price["embers"]), Loc.t("EMBERS")]
		else:
			price_text = String(look.get("source", "evento"))
		var is_active: bool = GameState.active_cosmetic(String(look.get("slot", ""))) == look_id
		var action_text: String
		var action_color: Color = PINK
		var enabled: bool = (not owned and not price.is_empty()) or owned
		if owned:
			action_text = Loc.t("EQUIPPED") if is_active else Loc.t("EQUIP")
			action_color = GREEN if is_active else PINK
		elif price.is_empty():
			action_text = "EVENTO"
			action_color = Color("b0bec5")
		else:
			action_text = Loc.t("BUY")
		_info_row(
			String(look.get("name", look_id)),
			price_text,
			action_text,
			action_color,
			enabled,
			func(lid: String = look_id) -> void:
				if GameState.unlocked_cosmetics.has(lid):
					if GameState.equip_cosmetic(lid):
						AudioManager.play(&"equip")
						EventBus.toast_requested.emit(
							"%s ✓" % ContentDB.cosmetic(lid).get("name", lid), GREEN
						)
				elif GameState.buy_cosmetic(lid):
					GameState.equip_cosmetic(lid)
					AudioManager.play(&"coin")
					EventBus.toast_requested.emit(
						"%s ✓" % ContentDB.cosmetic(lid).get("name", lid), GREEN
					)
				else:
					AudioManager.play(&"error_soft")
		)
	# Rewarded ads honesto: fachada avisa indisponível offline; o adapter real
	# chamará o callback de recompensa apenas em conclusão verificada.
	_info_row(
		"+1 %s" % Loc.t("EMBERS"),
		"anúncio recompensado",
		"▶",
		BLUE,
		true,
		func() -> void:
			AdsManager.request_rewarded(&"ember_shop", _grant_ember)
	)
	for sku: String in IAPManager.PRODUCTS:
		_info_row(sku, "R$", "OFFLINE", Color("b0bec5"), false, Callable())
	_note(Loc.t("COSMETIC_NO_FX"))
	_note(Loc.t("IAP_NOTE"))


func _grant_ember() -> void:
	GameState.embers += 1
	EventBus.currency_changed.emit(&"coins", GameState.coins)
	SaveManager.request_save()
	AudioManager.play(&"coin")
	_rebuild(&"shop")


func _build_map() -> void:
	var rep: int = GameState.reviews_sum
	var tier: int = Economy.neighborhood_tier(rep)
	var next_at: int = (
		Economy.NEIGHBORHOOD_TIERS[tier + 1]
		if tier + 1 < Economy.NEIGHBORHOOD_TIERS.size()
		else -1
	)
	var rep_line: String = "%s: %s • %d⭐ %s" % [
		Loc.t("NEIGHBORHOOD"),
		Loc.t("NEIGHBORHOOD_%d" % tier),
		rep,
		"(%d)" % next_at if next_at > 0 else "(MAX)",
	]
	var text: String = (
		"EVENTO: %s\nCARREIRA: nível %d/120 • %.1fh ativas\n%s\n\n"
		% [
			LiveOps.current_event_name(),
			GameState.player_level,
			GameState.active_play_seconds / 3600.0,
			rep_line,
		]
	)
	for entry: Dictionary in ContentDB.career.get("establishments", []):
		var unlock_level: int = int(entry.get("unlock_level", 1))
		var marker: String = "✓" if GameState.player_level >= unlock_level else "□"
		text += "%s %s — nível %d\n" % [marker, entry.get("name", "Petshop"), unlock_level]
	text += "\nA jornada foi balanceada para 50+ horas, sem bloquear ações ou compras."
	_note(text, 28, CHARCOAL, true)
	var tokens: int = GameState.prestige_tokens_available()
	_info_row(
		"%s Nv.%d" % [Loc.t("PRESTIGE_TITLE"), GameState.prestige_level],
		Loc.t("PRESTIGE_DESC") % [tokens, Economy.prestige_coin_multiplier(GameState.prestige_level)],
		Loc.t("PRESTIGE_GO") if GameState.can_prestige() else Loc.t("PRESTIGE_LOCKED"),
		Color("ce93d8") if GameState.can_prestige() else Color("b0bec5"),
		GameState.can_prestige(),
		func() -> void:
			if GameState.perform_prestige():
				AudioManager.play(&"prestige")
				EventBus.toast_requested.emit(
					Loc.t("PRESTIGE_DONE") % GameState.prestige_level, Color("ce93d8")
				)
				_rebuild(&"map")
	)
	_note(Loc.t("PRESTIGE_KEEP"))
	_note(Loc.t("PRESTIGE_LOST"))


func _build_settings() -> void:
	_add_slider(Loc.t("SFX_VOLUME"), "sfx", 0.9)
	_add_slider(Loc.t("MUSIC_VOLUME"), "music", 0.7)
	_add_toggle(Loc.t("HAPTICS"), "haptics", true)
	_add_toggle(Loc.t("REDUCED_FX") + " / " + Loc.t("ECO_MODE"), "eco_mode", false)
	var lang_row: HBoxContainer = HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	screen.content_box.add_child(lang_row)
	var caption: Label = _label_node(Loc.t("LANGUAGE") + ":", 28, CHARCOAL)
	lang_row.add_child(caption)
	for code: String in Loc.LANGS:
		var lang_button: Button = Button.new()
		_style_button(lang_button, BLUE if code == Loc.lang else Color("b0bec5"))
		lang_button.text = code
		lang_button.custom_minimum_size = Vector2(150, 60)
		lang_button.pressed.connect(
			func(c: String = code) -> void:
				Loc.set_language(c)
				_rebuild(&"settings")
		)
		lang_row.add_child(lang_button)


func _add_slider(caption: String, setting_key: String, default_value: float) -> void:
	var row: HBoxContainer = SLIDER_ROW.instantiate()
	screen.content_box.add_child(row)
	var caption_label: Label = row.get_node("Caption")
	caption_label.text = caption + ":"
	caption_label.add_theme_font_size_override("font_size", 28)
	caption_label.add_theme_color_override("font_color", CHARCOAL)
	var slider: HSlider = row.get_node("Slider")
	slider.value = float(GameState.settings.get(setting_key, default_value))
	slider.value_changed.connect(
		func(v: float) -> void:
			GameState.settings[setting_key] = v
			SaveManager.request_save()
			AudioManager.apply_volumes()
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
		SaveManager.request_save()
	)


func _info_row(
	name_text: String,
	desc_text: String,
	action_text: String,
	action_color: Color,
	enabled: bool,
	on_action: Callable,
) -> void:
	var row: PanelContainer = INFO_ROW.instantiate()
	screen.content_box.add_child(row)
	row.add_theme_stylebox_override(
		"panel", StyleFactory.box(Color("ffffff", 0.9), 24, 16, PINK, 3)
	)
	var name_label: Label = row.get_node("Box/Info/Name")
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", CHARCOAL)
	var desc_label: Label = row.get_node("Box/Info/Desc")
	desc_label.text = desc_text
	desc_label.add_theme_font_size_override("font_size", 24)
	desc_label.add_theme_color_override("font_color", Color("546e7a"))
	var button: Button = row.get_node("Box/Action")
	_style_button(button, action_color)
	button.text = action_text
	button.disabled = not enabled
	if enabled and on_action.is_valid():
		button.pressed.connect(
			func() -> void:
				on_action.call()
				if refresh_callback.is_valid():
					refresh_callback.call()
				_rebuild(_current_section())
		)


func _current_section() -> StringName:
	return _section


func _note(
	text: String, size: int = 24, color: Color = Color("90a4ae"), wrap: bool = false
) -> void:
	var note: Label = _label_node(text, size, color)
	if wrap:
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.content_box.add_child(note)


func _label_node(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_button(button: Button, color: Color) -> void:
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", StyleFactory.box(color, 30, 10))
	button.add_theme_stylebox_override("hover", StyleFactory.box(color.lightened(0.08), 30, 10))
	button.add_theme_stylebox_override("pressed", StyleFactory.box(color.darkened(0.12), 26, 14))
	button.add_theme_stylebox_override("disabled", StyleFactory.box(Color("b0bec5"), 30, 10))
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
