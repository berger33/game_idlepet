extends Control
## Playable Core: chegada → servir → esfregar → timing → moedas/review/save.

const BathServiceScript: Script = preload("res://core/gameplay/BathService.gd")
const PetShopCanvasScript: Script = preload("res://core/gameplay/PetShopCanvas.gd")
const MENU_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_perfume.png")
const NAV_ICONS: Dictionary = {
	&"missions": preload("res://art/ui/icons/missions.png"),
	&"collection": preload("res://art/ui/icons/collection.png"),
	&"staff": preload("res://art/ui/icons/staff.png"),
	&"shop": preload("res://art/ui/icons/shop.png"),
	&"map": preload("res://art/ui/icons/map.png"),
	&"settings": preload("res://art/ui/icons/settings.png"),
}
const PINK: Color = Color("ff8fb1")
const BLUE: Color = Color("4fc3f7")
const GREEN: Color = Color("7ed957")
const CREAM: Color = Color("fff3e0")
const CHARCOAL: Color = Color("263238")
const SERVICE_TOOLS: Dictionary = {
	&"bath": &"soap",
	&"groom": &"clipper",
	&"dry": &"dryer",
	&"perfume": &"perfume",
	&"style": &"bow"
}
const SERVICE_UNLOCK_LEVELS: Dictionary = {
	&"bath": 1, &"groom": 3, &"dry": 5, &"perfume": 7, &"style": 10
}
const SERVICE_LABELS: Dictionary = {
	&"bath": "ensaboar",
	&"groom": "tosar",
	&"dry": "secar",
	&"perfume": "perfumar",
	&"style": "colocar lacinho"
}
const TutorialOverlayScript: Script = preload("res://scenes/main/TutorialOverlay.gd")
const UPGRADES_ICON: Texture2D = preload("res://art/ui/icons/upgrades.png")

var bath: BathService
var world: PetShopCanvas
var coin_label: Label
var combo_label: Label
var review_label: Label
var instruction_label: Label
var primary_button: Button
var share_button: Button
var upgrades_button: Button
var upgrades_pulse_time: float = 0.0
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var dragging: bool = false
var bubble_sound_gate: float = 0.0
var toast_layer: Control
var current_service: StringName = &"bath"
var current_pet_id: String = "caramelo"
var current_pet_name: String = "Caramelo"
var pet_touch_gate: float = 0.0
var meta: MetaPanel
var dragged_tool: StringName = &""
var wrong_tool_gate: float = 0.0
## Fila de clientes (até 3): o jogador escolhe quem atender — decisão real.
var queue: Array[Dictionary] = [{}, {}, {}]
var selected_slot: int = -1
var refill_timers: Array[float] = [0.0, 0.0, 0.0]
var queue_row: HBoxContainer
var queue_cards: Array[Button] = []
var queue_name_labels: Array[Label] = []
var queue_service_labels: Array[Label] = []
var queue_info_labels: Array[Label] = []
var queue_bars: Array[ColorRect] = []
var current_vip: bool = false
var last_tip_percent: int = 0
var tutorial_overlay: Control
var tutorial_skip_button: Button
var tutorial := TutorialFlow.new()
## Onda 1: consequências visíveis + penalidade de recuperação pós-exagero.
var recovery_penalty: bool = false
var consecutive_perfects: int = 0
var mood_buff_clients: int = 0
## Onda 2: pico do bairro e pedidos especiais (upsell).
var rush_cooldown: float = 240.0
var rush_left: float = 0.0
var rush_active: bool = false
var rush_label: Label
var pending_special: StringName = &""
var special_active: bool = false
var special_multiplier: float = 1.0
var upsell_panel: PanelContainer
var upsell_label: Label
var upsell_accept: Button
var upsell_decline: Button
## Onda 3: maestria e carinho com limite por cliente.
var petting_count: int = 0
var pending_special_result: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bath = BathServiceScript.new()
	_configure_current_service()
	_build_interface()
	world.clear_room()
	for slot: int in 3:
		queue[slot] = SalonTuning.make_client(_available_services())
	_update_queue_ui()
	_connect_events()
	_refresh_economy()
	# Onda 2: o pico do bairro começa a contar desde a abertura.
	rush_cooldown = RemoteConfig.get_float("rush_interval_seconds")
	_show_pending_offline_reward()
	SessionFeedback.show_comeback(self)
	if GameState.tutorial_complete:
		LiveOps.claim_seasonal_gift()  # Temporada do mês presenteia seu cosmético.
	# Retenção: o opt-in de lembretes persiste nos ajustes; sincroniza antes de
	# agendar (sem isso o gatilho externo nunca era armado).
	NotificationManager.permission_granted = bool(
		GameState.settings.get("notifications", false)
	)
	NotificationManager.schedule_return_reminders(GameState.last_seen_unix)
	if GameState.tutorial_complete and GameState.unlocked_pets.has(GameState.favorite_pet):
		var buddy_name: String = String(ContentDB.pet(GameState.favorite_pet).get("name", "Pet"))
		_show_toast(Loc.t("BUDDY_VISIT") % buddy_name, PINK)
	if GameState.tutorial_complete:
		var deep_section: StringName = NotificationManager.deep_link_section()
		if deep_section != &"":
			meta.open(deep_section)
	tutorial.attach(self)
	tutorial.setup()
	Analytics.track(&"first_open" if GameState.services_completed == 0 else &"session_resume")


func _process(delta: float) -> void:
	bubble_sound_gate = maxf(0.0, bubble_sound_gate - delta)
	pet_touch_gate = maxf(0.0, pet_touch_gate - delta)
	wrong_tool_gate = maxf(0.0, wrong_tool_gate - delta)
	upgrades_pulse_time += delta
	if is_instance_valid(upgrades_button):
		if _upgrades_affordable():
			var pulse: float = 0.5 + 0.5 * sin(upgrades_pulse_time * 3.2)
			upgrades_button.modulate = Color.WHITE.lerp(Color("d7ffb8"), pulse * 0.55)
		else:
			upgrades_button.modulate = Color.WHITE
	if bath.state == BathService.State.ACTIVE:
		if bath.tick(delta):
			_fail(&"timeout")
			return
		# Aro de dosagem (progresso cru) + barra de paciência no topo da cena.
		world.progress = bath.progress
		world.service_time_ratio = (
			bath.time_left / bath.duration_seconds if bath.duration_seconds > 0.0 else 0.0
		)
		# Onda 1: UI de gesto por serviço + pulinho do brincalhão.
		world.gesture_ui = GestureArt.gesture_snapshot(bath)
		world.playful_hop = bath.hopping
	else:
		world.gesture_ui = {}
		world.playful_hop = false
	world.tool_levels = GameState.tool_upgrade_levels
	world.rush_active = rush_active
	_update_rush(delta)
	_process_queue(delta)


func _input(event: InputEvent) -> void:
	if (
		meta.is_open()
		or (is_instance_valid(result_panel) and result_panel.visible)
		or (is_instance_valid(upsell_panel) and upsell_panel.visible)
	):
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_begin_pointer(touch.position)
		else:
			_end_pointer()
	elif event is InputEventScreenDrag:
		_move_pointer((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_begin_pointer(mouse_button.position)
			else:
				_end_pointer()
	elif event is InputEventMouseMotion:
		_move_pointer((event as InputEventMouseMotion).position)


func _begin_pointer(point: Vector2) -> void:
	dragged_tool = world.tool_at(point)
	if not dragged_tool.is_empty():
		dragging = true
		world.grab_tool(dragged_tool, point)
		AudioManager.play(&"tool_pickup")
		HapticsManager.light()
	elif bath.state == BathService.State.WAITING and _pet_hit(point):
		_react_to_pet_touch()


func _move_pointer(point: Vector2) -> void:
	if not dragging or dragged_tool.is_empty():
		return
	world.move_tool(point)
	if not _pet_hit(point):
		world.set_tool_contact(false)
		bath.release_pointer()
		return
	var required_tool: StringName = StringName(SERVICE_TOOLS[current_service])
	if dragged_tool != required_tool:
		world.set_tool_contact(false)
		if wrong_tool_gate <= 0.0:
			wrong_tool_gate = 0.8
			_show_toast(
				"Use %s neste pedido" % SalonTuning.tool_display_name(required_tool),
				Color("ffd54f")
			)
			AudioManager.play(&"error_soft")
		return
	var contact_resumed: bool = not world.tool_contact_valid
	world.set_tool_contact(true)
	if bath.state == BathService.State.WAITING:
		_start_bath()
	if bath.state == BathService.State.ACTIVE:
		if contact_resumed and bath.fill_mode == &"pulse":
			# Perfume (Onda 1): cada novo contato é uma borrifada — acerto se
			# o anel dourado está aceso, desperdício se está apagado.
			var spray: StringName = bath.pulse_contact()
			if spray == &"hit":
				# Cada borrifada sobe uma nota (C6, D6, E6): a terceira É o perfect.
				AudioManager.play(StringName("spray_%d" % maxi(0, bath.pulses_hit - 1)))
				HapticsManager.light()
				world.spawn_bubble(point)
			elif spray == &"miss":
				AudioManager.play(&"error_soft")
		_rub(point)


func _end_pointer() -> void:
	# Soltar a ferramenta com o serviço em andamento entrega o resultado:
	# o jogador dosa a espuma e solta dentro da faixa verde (sem auto-complete).
	var finalize_now: bool = (
		bath.state == BathService.State.ACTIVE and bath.progress >= BathService.GOOD_FLOOR
	)
	dragging = false
	dragged_tool = &""
	bath.release_pointer()
	world.release_tool()
	if finalize_now:
		_finish_bath()


## Alguma melhoria está ao alcance do jogador agora (pulso do botão redondo).
func _upgrades_affordable() -> bool:
	if GameState.bath_upgrade_level < GameState.MAX_CAREER_LEVEL:
		if Economy.upgrade_cost(GameState.bath_upgrade_level) <= GameState.coins:
			return true
	for tool_id: StringName in [&"soap", &"clipper", &"dryer", &"perfume", &"bow"]:
		var level: int = int(GameState.tool_upgrade_levels.get(String(tool_id), 0))
		if level < 30 and GameState.tool_upgrade_cost(tool_id) <= GameState.coins:
			return true
	return false


func _pet_hit(point: Vector2) -> bool:
	return point.distance_to(world.pet_focus()) < 245.0


func _react_to_pet_touch() -> void:
	if pet_touch_gate > 0.35:
		return
	if petting_count >= int(RemoteConfig.get_float("petting_max_per_client")):
		# C3: carinho segue rendendo reação, mas o afeto tem teto por cliente.
		if pet_touch_gate <= 0.0:
			pet_touch_gate = 0.6
			world.react_to_touch()
			_show_toast("%s já está banhado de carinho!" % current_pet_name, PINK)
		return
	pet_touch_gate = 0.35
	petting_count += 1
	var message: String = world.react_to_touch()
	var affection: int = GameState.register_pet_interaction(current_pet_id)
	world.affection_level = affection
	AudioManager.play(&"pet_happy")
	HapticsManager.light()
	_show_toast("%s  •  carinho %d/50" % [message, affection], PINK)
	if GameState.services_completed == 0 and affection >= 3:
		instruction_label.text = "Caramelo está pronto! Arraste o sabonete até ele."
	Analytics.track(&"pet_interacted", {"pet_id": current_pet_id, "kind": "pet"})


func _rub(point: Vector2) -> void:
	bath.rub(point)
	world.react_to_service(bath.progress)
	world.spawn_bubble(point)
	if bubble_sound_gate <= 0.0:
		# Trilha progressiva do gesto (AudioManager): a nota sobe a pentatônica
		# junto com o avanço e um chime avisa a janela perfeita — dosa de ouvido.
		AudioManager.play_gesture(current_service, bath)
		bubble_sound_gate = 0.16
	EventBus.service_progress.emit(bath.progress)


func _on_primary_pressed() -> void:
	if bath.state == BathService.State.COMPLETE or bath.state == BathService.State.FAILED:
		_dismiss_result()


func _start_bath() -> void:
	bath.start_service()
	world.begin_service()
	ShareManager.begin_snapshot(get_viewport())
	instruction_label.text = SalonTuning.hint(current_service)
	AudioManager.play(&"service_start")
	Analytics.track(&"service_start", {"type": String(current_service)})
	EventBus.service_started.emit(current_service)
	if tutorial.step == 1:
		tutorial.advance()


func _finish_bath() -> void:
	var quality: StringName = bath.finish()
	if quality == &"perfect" or quality == &"good":
		world.complete_service()
		var used_tool: StringName = StringName(SERVICE_TOOLS[current_service])
		var mastery: Dictionary = GameState.register_tool_use(used_tool)
		var reward_result: Dictionary = SalonTuning.compute_reward({
			"service": current_service,
			"quality": quality,
			"pet_id": current_pet_id,
			"vip": current_vip,
			"buddy": world.buddy_active,
			"rush": rush_active,
			"special": special_multiplier,
			"mastery": SalonTuning.mastery_bonus(int(GameState.tool_uses.get(String(used_tool), 0))),
			"tool_level": int(GameState.tool_upgrade_levels.get(String(used_tool), 0)),
			"rand": randf(),
		})
		var reward: float = float(reward_result["reward"])
		last_tip_percent = int(reward_result["tip_percent"])
		if mastery.has("milestone"):
			_show_toast(
				"Maestria de %s %s!" % [
					SalonTuning.tool_display_name(used_tool).strip_edges(), "★".repeat(int(mastery["milestone"]))
				],
				Color("ffd54f")
			)
			Analytics.track(
				&"tool_milestone", {"tool": String(used_tool), "milestone": int(mastery["milestone"])}
			)
		var stars: int = 5 if quality == &"perfect" else 4
		var reputation_before: int = GameState.reviews_sum
		GameState.register_review(stars)
		if Economy.neighborhood_tier(GameState.reviews_sum) > Economy.neighborhood_tier(
			reputation_before
		):
			EventBus.toast_requested.emit(Loc.t("REP_UP"), Color("ffd54f"))
			Analytics.track(
				&"neighborhood_tier_up", {"tier": Economy.neighborhood_tier(GameState.reviews_sum)}
			)
		if last_tip_percent > 0:
			GameState.register_weekly_event(&"tips")
		if current_vip:
			GameState.register_weekly_event(&"vip")
		if current_service == &"style":
			GameState.register_weekly_event(&"style")
		EventBus.service_completed.emit(current_service, quality, reward)
		Analytics.track(
			&"service_complete",
			{"type": String(current_service), "quality": String(quality), "reward": reward}
		)
		if quality == &"perfect":
			Analytics.track(&"perfect_service")
		# A3: recuperação — qualquer acerto limpa a penalidade do exagero.
		recovery_penalty = false
		if quality == &"perfect":
			consecutive_perfects += 1
			if consecutive_perfects >= 2:
				# Ritmo do salão: a fila inteira perde paciência mais devagar.
				mood_buff_clients = 3
				world.forced_state = &"happy_squash"
				world.forced_state_time = 2.0
				_show_toast("O salão está no ritmo! Fila mais paciente.", GREEN)
				Analytics.track(&"mood_buff", {"streak": consecutive_perfects})
		else:
			consecutive_perfects = 0
		# Onda 2: pedido especial (upsell) — oferecer antes do resultado.
		var client: Dictionary = queue[selected_slot] if selected_slot >= 0 else {}
		var offered: StringName = StringName(client.get("special", &""))
		if not special_active and offered != &"" and offered != current_service:
			_offer_special(offered, quality, reward, stars)
			return
		_show_success(quality, reward, stars)
	else:
		_fail(quality)


func _show_success(quality: StringName, reward: float, stars: int) -> void:
	# Perfect and long-combo outcomes are genuinely special; ordinary good service has no stars VFX.
	world.celebrate(quality == &"perfect" or GameState.combo >= 5)
	AudioManager.play(&"perfect" if quality == &"perfect" else &"coin")
	HapticsManager.success()
	result_title.text = (
		Loc.t("PERFECT_RESULT") if quality == &"perfect" else Loc.t("GOOD_RESULT")
	)
	if current_vip:
		result_title.text = Loc.t("VIP_TAG") + "! " + result_title.text
	if tutorial.step == 2:
		tutorial.advance()
	if GameState.combo >= 5:
		result_title.text = "RITMO PERFEITO ×%d" % GameState.combo
		Analytics.track(&"combo_reached", {"level": GameState.combo})
	result_title.modulate = Color("ffd54f") if quality == &"perfect" else GREEN
	var outcome: String = (
		{
			&"bath": "saiu limpinho!",
			&"groom": "ganhou um corte novo!",
			&"dry": "ficou sequinho e fofo!",
			&"perfume": "ficou muito cheiroso!",
			&"style": "amou o novo lacinho!",
		}
		. get(current_service, "recebeu cuidado especial!")
	)
	var xp_reward: int = 15 if quality == &"perfect" else 10
	xp_reward = int(xp_reward * (1.0 + GameState.staff_bonus(&"veterinary_xp")))
	var tip_line: String = (
		Loc.t("TIP_LINE") % last_tip_percent if last_tip_percent > 0 else Loc.t("NO_TIP")
	)
	if current_vip:
		tip_line = Loc.t("VIP_TAG") + " ×2 · " + tip_line
	var extra_line: String = ""
	if special_active:
		extra_line += "\n★ pedido especial atendido!"
	if world.buddy_active:
		extra_line += "\n• buddy na banheira dupla: +40%"
	result_detail.text = (
		"%s\n+%d moedas  •  +%d XP\n%s\n%s %s%s"
		% [
			"★".repeat(stars),
			int(reward),
			xp_reward,
			tip_line,
			current_pet_name,
			outcome,
			extra_line,
		]
	)
	ShareManager.finish_snapshot(get_viewport(), String(current_service))
	share_button.visible = true
	_pop_panel(result_panel)
	primary_button.text = "✓  CONTINUAR"
	primary_button.disabled = false
	primary_button.show()
	_refresh_economy()


func _fail(reason: StringName) -> void:
	bath.state = BathService.State.FAILED
	dragging = false
	dragged_tool = &""
	world.gesture_ui = {}
	world.playful_hop = false
	# A3: o pet REAGE ao erro — tonto no exagero, triste no tempo esgotado;
	# exagerar estreita a janela do próximo atendimento até um acerto.
	if reason == &"overwashed":
		world.forced_state = &"dizzy"
		world.forced_state_time = 3.0
		recovery_penalty = true
	elif reason == &"timeout":
		world.forced_state = &"sad"
		world.forced_state_time = 2.5
	consecutive_perfects = 0
	EventBus.service_failed.emit(current_service, reason)
	Analytics.track(&"service_fail", {"type": String(current_service), "reason": String(reason)})
	world.react_to_failure()
	AudioManager.play(&"error")
	HapticsManager.error()
	result_title.text = "QUASE LÁ!"
	result_title.modulate = Color("ef5350")
	var action_name: String = String(SERVICE_LABELS.get(current_service, "cuidado"))
	var hint: String
	if reason == &"timeout":
		hint = "O tempo acabou. Faça o movimento com mais ritmo!"
	elif reason == &"overwashed":
		hint = (
			"%s demais. Solte assim que o aro entrar na faixa verde."
			% action_name.capitalize()
		)
	else:
		hint = "Leve a %s até a faixa verde antes de finalizar." % action_name
	result_detail.text = "★★☆☆☆\n%s\nSem punição — tente de novo." % hint
	share_button.visible = false
	_pop_panel(result_panel)
	primary_button.text = "↻  TENTAR NOVAMENTE"
	primary_button.disabled = false
	primary_button.show()
	if tutorial.step == 2:
		tutorial.advance()


func _dismiss_result() -> void:
	result_panel.hide()
	world.reset_pet()
	world.depart()
	world.clear_room()
	world.gesture_ui = {}
	world.buddy_active = false
	bath = BathServiceScript.new()
	if selected_slot >= 0:
		queue[selected_slot] = {}
		refill_timers[selected_slot] = _refill_delay()
	selected_slot = -1
	current_vip = false
	special_active = false
	pending_special = &""
	pending_special_result = {}
	special_multiplier = 1.0
	mood_buff_clients = maxi(0, mood_buff_clients - 1)
	instruction_label.text = Loc.t("CHOOSE_CLIENT")
	primary_button.hide()
	_update_queue_ui()


## Recarga da fila: o pico do bairro (Onda 2) traz clientes bem mais rápido.
func _refill_delay() -> float:
	return 0.35 if rush_active else 1.1


## Pico do bairro (B3): janela periódica com gorjetas ×2, recarga rápida e
## proteção de combo — o jogador corre para aproveitar antes de acabar.
func _update_rush(delta: float) -> void:
	if rush_active:
		rush_left -= delta
		if is_instance_valid(rush_label):
			rush_label.text = "PICO ×2 — %ds" % int(ceilf(maxf(0.0, rush_left)))
			rush_label.modulate = (
				Color("ffd54f") if fmod(rush_left, 0.8) < 0.4 else Color("ff8f00")
			)
		if rush_left <= 0.0:
			_end_rush()
	elif (
		bool(GameState.tutorial_complete)
		and not result_panel.visible
		and not upsell_panel.visible
	):
		rush_cooldown -= delta
		if is_instance_valid(rush_label):
			rush_label.text = (
				"pico em %ds" % int(ceilf(rush_cooldown)) if rush_cooldown <= 10.0 else ""
			)
		if rush_cooldown <= 0.0:
			_start_rush()


func _start_rush() -> void:
	rush_active = true
	rush_left = RemoteConfig.get_float("rush_duration")
	GameState.rush_combo_protection = true
	_show_toast("PICO DO BAIRRO! Gorjetas dobradas e fila cheia!", Color("ffb300"))
	Analytics.track(&"rush_started", {})
	for slot: int in 3:
		if queue[slot].is_empty():
			refill_timers[slot] = minf(refill_timers[slot], 0.5)


func _end_rush() -> void:
	rush_active = false
	GameState.rush_combo_protection = false
	rush_cooldown = RemoteConfig.get_float("rush_interval_seconds")
	if is_instance_valid(rush_label):
		rush_label.text = ""


## Upsell (B2): oferecer o serviço extra ANTES do resultado — aceitar abre
## um novo atendimento com gorjeta extra; recusar segue direto pro resultado.
func _offer_special(
	offered: StringName, quality: StringName, reward: float, stars: int
) -> void:
	pending_special = offered
	pending_special_result = {"quality": quality, "reward": reward, "stars": stars}
	var service_name: String = String(SERVICE_LABELS.get(offered, "cuidado")).capitalize()
	upsell_label.text = (
		"%s adoraria também um %s!\nAceitar o pedido?" % [current_pet_name, service_name]
	)
	world.forced_state = &"happy_squash"
	world.forced_state_time = 1.6
	Analytics.track(&"upsell_offered", {"service": String(offered)})
	_pop_panel(upsell_panel)


func _on_upsell_accept() -> void:
	upsell_panel.hide()
	special_active = true
	special_multiplier = RemoteConfig.get_float("upsell_tip_mult")
	current_service = pending_special
	bath = BathServiceScript.new()
	world.progress = 0.0
	world.forced_state = &""
	_configure_current_service()
	instruction_label.text = SalonTuning.hint(current_service)
	Analytics.track(&"upsell_accepted", {"service": String(current_service)})


func _on_upsell_decline() -> void:
	upsell_panel.hide()
	var result: Dictionary = pending_special_result
	pending_special = &""
	pending_special_result = {}
	Analytics.track(&"upsell_declined", {"service": String(current_service)})
	_show_success(
		StringName(result.get("quality", &"good")),
		float(result.get("reward", 0.0)),
		int(result.get("stars", 4)),
	)


func _on_queue_pressed(slot: int) -> void:
	if not _can_select(slot):
		return
	selected_slot = slot
	var client: Dictionary = queue[slot]
	current_vip = bool(client.get("vip", false))
	current_pet_id = String(client["pet"])
	current_service = StringName(client["service"])
	petting_count = 0
	special_active = false
	special_multiplier = 1.0
	pending_special = StringName(client.get("special", &""))
	var profile: Dictionary = ContentDB.pet(current_pet_id)
	current_pet_name = String(profile.get("name", "Pet"))
	_configure_current_service()
	world.set_service_layout(current_service)
	world.set_pet_profile(profile)
	world.affection_level = int(GameState.pet_affection.get(current_pet_id, 0))
	# Banheira dupla (Onda 3, marco 30): o buddy entra junto e é atendido em
	# paralelo — o atendimento paga +40% sem segundo gesto.
	world.buddy_active = (
		GameState.bath_upgrade_level >= 30
		and GameState.favorite_pet != current_pet_id
		and GameState.unlocked_pets.has(GameState.favorite_pet)
	)
	world.buddy_pet_id = GameState.favorite_pet
	world.arrive()
	_refresh_economy()
	var required_tool: StringName = StringName(SERVICE_TOOLS[current_service])
	instruction_label.text = (
		"Arraste %s da prateleira até %s" % [
			SalonTuning.tool_display_name(required_tool), current_pet_name
		]
	)
	_update_queue_ui()
	Analytics.track(
		&"client_selected",
		{
			"pet_id": current_pet_id,
			"service": String(current_service),
			"vip": current_vip,
			"rarity": profile.get("rarity", "common"),
		}
	)
	EventBus.pet_arrived.emit(StringName(current_pet_id))
	if tutorial.step == 0:
		tutorial.advance()


func _can_select(slot: int) -> bool:
	if queue[slot].is_empty() or selected_slot != -1:
		return false
	if is_instance_valid(result_panel) and result_panel.visible:
		return false
	if meta.is_open():
		return false
	return true


func _process_queue(delta: float) -> void:
	for slot: int in 3:
		if refill_timers[slot] > 0.0:
			refill_timers[slot] -= delta
			if refill_timers[slot] <= 0.0:
				queue[slot] = SalonTuning.make_client(_available_services())
				_update_queue_ui()
		elif (
			not queue[slot].is_empty()
			and slot != selected_slot
			and bool(GameState.tutorial_complete)
		):
			# Onda 2: pico deixa a fila mais paciente (dá pra atender todos);
			# A3: sequência de perfects deixa o salão "no ritmo" (-10%);
			# pesquisa "Comportamento Animal" drena a paciência mais devagar.
			var patience_drain: float = delta * (1.0 - Research.bonus(&"patience"))
			if rush_active:
				patience_drain *= 0.5
			if mood_buff_clients > 0:
				patience_drain *= 0.9
			queue[slot]["wait_left"] = float(queue[slot]["wait_left"]) - patience_drain
			if float(queue[slot]["wait_left"]) <= 0.0:
				_client_left(slot)
	# Barras de paciência e habilitação dos cartões (estado muda todo frame).
	for slot: int in 3:
		var client: Dictionary = queue[slot]
		if client.is_empty():
			queue_bars[slot].custom_minimum_size.x = 0.0
		else:
			var ratio: float = clampf(
				float(client["wait_left"]) / float(client["wait_total"]), 0.0, 1.0
			)
			var bar_width: float = queue_bars[slot].get_parent().size.x * ratio
			queue_bars[slot].custom_minimum_size.x = bar_width
			queue_bars[slot].color = (
				Color("ef5350") if ratio <= 0.25 else Color("7ed957")
			)
		queue_cards[slot].disabled = not _can_select(slot)


func _client_left(slot: int) -> void:
	var client: Dictionary = queue[slot]
	var leaver_name: String = String(
		ContentDB.pet(String(client["pet"])).get("name", "Alguém")
	)
	_show_toast("%s cansou de esperar e foi embora." % leaver_name, Color("ef5350"))
	GameState.register_review(3)
	Analytics.track(&"client_left", {"pet_id": String(client["pet"])})
	queue[slot] = {}
	refill_timers[slot] = 2.0 if not rush_active else 0.6
	_update_queue_ui()


func _update_queue_ui() -> void:
	for slot: int in 3:
		var client: Dictionary = queue[slot]
		if client.is_empty():
			queue_name_labels[slot].text = "· · ·"
			queue_service_labels[slot].text = "aguardando cliente"
			queue_info_labels[slot].text = ""
			queue_cards[slot].modulate.a = 0.45
			queue_cards[slot].add_theme_stylebox_override(
				"panel", _style(Color("ffffff", 0.94), 26, 16, PINK, 4)
			)
		else:
			var profile: Dictionary = ContentDB.pet(String(client["pet"]))
			var client_name: String = String(profile.get("name", "Pet"))
			if bool(client["vip"]):
				client_name = "VIP " + client_name
			if String(client["pet"]) == GameState.favorite_pet:
				# Buddy na fila: marcador localizado (investimento emocional visível).
				client_name += " • " + Loc.t("BUDDY_TAG")
			queue_name_labels[slot].text = client_name
			var service_text: String = String(
				SERVICE_LABELS.get(StringName(client["service"]), "cuidado")
			).capitalize()
			if StringName(client.get("special", &"")) != &"":
				service_text += " + ★"
			queue_service_labels[slot].text = service_text
			# B1: trade-offs explícitos — temperamento, pagamento e raridade.
			queue_info_labels[slot].text = SalonTuning.queue_info_text(profile)
			var border: Dictionary = SalonTuning.queue_border(profile)
			queue_cards[slot].add_theme_stylebox_override(
				"panel",
				_style(
					Color("ffffff", 0.94), 26, 16,
					border["color"], int(border["width"])
				)
			)
			queue_cards[slot].modulate.a = 1.0
			queue_cards[slot].disabled = not _can_select(slot)

func _configure_current_service() -> void:
	var duration: float = (
		{&"bath": 10.0, &"groom": 11.0, &"dry": 9.0, &"perfume": 8.0, &"style": 8.0}
		. get(current_service, 10.0)
	)
	var required_distance: float = (
		{&"bath": 1350.0, &"groom": 1550.0, &"dry": 1250.0, &"perfume": 1050.0, &"style": 900.0}
		. get(current_service, 1350.0)
	)
	# A paciência do pet modula o tempo real do atendimento (27–50 no catálogo);
	# passivos de equipe contratada (staff.json) ajustam tempo, distância e janela.
	var patience: float = float(ContentDB.pet(current_pet_id).get("patience", 42))
	var patience_factor: float = clampf(patience / 42.0, 0.6, 1.25)
	patience_factor += GameState.staff_bonus(&"patience")
	if current_service == &"bath":
		required_distance *= 1.0 - GameState.staff_bonus(&"bath_speed")
	var window_bonus: float = GameState.staff_bonus(&"perfect_window")
	if current_service == &"groom":
		window_bonus += GameState.staff_bonus(&"groom_quality")
	# Perfume funciona em borrifadas discretas: o perfect É a última
	# borrifada (progresso salta em 1/n); Good aceita n-1 acertos. A janela
	# máxima precisa ser 1.0 — senão 3 acertos (progresso 1.0) nunca dão
	# perfect.
	var target_min: float = RemoteConfig.get_float("bath_target_min")
	var target_max: float = minf(RemoteConfig.get_float("bath_target_max") + window_bonus, 1.0)
	if current_service == &"perfume":
		target_min = 0.95
		target_max = 1.0
	bath.configure(
		duration * patience_factor,
		target_min,
		target_max,
		required_distance,
	)
	var gesture: Dictionary = SalonTuning.GESTURES.get(
		current_service, SalonTuning.GESTURES[&"bath"]
	)
	bath.configure_gesture(
		gesture["axis"], gesture["mode"], gesture["cap"], gesture["rate"]
	)
	# --- Ondas 1–3: gesto com identidade própria, ajustado ao pet
	# (temperamento, espécie, porte, marcos de maestria e recuperação).
	SalonTuning.apply(
		bath,
		current_service,
		ContentDB.pet(current_pet_id),
		GameState.tool_upgrade_levels,
		recovery_penalty,
		world.pet_focus() if is_instance_valid(world) else Vector2(540, 990)
	)
	if is_instance_valid(world):
		world.set_service_layout(current_service)
		world.player_level = GameState.player_level
		world.establishment_tier = GameState.establishment_tier


func _available_services() -> Array[StringName]:
	var result: Array[StringName] = []
	for service: StringName in SERVICE_UNLOCK_LEVELS:
		if GameState.player_level >= int(SERVICE_UNLOCK_LEVELS[service]):
			result.append(service)
	return result if not result.is_empty() else [&"bath"]


func _refresh_economy(_currency: StringName = &"coins", _amount: float = 0.0) -> void:
	coin_label.text = "%d" % int(GameState.coins)
	var xp_percent: int = int(100.0 * GameState.player_xp / GameState.xp_to_next_level())
	combo_label.text = (
		"NV.%d %d%% • ×%d" % [GameState.player_level, xp_percent, maxi(1, GameState.combo)]
	)
	review_label.text = "★ %.1f" % GameState.review_average()
	if is_instance_valid(world):
		world.upgrade_level = GameState.bath_upgrade_level
		world.player_level = GameState.player_level
		world.set_cosmetics(GameState.active_cosmetics)


func _show_pending_offline_reward() -> void:
	var offline: Dictionary = SaveManager.consume_pending_offline_reward()
	if offline.is_empty():
		return
	var minutes: int = int(float(offline["seconds"]) / 60.0)
	_show_toast(
		"Cofre offline (%d min): +%d moedas" % [minutes, int(offline["reward"])],
		Color("ffd54f"),
	)
	AudioManager.play(&"coin")


func _show_toast(message: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_stylebox_override("normal", _style(color, 24, 16))
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-360, 120)
	label.size = Vector2(720, 78)
	toast_layer.add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", 165.0, 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


func _connect_events() -> void:
	EventBus.currency_changed.connect(_refresh_economy)
	EventBus.combo_changed.connect(func(_value: int) -> void: _refresh_economy())
	EventBus.toast_requested.connect(_show_toast)


func _build_interface() -> void:
	world = PetShopCanvasScript.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(world)

	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.position = Vector2(45, 35)
	top_bar.size = Vector2(990, 100)
	top_bar.add_theme_constant_override("separation", 18)
	add_child(top_bar)
	coin_label = _pill(top_bar, "0", Color("ffd54f"), 280)
	review_label = _pill(top_bar, "★ 5.0", PINK, 235)
	combo_label = _pill(top_bar, "COMBO ×1", GREEN, 300)
	rush_label = _pill(top_bar, "", Color("ff8f00"), 210)

	# Fila de clientes: 3 cartões tocáveis com nome, pedido, paciência e VIP.
	queue_row = HBoxContainer.new()
	queue_row.position = Vector2(45, 310)
	queue_row.size = Vector2(990, 175)
	queue_row.add_theme_constant_override("separation", 15)
	add_child(queue_row)
	for slot: int in 3:
		var card_ui: Dictionary = SalonPanels.build_queue_card(_style, _button)
		card_ui["card"].pressed.connect(_on_queue_pressed.bind(slot))
		queue_row.add_child(card_ui["card"])
		queue_cards.append(card_ui["card"])
		queue_name_labels.append(card_ui["name"])
		queue_service_labels.append(card_ui["service"])
		queue_info_labels.append(card_ui["info"])
		queue_bars.append(card_ui["bar"])

	# Navegação superior compacta: ícones flutuantes preservam o cenário e a área de trabalho.
	var nav: HBoxContainer = HBoxContainer.new()
	nav.position = Vector2(45, 155)
	nav.add_theme_constant_override("separation", 14)
	add_child(nav)
	# Ícones desenhados (PNG) em vez de glifos Unicode: renderização idêntica
	# em qualquer plataforma, sem depender da cobertura da fonte do dispositivo.
	for item: Dictionary in [
		{"id": "missions", "tip": "Missões"},
		{"id": "collection", "tip": "Pets"},
		{"id": "staff", "tip": "Equipe"},
		{"id": "shop", "tip": "Loja"},
		{"id": "map", "tip": "Mapa"},
		{"id": "settings", "tip": "Ajustes"}
	]:
		var nav_button: Button = _button("", CHARCOAL, 82, 82)
		nav_button.icon = NAV_ICONS[StringName(item["id"])]
		nav_button.tooltip_text = String(item["tip"])
		nav_button.add_theme_stylebox_override(
			"normal", _style(Color("263238", 0.88), 41, 8, Color("ffffff", 0.72), 3)
		)
		nav_button.add_theme_stylebox_override("hover", _style(PINK, 41, 8, Color.WHITE, 3))
		nav_button.pressed.connect(
			SessionFeedback.open_meta.bind(self, StringName(item["id"]), nav_button)
		)
		nav.add_child(nav_button)
	# Evento do dia visível NA cena (antes só aparecia dentro do painel):
	# gatilho interno de retorno ("hoje paga 2×").
	var event_pill: Label = _pill(nav, LiveOps.current_event_name(), Color("4fc3f7"), 250)
	event_pill.add_theme_font_size_override("font_size", 22)
	event_pill.custom_minimum_size = Vector2(250, 60)

	# HUD flutuante sem rodapé sólido: cenário continua visível até a borda inferior.
	var action_hud: VBoxContainer = VBoxContainer.new()
	action_hud.position = Vector2(45, 1350)
	action_hud.size = Vector2(990, 260)
	action_hud.add_theme_constant_override("separation", 16)
	add_child(action_hud)
	instruction_label = Label.new()
	instruction_label.text = "Arraste o sabonete da prateleira até Caramelo"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 33)
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_label.add_theme_stylebox_override(
		"normal", _style(Color("263238", 0.82), 34, 14, Color("ffffff", 0.42), 2)
	)
	instruction_label.custom_minimum_size = Vector2(990, 72)
	action_hud.add_child(instruction_label)
	# Painel de melhorias: botão redondo único no canto superior direito
	# (substitui os dois botões grandes do HUD de ação).
	upgrades_button = _button("", Color("7ed957", 0.96), 86, 86)
	upgrades_button.position = Vector2(952, 150)
	upgrades_button.icon = UPGRADES_ICON
	upgrades_button.expand_icon = true
	upgrades_button.tooltip_text = Loc.t("UPGRADES_TITLE")
	upgrades_button.add_theme_stylebox_override(
		"normal", _style(Color("7ed957", 0.96), 43, 6, Color.WHITE, 4)
	)
	upgrades_button.add_theme_stylebox_override(
		"hover", _style(Color("8fe46b", 0.98), 43, 6, Color.WHITE, 5)
	)
	upgrades_button.add_theme_stylebox_override(
		"pressed", _style(Color("5fae43", 1.0), 43, 8, Color.WHITE, 4)
	)
	add_child(upgrades_button)
	upgrades_button.pressed.connect(
		SessionFeedback.open_meta.bind(self, &"upgrades", upgrades_button)
	)

	meta = MetaPanel.new()
	meta.refresh_callback = _refresh_economy
	meta.build(self)

	var result_ui: Dictionary = SalonPanels.build_result_panel(
		self, _style, _button, _on_primary_pressed, SessionFeedback.on_share_pressed.bind(self)
	)
	result_panel = result_ui["panel"]
	result_title = result_ui["title"]
	result_detail = result_ui["detail"]
	primary_button = result_ui["primary"]
	share_button = result_ui["share"]

	# Onda 2: painel de pedido especial (upsell) — decisão antes do resultado.
	var upsell_ui: Dictionary = SalonPanels.build_upsell_panel(
		self, _style, _button, _on_upsell_accept, _on_upsell_decline
	)
	upsell_panel = upsell_ui["panel"]
	upsell_label = upsell_ui["body"]
	upsell_accept = upsell_ui["accept"]
	upsell_decline = upsell_ui["decline"]

	toast_layer = Control.new()
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(toast_layer)

	# Spotlight por cima de tudo (input passa direto: guia não-bloqueante).
	tutorial_overlay = TutorialOverlayScript.new()
	tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_overlay.visible = false
	add_child(tutorial_overlay)
	tutorial_skip_button = _button(Loc.t("SKIP_TUTORIAL"), Color("7f8c8d", 0.9), 300, 64)
	tutorial_skip_button.position = Vector2(390, 1830)
	tutorial_skip_button.pressed.connect(tutorial.skip)
	tutorial_skip_button.visible = false
	add_child(tutorial_skip_button)


func _pop_panel(panel: Control) -> void:
	panel.show()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)


func _pill(parent: Container, text: String, color: Color, width: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(width, 82)
	label.add_theme_font_size_override("font_size", 33)
	label.add_theme_color_override("font_color", CHARCOAL)
	label.add_theme_stylebox_override("normal", _style(Color("ffffff", 0.95), 35, 12, color, 5))
	parent.add_child(label)
	return label


func _button(text: String, color: Color, width: float, height: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(color, 34, 14))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.08), 34, 14))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.12), 30, 18))
	button.add_theme_stylebox_override("disabled", _style(Color("b0bec5"), 34, 14))
	InteractionFX.bind_button(button)
	return button


func _style(
	color: Color,
	radius: int,
	content_margin: int,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	if radius >= 20:
		style.shadow_color = Color("263238", 0.16)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 6)
	return style
