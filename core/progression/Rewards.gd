class_name Rewards
extends RefCounted
## Recompensas e preços em "segundos de renda atual".
##
## Auditoria de retenção: as recompensas fixas (diária 75, semanal 400–600,
## streak 25×dia, level-up 20+5×nível) ficavam invisíveis após ~1h porque a
## renda por atendimento cresce exponencialmente (~840 aos 30 min, ~2.000 em
## 1h, ~38.000 em 20h). Aqui tudo é expresso em tempo de jogo: uma missão
## diária vale sempre "cerca de 4 atendimentos", em qualquer ponto da curva.
## O valor fixo do JSON vira piso (nunca paga menos que antes).
##
## A estimativa de renda é analítica (estado atual, sem medir o jogador):
## não dá para inflar guardando moedas nem "farmar" uma taxa recente.

## Duração média de um atendimento (mesma constante do career_sim.py).
const SERVICE_SECONDS: float = 14.5
## Segundos de renda por tipo de recompensa.
const SECONDS: Dictionary = {
	&"daily_mission": 60.0,
	&"weekly_mission": 480.0,
	&"weekly_chest": 900.0,
	&"pass_day": 90.0,
	&"streak_day": 30.0,
	&"level_up": 45.0,
	&"achievement": 240.0,
	&"return_bonus": 900.0,
	&"prestige_start": 60.0,
	&"event_goal": 600.0,
}
## Preços dinâmicos (segundos de renda) — sinks acompanham a curva.
const COSMETIC_SECONDS: float = 600.0
const HIRE_SECONDS: Dictionary = {
	"common": 300.0, "rare": 600.0, "epic": 1200.0, "legendary": 2400.0
}
## Ferramenta de cada serviço (para a média de bônus de ferramenta).
const SERVICE_TOOL: Dictionary = {
	"bath": "soap", "groom": "clipper", "dry": "dryer", "perfume": "perfume", "style": "bow"
}


## Serviços já destravados pelo nível (gates em data/service_layouts.json).
static func unlocked_services(level: int) -> Array[String]:
	var result: Array[String] = []
	for service: String in SERVICE_TOOL:
		var layout: Dictionary = ContentDB.service_layouts.get(service, {})
		if level >= int(layout.get("unlock_level", 1)):
			result.append(service)
	return result if not result.is_empty() else ["bath"]


## Renda estimada por segundo no estado atual (moedas/s). Usa a fórmula real
## de pagamento (Economy.service_reward) com qualidade Good e combo modesto —
## deliberadamente conservadora (~2/3 da renda observada de um bom jogador).
static func income_per_second() -> float:
	var services: Array[String] = unlocked_services(GameState.player_level)
	var base_sum: float = 0.0
	var tool_sum: float = 0.0
	for service: String in services:
		base_sum += SalonTuning.base_reward(StringName(service))
		tool_sum += float(GameState.tool_upgrade_levels.get(String(SERVICE_TOOL[service]), 0))
	var count: float = float(services.size())
	var per_service: float = Economy.service_reward(
		base_sum / count,
		&"good",
		GameState.bath_upgrade_level,
		6,
		int(tool_sum / count),
		GameState.prestige_level
	)
	return maxf(per_service, 1.0) / SERVICE_SECONDS


## Moedas equivalentes a `seconds` de renda, nunca abaixo de `minimum`.
## Escala remota (RemoteConfig.reward_scale) permite LiveOps ajustar sem build.
static func scaled(seconds: float, minimum: int = 0) -> int:
	var scale: float = RemoteConfig.get_float("reward_scale")
	if scale <= 0.0:
		scale = 1.0
	return maxi(minimum, int(roundf(income_per_second() * seconds * scale)))


## Recompensa de um tipo (ver SECONDS) com piso.
static func for_kind(kind: StringName, minimum: int = 0) -> int:
	return scaled(float(SECONDS.get(kind, 60.0)), minimum)


## Moedas do dia N do passe (piso = JSON); cresce com o dia.
static func pass_day_coins(day: int) -> int:
	var reward: Dictionary = ContentDB.pass_day(day)
	if not reward.has("coins"):
		return 0
	return scaled(float(SECONDS[&"pass_day"]) + 10.0 * day, int(reward["coins"]))


## Preço em moedas de um cosmético: piso do catálogo ou ~10 min de renda.
## Escala remota permite ajustar sink sem novo build (cosmetic_price_scale).
static func cosmetic_price(cosmetic_id: String) -> int:
	var price: Dictionary = ContentDB.cosmetic(cosmetic_id).get("price", {})
	if not price.has("coins"):
		return 0
	var base: int = scaled(COSMETIC_SECONDS, int(price.get("coins", 0)))
	var scale: float = RemoteConfig.get_float("cosmetic_price_scale")
	if scale <= 0.0:
		scale = 1.0
	return int(roundf(base * scale))


## Preço de contratação: piso por raridade (HIRE_COSTS) ou minutos de renda.
static func hire_price(staff_id: String, floor_cost: int) -> int:
	var rarity: String = String(ContentDB.staff(staff_id).get("rarity", "common"))
	var base: int = scaled(float(HIRE_SECONDS.get(rarity, 300.0)), floor_cost)
	var scale: float = RemoteConfig.get_float("hire_price_scale")
	if scale <= 0.0:
		scale = 1.0
	return int(roundf(base * scale))


## Fração da renda ativa que a equipe contratada produz sozinha
## (staff.json "automation"): renda passiva em jogo e taxa do cofre offline.
static func automation_share() -> float:
	var total: float = 0.0
	for staff_id: String in GameState.hired_staff:
		total += float(ContentDB.staff(staff_id).get("automation", 0.0))
	return clampf(total, 0.0, 0.6)


## Renda passiva por segundo (equipe trabalhando enquanto você joga).
static func passive_income_per_second() -> float:
	var share: float = automation_share()
	return income_per_second() * share if share > 0.0 else 0.0
