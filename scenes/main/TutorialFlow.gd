class_name TutorialFlow
extends RefCounted
## Roteiro do tutorial (spotlight em 3 passos: escolher cliente, pegar a
## ferramenta, executar o gesto), isolado do fluxo principal do salão.
## Guarda apenas o passo atual; a UI continua no Main.

var main: Control
var step: int = -1


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
			"1/3 · Toque em um cliente da fila para atender",
		)
	elif step == 1:
		var tool: StringName = StringName(main.SERVICE_TOOLS[main.current_service])
		main.tutorial_overlay.show_step(
			spot_rect(),
			"2/3 · Arraste %s até %s" % [SalonTuning.tool_display_name(tool), main.current_pet_name],
		)
	elif step == 2:
		main.tutorial_overlay.show_step(
			Rect2(main.world.pet_focus() - Vector2(250, 250), Vector2(500, 560)),
			"3/3 · " + SalonTuning.hint(main.current_service),
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


func spot_rect() -> Rect2:
	var tool: StringName = StringName(main.SERVICE_TOOLS[main.current_service])
	var shelf: Vector2 = main.world.tool_shelf_position(tool)
	return Rect2(shelf - Vector2(80, 80), Vector2(160, 160))
