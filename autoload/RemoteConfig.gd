extends Node
## Defaults locais confiáveis; provedor Firebase pode sobrepor apenas chaves permitidas.

const DEFAULTS: Dictionary = {
	"bath_base_reward": 52.0, # Realismo Guarulhos 2025: banho pequeno-medio R$40-60 => media R$52 (antes 12)
	"bath_duration": 8.5, # ritmo confortável: +40% para gesto respirar (antes 6.0)
	"bath_target_min": 0.82,
	"bath_target_max": 0.96,
	"upgrade_cost_base": 55.0, # escalado 2.2x para manter ritmo 62h com prêmio medio 2.2x (antes 25)
	"upgrade_cost_growth": 1.18,
	"upgrade_income_growth": 1.075,
	"offline_rate": 0.18,  # parcela da renda ativa que o cofre rende fechado (Nota10: 0.15→0.18 base)
	"offline_cap_hours": 4.0, # Nota10: 2h→4h base + 8h primeira noite generosa
	"autosave_seconds": 15.0,
	"rewarded_daily_cap": 8,
	"rewarded_cooldown_seconds": 180,
	"interstitial_min_session_seconds": 1200,
	"events_enabled": 1.0,
	"event_boost_scale": 1.0,
	"rush_interval_seconds": 360.0, # 6 min: pico respirável (antes 4 min)
	"rush_duration": 30.0, # 30s de êxtase contido (antes 45s)
	"rush_tip_mult": 2.0,
	"upsell_chance": 0.35,
	"upsell_tip_mult": 1.4,
	"petting_max_per_client": 5.0,
	# Economia escalável via remote: multiplicadores que afetam Rewards.gd
	"cosmetic_price_scale": 1.0,
	"hire_price_scale": 1.0,
	"reward_scale": 1.0,
	"offline_cap_scale": 1.0,
	# LiveOps sem build: overrides JSON como string (vazio = usa data/events.json)
	"events_weekly_override": "",
	"events_seasonal_override": "",
	# Rotativo semanal de cosméticos (id do cosmético em destaque na loja)
	"weekly_featured_cosmetic": "",
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
	"cosmetic_price_scale": Vector2(0.1, 5.0),
	"hire_price_scale": Vector2(0.1, 5.0),
	"reward_scale": Vector2(0.1, 5.0),
	"offline_cap_scale": Vector2(0.5, 3.0),
}
# Chaves que aceitam string (JSON ou id) — tamanho limitado para evitar abuso.
const STRING_KEYS: Array[String] = [
	"events_weekly_override", "events_seasonal_override", "weekly_featured_cosmetic"
]
const STRING_MAX_LEN: int = 8192

var values: Dictionary = DEFAULTS.duplicate(true)


func get_float(key: StringName) -> float:
	return float(values.get(String(key), DEFAULTS.get(String(key), 0.0)))


func get_int(key: StringName) -> int:
	return int(values.get(String(key), DEFAULTS.get(String(key), 0)))


func get_string(key: StringName) -> String:
	return String(values.get(String(key), DEFAULTS.get(String(key), "")))


func apply_verified(payload: Dictionary) -> void:
	for raw_key: Variant in payload:
		var key: String = String(raw_key)
		if not DEFAULTS.has(key):
			continue
		var expected_type: int = typeof(DEFAULTS[key])
		if typeof(payload[raw_key]) != expected_type:
			# Permite int->float coercion para chaves numéricas
			if expected_type == TYPE_FLOAT and typeof(payload[raw_key]) == TYPE_INT:
				pass
			else:
				continue
		if expected_type == TYPE_STRING:
			if not STRING_KEYS.has(key):
				continue
			var str_value: String = String(payload[raw_key])
			if str_value.length() > STRING_MAX_LEN:
				continue
			# Validação leve de JSON para overrides de eventos
			if key.ends_with("_override") and not str_value.is_empty():
				var parsed: Variant = JSON.parse_string(str_value)
				if not parsed is Array and not parsed is Dictionary:
					continue
			values[key] = str_value
			continue
		var numeric_value: float = float(payload[raw_key])
		var allowed: Vector2 = RANGES.get(key, Vector2(-INF, INF))
		if not is_finite(numeric_value) or numeric_value < allowed.x or numeric_value > allowed.y:
			continue
		values[key] = payload[raw_key]
	if get_float("bath_target_min") >= get_float("bath_target_max"):
		values["bath_target_min"] = DEFAULTS["bath_target_min"]
		values["bath_target_max"] = DEFAULTS["bath_target_max"]
	# Se houver overrides de eventos, aplica no ContentDB (LiveOps sem build)
	if Engine.has_singleton("ContentDB") or has_node("/root/ContentDB"):
		var cdb: Node = get_node_or_null("/root/ContentDB")
		if cdb != null and cdb.has_method("apply_remote_overrides"):
			cdb.apply_remote_overrides()
