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
	_test_tutorial_ux()
	_test_regressoes_auditoria_2026_09_27()
	_test_regressoes_auditoria_2026_09_27_v2()
	_test_regressoes_auditoria_v3()
	_test_save_transfer_code()
	_test_park_activities()
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


func _test_tutorial_ux() -> void:
	# T-01: artigo variável por gênero da ferramenta nos 3 idiomas.
	var lang_before: String = Loc.lang
	Loc.lang = "pt_BR"
	_expect(SalonTuning.tool_with_article(&"clipper").begins_with("a "), "pt: 'a máquina de tosa'")
	_expect(SalonTuning.tool_with_article(&"soap").begins_with("o "), "pt: 'o sabonete'")
	Loc.lang = "es_ES"
	_expect(SalonTuning.tool_with_article(&"clipper").begins_with("la "), "es: 'la máquina'")
	_expect(SalonTuning.tool_with_article(&"bow").begins_with("el "), "es: 'el lazo'")
	Loc.lang = "en_US"
	_expect(SalonTuning.tool_with_article(&"clipper").begins_with("the "), "en: 'the clippers'")
	# T-01: textos do guia neutros de gênero do pet (Luna/Mel/Amora…).
	for code: String in ["pt_BR", "en_US", "es_ES"]:
		Loc.lang = code
		var queue_txt: String = Loc.t("GUIDE_QUEUE")
		_expect(not queue_txt.contains("chamá-lo"), code + ": sem 'chamá-lo'")
		_expect(not queue_txt.contains("call him"), code + ": sem 'call him'")
		_expect(not queue_txt.contains("llamarlo"), code + ": sem 'llamarlo'")
		var wrong_txt: String = Loc.t("GUIDE_WRONG_TOOL")
		_expect(not wrong_txt.contains("ele precisa"), code + ": sem 'ele precisa'")
		_expect(not wrong_txt.contains("he needs"), code + ": sem 'he needs'")
		# %s do GUIDE_TOOL: artigo-ferramenta + pet (2 placeholders).
		var tool_txt: String = Loc.t("GUIDE_TOOL")
		_expect(tool_txt.count("%s") == 2, code + ": GUIDE_TOOL com 2 placeholders")
		_expect(Loc.t("DRAG_TOOL_TO").count("%s") == 2, code + ": DRAG_TOOL_TO com 2 placeholders")
	# T-02: chaves de confirmação de skip e replay presentes.
	for key: String in ["SKIP_CONFIRM_TAP", "REPLAY_TUTORIAL", "REPLAY_TUTORIAL_GO", "TUTORIAL_REPLAYED"]:
		_expect(Loc.t(key) != key, "chave localizada ausente: " + key)
	# T-02/T-03: contratos no código do fluxo.
	_expect(TutorialFlow.STEP_NAMES.size() == TutorialFlow.STEP_COUNT, "STEP_NAMES cobre os 4 passos")
	_expect(TutorialFlow.STEP_NAMES == ["welcome", "queue", "tool", "gesture"], "nomes estáveis do funil")
	# P2: "serviço ensinado" só é gravado depois de show_guide em teach_service.
	var tutorial_src: String = FileAccess.get_file_as_string("res://scenes/main/TutorialFlow.gd")
	var show_at: int = tutorial_src.find("func teach_service")
	var save_at: int = tutorial_src.find("taught.append", show_at)
	var guide_at: int = tutorial_src.find("show_guide", show_at)
	_expect(guide_at > 0 and save_at > guide_at, "services_taught gravado após exibir a fala")
	_expect(TutorialFlow.STEP_COUNT == 4, "tutorial segue 4 passos")
	Loc.lang = lang_before


## Regressões da auditoria universal de 2026-09-27.
func _test_regressoes_auditoria_2026_09_27() -> void:
	# 1) active_cosmetics: o save escreve, o load TEM que restaurar (antes
	#    apply_dictionary ignorava a chave e o pet voltava sem acessórios).
	var cosmetics_save: Dictionary = {
		"version": GameState.SAVE_VERSION,
		"unlocked_cosmetics": ["tub_pink", "crown_bubbles"],
		"active_cosmetics": {
			"bath": "tub_pink",
			"pet_accessory": "crown_bubbles",
			"wall": "nao_possuido",
		},
	}
	GameState.apply_dictionary(cosmetics_save)
	var bath_slot: String = String(GameState.active_cosmetics.get("bath", ""))
	_expect(bath_slot == "tub_pink", "load deve restaurar cosmético equipado")
	var accessory_slot: String = String(GameState.active_cosmetics.get("pet_accessory", ""))
	_expect(accessory_slot == "crown_bubbles", "load deve restaurar acessório do pet")
	_expect(not GameState.active_cosmetics.has("wall"), "cosmético não possuído não sobrevive ao load")
	# round-trip completo: to_dictionary -> apply_dictionary preserva o equipado
	var snapshot: Dictionary = GameState.to_dictionary()
	GameState.active_cosmetics = {}
	GameState.apply_dictionary(snapshot)
	var roundtrip_slot: String = String(GameState.active_cosmetics.get("bath", ""))
	_expect(roundtrip_slot == "tub_pink", "round-trip do save preserva active_cosmetics")
	# 2) AdsPolicy: cap/cooldown precisam voltar persistidos (antes a política
	#    era carregada mas nunca escrita de volta em GameState.ads_policy).
	AdsManager.on_rewarded_completed(&"audit_test")
	var rewarded_today: int = int(GameState.ads_policy.get("rewarded_today", 0))
	_expect(rewarded_today >= 1, "rewarded deve persistir a política de ads no estado")
	AdsManager.record_purchase_for_policy()
	var purchased_recently: bool = bool(GameState.ads_policy.get("purchased_recently", false))
	_expect(purchased_recently, "compra recente deve persistir na política de ads")


## Regressões da 2ª passada da auditoria universal (2026-09-27): QR quebrado e
## strings de localização formatadas com `%` inválido.
func _test_regressoes_auditoria_2026_09_27_v2() -> void:
	# 1) QR: o vetor abaixo é a matriz de referência (v2, ECC L, máscara 0) para
	#    o payload abaixo, idêntica à do gerador de referência ISO/IEC 18004
	#    (qrcode/Nayuki). Antes das correções desta auditoria a matriz divergia
	#    em ~184/625 módulos e NENHUM leitor decodificava (GF(256) com LOG[1]
	#    errado, zigzag em ordem trocada, módulos de formato liberados e
	#    format info transposto).
	var payload: String = "https://p.tycoon/a/first_bath"
	var matrix: Array = QRCodeArt.generate_matrix(payload)
	_expect(matrix.size() == 25, "QR v2 deve ter 25 módulos de lado")
	var reference_rows: PackedStringArray = [
		"1111111001101011001111111",
		"1000001000110101101000001",
		"1011101011101001001011101",
		"1011101001100000001011101",
		"1011101000110111101011101",
		"1000001001010011001000001",
		"1111111010101010101111111",
		"0000000011111110100000000",
		"1110111110100101111000100",
		"1011000010101100111100001",
		"0110101111000100010010111",
		"1101010100010100111100010",
		"0010001100001101111101011",
		"0011010110001000101001001",
		"1010101011101010011100111",
		"0100010000000110110010010",
		"1001111010101101111111000",
		"0000000011101111100011011",
		"1111111010000111101011011",
		"1000001011101100100011000",
		"1011101011110100111111010",
		"1011101000111110100111100",
		"1011101011101110110010001",
		"1000001010111111111011010",
		"1111111010100101111100011",
	]
	if matrix.size() == 25:
		for y: int in 25:
			var row: String = ""
			for x: int in 25:
				row += str(int(matrix[y][x]))
			_expect(row == reference_rows[y], "QR linha %d divergiu da referência" % y)
	# 2) PRESTIGE_DONE tinha "%" literal sem escape e o operador % do Godot
	#    devolve erro ("unsupported format character") → toast de prestígio
	#    quebrado nos 3 idiomas.
	var prestige_txt = Loc.t("PRESTIGE_DONE") % 1
	_expect(prestige_txt is String and String(prestige_txt).contains("%"), "PRESTIGE_DONE precisa formatar com o % escapado")
	# 3) Nó de pesquisa com efeito sem placeholder ("proteção de combo") não
	#    pode passar pelo operador % (erro "not all arguments converted").
	var combo_text: String = Research.effect_text("combo_shield")
	_expect(not combo_text.is_empty() and combo_text.to_lower().contains("combo"), "effect_text do Escudo de Combo deve render")


## Regressões da 3ª passada (i18n, boot do idioma, parser CSV).
func _test_regressoes_auditoria_v3() -> void:
	# 1) Parser CSV do Loc: vírgula citada, aspas escapadas, \n e header.
	var sample: String = "key,pt_BR\nA,\"olá, mundo\"\nB,simples\nC,\"l1\\nl2\"\nD,\"aspas \"\"internas\"\"\"\nE,\n"
	var table: Dictionary = Loc.parse_csv(sample)
	_expect(String(table.get("A", "")) == "olá, mundo", "CSV: vírgula entre aspas deve sobreviver")
	_expect(String(table.get("B", "")) == "simples", "CSV: valor simples")
	_expect(String(table.get("C", "")) == "l1\nl2", "CSV: \\n vira quebra de linha real")
	_expect(String(table.get("D", "")) == "aspas \"internas\"", "CSV: aspas duplas escapadas")
	_expect(table.has("E") and String(table["E"]) == "", "CSV: valor vazio é válido")
	_expect(not table.has("key"), "CSV: header não entra na tabela")
	# 2) As 3 tabelas carregam com o mesmo número de chaves (paridade real).
	var sizes: Array[int] = []
	for code: String in Loc.LANGS:
		sizes.append((Loc.tables.get(code, {}) as Dictionary).size())
	_expect(sizes.size() == 3 and sizes[0] > 600, "tabelas de idioma carregadas")
	_expect(sizes[0] == sizes[1] and sizes[1] == sizes[2], "paridade de chaves entre idiomas: " + str(sizes))
	# 3) Idioma salvo é aplicado ao carregar o save (antes só valia depois de
	#    abrir Ajustes, porque o Loc lê o idioma antes do SaveManager).
	Loc.lang = "pt_BR"
	GameState.apply_dictionary({"version": GameState.SAVE_VERSION, "settings": {"language": "en_US"}})
	_expect(Loc.lang == "en_US", "load do save deve aplicar o idioma salvo")
	GameState.apply_dictionary({"version": GameState.SAVE_VERSION, "settings": {"language": "pt_BR"}})
	_expect(Loc.lang == "pt_BR", "troca de volta do idioma")
	# Chave inexistente cai no pt_BR e não devolve o identificador cru quando
	# existir em qualquer outro idioma.
	_expect(Loc.t("COINS") != "COINS", "chave conhecida resolve")
	_expect(Loc.t("CHAVE_QUE_NAO_EXISTE_XYZ") == "CHAVE_QUE_NAO_EXISTE_XYZ", "chave desconhecida volta crua")


	# 4) RENDER do QR (B6.5): zona de silêncio de 4 módulos, célula inteira e
	#    cada módulo desenhado no lugar certo. O desenho antigo começava no
	#    pixel 0 (sem margem) e o OpenCV não decodificava a imagem final.
	var reference: Array = QRCodeArt.generate_matrix("https://p.tycoon/a/first_bath")
	_expect(reference.size() == 25, "render: matriz v2 de referência")
	var img: Image = QRCodeArt.generate_image("https://p.tycoon/a/first_bath", 220)
	var side: int = img.get_width()
	_expect(img.get_height() == side, "render: imagem quadrada")
	_expect(side % 33 == 0, "render: (25 módulos + 8 de silêncio) * célula inteira")
	var cell: int = side / 33
	_expect(cell >= 5, "render: célula de pelo menos 5 px")
	var border_white: bool = true
	for i: int in range(4 * cell):
		if img.get_pixel(i, 0) != Color.WHITE or img.get_pixel(0, i) != Color.WHITE:
			border_white = false
	_expect(border_white, "render: 4 módulos de zona de silêncio no topo/esquerda")
	var mismatches: int = 0
	for y: int in reference.size():
		for x: int in reference.size():
			var px: Color = img.get_pixel((x + 4) * cell + cell / 2, (y + 4) * cell + cell / 2)
			var expected: Color = Color.BLACK if int(reference[y][x]) == 1 else Color.WHITE
			if px != expected:
				mismatches += 1
	_expect(mismatches == 0, "render: módulo a módulo igual à matriz (%d divergências)" % mismatches)
	# 5) Share: o QR do cartão é desenhado 1:1 (reescalar borraria os módulos).
	var share_src: String = FileAccess.get_file_as_string("res://autoload/ShareManager.gd")
	_expect(share_src.count("custom_minimum_size = Vector2(qr_side, qr_side)") == 1
		and share_src.count("custom_minimum_size = Vector2(qr_side2, qr_side2)") == 1,
		"cartões de banho e conquista usam o lado real da imagem")


## Código de transferência (export/import): sem cloud save, é o único caminho de
## migrar progresso entre aparelhos — precisa restaurar e recusar adulteração.
func _test_save_transfer_code() -> void:
	GameState.apply_dictionary({"version": GameState.SAVE_VERSION})
	GameState.coins = 1234.0
	GameState.player_level = 7
	GameState.pet_affection["caramelo"] = 4
	var code: String = SaveManager.export_code()
	_expect(code.length() > 40, "código de transferência gerado")
	GameState.coins = 0.0
	GameState.player_level = 1
	GameState.pet_affection["caramelo"] = 0
	_expect(SaveManager.import_code(code), "import do próprio código funciona")
	# O load reavalia conquistas e as de limiar PAGAM moedas (earn_500 = +50),
	# então o valor restaurado é >= o exportado — comportamento correto.
	var restored: float = GameState.coins
	_expect(restored >= 1234.0, "moedas restauradas pelo código (conquistas podem somar)")
	_expect(GameState.player_level == 7, "nível restaurado pelo código")
	_expect(int(GameState.pet_affection.get("caramelo", 0)) == 4, "afeto restaurado pelo código")
	_expect(not SaveManager.import_code("isso-nao-e-um-save"), "código inválido é recusado")
	# Segunda volta: com as conquistas já desbloqueadas o valor é exato — prova
	# que o envelope carrega as moedas sem perda.
	var code2: String = SaveManager.export_code()
	GameState.coins = 0.0
	_expect(SaveManager.import_code(code2), "segundo import funciona")
	_expect(is_equal_approx(GameState.coins, restored), "round-trip exato (sem prêmio novo)")
	# Adulteração: o envelope é XOR + base64, então mexe no meio da string.
	var index: int = code2.length() / 3
	var original: String = code2.substr(index, 1)
	_expect(not original.is_empty(), "código tem conteúdo")
	var tampered: String = code2.substr(0, index) + ("A" if original != "A" else "B") + code2.substr(index + 1)
	_expect(not SaveManager.import_code(tampered), "código adulterado é recusado")


## Parquinho: as 3 atividades decidem recompensa por conta própria — o resultado
## (perfect/good/fail) é contrato de economia e precisa de teste determinístico.
func _test_park_activities() -> void:
	# Bola: arrastar até o pet acumula progresso e fetch; 60 arrastos = perfect.
	var park: ParkService = ParkService.new()
	park.configure(&"ball")
	_expect(park.activity == ParkService.Activity.BALL, "configure reconhece a atividade")
	park.start()
	var pet_focus: Vector2 = Vector2(540, 1050)
	for i: int in 60:
		park.drag_ball(pet_focus + Vector2(float(i % 5) * 4.0, 0.0), pet_focus)
	_expect(park.progress > 0.95 and park.fetch_count >= 3, "bola: progresso e fetches acumulados")
	_expect(park.finish() == &"perfect", "bola: 60 arrastos rende perfect")
	# Longe do pet não acumula: o progresso cai.
	park = ParkService.new()
	park.configure(&"ball")
	park.start()
	park.drag_ball(Vector2(50, 50), pet_focus)
	_expect(park.progress < 0.02, "bola: arrasto longe do pet não pontua")
	# Tempo esgotado falha a atividade (sem punir a fila — estado próprio).
	park = ParkService.new()
	park.configure(&"ball")
	park.start()
	_expect(park.tick(park.duration + 1.0) and park.state == ParkService.State.FAILED,
		"atividade expira em FAILED")
	_expect(park.finish() == &"fail", "finish depois do tempo devolve fail")
	# Petisco: acertar o pote escondido é perfect; errar rende good.
	park = ParkService.new()
	park.configure(&"treat")
	park.start()
	park.treat_hidden_slot = 2
	park.treat_slots = [0, 0, 1]
	park.pick_treat(2)
	_expect(park.treat_revealed and park.score == 1, "petisco: pote certo pontua")
	_expect(park.finish() == &"perfect", "petisco: acerto é perfect")
	park = ParkService.new()
	park.configure(&"treat")
	park.start()
	park.treat_hidden_slot = 0
	park.treat_slots = [1, 0, 0]
	park.pick_treat(1)
	_expect(park.score == 0, "petisco: pote errado não pontua")
	_expect(park.finish() == &"good", "petisco: erro rende good (não pune)")
	# Foto: clique alinhado pontua; desalinhado desconta e não pontua.
	park = ParkService.new()
	park.configure(&"photo")
	park.start()
	park.photo_align = 0.95
	_expect(park.try_photo(), "foto: clique alinhado é aceito")
	park.photo_align = 0.95
	park.try_photo()
	park.photo_align = 0.95
	park.try_photo()
	_expect(park.perfect and park.score >= 2, "foto: sequência alinhada é perfect")
	_expect(park.finish() == &"perfect", "foto: resultado perfect")
	park = ParkService.new()
	park.configure(&"photo")
	park.start()
	park.photo_align = 0.1
	var before: float = park.progress
	_expect(not park.try_photo() and park.progress <= before, "foto: clique desalinhado desconta")
	# Dicas localizadas em vez de português fixo.
	for activity_id: StringName in [&"ball", &"treat", &"photo"]:
		park = ParkService.new()
		park.configure(activity_id)
		var hint: String = park.quick_hint()
		_expect(not hint.is_empty() and not hint.begins_with("PARK_HINT"), "dica localizada: " + String(activity_id))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	# stdout além do push_error: o CI transforma estas linhas em annotations,
	# então a falha fica legível no GitHub sem baixar o log.
	print("TEST_FAIL: " + message)
	push_error(message)
