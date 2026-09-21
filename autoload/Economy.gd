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
	var research_vip: float = Research.bonus(&"vip_chance")
	return minf(0.50, VIP_CHANCE + neighborhood_tier(reputation) * NEIGHBORHOOD_VIP_BONUS + research_vip)


func tip_bonus(reputation: int) -> float:
	var research_tip: float = Research.bonus(&"tip_bonus")
	return neighborhood_tier(reputation) * NEIGHBORHOOD_TIP_BONUS + research_tip


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


## Cofre offline. rate_per_second = renda ATIVA estimada (Rewards.income_per_second);
## offline_rate (remoto) é a parcela dela que o salão rende fechado (0,15 base 4h + pesquisa,
## 8h primeira noite generosa). automation_share soma equipe, research_bonus é "Clínica Móvel",
## research_cap_bonus soma horas de pesquisa (second_branch, franchise_network, empire_legacy).
## is_first garante 8h cap mínimo D1.
func offline_earnings(
	rate_per_second: float,
	elapsed_seconds: float,
	prestige_level: int,
	research_bonus: float = 0.0,
	automation_share: float = 0.0,
	research_cap_bonus: float = 0.0,
	is_first: bool = false
) -> float:
	var base_cap: float = RemoteConfig.get_float("offline_cap_hours")
	var cap_scale: float = RemoteConfig.get_float("offline_cap_scale")
	if cap_scale <= 0.0:
		cap_scale = 1.0
	var cap_hours: float = (base_cap + prestige_level + research_cap_bonus) * cap_scale
	if is_first:
		cap_hours = maxf(cap_hours, 8.0)
	cap_hours = minf(24.0, cap_hours)
	var clamped_seconds: float = clampf(elapsed_seconds, 0.0, cap_hours * 3600.0)
	var share: float = RemoteConfig.get_float("offline_rate") + clampf(automation_share, 0.0, 0.6)
	return floor(
		(
			rate_per_second
			* clamped_seconds
			* share
			* (1.0 + prestige_level * 0.05)
			* (1.0 + clampf(research_bonus, 0.0, 1.0))
		)
	)


func prestige_tokens(total_coins: float) -> int:
	# Realismo R$ 2.2x: denominador escalado 550k (antes 250k) para manter
	# pacing ~62h Lv120; com renda média 2.2x, total/250k daria tokens 1.48x
	# mais rápido. Garantia ajustada 44k (20k*2.2), bônus linear 11M (5M*2.2).
	# Agora: 44k→1, 550k→1, 2.2M→2, 8.8M→4, 22M→6, 55M→10, 220M→20 (D30 viável)
	var t: float = maxf(0.0, total_coins)
	var tokens: int = int(floor(sqrt(t / 550000.0)))
	if tokens == 0 and t >= 44000.0:
		tokens = 1
	tokens += int(floor(t / 11000000.0))
	return tokens
