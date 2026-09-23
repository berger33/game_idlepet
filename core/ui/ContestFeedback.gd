class_name ContestFeedback
extends RefCounted
## Superfícies de retenção do Concurso da Capa fora do Álbum (mesmo padrão
## SessionFeedback/D1Retention): cartão de resultado no login, toast de
## "Sábado da Capa" e nudge quando um rival ultrapassa o jogador. Cada aviso
## sai no máximo uma vez por dia; o cartão de resultado insiste até ser coletado.

const GOLD: Color = Color("ffd54f")
const ALBUM_ICON: String = "res://art/ui/icons/album.png"


static func on_boot(main: Control) -> void:
	if GameState.park_plays_total == 0 and not Contest.has_pending():
		return
	Contest.sync()
	if Contest.has_pending():
		show_result_card(main)
	var today: String = Time.get_date_string_from_system()
	if String(GameState.settings.get("contest_nudge_date", "")) == today or not bool(GameState.tutorial_complete):
		return
	if Contest.is_saturday():
		GameState.settings["contest_nudge_date"] = today
		main._show_toast(Loc.t("CONTEST_SATURDAY_TOAST"), GOLD)
	elif Contest.was_overtaken():
		GameState.settings["contest_nudge_date"] = today
		main._show_toast(Loc.t("CONTEST_OVERTAKEN_TOAST") % Contest.placement_label(Contest.rank()), GOLD)


## Cartão do resultado fechado: coleta no botão principal (RevealCard on_primary).
static func show_result_card(main: Control) -> void:
	var pending: Dictionary = GameState.park_contest_pending
	if pending.is_empty():
		return
	var placement: int = clampi(int(pending.get("rank", 4)), 1, 4)
	var embers: int = int(pending.get("embers", 0))
	var body: String = Loc.t("CONTEST_RESULT_BODY") % [
		int(pending.get("points", 0)), Contest.placement_label(placement), int(pending.get("coins", 0)),
		(Loc.t("CONTEST_RESULT_EMBERS") % embers) if embers > 0 else "",
	]
	body += "\n\n" + Loc.t("CONTEST_RESULT_HINT_WIN" if placement == 1 else "CONTEST_RESULT_HINT_LOSE")
	RevealCard.enqueue(main, {
		"title": Loc.t("CONTEST_RESULT_TITLE_%d" % placement),
		"body": body,
		"color": GOLD if placement == 1 else main.BLUE,
		"image": ALBUM_ICON,
		"primary": Loc.t("CONTEST_CLAIM"),
		"sound": &"perfect" if placement == 1 else &"window",
		"on_primary": func() -> void: claim(main),
	})


## Entrega o prêmio pendente com feedback (usado pelo cartão e pelo Álbum).
static func claim(main: Control) -> Dictionary:
	var result: Dictionary = Contest.claim()
	if result.is_empty():
		return result
	AudioManager.play(&"perfect" if int(result.get("rank", 4)) == 1 else &"coin")
	HapticsManager.success()
	main._show_toast(Loc.t("CONTEST_CLAIM_TOAST") % [int(result.get("coins", 0)), int(result.get("embers", 0))], GOLD)
	main._animate_coin_fly(int(result.get("coins", 0)))
	main._refresh_economy()
	return result
