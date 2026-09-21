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
	main._show_toast("Bem-vindo de volta! Presente de retorno resgatado.", main.GREEN)
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


## Abre uma seção do painel meta. Mediado porque os botões de navegação são
## criados antes do MetaPanel existir; o acesso ao painel acontece só no clique.
static func open_meta(main, section: StringName, origin: Control) -> void:
	main.meta.open(section, origin)


## Compartilhar o antes/depois: o PNG composto é salvo pelo ShareManager ao
## concluir o serviço. Sem adapter de rede social nesta build, o toast indica
## o arquivo salvo em disco (contrato do ShareManager; não prometer rede social).
static func on_share_pressed(main) -> void:
	var path: String = ShareManager.last_saved_path
	if path.is_empty():
		main.share_button.visible = false
		return
	AudioManager.play(&"share_saved")
	HapticsManager.success()
	main._show_toast(
		"Antes/depois salvo em %s" % ProjectSettings.globalize_path(path), main.BLUE
	)
