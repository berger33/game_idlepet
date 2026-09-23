extends Node
## Catálogo/entitlements offline-safe; BillingProvider Android é injetado no build de loja.
## Agora com persistência em GameState e mock apenas em debug.

const PurchaseLedgerScript: Script = preload("res://core/iap/PurchaseLedger.gd")
const PRODUCTS: PackedStringArray = [
	"starter_pack",
	"no_ads",
	"brasa_small",
	"brasa_medium",
	"brasa_large",
	"bath_pass",
	"cosmetic_pack"
]

var ledger: PurchaseLedger
var provider_ready: bool = false
var entitlements: Dictionary = {"no_ads": false, "bath_pass": false}


func _ready() -> void:
	ledger = PurchaseLedgerScript.new()
	# Restaura entitlements persistidos de GameState
	_restore_entitlements()
	# Restaura ledger se GameState tiver
	if GameState.get("purchase_ledger") is Dictionary:
		var dict: Dictionary = GameState.get("purchase_ledger")
		for tx_id: String in dict.keys():
			var entry: Dictionary = dict[tx_id] as Dictionary
			if entry != null:
				ledger.processed_ids[tx_id] = entry


const MOCK_REWARDS: Dictionary = {
	&"brasa_small": {"embers": 10},
	&"brasa_medium": {"embers": 35},
	&"brasa_large": {"embers": 120},
	&"starter_pack": {"embers": 50, "entitlement": &"no_ads"},
	&"no_ads": {"entitlement": &"no_ads"},
	&"bath_pass": {"embers": 20, "entitlement": &"bath_pass"},
	&"cosmetic_pack": {"embers": 15, "cosmetics": ["crown_gold", "scarf_caramel"]}
}


func _restore_entitlements() -> void:
	var persisted: Variant = GameState.get("purchased_entitlements")
	if persisted is Dictionary:
		for key: String in persisted.keys():
			entitlements[key] = bool(persisted[key])
	# Compat: também checa active_cosmetics? não, só entitlements


func _persist_entitlements() -> void:
	if GameState.get("purchased_entitlements") is Dictionary:
		GameState.purchased_entitlements = entitlements.duplicate(true)
	else:
		# Fallback: cria campo dinâmico via set (GameState deve ter var)
		if "purchased_entitlements" in GameState:
			GameState.purchased_entitlements = entitlements.duplicate(true)
	# Persiste ledger também
	if "purchase_ledger" in GameState:
		GameState.purchase_ledger = ledger.to_dictionary()
	SaveManager.request_save()
	# Notifica AdsPolicy sobre compra recente
	if has_node("/root/AdsManager"):
		var ads: Node = get_node("/root/AdsManager")
		if ads.has_method("record_purchase_for_policy"):
			ads.record_purchase_for_policy()


func purchase(sku: StringName) -> bool:
	if not PRODUCTS.has(String(sku)):
		Analytics.track(&"iap_fail", {"sku": String(sku), "reason": "unknown_sku"})
		return false
	Analytics.track(&"iap_view", {"sku": String(sku)})
	if not provider_ready:
		# Mock apenas em debug — em release retorna indisponível
		if not OS.is_debug_build():
			EventBus.toast_requested.emit(Loc.t("IAP_STORE_UNAVAILABLE"), Color("b0bec5"))
			Analytics.track(&"iap_fail", {"sku": String(sku), "reason": "provider_not_ready"})
			return false
		# Mock offline funcional (debug): grant embers/entitlements sem provider
		_grant_mock(sku)
		EventBus.toast_requested.emit(Loc.t("IAP_MOCK_GRANTED") % String(sku), Color("ffd54f"))
		Analytics.track(&"iap_mock_grant", {"sku": String(sku)})
		return true
	# Provider real deve implementar fluxo de compra; este stub retorna false até integração
	Analytics.track(&"iap_fail", {"sku": String(sku), "reason": "provider_not_implemented"})
	return false


func _grant_mock(sku: StringName) -> void:
	var reward: Dictionary = MOCK_REWARDS.get(sku, {})
	var embers_gain: int = int(reward.get("embers", 0))
	if embers_gain > 0:
		GameState.embers += embers_gain
		EventBus.currency_changed.emit(&"embers", float(GameState.embers))
	var ent: StringName = StringName(reward.get("entitlement", &""))
	if ent != &"":
		entitlements[String(ent)] = true
	var cosmetics: Array = reward.get("cosmetics", [])
	for cid: Variant in cosmetics:
		var cid_str: String = String(cid)
		if not GameState.unlocked_cosmetics.has(cid_str):
			GameState.unlocked_cosmetics.append(cid_str)
	# Persistência
	_persist_entitlements()
	# Ledger mock para idempotência com ID único (usec + random)
	if is_instance_valid(ledger):
		var tx: String = "%s_mock_%d_%d" % [String(sku), Time.get_ticks_usec(), randi() % 1000000]
		ledger.mark_processed(tx, sku)
		if "purchase_ledger" in GameState:
			GameState.purchase_ledger = ledger.to_dictionary()


func grant_entitlement_from_provider(sku: StringName, transaction_id: String) -> bool:
	# Chamado pelo provider real após validação
	if not ledger.can_process(transaction_id):
		Analytics.track(&"iap_duplicate", {"sku": String(sku), "tx": transaction_id})
		return false
	var reward: Dictionary = MOCK_REWARDS.get(sku, {})
	var embers_gain: int = int(reward.get("embers", 0))
	if embers_gain > 0:
		GameState.embers += embers_gain
		EventBus.currency_changed.emit(&"embers", float(GameState.embers))
	var ent: StringName = StringName(reward.get("entitlement", &""))
	if ent != &"":
		entitlements[String(ent)] = true
	var cosmetics: Array = reward.get("cosmetics", [])
	for cid: Variant in cosmetics:
		var cid_str: String = String(cid)
		if not GameState.unlocked_cosmetics.has(cid_str):
			GameState.unlocked_cosmetics.append(cid_str)
	ledger.mark_processed(transaction_id, sku)
	_persist_entitlements()
	Analytics.track(&"iap_granted", {"sku": String(sku), "tx": transaction_id})
	return true


func has_entitlement(id: StringName) -> bool:
	# Checa memória + GameState persistido
	if bool(entitlements.get(String(id), false)):
		return true
	var persisted: Variant = GameState.get("purchased_entitlements")
	if persisted is Dictionary:
		return bool(persisted.get(String(id), false))
	return false
