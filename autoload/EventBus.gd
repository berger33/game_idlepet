extends Node
## Barramento tipado: sistemas não dependem de cenas concretas.

signal currency_changed(currency: StringName, amount: float)
signal service_started(service_id: StringName)
signal service_progress(value: float)
signal service_completed(service_id: StringName, quality: StringName, reward: float)
signal service_failed(service_id: StringName, reason: StringName)
signal pet_arrived(pet_id: StringName)
signal review_received(stars: int)
signal combo_changed(value: int)
signal upgrade_purchased(upgrade_id: StringName, level: int)
signal save_completed()
signal toast_requested(message: String, color: Color)
signal settings_changed()
