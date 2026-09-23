class_name D1Retention
extends RefCounted
## Gatilhos D1 retenção: daily auto-popup, notif soft prompt, tomorrow card
## Static helper para manter Main <1100 linhas (padrão CelebrationFX).

static func should_show_daily(main) -> bool:
	return not GameState.is_daily_claimed_today() and GameState.services_completed >= 1 and bool(GameState.tutorial_complete)

static func show_daily_login(main) -> void:
	if not should_show_daily(main): return
	var today: String = Time.get_date_string_from_system()
	if GameState.settings.get("daily_popup_shown_today", "") == today: return
	var next_day: int = GameState.daily_streak % 7 + 1
	var coins: int = Rewards.scaled(float(Rewards.SECONDS["streak_day"]) * next_day, 25 * next_day)
	var title: String = Loc.t("DAILY_AUTO_TITLE") % next_day
	var body: String = Loc.t("DAILY_AUTO_BODY") % [next_day, coins, GameState.daily_streak, GameState.streak_freezes]
	if next_day == 7:
		body += "\n" + Loc.t("DAILY_AUTO_BONUS")
	GameState.settings["daily_popup_shown_today"] = today
	SaveManager.request_save()
	RevealCard.enqueue(main, {
		"title": title,
		"body": body,
		"color": Color("ffd54f"),
		"primary": Loc.t("CLAIM"),
		"sound": &"coin",
		"on_primary": func() -> void:
			var reward: int = GameState.claim_daily_reward()
			if reward > 0:
				AudioManager.play(&"coin")
				EventBus.toast_requested.emit(Loc.t("DAILY_CLAIMED_TOAST") % reward, Color("ffd54f"))
				Analytics.track(&"daily_auto_claimed", {"day": next_day, "reward": reward})
	})

static func should_show_notif_prompt() -> bool:
	if bool(GameState.settings.get("notifications", false)): return false
	if bool(GameState.settings.get("notif_prompted", false)): return false
	return GameState.services_completed >= 3 and bool(GameState.tutorial_complete)

static func show_notif_prompt(main) -> void:
	if not should_show_notif_prompt(): return
	GameState.settings["notif_prompted"] = true
	SaveManager.request_save()
	RevealCard.enqueue(main, {
		"title": Loc.t("NOTIF_PROMPT_TITLE"),
		"body": Loc.t("NOTIF_PROMPT_BODY"),
		"color": Color("4fc3f7"),
		"primary": Loc.t("NOTIF_PROMPT_YES"),
		"secondary": Loc.t("NOTIF_PROMPT_NO"),
		"sound": &"tap",
		"on_primary": func() -> void:
			GameState.settings["notifications"] = true
			NotificationManager.permission_granted = true
			NotificationManager.schedule_return_reminders(GameState.last_seen_unix)
			SaveManager.request_save()
			EventBus.toast_requested.emit(Loc.t("NOTIF_ENABLED_TOAST"), Color("4fc3f7"))
			Analytics.track(&"notif_optin", {"source": "d1_soft_prompt"})
	})

static func should_show_tomorrow() -> bool:
	if bool(GameState.settings.get("tomorrow_shown", false)): return false
	return GameState.services_completed >= 3 and bool(GameState.tutorial_complete)

static func show_tomorrow_card(main) -> void:
	if not should_show_tomorrow(): return
	GameState.settings["tomorrow_shown"] = true
	SaveManager.request_save()
	var tomorrow: int = (LiveOps.weekday() + 1) % 7
	var event_name: String = LiveOps.event_name_for(tomorrow)
	var next_pet: String = Goals.hud_line()
	RevealCard.enqueue(main, {
		"title": Loc.t("TOMORROW_CARD_TITLE"),
		"body": Loc.t("TOMORROW_CARD_BODY") % [event_name, next_pet, GameState.daily_streak],
		"color": Color("ce93d8"),
		"primary": Loc.t("REVEAL_OK"),
		"sound": &"level_up"
	})

static func missions_has_badge() -> bool:
	return DailySpin.can_spin() or not GameState.is_daily_claimed_today()

static func _find_missions_button(main) -> Button:
	# Nota10 P2-13: ref robusta via Main.missions_button, fallback busca frágil
	if "missions_button" in main and is_instance_valid(main.missions_button):
		return main.missions_button as Button
	# Fallback legado
	for child in main.get_children():
		if child is HBoxContainer:
			for col in child.get_children():
				if col is VBoxContainer:
					for b in col.get_children():
						if b is Button and b.name == "Nav_missions":
							return b
	return null

static func ensure_missions_badge(main) -> void:
	var btn: Button = _find_missions_button(main)
	if not is_instance_valid(btn): return
	if not missions_has_badge() or not bool(GameState.tutorial_complete):
		var mb: Label = btn.get_node_or_null("MissionBadge") as Label
		if is_instance_valid(mb): mb.visible = false
		return
	var badge: Label = btn.get_node_or_null("MissionBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "MissionBadge"
		badge.text = "!"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 26)
		badge.add_theme_color_override("font_color", Color.WHITE)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("ef5350")
		sb.corner_radius_top_left = 18
		sb.corner_radius_top_right = 18
		sb.corner_radius_bottom_left = 18
		sb.corner_radius_bottom_right = 18
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		badge.add_theme_stylebox_override("normal", sb)
		badge.custom_minimum_size = Vector2(36, 36)
		badge.position = Vector2(44, -10)
		btn.add_child(badge)
	badge.visible = true

static func update_missions_badge(main, pulse_time: float) -> void:
	ensure_missions_badge(main)
	var btn: Button = _find_missions_button(main)
	if not is_instance_valid(btn): return
	var mb: Label = btn.get_node_or_null("MissionBadge") as Label
	if is_instance_valid(mb) and mb.visible:
		var s: float = 1.0 + 0.15 * sin(pulse_time * 4.0)
		mb.scale = Vector2(s, s)
