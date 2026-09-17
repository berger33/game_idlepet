extends SceneTree
## Execute: godot --headless --path . --script tests/run_godot_tests.gd

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_bath_boundaries()
	_test_economy_invariants()
	_test_content_contract()
	_test_state_sanitization()
	if failures == 0:
		print("Godot domain tests: PASS")
	else:
		push_error("Godot domain tests: %d failure(s)" % failures)
	quit(failures)


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
	_expect(Economy.prestige_tokens(999999.0) == 0, "prestígio precoce deve ser zero")


func _test_content_contract() -> void:
	_expect(ContentDB.pets.size() == 30, "catálogo deve carregar 30 pets")
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
	_expect(GameState.coins == 0.0, "moedas negativas devem ser reparadas")
	_expect(GameState.player_level == 120, "nível deve respeitar o cap")
	_expect(GameState.unlocked_pets.has("caramelo"), "save sem pet válido deve recuperar Caramelo")
	_expect(float(GameState.settings["music"]) == 1.0, "volume deve ser limitado")
	_expect(float(GameState.settings["sfx"]) == 0.0, "volume negativo deve ser limitado")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
