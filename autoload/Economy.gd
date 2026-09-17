extends Node
## Fonte única para fórmulas monetárias. Nunca muta o estado diretamente.


func upgrade_cost(level: int) -> float:
	return ceil(
		(
			RemoteConfig.get_float("upgrade_cost_base")
			* pow(RemoteConfig.get_float("upgrade_cost_growth"), level)
		)
	)


func income_multiplier(level: int) -> float:
	return pow(RemoteConfig.get_float("upgrade_income_growth"), level)


func service_reward(
	base_reward: float, quality: StringName, upgrade_level: int, combo: int
) -> float:
	var quality_multiplier: float = 1.0
	if quality == &"perfect":
		quality_multiplier = 1.5
	elif quality == &"good":
		quality_multiplier = 1.15
	var combo_multiplier: float = 1.0 + minf(float(combo), 20.0) * 0.025
	return floor(
		base_reward * income_multiplier(upgrade_level) * quality_multiplier * combo_multiplier
	)


func offline_earnings(rate_per_second: float, elapsed_seconds: float, prestige_level: int) -> float:
	var cap_hours: float = minf(24.0, RemoteConfig.get_float("offline_cap_hours") + prestige_level)
	var clamped_seconds: float = clampf(elapsed_seconds, 0.0, cap_hours * 3600.0)
	return floor(
		(
			rate_per_second
			* clamped_seconds
			* RemoteConfig.get_float("offline_rate")
			* (1.0 + prestige_level * 0.05)
		)
	)


func prestige_tokens(total_coins: float) -> int:
	return int(floor(sqrt(maxf(0.0, total_coins) / 1000000.0)))
