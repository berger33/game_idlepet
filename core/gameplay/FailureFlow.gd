class_name FailureFlow
extends RefCounted
## Decisões do fluxo de falha do salão (padrão ParkFlow/SalonPanels): o Main
## guarda o estado e os nós; aqui fica a política de retry/desistência.
##
## Regra de produto: errar oferece "Tentar de novo • ver vídeo" (o retry custa
## um rewarded; sem SDK de ads o AdsManager simula 3 s) e "Desistir" ao lado —
## o pet vai embora sem completar o atendimento e sem gerar recompensa.


static func request_retry_with_ad(main: Control) -> void:
	AudioManager.play(&"tap")
	HapticsManager.light()
	Analytics.track(
		&"retry_requested",
		{"type": String(main.current_service), "reason": String(main.last_failure_reason)}
	)
	if AdsManager.request_rewarded(&"retry", _on_rewarded.bind(main)):
		return
	# Sem vídeo disponível (cap diário/cooldown da política): não deixa o
	# jogador travado na tela de falha — libera a tentativa com aviso.
	# "Desistir" continua sempre disponível ao lado.
	main._show_toast(Loc.t("RETRY_FREE_FALLBACK"), main.BLUE)
	main._retry_service()


static func _on_rewarded(main: Control) -> void:
	main._retry_service()


static func giveup(main: Control) -> void:
	AudioManager.play(&"tap")
	HapticsManager.light()
	Analytics.track(
		&"service_giveup",
		{"type": String(main.current_service), "reason": String(main.last_failure_reason)}
	)
	main._dismiss_result()
