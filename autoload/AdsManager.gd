extends Node
## Fachada segura: gameplay nunca depende de disponibilidade de anúncio.
## Agora com ciclo de vida completo: session tracking, no_ads gating, record_rewarded wiring.

const AdsPolicyScript: Script = preload("res://core/ads/AdsPolicy.gd")
var policy: AdsPolicy
var provider_ready: bool = false
var unavailable_reason: String = "provider_not_installed"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	policy = AdsPolicyScript.new()
	# Carrega estado persistido se houver
	if GameState.has_method("ads_policy_dict"):
		pass # futuro: GameState conterá ads policy
	# Session count incrementa a cada boot
	policy.record_session_start()
	# Escuta compras para purchased_recently
	EventBus.currency_changed.connect(_on_currency_changed)
	# Tenta carregar policy do save se GameState tiver campo
	if GameState.get("ads_policy") is Dictionary:
		policy.from_dictionary(GameState.get("ads_policy"))


func _process(delta: float) -> void:
	if policy != null:
		policy.add_session_seconds(delta)


func _on_currency_changed(_type: StringName, _amount: float) -> void:
	# Heurística: se entitlements mudaram recentemente, marca purchased_recently via IAPManager
	pass


func is_rewarded_available() -> bool:
	# no_ads não bloqueia rewarded (apenas interstitial) — mas se provider não pronto, bloqueia
	if IAPManager != null and IAPManager.has_entitlement(&"no_ads"):
		# Rewarded continua permitido mesmo com no_ads (é opt-in), mas interstitial não
		pass
	if not provider_ready:
		return false
	return policy.can_show_rewarded()


func request_rewarded(offer_type: StringName, _on_reward: Callable) -> bool:
	Analytics.track(
		&"rewarded_offer", {"type": String(offer_type), "eligible": is_rewarded_available()}
	)
	if not is_rewarded_available():
		EventBus.toast_requested.emit(
			Loc.t("ADS_REWARDED_UNAVAILABLE"), Color("b0bec5")
		)
		return false
	# O adapter Android chama on_rewarded_completed apenas no callback de conclusão verificado.
	return false


func on_rewarded_completed(offer_type: StringName) -> void:
	# Chamado pelo provider real após callback verificado
	if policy != null:
		policy.record_rewarded()
	Analytics.track(&"rewarded_complete", {"type": String(offer_type)})
	SaveManager.request_save()


func is_interstitial_allowed() -> bool:
	if IAPManager != null and IAPManager.has_entitlement(&"no_ads"):
		return false
	if not provider_ready:
		return false
	return policy.can_show_interstitial()


func on_interstitial_shown() -> void:
	if policy != null:
		policy.record_interstitial()
	Analytics.track(&"interstitial_shown", {})


func record_purchase_for_policy() -> void:
	if policy != null:
		policy.record_purchase()
