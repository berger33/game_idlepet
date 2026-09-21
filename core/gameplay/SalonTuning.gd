class_name SalonTuning
extends RefCounted
## Ajuste do jogo segundo o PET e o progresso do jogador (ondas 1–3 do
## DESIGN_ENGAJAMENTO): cada serviço tem gesto próprio, e temperamento,
## espécie, porte e marcos de maestria calibram o BathService DEPOIS do
## configure(). Tudo estático, sem estado: o Main é quem aplica.

## Gestos distintos por serviço: cada mecânica tem identidade própria em vez
## do mesmo "esfregar até encher".
##   rub = dosagem clássica | stroke = traçado direcionado (setas)
##   zone = acompanhar o círculo | pulse = borrifadas no ritmo | drop = encaixe
const GESTURES: Dictionary = {
	&"bath": {"axis": &"any", "mode": &"rub", "cap": 90.0, "rate": 0.0},
	&"groom": {"axis": &"vertical", "mode": &"stroke", "cap": 70.0, "rate": 0.0},
	&"dry": {"axis": &"any", "mode": &"zone", "cap": 70.0, "rate": 0.30},
	&"perfume": {"axis": &"any", "mode": &"pulse", "cap": 90.0, "rate": 0.0},
	&"style": {"axis": &"any", "mode": &"drop", "cap": 90.0, "rate": 0.0},
}
const AGITATED_TEMPERAMENTS: Array[StringName] = [&"active", &"irritated", &"curious"]
const PLAYFUL_TEMPERAMENTS: Array[StringName] = [&"playful", &"happy"]
const CALM_TEMPERAMENTS: Array[StringName] = [&"calm", &"gentle", &"elegant"]
const TEMPERAMENT_LABELS: Dictionary = {
	&"active": "agitado", &"irritated": "agitado", &"curious": "agitado",
	&"calm": "calmo", &"gentle": "calmo", &"elegant": "calmo",
	&"playful": "brincalhão", &"happy": "brincalhão",
	&"anxious": "tímido", &"fearful": "tímido",
}
const SMALL_BREEDS: Array[String] = [
	"Pinscher", "Yorkshire", "Pug", "Maltês", "Munchkin", "Shih-tzu",
]
const LARGE_BREEDS: Array[String] = ["Golden", "Labrador", "Samoieda", "Bernês", "Maine Coon"]
## Marcos de maestria por usos da ferramenta (C2): 1/2/3 selos.
const TOOL_MASTERY_STEPS: Array[int] = [100, 500, 2000]
## Posto de raridade para o viés da "Quinta do Pet Raro": peso = viés^posto.
const RARITY_RANK: Dictionary = {
	&"common": 0, &"uncommon": 1, &"rare": 2, &"epic": 3, &"legendary": 4
}
## Pagamento base por serviço (banho vem do RemoteConfig: bath_base_reward).
const BASE_REWARDS: Dictionary = {&"groom": 20.0, &"dry": 24.0, &"perfume": 30.0, &"style": 38.0}
## Teto de VIPs na fila mesmo com evento (VIP tem menos paciência; a fila
## inteira VIP viraria punição, não festa).
const VIP_CHANCE_CAP: float = 0.5
const GESTURE_HINTS: Dictionary = {
	&"bath": "HINT_BATH",
	&"groom": "HINT_GROOM",
	&"dry": "HINT_DRY",
	&"perfume": "HINT_PERFUME",
	&"style": "HINT_STYLE",
}


## Aplica identidade de gesto + temperamento + espécie + marcos + recuperação.
## `body_center` é o foco do pet no mundo (fallback quando o mundo não existe).
static func apply(
	bath: BathService,
	service: StringName,
	profile: Dictionary,
	levels: Dictionary,
	recovery_penalty: bool,
	body_center: Vector2
) -> void:
	# --- Onda 1: gesto com identidade própria por serviço ---
	match service:
		&"groom":
			# Tosa: traçado direcionado — a sequência de setas deriva do pet.
			bath.configure_strokes(
				stroke_axes_for(String(profile.get("id", ""))), 520.0 * breed_size_factor(profile)
			)
		&"dry":
			# Secação: acompanhar o círculo que deriva (raças pequenas derivam mais).
			bath.configure_zone(body_center, 112.0, 1.2 if breed_size_factor(profile) < 1.0 else 1.0)
		&"perfume":
			bath.configure_pulses(3, 1.35, 0.45)
		&"style":
			# Laço: encaixe de precisão na marca do pescoço.
			bath.configure_drop(body_center + Vector2(0.0, -74.0), 112.0, 0.5)
	# --- A2: temperamento e espécie mudam o jogo ---
	var temperament: StringName = StringName(profile.get("temperament", "happy"))
	var species: StringName = StringName(profile.get("species", "dog"))
	var window_shift: float = 0.0
	if temperament in AGITATED_TEMPERAMENTS:
		window_shift += 0.03
		bath.configure_temperament(1.0, -1.0)
	elif temperament in PLAYFUL_TEMPERAMENTS:
		bath.configure_temperament(0.0, 4.0)
	elif temperament in CALM_TEMPERAMENTS:
		window_shift -= 0.05
		bath.configure_temperament(0.0, -1.0)
	if species == &"cat":
		# Gato odeia água, mas aceita tosa/laço de bom grado.
		window_shift += 0.02 if service == &"bath" else -0.04
	bath.target_minimum = clampf(
		bath.target_minimum + window_shift, BathService.GOOD_FLOOR, 0.95
	)
	# --- C1: marcos de maestria — upgrades que mudam a ação ---
	var tool: StringName = StringName(
		{"bath": "soap", "groom": "clipper", "dry": "dryer", "style": "bow"}.get(service, "")
	)
	if tool != &"" and int(levels.get(String(tool), 0)) >= milestone_level(tool):
		match tool:
			&"soap":
				# Sabonete espumante: janela perfeita 30% mais larga.
				bath.target_minimum = BathService.GOOD_FLOOR + 0.7 * (
					bath.target_minimum - BathService.GOOD_FLOOR
				)
			&"clipper":
				bath.stroke_quota *= 0.85
			&"dryer":
				bath.zone_speed *= 0.7
				bath.hold_rate = clampf(bath.hold_rate * 1.5, 0.0, 0.5)
			&"bow":
				bath.drop_radius *= 1.4
	# --- A3: exagero (overwashed) estreita a próxima janela até um acerto ---
	if recovery_penalty:
		bath.target_minimum = clampf(
			bath.target_minimum + 0.04, BathService.GOOD_FLOOR, 0.95
		)
	# --- Pesquisa da franquia (research.json): meta permanente comprada com
	# tokens de prestígio. Paciência = mais tempo; satisfação = janela de
	# Perfect mais larga; velocidade = menos gesto para encher (todos os modos).
	bath.duration_seconds *= 1.0 + Research.bonus(&"patience")
	bath.target_maximum = minf(bath.target_maximum + Research.bonus(&"satisfaction"), 1.0)
	var speed: float = clampf(Research.bonus(&"service_speed"), 0.0, 0.5)
	if speed > 0.0:
		bath.distance_required *= 1.0 - speed
		bath.stroke_quota *= 1.0 - speed
		bath.hold_rate = clampf(bath.hold_rate * (1.0 + speed), 0.0, 0.5)


## Nível do marco que destrava o bônus da ferramenta (C1).
static func milestone_level(_tool: StringName) -> int:
	return 10 if _tool != &"dryer" else 20


## Sequência de setas da tosa: determinística por pet (o jogador aprende
## o "desenho" do traçado de cada cliente).
static func stroke_axes_for(pet_id: String) -> Array[StringName]:
	var seed_hash: int = pet_id.hash()
	var axes: Array[StringName] = []
	for i: int in 3:
		axes.append(&"vertical" if ((seed_hash >> (i * 3)) & 1) == 0 else &"horizontal")
	return axes


static func breed_size_factor(profile: Dictionary) -> float:
	var breed: String = String(profile.get("breed", ""))
	for needle: String in LARGE_BREEDS:
		if breed.contains(needle):
			return 1.15
	for needle: String in SMALL_BREEDS:
		if breed.contains(needle):
			return 0.9
	return 1.0


## Linha de trade-offs do cartão da fila (B1): temperamento + pagamento.
static func queue_info_text(profile: Dictionary) -> String:
	var temperament: StringName = StringName(profile.get("temperament", "happy"))
	var temperament_text: String = String(TEMPERAMENT_LABELS.get(temperament, ""))
	var tip: float = float(profile.get("base_tip", 1.0))
	var pay_pips: String = "●" if tip < 1.4 else ("●●" if tip < 2.2 else "●●●")
	return "%s  paga %s" % [temperament_text, pay_pips]


## Borda do cartão pela raridade do pet (B1): leitura instantânea do valor.
static func queue_border(profile: Dictionary) -> Dictionary:
	var rarity: StringName = StringName(profile.get("rarity", "common"))
	var color: Color = {
		&"common": Color("90a4ae"), &"uncommon": Color("7ed957"), &"rare": Color("4fc3f7"),
		&"epic": Color("ce93d8"), &"legendary": Color("ffd54f"),
	}. get(rarity, Color("f48fb1"))
	return {"color": color, "width": 5 if rarity != &"common" else 3}



## Instrução localizada do gesto do serviço.
static func hint(service: StringName) -> String:
	return Loc.t(String(GESTURE_HINTS.get(service, GESTURE_HINTS[&"bath"])))


## Som de feedback por serviço.
static func service_sound(service: StringName) -> StringName:
	return (
		{
			&"bath": &"bubble",
			&"groom": &"clipper",
			&"dry": &"dryer",
			&"perfume": &"spray",
			&"style": &"bow",
		}
		. get(service, &"bubble")
	)


## Nome de exibição da ferramenta (tutorial e toasts).
static func tool_display_name(tool: StringName) -> String:
	return (
		{
			&"soap": "o sabonete",
			&"clipper": "a máquina de tosa",
			&"dryer": "o secador",
			&"perfume": "o perfume",
			&"bow": "o lacinho",
		}
		. get(tool, "o utensílio")
	)


## Recompensa total de um atendimento (bônus de bairro + evento + carinho +
## gorjeta + VIP + buddy + maestria + pedido especial). `rand` é o roll da
## gorjeta (passado pelo Main para manter o random global do jogo).
static func compute_reward(ctx: Dictionary) -> Dictionary:
	var service: StringName = ctx["service"]
	var quality: StringName = ctx["quality"]
	var base_reward: float = base_reward(service)
	var affection: int = int(GameState.pet_affection.get(String(ctx["pet_id"]), 0))
	var affection_multiplier: float = 1.0 + minf(50.0, affection) * 0.005
	var tip_multiplier: float = (
		Economy.tip_multiplier(float(ctx["rand"]))
		* (1.0 + Economy.tip_bonus(GameState.reviews_sum))
	)
	# Pico do bairro (B3): gorjetas multiplicadas durante o rush.
	if bool(ctx["rush"]):
		tip_multiplier *= RemoteConfig.get_float("rush_tip_mult")
	var vip_multiplier: float = Economy.VIP_REWARD_MULTIPLIER if bool(ctx["vip"]) else 1.0
	# Banheira dupla (C1): o buddy é atendido em paralelo (+40%).
	var buddy_multiplier: float = 1.4 if bool(ctx["buddy"]) else 1.0
	var mastery_multiplier: float = 1.0 + float(ctx["mastery"])
	# Pesquisa "Água Purificada" (research.json): banho rende +10% para sempre.
	var research_multiplier: float = 1.0
	if service == &"bath":
		research_multiplier += Research.bonus(&"bath_income")
	var reward: float = (
		Economy
		. service_reward(
			base_reward,
			quality,
			GameState.bath_upgrade_level,
			GameState.combo,
			int(ctx["tool_level"]),
			GameState.prestige_level,
		)
		* LiveOps.multiplier_for(service)
		* LiveOps.bonus_for_quality(quality)
		* affection_multiplier
		* tip_multiplier
		* vip_multiplier
		* buddy_multiplier
		* mastery_multiplier
		* research_multiplier
		* float(ctx["special"])
	)
	return {"reward": reward, "tip_percent": int(roundf((tip_multiplier - 1.0) * 100.0))}


## Pagamento base de cada serviço (fonte única: pagamento real e estimativa
## de renda em Rewards.income_per_second).
static func base_reward(service: StringName) -> float:
	if service == &"bath":
		return RemoteConfig.get_float("bath_base_reward")
	return float(BASE_REWARDS.get(service, 12.0))


## Sorteio de um cliente da fila: pet desbloqueado (buddy tem prioridade),
## serviço (evento do dia pesa), VIP, paciência e pedido especial (B2).
static func make_client(services: Array[StringName]) -> Dictionary:
	var unlocked: Array[String] = GameState.unlocked_pets
	if unlocked.is_empty():
		unlocked = ["caramelo"]
	# Quinta do Pet Raro (events.json rare_chance): raridades altas pesam mais.
	var rare_bias: float = LiveOps.modifier_multiplier(&"rare_chance")
	var pet_id: String = draw_pet(unlocked, rare_bias)
	if rare_bias > 1.0 and rarity_rank(pet_id) >= 2:
		Analytics.track(&"event_client", {"rare_pet": pet_id})
	# O pet preferido (buddy) visita com prioridade: 25% + até 15% pelo afeto
	# (antes 40% fixo: o mesmo pet dominava a fila e a coleção perdia novidade).
	var buddy_affection: float = float(GameState.pet_affection.get(GameState.favorite_pet, 0))
	var buddy_chance: float = 0.25 + 0.15 * clampf(buddy_affection / 50.0, 0.0, 1.0)
	if pet_id != GameState.favorite_pet and randf() < buddy_chance:
		pet_id = GameState.favorite_pet
		Analytics.track(&"buddy_spawned", {"pet_id": pet_id})
	# Visitante misterioso (Discovery): o próximo pet da carreira aparece antes
	# do nível dele; 3 atendimentos o adotam.
	var visitor: String = Discovery.roll_visitor()
	var is_visitor: bool = not visitor.is_empty()
	if is_visitor:
		pet_id = visitor
		Analytics.track(&"visitor_spawned", {"pet_id": pet_id})
	var service: StringName = services[randi() % services.size()]
	# A fila segue o evento do dia: no dia temático, metade dos clientes
	# chega com o serviço em destaque — o evento se sente andando pela porta.
	var featured: StringName = LiveOps.featured_service()
	if featured != &"" and featured in services and service != featured and randf() < 0.5:
		service = featured
		Analytics.track(&"event_client", {"service": String(service)})
	# Sexta do VIP (events.json vip_frequency): VIPs em dobro, com teto.
	var vip_chance: float = minf(
		VIP_CHANCE_CAP,
		Economy.vip_chance(GameState.reviews_sum) * LiveOps.modifier_multiplier(&"vip_frequency")
	)
	var vip: bool = randf() < vip_chance
	var wait_total: float = randf_range(60.0, 90.0) * (0.7 if vip else 1.0)
	# B2: pedido especial (upsell) — a preferência do pet tem prioridade.
	var special: StringName = &""
	if randf() < RemoteConfig.get_float("upsell_chance") and services.size() > 1:
		var candidates: Array[StringName] = []
		for candidate: StringName in services:
			if candidate != service:
				candidates.append(candidate)
		if not candidates.is_empty():
			var preferred: StringName = StringName(
				ContentDB.pet(pet_id).get("preferred_service", "bath")
			)
			special = (
				preferred if candidates.has(preferred) else candidates[randi() % candidates.size()]
			)
	return {
		"pet": pet_id,
		"service": service,
		"vip": vip,
		"visitor": is_visitor,
		"special": special,
		"wait_total": wait_total,
		"wait_left": wait_total,
	}


static func rarity_rank(pet_id: String) -> int:
	return int(RARITY_RANK.get(StringName(ContentDB.pet(pet_id).get("rarity", "common")), 0))


## Sorteio ponderado por raridade: peso = bias^posto (bias 1.0 = uniforme).
## Com 1.5 na quinta, um lendário pesa ~5× um comum — a fila brilha mais sem
## virar só lendários (a loteria continua entre todos os desbloqueados).
static func draw_pet(unlocked: Array[String], bias: float) -> String:
	if unlocked.is_empty():
		return "caramelo"
	if bias <= 1.0:
		return unlocked[randi() % unlocked.size()]
	var weights: Array[float] = []
	var total: float = 0.0
	for pet_id: String in unlocked:
		var weight: float = pow(bias, rarity_rank(pet_id))
		weights.append(weight)
		total += weight
	var roll: float = randf() * total
	for index: int in unlocked.size():
		roll -= weights[index]
		if roll <= 0.0:
			return unlocked[index]
	return unlocked[unlocked.size() - 1]


## Bônus de maestria no pagamento (C2): +2% por selo (até +6%).
static func mastery_bonus(uses: int) -> float:
	var badges: int = 0
	for step: int in TOOL_MASTERY_STEPS:
		if uses >= step:
			badges += 1
	return badges * 0.02
