class_name TutorialFlow
extends RefCounted
## Roteiro da guia Bia (vizinha e futura sócia): tutorial em 4 passos
## (boas-vindas, escolher cliente, pegar a ferramenta, executar o gesto) e,
## depois, "primeiros passos" — dicas contextuais mostradas uma única vez cada
## (persistidas em GameState.guide_steps_done): passeio, brincadeiras, ritmo
## de 8 min, Concurso da Capa, melhorias e missões. Sem voz: tudo em tela.
## Guarda apenas o passo atual; a UI é o TutorialOverlay (cartão da Bia).

const STEP_WELCOME: int = 0
const STEP_QUEUE: int = 1
const STEP_TOOL: int = 2
const STEP_GESTURE: int = 3
const STEP_COUNT: int = 4
## Eventos que cada dica escuta e ordem de prioridade dentro do evento.
const TIPS: Dictionary = {
	&"result_dismissed": ["first_done", "park", "missions", "upgrade"],
	&"park_opened": ["park_choose"],
	&"park_result_dismissed": ["park_done", "contest"],
}

var main: Control
var step: int = -1
## Boas-vindas aguardam o splash sumir (senão a Bia fala atrás dele).
var welcome_pending: bool = false
## Mini-tutorial de gesto em exibição (independente dos passos iniciais).
var teaching: bool = false
## Dica de primeiros passos em exibição.
var tip_id: String = ""
var pending_event: StringName = &""


func attach(owner: Control) -> void:
	main = owner


func setup() -> void:
	if bool(GameState.tutorial_complete):
		return
	step = STEP_WELCOME
	main.tutorial_skip_button.visible = true
	welcome_pending = true


func apply() -> void:
	main.tutorial_overlay.locked = true
	var is_kids: bool = bool(GameState.settings.get("kids_mode", false))
	match step:
		STEP_WELCOME:
			main.tutorial_overlay.show_guide(Loc.t("GUIDE_WELCOME"), &"hello", Rect2(), Loc.t("GUIDE_GO"), advance)
		STEP_QUEUE:
			var pad: Vector2 = Vector2(18, 18) if is_kids else Vector2(10, 10)
			var rect: Rect2 = Rect2(main.queue_row.position - pad, main.queue_row.size + pad * 2.0)
			var first_card: Vector2 = main.queue_row.position + Vector2(main.queue_row.size.x / 6.0, main.queue_row.size.y * 0.5)
			var pet_name: String = ContentDB.pet_name("caramelo") if ContentDB.has_pet("caramelo") else "Caramelo"
			main.tutorial_overlay.show_guide(Loc.t("GUIDE_QUEUE") % pet_name, &"point", rect, "", Callable(), &"tap", first_card, first_card)
		STEP_TOOL:
			var tool: StringName = StringName(main.SERVICE_TOOLS[main.current_service])
			main.tutorial_overlay.show_guide(
				Loc.t("GUIDE_TOOL") % [SalonTuning.tool_display_name(tool), main.current_pet_name],
				&"point", spot_rect(), "", Callable(), &"drag", main.world.tool_shelf_position(tool), main.world.pet_focus()
			)
		STEP_GESTURE:
			var focus: Vector2 = main.world.pet_focus()
			var rect: Rect2 = Rect2(focus - Vector2(300, 330), Vector2(600, 680)) if is_kids else Rect2(focus - Vector2(250, 250), Vector2(500, 560))
			main.tutorial_overlay.show_guide(Loc.t("GUIDE_GESTURE") % SalonTuning.hint(main.current_service), &"cheer", rect)


func advance() -> void:
	step += 1
	# Jogador adiantado (tocou a fila/pegou a ferramenta antes da fala): pula o passo já feito.
	if step == STEP_QUEUE and main.selected_slot >= 0:
		step = STEP_TOOL
	if step == STEP_TOOL and main.bath.state != BathService.State.WAITING:
		step = STEP_GESTURE
	if step >= STEP_COUNT:
		finish()
		Analytics.track(&"tutorial_complete")
	else:
		apply()


func finish() -> void:
	step = -1
	main.tutorial_overlay.finish()
	main.tutorial_skip_button.visible = false
	GameState.tutorial_complete = true


func skip() -> void:
	finish()
	Analytics.track(&"tutorial_skipped")


## Mini-tutorial por gesto novo (auditoria §4): na PRIMEIRA vez que cada
## serviço é selecionado, a Bia cai sobre o pet com a dica do gesto; some no
## primeiro arrasto. Persistido em settings["services_taught"] (uma vez por serviço).
func teach_service(service: StringName) -> void:
	if step >= 0 or not bool(GameState.tutorial_complete):
		return
	var taught: Array = GameState.settings.get("services_taught", [])
	if String(service) in taught:
		return
	taught.append(String(service))
	GameState.settings["services_taught"] = taught
	dismiss_tip()
	teaching = true
	var is_kids_teach: bool = bool(GameState.settings.get("kids_mode", false))
	var focus: Vector2 = main.world.pet_focus()
	var teach_rect: Rect2 = Rect2(focus - Vector2(300, 330), Vector2(600, 680)) if is_kids_teach else Rect2(focus - Vector2(250, 250), Vector2(500, 560))
	main.tutorial_overlay.show_guide("%s\n%s" % [Loc.t("TEACH_NEW_GESTURE"), SalonTuning.hint(service)], &"think", teach_rect)
	Analytics.track(&"gesture_taught", {"service": String(service)})
	SaveManager.request_save()


## Encerra o mini-tutorial de gesto (primeiro arrasto ou fim do serviço).
func stop_teaching() -> void:
	if not teaching:
		return
	teaching = false
	main.tutorial_overlay.finish()


func spot_rect() -> Rect2:
	var tool: StringName = StringName(main.SERVICE_TOOLS[main.current_service])
	var shelf: Vector2 = main.world.tool_shelf_position(tool)
	var is_kids_spot: bool = bool(GameState.settings.get("kids_mode", false))
	var half: float = 95.0 if is_kids_spot else 80.0
	return Rect2(shelf - Vector2(half, half), Vector2(half * 2, half * 2))


## ── Primeiros passos ── eventos do jogo viram dicas da Bia (uma vez cada).
func notify(event: StringName) -> void:
	dismiss_tip()
	if TIPS.has(event):
		pending_event = event


## Chamado do Main._process: mostra a dica pendente quando a tela está livre.
func tick() -> void:
	if welcome_pending:
		if main.splash_done and not RevealCard.is_showing():
			welcome_pending = false
			apply()
		return
	if step >= 0 or teaching:
		return
	if not tip_id.is_empty():
		# A dica some sozinha quando a tela muda (meta aberto, resultado, passeio começou/fechou).
		var park_context: bool = tip_id == "park_choose"
		var park_ok: bool = main.park_active and main.park_choose_panel.visible if park_context else not main.park_active
		if main.meta.is_open() or main.result_panel.visible or not park_ok:
			dismiss_tip()
		return
	if pending_event == &"" or RevealCard.is_showing() or main.meta.is_open() or main.result_panel.visible:
		return
	if main.park_active and pending_event != &"park_opened":
		return
	var event: StringName = pending_event
	pending_event = &""
	for id: String in TIPS[event]:
		if id in GameState.guide_steps_done or not _tip_ready(id):
			continue
		_show_tip(id)
		return


func dismiss_tip() -> void:
	pending_event = &""
	if tip_id.is_empty():
		return
	tip_id = ""
	main.tutorial_overlay.finish()


func _tip_ready(id: String) -> bool:
	var done: int = GameState.services_completed
	var ready: Dictionary = {
		"first_done": done >= 1,
		"park": done >= 2 and GameState.park_plays_total == 0 and is_instance_valid(main.park_button),
		"missions": done >= 3 and is_instance_valid(main.missions_button) and not main.missions_button.disabled,
		"upgrade": done >= 4 and is_instance_valid(main.upgrades_button) and SalonTuning.affordable_upgrades_count() > 0,
		"park_choose": is_instance_valid(main.park_choose_panel) and main.park_choose_panel.visible,
		"park_done": GameState.park_plays_total >= 1,
		"contest": GameState.park_contest_points > 0 and is_instance_valid(main.album_button) and not main.album_button.disabled,
	}
	return bool(ready.get(id, false))


func _show_tip(id: String) -> void:
	tip_id = id
	GameState.guide_steps_done.append(id)
	SaveManager.request_save()
	Analytics.track(&"guide_tip", {"id": id})
	var overlay: Control = main.tutorial_overlay
	var ok: String = Loc.t("GUIDE_OK")
	match id:
		"first_done":
			overlay.show_guide(Loc.t("GUIDE_DONE"), &"cheer", Rect2(), Loc.t("GUIDE_THANKS"), dismiss_tip)
		"park":
			var rect: Rect2 = _button_rect(main.park_button, 22.0)
			overlay.show_guide(Loc.t("GUIDE_TIP_PARK"), &"point", rect, ok, dismiss_tip, &"tap", rect.get_center(), rect.get_center())
		"missions":
			overlay.show_guide(Loc.t("GUIDE_TIP_MISSIONS"), &"think", _button_rect(main.missions_button, 16.0), ok, dismiss_tip)
		"upgrade":
			overlay.show_guide(Loc.t("GUIDE_TIP_UPGRADE"), &"point", _button_rect(main.upgrades_button, 22.0), ok, dismiss_tip)
		"park_choose":
			overlay.show_guide(Loc.t("GUIDE_TIP_PARK_CHOOSE"), &"point", _button_rect(main.park_choose_panel, 12.0), ok, dismiss_tip)
		"park_done":
			overlay.show_guide(Loc.t("GUIDE_TIP_PARK_DONE"), &"think", Rect2(), Loc.t("GUIDE_THANKS"), dismiss_tip)
		"contest":
			var rect: Rect2 = _button_rect(main.album_button, 16.0)
			overlay.show_guide(Loc.t("GUIDE_TIP_CONTEST"), &"cheer", rect, ok, dismiss_tip, &"tap", rect.get_center(), rect.get_center())


func _button_rect(control: Control, grow: float) -> Rect2:
	if not is_instance_valid(control):
		return Rect2()
	return Rect2(control.global_position, control.size).grow(grow)
