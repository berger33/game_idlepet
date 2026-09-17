extends Node
## Estado autoritativo serializável da sessão.

const SAVE_VERSION: int = 1
var coins: float = 0.0
var embers: int = 0
var franchise_tokens: int = 0
var total_coins: float = 0.0
var bath_upgrade_level: int = 0
var combo: int = 0
var best_combo: int = 0
var services_completed: int = 0
var reviews_total: int = 0
var reviews_sum: int = 0
var prestige_level: int = 0
var last_seen_unix: int = 0
var tutorial_complete: bool = false
var settings: Dictionary = {"music": 0.7, "sfx": 0.9, "haptics": true, "reduced_particles": false, "eco_mode": false}

func _ready() -> void:
    EventBus.service_completed.connect(_on_service_completed)
    EventBus.service_failed.connect(_on_service_failed)

func add_coins(amount: float, source: StringName) -> void:
    if amount <= 0.0:
        return
    coins += amount
    total_coins += amount
    EventBus.currency_changed.emit(&"coins", coins)
    Analytics.track(&"currency_earned", {"type": "coins", "source": String(source), "amount": amount})

func spend_coins(amount: float, sink: StringName) -> bool:
    if amount <= 0.0 or coins < amount:
        return false
    coins -= amount
    EventBus.currency_changed.emit(&"coins", coins)
    Analytics.track(&"currency_spent", {"type": "coins", "sink": String(sink), "amount": amount})
    return true

func buy_bath_upgrade() -> bool:
    var cost: float = Economy.upgrade_cost(bath_upgrade_level)
    if not spend_coins(cost, &"bath_upgrade"):
        return false
    bath_upgrade_level += 1
    EventBus.upgrade_purchased.emit(&"bath", bath_upgrade_level)
    Analytics.track(&"establishment_upgrade", {"id": "bath", "level": bath_upgrade_level})
    SaveManager.request_save()
    return true

func register_review(stars: int) -> void:
    reviews_total += 1
    reviews_sum += clampi(stars, 1, 5)
    EventBus.review_received.emit(stars)

func review_average() -> float:
    return 5.0 if reviews_total == 0 else float(reviews_sum) / float(reviews_total)

func to_dictionary() -> Dictionary:
    return {"version": SAVE_VERSION, "coins": coins, "embers": embers, "franchise_tokens": franchise_tokens,
        "total_coins": total_coins, "bath_upgrade_level": bath_upgrade_level, "combo": combo,
        "best_combo": best_combo, "services_completed": services_completed, "reviews_total": reviews_total,
        "reviews_sum": reviews_sum, "prestige_level": prestige_level, "last_seen_unix": Time.get_unix_time_from_system(),
        "tutorial_complete": tutorial_complete, "settings": settings}

func apply_dictionary(data: Dictionary) -> void:
    coins = float(data.get("coins", 0.0))
    embers = int(data.get("embers", 0))
    franchise_tokens = int(data.get("franchise_tokens", 0))
    total_coins = float(data.get("total_coins", coins))
    bath_upgrade_level = int(data.get("bath_upgrade_level", 0))
    combo = int(data.get("combo", 0))
    best_combo = int(data.get("best_combo", combo))
    services_completed = int(data.get("services_completed", 0))
    reviews_total = int(data.get("reviews_total", 0))
    reviews_sum = int(data.get("reviews_sum", 0))
    prestige_level = int(data.get("prestige_level", 0))
    last_seen_unix = int(data.get("last_seen_unix", 0))
    tutorial_complete = bool(data.get("tutorial_complete", false))
    settings.merge(data.get("settings", {}), true)
    EventBus.currency_changed.emit(&"coins", coins)

func _on_service_completed(_service_id: StringName, quality: StringName, reward: float) -> void:
    services_completed += 1
    combo = combo + 1 if quality == &"perfect" else 0
    best_combo = maxi(best_combo, combo)
    add_coins(reward, &"service")
    EventBus.combo_changed.emit(combo)
    SaveManager.request_save()

func _on_service_failed(_service_id: StringName, _reason: StringName) -> void:
    combo = 0
    EventBus.combo_changed.emit(combo)
