extends Node
## Fonte única para fórmulas monetárias. Nunca muta o estado diretamente.

## Loteria de gorjeta (odds publicadas na tela de resultado):
## 60% sem gorjeta · 25% +15% · 10% +30% · 5% +60%.
const TIP_ODDS: Array[float] = [0.60, 0.25, 0.10, 0.05]
const TIP_MULTIPLIERS: Array[float] = [1.0, 1.15, 1.30, 1.60]
## Chance de um cliente da fila ser VIP (recompensa ×2, paciência menor).
const VIP_CHANCE: float = 0.12
const VIP_REWARD_MULTIPLIER: float = 2.0

## Reputação do bairro: estrelas acumuladas desde sempre (reviews_sum, que já
## sobrevive ao prestígio). Cada faixa dá +3% de chance de VIP e +2% de gorjeta.
const NEIGHBORHOOD_TIERS: Array[int] = [0, 60, 150, 300, 600]
const NEIGHBORHOOD_VIP_BONUS: float = 0.03
const NEIGHBORHOOD_TIP_BONUS: float = 0.02
## Prestígio: cada nível de franquia rende +10% em todas as recompensas.
const PRESTIGE_COIN_BONUS: float = 0.10


func tip_multiplier(roll: float) -> float:
	var accumulated: float = 0.0
	for index: int in TIP_ODDS.size():
		accumulated += TIP_ODDS[index]
		if roll < accumulated:
			return TIP_MULTIPLIERS[index]
	return TIP_MULTIPLIERS[TIP_MULTIPLIERS.size() - 1]


func upgrade_cost(level: int) -> float:
	return ceil(
		(
			RemoteConfig.get_float("upgrade_cost_base")
			* pow(RemoteConfig.get_float("upgrade_cost_growth"), level)
		)
	)


func income_multiplier(level: int) -> float:
	return pow(RemoteConfig.get_float("upgrade_income_growth"), level)


func neighborhood_tier(reputation: int) -> int:
	var tier: int = 0
	for index: int in NEIGHBORHOOD_TIERS.size():
		if reputation >= NEIGHBORHOOD_TIERS[index]:
			tier = index
	return tier


func vip_chance(reputation: int) -> float:
	return minf(0.35, VIP_CHANCE + neighborhood_tier(reputation) * NEIGHBORHOOD_VIP_BONUS)


func tip_bonus(reputation: int) -> float:
	return neighborhood_tier(reputation) * NEIGHBORHOOD_TIP_BONUS


func prestige_coin_multiplier(prestige_level: int) -> float:
	return 1.0 + clampi(prestige_level, 0, 200) * PRESTIGE_COIN_BONUS


func service_reward(
	base_reward: float,
	quality: StringName,
	upgrade_level: int,
	combo: int,
	tool_level: int = 0,
	prestige_level: int = 0
) -> float:
	var quality_multiplier: float = 1.0
	if quality == &"perfect":
		quality_multiplier = 1.5
	elif quality == &"good":
		quality_multiplier = 1.15
	var combo_multiplier: float = 1.0 + minf(float(combo), 20.0) * 0.025
	var tool_multiplier: float = 1.0 + clampi(tool_level, 0, 30) * 0.04
	return floor(
		(
			base_reward
			* income_multiplier(upgrade_level)
			* tool_multiplier
			* quality_multiplier
			* combo_multiplier
			* prestige_coin_multiplier(prestige_level)
		)
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
