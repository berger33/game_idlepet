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
