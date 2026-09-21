extends Node
## Defaults locais confiáveis; provedor Firebase pode sobrepor apenas chaves permitidas.

const DEFAULTS: Dictionary = {
	"bath_base_reward": 12.0,
	"bath_duration": 6.0,
	"bath_target_min": 0.82,
	"bath_target_max": 0.96,
	"upgrade_cost_base": 25.0,
	"upgrade_cost_growth": 1.18,
	"upgrade_income_growth": 1.075,
	"offline_rate": 0.15,  # parcela da renda ativa que o cofre rende fechado
	"offline_cap_hours": 2.0,
	"autosave_seconds": 15.0,
	"rewarded_daily_cap": 8,
	"rewarded_cooldown_seconds": 180,
	"interstitial_min_session_seconds": 1200,
	"events_enabled": 1.0,
	"event_boost_scale": 1.0,
	"rush_interval_seconds": 240.0,
	"rush_duration": 45.0,
	"rush_tip_mult": 2.0,
	"upsell_chance": 0.35,
	"upsell_tip_mult": 1.4,
	"petting_max_per_client": 5.0,
}
const RANGES: Dictionary = {
	"bath_base_reward": Vector2(1.0, 1000.0),
	"bath_duration": Vector2(2.0, 30.0),
	"bath_target_min": Vector2(0.4, 0.95),
	"bath_target_max": Vector2(0.5, 1.0),
	"upgrade_cost_base": Vector2(1.0, 10000.0),
	"upgrade_cost_growth": Vector2(1.01, 2.0),
	"upgrade_income_growth": Vector2(1.0, 2.0),
	"offline_rate": Vector2(0.0, 1.0),
	"offline_cap_hours": Vector2(1.0, 24.0),
	"autosave_seconds": Vector2(5.0, 120.0),
	"rewarded_daily_cap": Vector2(0.0, 8.0),
	"rewarded_cooldown_seconds": Vector2(180.0, 86400.0),
	"interstitial_min_session_seconds": Vector2(1200.0, 86400.0),
	"events_enabled": Vector2(0.0, 1.0),
	"event_boost_scale": Vector2(0.0, 1.0),
	"rush_interval_seconds": Vector2(60.0, 1800.0),
	"rush_duration": Vector2(15.0, 120.0),
	"rush_tip_mult": Vector2(1.0, 5.0),
	"upsell_chance": Vector2(0.0, 1.0),
	"upsell_tip_mult": Vector2(1.0, 3.0),
	"petting_max_per_client": Vector2(0.0, 20.0),
}

var values: Dictionary = DEFAULTS.duplicate(true)


func get_float(key: StringName) -> float:
	return float(values.get(String(key), DEFAULTS.get(String(key), 0.0)))


func get_int(key: StringName) -> int:
	return int(values.get(String(key), DEFAULTS.get(String(key), 0)))


func apply_verified(payload: Dictionary) -> void:
	for raw_key: Variant in payload:
		var key: String = String(raw_key)
		if not DEFAULTS.has(key) or typeof(payload[raw_key]) != typeof(DEFAULTS[key]):
			continue
		var numeric_value: float = float(payload[raw_key])
		var allowed: Vector2 = RANGES.get(key, Vector2(-INF, INF))
		if not is_finite(numeric_value) or numeric_value < allowed.x or numeric_value > allowed.y:
			continue
		values[key] = payload[raw_key]
	if get_float("bath_target_min") >= get_float("bath_target_max"):
		values["bath_target_min"] = DEFAULTS["bath_target_min"]
		values["bath_target_max"] = DEFAULTS["bath_target_max"]
