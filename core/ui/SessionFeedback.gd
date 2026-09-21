class_name SessionFeedback
extends RefCounted
## Feedback de sessão do Main: presente de retorno (comeback) e
## compartilhamento antes/depois. Recebe o Main para tocar toast, chime e
## haptics sem duplicar UI nem engordar o Main além do limite de 1000 linhas
## (mesmo padrão de PetCosmeticsArt/style_factory).


## Bem-vindo de volta: ausência >= 48h concede moedas e um congelamento de
## streak. Economia e idempotência por dia ficam em GameState.check_return_bonus.
static func show_comeback(main) -> void:
	if not GameState.check_return_bonus():
		return
	main._show_toast(Loc.t("COMEBACK_TOAST"), main.GREEN)
	AudioManager.play(&"comeback")
	HapticsManager.success()


## Cartão "Enquanto você estava fora" (substitui o toast do cofre): minutos,
## moedas, parte da equipe, evento de hoje e login diário pendente. Dobrar
## custa 1 brasa (ou um vídeo recompensado, quando o adapter existir) —
## sink honesto da moeda escassa com valor imediato e legível.
static func show_offline_card(main) -> void:
	var offline: Dictionary = SaveManager.consume_pending_offline_reward()
	if offline.is_empty():
		return
	var minutes: int = int(float(offline["seconds"]) / 60.0)
	var reward: int = int(offline["reward"])
	var body: String = Loc.t("OFFLINE_BODY") % [minutes, reward]
	var share: int = int(roundf(Rewards.automation_share() * 100.0))
	if share > 0:
		body += "\n" + Loc.t("OFFLINE_STAFF") % share
	body += "\n" + Loc.t("OFFLINE_TODAY") % [
		LiveOps.current_event_name(), LiveOps.event_description_for(LiveOps.weekday())
	]
	if not GameState.is_daily_claimed_today():
		body += "\n" + Loc.t("OFFLINE_DAILY") % (GameState.daily_streak % 7 + 1)
	var spec: Dictionary = {
		"title": Loc.t("OFFLINE_TITLE"),
		"body": body,
		"color": Color("ffd54f"),
		"primary": Loc.t("COLLECT"),
		"sound": &"coin",
	}
	var grant_double: Callable = func() -> void:
		GameState.add_coins(float(reward), &"offline_double")
		Analytics.track(&"offline_doubled", {"amount": reward})
		AudioManager.play(&"coin")
	if reward > 0 and AdsManager.is_rewarded_available():
		spec["secondary"] = Loc.t("OFFLINE_DOUBLE_AD")
		spec["on_secondary"] = func() -> void:
			AdsManager.request_rewarded(&"offline_double", grant_double)
	elif reward > 0 and GameState.embers >= 1:
		spec["secondary"] = Loc.t("OFFLINE_DOUBLE_EMBER")
		spec["on_secondary"] = func() -> void:
			GameState.embers -= 1
			EventBus.currency_changed.emit(&"embers", float(GameState.embers))
			Analytics.track(&"currency_spent", {"currency": "embers", "sink": "offline_double"})
			grant_double.call()
	RevealCard.enqueue(main, spec)


## Toast com fila: evita sobreposição empilhando com offset por toast existente.
static func toast(main, message: String, color: Color) -> void:
	var existing: int = main.toast_layer.get_child_count()
	if existing >= 3:
		# Se já tem 3, remove o mais antigo para não poluir
		var oldest: Node = main.toast_layer.get_child(0)
		if is_instance_valid(oldest):
			oldest.queue_free()
			existing -= 1
	var label: Label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_stylebox_override("normal", main._style(color, 22, 14))
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var y_base: float = 120.0 + existing * 88.0
	label.position = Vector2(-360, y_base)
	label.size = Vector2(720, 76)
	main.toast_layer.add_child(label)
	var tween: Tween = main.create_tween()
	tween.tween_property(label, "position:y", y_base + 45.0, 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(1.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)


## Abre uma seção do painel meta. Mediado porque os botões de navegação são
## criados antes do MetaPanel existir; o acesso ao painel acontece só no clique.
static func open_meta(main, section: StringName, origin: Control) -> void:
	main.meta.open(section, origin)


## Compartilhar o antes/depois: o cartão 9:16 é gerado pelo ShareManager ao
## concluir o serviço. Web abre a folha nativa/download; nas demais plataformas
## a foto já está na galeria e a legenda vai para o clipboard (toast diz isso).
static func on_share_pressed(main) -> void:
	var channel: StringName = ShareManager.share_last()
	if channel == &"none":
		main.share_button.visible = false
		main._show_toast(Loc.t("SHARE_FAILED"), Color("b0bec5"))
		return
	AudioManager.play(&"share_saved")
	HapticsManager.success()
	if channel == &"web_share":
		main._show_toast(Loc.t("SHARE_WEB"), main.BLUE)
		return
	main._show_toast(Loc.t("SHARE_SAVED_GALLERY"), main.BLUE)
	if OS.has_feature("pc"):
		OS.shell_open(ProjectSettings.globalize_path(ShareManager.share_directory()))
