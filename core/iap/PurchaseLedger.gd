class_name PurchaseLedger
extends RefCounted
## Ledger idempotente local. Produção valida token no backend antes do grant consumível.

var processed_ids: Dictionary = {}


func can_process(transaction_id: String) -> bool:
	return not transaction_id.is_empty() and not processed_ids.has(transaction_id)


func mark_processed(transaction_id: String, sku: StringName) -> bool:
	if not can_process(transaction_id):
		return false
	processed_ids[transaction_id] = {"sku": String(sku), "time": Time.get_unix_time_from_system()}
	return true


func to_dictionary() -> Dictionary:
	return processed_ids.duplicate(true)
