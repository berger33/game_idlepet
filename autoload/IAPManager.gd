extends Node
## Catálogo/entitlements offline-safe; BillingProvider Android é injetado no build de loja.

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


const MOCK_REWARDS: Dictionary = {
	&"brasa_small": {"embers": 10},
	&"brasa_medium": {"embers": 35},
	&"brasa_large": {"embers": 120},
	&"starter_pack": {"embers": 50, "entitlement": &"no_ads"},
	&"no_ads": {"entitlement": &"no_ads"},
	&"bath_pass": {"embers": 20, "entitlement": &"bath_pass"},
	&"cosmetic_pack": {"embers": 15, "cosmetics": ["crown_gold", "scarf_caramel"]}
}

func purchase(sku: StringName) -> bool:
	if not PRODUCTS.has(String(sku)):
		Analytics.track(&"iap_fail", {"sku": String(sku), "reason": "unknown_sku"})
		return false
	Analytics.track(&"iap_view", {"sku": String(sku)})
	if not provider_ready:
		# Mock offline funcional (P1): grant embers/entitlements sem provider
		_grant_mock(sku)
		EventBus.toast_requested.emit(Loc.t("IAP_MOCK_GRANTED") % String(sku), Color("ffd54f"))
		Analytics.track(&"iap_mock_grant", {"sku": String(sku)})
		return true
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
	SaveManager.request_save()
	# Ledger mock para idempotência
	if is_instance_valid(ledger):
		var tx: String = "%s_mock_%d_%05d" % [String(sku), int(Time.get_unix_time_from_system()), Time.get_ticks_msec() % 100000]
		ledger.mark_processed(tx, sku)


func has_entitlement(id: StringName) -> bool:
	return bool(entitlements.get(String(id), false))
