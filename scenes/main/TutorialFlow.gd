class_name TutorialFlow
extends RefCounted
## Roteiro do tutorial (spotlight em 3 passos: escolher cliente, pegar a
## ferramenta, executar o gesto), isolado do fluxo principal do salão.
## Guarda apenas o passo atual; a UI continua no Main.

var main: Control
var step: int = -1
## Mini-tutorial de gesto em exibição (independente dos 3 passos iniciais).
var teaching: bool = false


func attach(owner: Control) -> void:
	main = owner


func setup() -> void:
	if bool(GameState.tutorial_complete):
		return
	step = 0
	main.tutorial_skip_button.visible = true
	apply()


func apply() -> void:
	if step == 0:
		main.tutorial_overlay.show_step(
			Rect2(
				main.queue_row.position - Vector2(10, 10),
				main.queue_row.size + Vector2(20, 20)
			),
			"●○○ 1/3 · " + Loc.t("TUT_STEP_1"),
		)
	elif step == 1:
		var tool: StringName = StringName(main.SERVICE_TOOLS[main.current_service])
		main.tutorial_overlay.show_step(
			spot_rect(),
			"○●○ 2/3 · " + Loc.t("TUT_STEP_2") % [SalonTuning.tool_display_name(tool), main.current_pet_name],
		)
	elif step == 2:
		main.tutorial_overlay.show_step(
			Rect2(main.world.pet_focus() - Vector2(250, 250), Vector2(500, 560)),
			"○○● 3/3 · " + SalonTuning.hint(main.current_service),
		)


func advance() -> void:
	step += 1
	if step >= 3:
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


## Mini-tutorial por gesto novo (auditoria §4): tosa/secagem/perfume/laço
## chegavam só com toast. Na PRIMEIRA vez que cada serviço é selecionado, o
## spotlight do tutorial cai sobre o pet com a dica do gesto; some no primeiro
## arrasto. Persistido em settings["services_taught"] (uma vez por serviço).
func teach_service(service: StringName) -> void:
	if step >= 0 or not bool(GameState.tutorial_complete):
		return
	var taught: Array = GameState.settings.get("services_taught", [])
	if String(service) in taught:
		return
	taught.append(String(service))
	GameState.settings["services_taught"] = taught
	teaching = true
	main.tutorial_overlay.show_step(
		Rect2(main.world.pet_focus() - Vector2(250, 250), Vector2(500, 560)),
		"%s\n%s" % [Loc.t("TEACH_NEW_GESTURE"), SalonTuning.hint(service)]
	)
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
	return Rect2(shelf - Vector2(80, 80), Vector2(160, 160))
