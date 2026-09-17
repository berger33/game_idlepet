extends Node
## Defaults locais confiáveis; provedor Firebase pode sobrepor apenas chaves permitidas.

const DEFAULTS: Dictionary = {
	"bath_base_reward": 12.0,
	"bath_duration": 6.0,
	"bath_target_min": 0.82,
	"bath_target_max": 0.96,
	"upgrade_cost_base": 25.0,
	"upgrade_cost_growth": 1.18,
	"upgrade_income_growth": 1.15,
	"offline_rate": 0.5,
	"offline_cap_hours": 2.0,
	"autosave_seconds": 15.0,
	"rewarded_daily_cap": 8,
	"rewarded_cooldown_seconds": 180,
	"interstitial_min_session_seconds": 1200
}
var values: Dictionary = DEFAULTS.duplicate(true)


func get_float(key: StringName) -> float:
	return float(values.get(String(key), DEFAULTS.get(String(key), 0.0)))


func get_int(key: StringName) -> int:
	return int(values.get(String(key), DEFAULTS.get(String(key), 0)))


func apply_verified(payload: Dictionary) -> void:
	for key: Variant in payload:
		if DEFAULTS.has(key) and typeof(payload[key]) == typeof(DEFAULTS[key]):
			values[key] = payload[key]
