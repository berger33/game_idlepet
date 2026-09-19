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


func purchase(sku: StringName) -> bool:
	if not PRODUCTS.has(String(sku)):
		Analytics.track(&"iap_fail", {"sku": String(sku), "reason": "unknown_sku"})
		return false
	Analytics.track(&"iap_view", {"sku": String(sku)})
	if not provider_ready:
		EventBus.toast_requested.emit("Loja indisponível offline.", Color("b0bec5"))
		return false
	return false


func has_entitlement(id: StringName) -> bool:
	return bool(entitlements.get(String(id), false))
