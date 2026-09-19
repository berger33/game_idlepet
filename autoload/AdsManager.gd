extends Node
## Fachada segura: gameplay nunca depende de disponibilidade de anúncio.

const AdsPolicyScript: Script = preload("res://core/ads/AdsPolicy.gd")
var policy: AdsPolicy
var provider_ready: bool = false
var unavailable_reason: String = "provider_not_installed"


func _ready() -> void:
	policy = AdsPolicyScript.new()


func is_rewarded_available() -> bool:
	return provider_ready and policy.can_show_rewarded()


func request_rewarded(offer_type: StringName, _on_reward: Callable) -> bool:
	Analytics.track(
		&"rewarded_offer", {"type": String(offer_type), "eligible": is_rewarded_available()}
	)
	if not is_rewarded_available():
		EventBus.toast_requested.emit(
			"Vídeo indisponível. Continue jogando normalmente.", Color("b0bec5")
		)
		return false
	# O adapter Android chama on_reward apenas no callback de conclusão verificado.
	return false


func is_interstitial_allowed() -> bool:
	return provider_ready and policy.can_show_interstitial()
