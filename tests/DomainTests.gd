extends Node
## Testes de domínio no runtime REAL do jogo (autoloads instanciados pelo
## motor). Roda como cena, não como --script: o script de entrada do modo
## --script não resolve autoloads (Economy, GameState...) na compilação.
## Execute: godot --headless --path . res://tests/domain_tests.tscn

var failures: int = 0


func _ready() -> void:
	_test_bath_boundaries()
	_test_economy_invariants()
	_test_content_contract()
	_test_state_sanitization()
	_test_liveops_schedule()
	_test_rewards_and_missions()
	_test_save_migration()
	_test_prestige_and_research()
	_test_discovery()
	_test_contest()
	if failures == 0:
		print("Godot domain tests: PASS")
	else:
		push_error("Godot domain tests: %d failure(s)" % failures)
	get_tree().quit(failures)


func _test_bath_boundaries() -> void:
	var service: BathService = BathService.new()
	service.configure(6.0, 0.82, 0.96, 1000.0)
	service.start_service()
	service.progress = 0.61
	_expect(service.finish() == &"too_soon", "0.61 deve falhar cedo")

	service = BathService.new()
	service.configure(6.0, 0.82, 0.96, 1000.0)
	service.start_service()
	service.progress = 0.70
	_expect(service.finish() == &"good", "0.70 deve ser Good")

	service = BathService.new()
	service.configure(6.0, 0.82, 0.96, 1000.0)
	service.start_service()
	service.progress = 0.90
	_expect(service.finish() == &"perfect", "0.90 deve ser Perfect")

	service = BathService.new()
	service.configure(6.0, 0.82, 0.96, 1000.0)
	service.start_service()
	service.progress = 0.97
	_expect(service.finish() == &"overwashed", "0.97 deve falhar por excesso")


func _test_economy_invariants() -> void:
	var previous_cost: float = 0.0
	for level: int in 121:
		var cost: float = Economy.upgrade_cost(level)
		_expect(is_finite(cost) and cost >= previous_cost, "custo deve ser finito e monotônico")
		previous_cost = cost
	_expect(Economy.offline_earnings(1.0, -50.0, 0) == 0.0, "offline negativo deve ser zero")
	# Realismo R$ 2.2x: garantia de 1 token só a partir de 44k moedas acumuladas.
	_expect(Economy.prestige_tokens(10000.0) == 0, "prestígio precoce deve ser zero")
	_expect(Economy.prestige_tokens(44000.0) == 1, "44k garante o primeiro token")


func _test_content_contract() -> void:
	_expect(ContentDB.pets.size() == 50, "catálogo deve carregar 50 pets")
	_expect(ContentDB.has_pet("caramelo"), "Caramelo deve existir")
	_expect(ContentDB.establishment_for_level(120) == 10, "nível 120 deve abrir tier 10")


func _test_state_sanitization() -> void:
	(
		GameState
		. apply_dictionary(
			{
				"version": 5,
				"coins": -10,
				"player_level": 999,
				"player_xp": -5,
				"unlocked_pets": ["inexistente"],
				"settings": {"music": 9.0, "sfx": -2.0},
			}
		)
	)
	# Nível 999 → 120 destrava conquistas que pagam moedas no load; o que se
	# testa aqui é que o valor negativo nunca sobrevive (nunca fica < 0).
	_expect(GameState.coins >= 0.0, "moedas negativas devem ser reparadas")
	_expect(GameState.player_level == 120, "nível deve respeitar o cap")
	_expect(GameState.unlocked_pets.has("caramelo"), "save sem pet válido deve recuperar Caramelo")
	_expect(float(GameState.settings["music"]) == 1.0, "volume deve ser limitado")
	_expect(float(GameState.settings["sfx"]) == 0.0, "volume negativo deve ser limitado")


	GameState.apply_dictionary({"version": GameState.SAVE_VERSION, "coins": -10})
	_expect(GameState.coins == 0.0, "sem conquistas no load, moedas negativas viram zero")


func _test_liveops_schedule() -> void:
	for day: int in 7:
		_expect(not ContentDB.weekly_event_for(day).is_empty(), "agenda deve cobrir o dia %d" % day)
	_expect(LiveOps.modifier_multiplier(&"vip_frequency") >= 1.0, "modificador nunca reduz")
	_expect(LiveOps.event_goal_target() >= 0, "meta do dia não pode ser negativa")
	_expect(
		ContentDB.seasonal_for_month(6).get("cosmetic", "") == "wall_junina",
		"junho presenteia a parede de arraiá"
	)
	_expect(ContentDB.seasonal_for_month(9).is_empty(), "setembro não tem temporada")


func _test_rewards_and_missions() -> void:
	GameState.apply_dictionary(
		{"version": GameState.SAVE_VERSION, "player_level": 20, "bath_upgrade_level": 30}
	)
	var income: float = Rewards.income_per_second()
	_expect(income > 1.0, "renda estimada deve ser positiva com progresso")
	_expect(Rewards.scaled(60.0, 75) >= 75, "recompensa escalada respeita o piso")
	_expect(Rewards.scaled(60.0, 75) >= Rewards.scaled(30.0, 75), "mais segundos, mais moedas")
	_expect(Rewards.cosmetic_price("tub_pink") >= 300, "preço dinâmico nunca abaixo do catálogo")
	var roll_a: Array[String] = Missions.roll_for_day("2026-09-21", 20)
	var roll_b: Array[String] = Missions.roll_for_day("2026-09-21", 20)
	_expect(roll_a == roll_b, "sorteio diário deve ser determinístico por data")
	_expect(roll_a.size() == Missions.REGULAR_COUNT + 1, "3 regulares + épica")
	_expect(
		GameState.daily_mission_ids.size() >= Missions.REGULAR_COUNT,
		"GameState sorteia as diárias no load"
	)
	_expect(
		Missions.target_scale(1) == 1 and Missions.target_scale(50) == 3,
		"meta escala com o nível"
	)


func _test_save_migration() -> void:
	var legacy: Dictionary = {
		"version": 8, "coins": 1000, "player_level": 12, "prestige_level": 2, "tool_uses": {}
	}
	var migrated: Dictionary = SaveManager._migrate(legacy)
	_expect(
		int(migrated["version"]) == GameState.SAVE_VERSION,
		"migração deve chegar à versão atual"
	)
	var created: Array[String] = [
		"research_ids", "prestige_tokens_collected", "daily_mission_ids", "visitor_progress",
		"park_contest_pending", "guide_steps_done"
	]
	for key: String in created:
		_expect(migrated.has(key), "migração deve criar " + key)
	_expect(
		int(migrated["prestige_tokens_collected"]) == 2,
		"tokens coletados herdam o nº de prestígios"
	)


func _test_prestige_and_research() -> void:
	GameState.apply_dictionary(
		{
			"version": GameState.SAVE_VERSION,
			"coins": 5000,
			"total_coins": 6000000.0,
			"player_level": 20,
			"bath_upgrade_level": 40,
			"tool_upgrade_levels": {"soap": 8},
		}
	)
	_expect(GameState.prestige_tokens_available() == 3, "6M de moedas = 3 tokens (sqrt(6M/550k))")
	_expect(GameState.perform_prestige(), "prestígio deve ser possível")
	_expect(
		GameState.franchise_tokens == 3 and GameState.prestige_tokens_collected == 3,
		"tokens cumulativos"
	)
	_expect(GameState.prestige_tokens_available() == 0, "sem tokens em dobro após prestigiar")
	_expect(GameState.bath_upgrade_level == 10, "herança de 25% da estação")
	_expect(int(GameState.tool_upgrade_levels["soap"]) == 2, "herança de 25% das ferramentas")
	_expect(GameState.player_level == GameState.PRESTIGE_START_LEVEL, "recomeça no nível 10")
	_expect(GameState.coins >= 150.0, "caixa inicial da nova corrida")
	_expect(Research.can_buy("clean_water"), "tier 1 comprável com tokens")
	_expect(not Research.can_buy("fast_dryer"), "tier 2 exige pré-requisito")
	_expect(Research.buy("clean_water"), "compra de pesquisa")
	_expect(is_equal_approx(Research.bonus(&"bath_income"), 0.1), "efeito aplicado após a compra")
	_expect(GameState.franchise_tokens == 2, "token debitado")
	_expect(Research.can_buy("fast_dryer"), "pré-requisito satisfeito libera o tier 2")
	_expect(GameState.perform_prestige() == false, "sem tokens novos não há prestígio")
	_expect(
		Economy.offline_earnings(10.0, 3600.0, 0, 0.0, 0.3) > Economy.offline_earnings(10.0, 3600.0, 0),
		"equipe aumenta o cofre"
	)


func _test_discovery() -> void:
	GameState.apply_dictionary({"version": GameState.SAVE_VERSION, "player_level": 1})
	var candidate: String = Discovery.candidate()
	_expect(
		candidate != "" and not GameState.unlocked_pets.has(candidate),
		"próximo pet bloqueado visita"
	)
	_expect(
		int(ContentDB.pet(candidate).get("unlock_level", 1)) <= 1 + Discovery.LEVEL_WINDOW,
		"visitante dentro da janela"
	)
	for _i: int in Discovery.VISITS_TO_ADOPT - 1:
		_expect(not Discovery.register_service(candidate), "ainda não adotado")
	_expect(Discovery.register_service(candidate), "terceiro atendimento adota")
	_expect(GameState.unlocked_pets.has(candidate), "pet adotado entra na coleção")
	_expect(not GameState.visitor_progress.has(candidate), "progresso do visitante é limpo")


func _test_contest() -> void:
	GameState.apply_dictionary({"version": GameState.SAVE_VERSION, "player_level": 1})
	Contest.sync()
	_expect(GameState.park_contest_week == Contest.week_key(), "sync abre a semana corrente")
	_expect(GameState.park_contest_rivals.size() == Contest.RIVALS.size(), "3 rivais sorteados")
	_expect(Contest.rank() == 4, "sem votos = fora do pódio")
	var votes: int = Contest.register_walk("photo", true, true)
	_expect(votes >= Contest.VOTES_PERFECT_PHOTO, "foto perfeita vale ao menos 3 votos")
	_expect(GameState.park_contest_points == votes, "votos somam na semana")
	_expect(Contest.register_walk("ball", false, false) == 0, "passeio falho não pontua")
	_expect(Contest.rank() >= 1 and Contest.rank() <= 4, "colocação válida")
	_expect(Contest.seconds_to_close() > 0 and Contest.seconds_to_close() <= Contest.WEEK_SECONDS, "contagem até domingo")
	# Virada de semana: pontuação antiga vira resultado pendente e a nova semana zera.
	GameState.park_contest_week = Contest.week_key_for(int(Time.get_unix_time_from_system()) - Contest.WEEK_SECONDS)
	GameState.park_contest_points = 999
	Contest.sync()
	_expect(Contest.has_pending(), "virada de semana gera resultado pendente")
	_expect(int(GameState.park_contest_pending.get("rank", 4)) == 1, "999 votos vencem a capa")
	_expect(GameState.park_contest_points == 0, "nova semana começa zerada")
	var coins_before: float = GameState.coins
	var result: Dictionary = Contest.claim()
	_expect(not result.is_empty() and GameState.coins > coins_before, "prêmio da capa é pago")
	_expect(GameState.park_trophies == 1, "capa vira troféu")
	_expect(not Contest.has_pending(), "pendência limpa após coletar")
	_expect(GameState.park_contest_history.size() == 1 and Contest.best_rank() == 1, "histórico registra a capa")
	_expect(Contest.claim().is_empty(), "sem pendência não paga de novo")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
