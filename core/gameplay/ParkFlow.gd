class_name ParkFlow
extends RefCounted
## Fluxo do Parquinho (quintal): UI de escolha, minijogos (bolinha/petisco/foto),
## cooldown, recompensas e encerramento. Funções estáticas recebem a cena Main
## (`main: Control`) para manter Main.gd abaixo do limite de linhas — mesmo
## padrão SalonTuning/SalonPanels. Nenhuma mudança de comportamento: o código
## foi movido 1:1 de scenes/main/Main.gd.

const PARK_CANVAS_SCRIPT: Script = preload("res://core/gameplay/ParkCanvas.gd")
const PARK_ICON: Texture2D = preload("res://art/ui/icons/park.png")

## Estado do aviso "Hora do passeio!": -1 = ainda não avaliado (boot), 0 = em
## cooldown (vai avisar quando liberar), 1 = já avisou neste ciclo.
static var ready_state: int = -1

static func setup(main: Control) -> void:
	# Canvas do parquinho (quintal) — oculto até abrir — harden contra dupla chamada / godot headless
	if is_instance_valid(main.park_canvas) and main.park_canvas.is_inside_tree():
		return
	main.park_canvas = ParkFlow.PARK_CANVAS_SCRIPT.new()
	main.park_canvas.visible = false
	main.park_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(main.park_canvas)
	main.move_child(main.park_canvas, 1) # atrás do HUD mas à frente do mundo
	# Botão Parquinho — ao lado do botão Upgrades, com cooldown visual + ícone dedicado park.png
	var safe_top: float = SalonTuning.safe_area_top()
	# safe_top offset leve no botão para notch
	main.park_button = main._button("", Color("8bc34a", 0.96), 86, 86)
	main.park_button.icon = PARK_ICON
	main.park_button.expand_icon = true
	main.park_button.text = "🌳" # fallback se ícone falhar (Godot mostra texto sobre ícone)
	main.park_button.position = Vector2(952, 250 + safe_top * 0.5)
	main.park_button.tooltip_text = Loc.t("PARK_BUTTON") if Loc.has_method("t") and Loc.t("PARK_BUTTON") != "PARK_BUTTON" else "Parquinho"
	main.park_button.add_theme_stylebox_override("normal", main._style(Color("8bc34a", 0.96), 43, 6, Color.WHITE, 4))
	main.park_button.add_theme_stylebox_override("hover", main._style(Color("9ccc65", 0.98), 43, 6, Color.WHITE, 5))
	main.park_button.add_theme_stylebox_override("pressed", main._style(Color("689f38", 1.0), 43, 8, Color.WHITE, 4))
	main.park_button.pressed.connect(Callable(ParkFlow, "on_button").bind(main))
	main.add_child(main.park_button)
	# Painel de escolha de atividade (3 botões) — 560h evita sobrepor main.instruction_label em 1350
	main.park_choose_panel = PanelContainer.new()
	main.park_choose_panel.visible = false
	main.park_choose_panel.position = Vector2(60, 740)
	main.park_choose_panel.size = Vector2(960, 560)
	main.park_choose_panel.add_theme_stylebox_override("panel", main._style(Color.WHITE, 28, 18, Color("8bc34a"), 4))
	main.add_child(main.park_choose_panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	main.park_choose_panel.add_child(vbox)
	var title: Label = Label.new()
	title.text = Loc.t("PARK_TITLE") if Loc.t("PARK_TITLE") != "PARK_TITLE" else "🌳  Parquinho  —  escolha a brincadeira"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("33691e"))
	title.add_theme_stylebox_override("normal", main._style(Color("f1f8e9"), 18, 10))
	vbox.add_child(title)
	var pets_line: Label = Label.new()
	pets_line.name = "ParkPetsLine"
	pets_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pets_line.add_theme_font_size_override("font_size", 22)
	pets_line.add_theme_color_override("font_color", Color("558b2f"))
	vbox.add_child(pets_line)
	for act: Dictionary in [ {"id": &"ball", "emoji": "🎾", "key": "PARK_BALL"}, {"id": &"treat", "emoji": "🦴", "key": "PARK_TREAT"},
		{"id": &"photo", "emoji": "📸", "key": "PARK_PHOTO"},
	]:
		var btn: Button = main._button("%s  %s" % [act["emoji"], Loc.t(String(act["key"])) if Loc.t(String(act["key"])) != String(act["key"]) else String(act["key"])], Color("fff3e0"), 900, 78)
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", Color("3e2723"))
		btn.add_theme_stylebox_override("normal", main._style(Color("fff3e0"), 22, 10, Color("ffcc80"), 3))
		btn.add_theme_stylebox_override("hover", main._style(Color("ffe0b2"), 22, 10, Color.WHITE, 3))
		btn.pressed.connect(Callable(ParkFlow, "start_activity").bind(main, StringName(act["id"])))
		vbox.add_child(btn)
	var album_btn: Button = main._button("📖  %s (%d)" % [(Loc.t("ALBUM_TITLE") if Loc.t("ALBUM_TITLE") != "ALBUM_TITLE" else "Álbum"), GameState.park_photos.size()], Color("e1bee7"), 900, 68)
	album_btn.add_theme_font_size_override("font_size", 24)
	album_btn.add_theme_color_override("font_color", Color("4a148c"))
	album_btn.tooltip_text = Loc.t("ALBUM_TROPHIES") % GameState.park_trophies if Loc.t("ALBUM_TROPHIES") != "ALBUM_TROPHIES" else "Troféus: %d" % GameState.park_trophies
	album_btn.pressed.connect(func() -> void:
		close(main)
		main.meta.open(&"album")
	)
	vbox.add_child(album_btn)
	var close_btn: Button = main._button(Loc.t("PARK_CLOSE") if Loc.t("PARK_CLOSE") != "PARK_CLOSE" else "✕  Fechar", Color("90a4ae"), 900, 56)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(Callable(ParkFlow, "close").bind(main))
	vbox.add_child(close_btn)
	main.park_timer_label = Label.new()
	main.park_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.park_timer_label.add_theme_font_size_override("font_size", 18)
	main.park_timer_label.add_theme_color_override("font_color", Color("689f38"))
	vbox.add_child(main.park_timer_label)
	update_button(main)

static func format_cooldown(main: Control, sec: int) -> String:
	if sec <= 0:
		return Loc.t("PARK_READY") if Loc.has_method("t") and Loc.t("PARK_READY") != "PARK_READY" else "Pronto!"
	if sec < 60:
		return "%ds" % sec
	var m: int = sec / 60
	var s: int = sec % 60
	if sec < 3600:
		return "%d:%02d" % [m, s]
	var h: int = sec / 3600
	m = (sec % 3600) / 60
	return "%dh %02dm" % [h, m]

static func update_button(main: Control) -> void:
	if not is_instance_valid(main.park_button):
		return
	# harden: GameState pode ainda não ter sido preenchido no primeiro frame
	if GameState == null:
		return
	# Progressive disclosure: parquinho libera após 1 atendimento (main.tutorial feito) — não sobrecarrega D0
	var locked: bool = GameState.services_completed == 0 and GameState.player_level < 2
	if locked and not main.park_active:
		main.park_button.icon = null
		main.park_button.text = "🔒"
		main.park_button.tooltip_text = Loc.t("PARK_LOCKED") if Loc.has_method("t") and Loc.t("PARK_LOCKED") != "PARK_LOCKED" else "Desbloqueia após o 1º atendimento"
		main.park_button.disabled = false
		main.park_button.modulate = Color("ffffff", 0.85)
		main.park_button.add_theme_stylebox_override("normal", main._style(Color("90a4ae", 0.96), 43, 6, Color.WHITE, 3))
		return
	else:
		# só reaplica style se já tem um válido (evita flood de StyleBoxFlat no GC)
		if main.park_button.has_theme_stylebox_override("normal"):
			main.park_button.add_theme_stylebox_override("normal", main._style(Color("8bc34a", 0.96), 43, 6, Color.WHITE, 4))
	var remain: int = GameState.park_remaining_seconds()
	if main.park_active:
		main.park_button.icon = null
		main.park_button.text = "✕"
		main.park_button.tooltip_text = Loc.t("PARK_CLOSE") if Loc.t("PARK_CLOSE") != "PARK_CLOSE" else "Sair do parquinho"
		main.park_button.disabled = false
		main.park_button.modulate = Color.WHITE
		return
	if remain > 0:
		ready_state = 0
		main.park_button.icon = null
		main.park_button.text = "⏳ %s" % format_cooldown(main, remain)
		main.park_button.add_theme_font_size_override("font_size", 18)
		main.park_button.tooltip_text = (Loc.t("PARK_COOLDOWN") % format_cooldown(main, remain)) if Loc.has_method("t") and Loc.t("PARK_COOLDOWN") != "PARK_COOLDOWN" else "Volta em %s" % format_cooldown(main, remain)
		main.park_button.disabled = false
		main.park_button.modulate = Color("ffffff", 0.88)
		# quando em cooldown, leve pulse cinza
		var badge: Label = main.park_button.get_node_or_null("Badge") as Label
		if badge != null:
			badge.visible = false
	else:
		main.park_button.icon = PARK_ICON
		main.park_button.text = ""
		main.park_button.add_theme_font_size_override("font_size", 34)
		_announce_ready(main)
		var streak: int = GameState.park_streak if GameState != null else 0
		var tip: String = Loc.t("PARK_BUTTON") if Loc.has_method("t") and Loc.t("PARK_BUTTON") != "PARK_BUTTON" else "Parquinho"
		if streak > 1:
			tip += " • 🔥%d" % streak
		main.park_button.tooltip_text = tip
		main.park_button.disabled = false
		# brilho quando pronto
		if not GameState.park_plays_total == 0:
			var pulse: float = 0.5 + 0.5 * sin(main.upgrades_pulse_time * 2.6)
			main.park_button.modulate = Color.WHITE.lerp(Color("dcedc8"), pulse * 0.5)
		else:
			main.park_button.modulate = Color.WHITE
		# badge "!" na primeira vez
		if GameState.park_plays_total == 0:
			var badge: Label = main.park_button.get_node_or_null("Badge") as Label
			if badge == null:
				badge = Label.new()
				badge.name = "Badge"
				badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				badge.add_theme_font_size_override("font_size", 28)
				badge.add_theme_color_override("font_color", Color.WHITE)
				badge.add_theme_stylebox_override("normal", main._style(Color("ef5350"), 20, 6))
				badge.custom_minimum_size = Vector2(44, 44)
				badge.position = Vector2(52, -12)
				main.park_button.add_child(badge)
			badge.text = "!"
			badge.visible = true
		else:
			var badge: Label = main.park_button.get_node_or_null("Badge") as Label
			if is_instance_valid(badge):
				badge.visible = false

## Aviso in-session quando o cooldown de 8 min termina (uma vez por ciclo).
static func _announce_ready(main: Control) -> void:
	if ready_state == 1:
		return
	var first_pass: bool = ready_state == -1
	ready_state = 1
	if first_pass or GameState.park_plays_total == 0 or not bool(GameState.tutorial_complete):
		return
	main._show_toast(Loc.t("PARK_READY_TOAST"), Color("7ed957"))
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"window")
	if HapticsManager != null and HapticsManager.has_method("light"):
		HapticsManager.light()
	if Analytics != null and Analytics.has_method("track"):
		Analytics.track(&"park_ready_toast", {"plays": GameState.park_plays_total})


## Linha do concurso mostrada no painel de escolha do passeio.
static func contest_line() -> String:
	var st: Dictionary = Contest.status()
	var left: String = Contest.format_time_left(int(st.get("seconds_left", 0)))
	if int(st.get("points", 0)) <= 0:
		return Loc.t("PARK_CONTEST_LINE_EMPTY") % left
	return Loc.t("PARK_CONTEST_LINE") % [Contest.placement_label(int(st.get("rank", 4))), int(st.get("points", 0)), left]


static func on_button(main: Control) -> void:
	if not main.is_inside_tree() or GameState == null:
		return
	if main.park_active:
		close(main)
		return
	var locked: bool = GameState.services_completed == 0 and GameState.player_level < 2
	if locked:
		main._show_toast(Loc.t("PARK_LOCKED_TOAST") if Loc.has_method("t") and Loc.t("PARK_LOCKED_TOAST") != "PARK_LOCKED_TOAST" else "Termine seu primeiro atendimento para liberar o Parquinho!", Color("90a4ae"))
		if AudioManager != null and AudioManager.has_method("play"):
			AudioManager.play(&"error_soft")
		return
	if not GameState.park_can_play():
		var remain: int = GameState.park_remaining_seconds()
		main._show_toast((Loc.t("PARK_COOLDOWN_TOAST") % format_cooldown(main, remain)) if Loc.has_method("t") and Loc.t("PARK_COOLDOWN_TOAST") != "PARK_COOLDOWN_TOAST" else "Parquinho volta em %s — os pets estão tirando uma soneca!" % format_cooldown(main, remain), Color("90a4ae"))
		if AudioManager != null and AudioManager.has_method("play"):
			AudioManager.play(&"error_soft")
		return
	open_choose(main)

static func open_choose(main: Control) -> void:
	if not main.is_inside_tree() or not is_instance_valid(main.park_choose_panel) or not is_instance_valid(main.park_canvas):
		return
	main.park_active = true
	if GameState != null:
		GameState.park_ensure_pets()
	var ids: Array[String] = GameState.park_pets if GameState != null else ["caramelo", "caramelo", "caramelo"]
	if ids.size() != 3:
		ids = ["caramelo", "caramelo", "caramelo"]
	main.park_canvas.set_pets(ids)
	main.park_canvas.visible = true
	if is_instance_valid(main.world):
		main.world.visible = false
	if is_instance_valid(main.queue_row):
		main.queue_row.visible = false
	# atualiza linha de pets no painel de escolha
	var pets_line: Label = main.park_choose_panel.get_node_or_null("VBoxContainer/ParkPetsLine") as Label
	if pets_line == null:
		# fallback busca recursiva
		pets_line = main.park_choose_panel.find_child("ParkPetsLine", true, false) as Label
	if is_instance_valid(pets_line):
		var names: Array[String] = []
		for pid: String in ids:
			var nm: String = "?"
			if ContentDB != null and ContentDB.has_method("pet_name"):
				nm = ContentDB.pet_name(pid)
				if nm.is_empty():
					nm = pid.capitalize()
			else:
				nm = pid.capitalize()
			names.append(nm)
		pets_line.text = "🐾  %s, %s & %s" % [names[0] if names.size() > 0 else "?", names[1] if names.size() > 1 else "?", names[2] if names.size() > 2 else "?"]
	main.park_choose_panel.visible = true
	main.park_choose_panel.modulate.a = 0.0
	main.park_choose_panel.scale = Vector2(0.92, 0.92)
	if main.is_inside_tree():
		var tw: Tween = main.park_choose_panel.create_tween().set_parallel(true)
		tw.tween_property(main.park_choose_panel, "modulate:a", 1.0, 0.18)
		tw.tween_property(main.park_choose_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	if is_instance_valid(main.instruction_label):
		main.instruction_label.text = Loc.t("PARK_CHOOSE") if Loc.has_method("t") and Loc.t("PARK_CHOOSE") != "PARK_CHOOSE" else "Escolha como cuidar dos 3 no quintal"
		main.instruction_label.add_theme_stylebox_override("normal", main._style(Color("33691e", 0.88), 34, 14, Color.WHITE, 3))
	if is_instance_valid(main.park_timer_label) and GameState != null:
		var lines: Array[String] = [contest_line()]
		if GameState.park_streak > 1:
			lines.append(Loc.t("PARK_STREAK") % GameState.park_streak)
		main.park_timer_label.text = "\n".join(lines)
		Contest.mark_seen()
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"window")
	if Analytics != null and Analytics.has_method("track"):
		Analytics.track(&"park_opened", {"pets": ids})

static func start_activity(main: Control, id: StringName) -> void:
	if not is_instance_valid(main.park_choose_panel) or main.park_service == null or not is_instance_valid(main.park_canvas):
		return
	main.park_choose_panel.visible = false
	var activity_str: String = String(id)
	main.park_service.configure(id)
	main.park_service.start()
	if GameState != null and GameState.has_method("park_start_session"):
		GameState.park_start_session(activity_str)
	main.park_canvas.set_activity(id)
	main.park_canvas.visible = true
	main.park_dragging_ball = false
	# esconde nav fantasiado? mantém HUD
	if is_instance_valid(main.instruction_label):
		main.instruction_label.text = instruction(main)
		main.instruction_label.add_theme_stylebox_override("normal", main._style(Color("33691e", 0.88), 34, 14, Color.WHITE, 3))
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"service_start")
	if HapticsManager != null and HapticsManager.has_method("light"):
		HapticsManager.light()

static func instruction(main: Control) -> String:
	if main.park_service == null:
		return ""
	var hints: Dictionary = { ParkService.Activity.BALL: ["PARK_HINT_BALL", "🎾 Arraste a bolinha até o pet do meio!"],
		ParkService.Activity.TREAT: ["PARK_HINT_TREAT", "🦴 Toque no pote com o petisco escondido!"],
		ParkService.Activity.PHOTO: ["PARK_HINT_PHOTO", "📸 Espere o alinhamento e toque em FOTO!"],
	}
	if not hints.has(main.park_service.activity):
		return ""
	var pair: Array = hints[main.park_service.activity]
	if Loc != null and Loc.has_method("t"):
		var translated: String = Loc.t(pair[0])
		if translated != pair[0]:
			return translated
	return String(pair[1])

static func begin_pointer(main: Control, pos: Vector2) -> void:
	if main.park_service == null or main.park_service.state != ParkService.State.ACTIVE or not is_instance_valid(main.park_canvas) or not main.is_inside_tree():
		return
	match main.park_service.activity:
		ParkService.Activity.BALL:
			if main.park_canvas.has_method("ball_hit") and main.park_canvas.ball_hit(pos):
				main.park_dragging_ball = true
				if AudioManager != null and AudioManager.has_method("play"):
					AudioManager.play(&"tool_pickup")
				if HapticsManager != null and HapticsManager.has_method("light"):
					HapticsManager.light()
			else:
				# arrasto direto também move
				main.park_dragging_ball = true
				if main.park_canvas.has_method("pet_focus"):
					main.park_service.drag_ball(pos, main.park_canvas.pet_focus(1))
				if is_instance_valid(main.park_canvas):
					main.park_canvas.ball_pos = pos
		ParkService.Activity.TREAT:
			if not main.park_canvas.has_method("treat_slot_at"):
				return
			var slot: int = main.park_canvas.treat_slot_at(pos)
			if slot >= 0 and not main.park_service.treat_revealed:
				main.park_service.pick_treat(slot)
				main.park_canvas.treat_choice = slot
				main.park_canvas.treat_revealed = true
				main.park_canvas.treat_hidden_slot = main.park_service.treat_hidden_slot
				if AudioManager != null and AudioManager.has_method("play"):
					AudioManager.play(&"tap")
				if HapticsManager != null and HapticsManager.has_method("light"):
					HapticsManager.light()
				main.park_canvas.spawn_bubble(pos)
				# auto-finaliza após escolha — guard get_tree + is_inside_tree para não travar se cena já saiu
				if main.is_inside_tree() and main.get_tree() != null:
					main.get_tree().create_timer(0.9).timeout.connect(func() -> void:
						if main.is_inside_tree() and main.park_active and is_instance_valid(main.park_service) and main.park_service.state == ParkService.State.ACTIVE:
							finish(main, false)
					)
		ParkService.Activity.PHOTO:
			if not main.park_canvas.has_method("photo_hit") or not main.park_canvas.photo_hit(pos):
				return
			var ok: bool = main.park_service.try_photo()
			main.park_canvas.photo_align = main.park_service.photo_align
			main.park_canvas.spawn_bubble(pos)
			if AudioManager != null and AudioManager.has_method("play"):
				AudioManager.play(&"window" if ok else &"error_soft")
			if HapticsManager != null and HapticsManager.has_method("light"):
				HapticsManager.light()
			if main.park_service.progress >= 0.92:
				if main.is_inside_tree() and main.get_tree() != null:
					main.get_tree().create_timer(0.4).timeout.connect(func() -> void:
						if main.is_inside_tree() and main.park_active and is_instance_valid(main.park_service) and main.park_service.state == ParkService.State.ACTIVE:
							finish(main, false)
					)
			elif main.park_service.photo_shots >= 4:
				if main.is_inside_tree() and main.get_tree() != null:
					main.get_tree().create_timer(0.6).timeout.connect(func() -> void:
						if main.is_inside_tree() and main.park_active and is_instance_valid(main.park_service) and main.park_service.state == ParkService.State.ACTIVE:
							finish(main, false)
					)

static func move_pointer(main: Control, pos: Vector2) -> void:
	if main.park_service == null or main.park_service.state != ParkService.State.ACTIVE or not is_instance_valid(main.park_canvas) or not main.is_inside_tree():
		return
	if main.park_service.activity == ParkService.Activity.BALL and main.park_dragging_ball:
		if main.park_canvas.has_method("pet_focus"):
			main.park_service.drag_ball(pos, main.park_canvas.pet_focus(1))
		if is_instance_valid(main.park_canvas):
			main.park_canvas.ball_pos = pos
		if main.park_service.fetch_count > 0 and main.park_service.progress > 0.85 and is_instance_valid(main.park_canvas):
			main.park_canvas.spawn_bubble(pos)

static func end_pointer(main: Control) -> void:
	if main.park_service == null or not main.is_inside_tree():
		return
	if main.park_service.activity == ParkService.Activity.BALL and main.park_dragging_ball:
		main.park_dragging_ball = false
		# se já fez progresso bom, permite finalizar cedo com toque duplo? mantém tempo
		if main.park_service.progress >= 0.88 and main.park_service.fetch_count >= 3:
			# brilha e auto-finaliza
			if is_instance_valid(main.park_canvas) and main.park_canvas.has_method("celebrate"):
				main.park_canvas.celebrate(true)
			if main.is_inside_tree() and main.get_tree() != null:
				main.get_tree().create_timer(0.5).timeout.connect(func() -> void:
					if main.is_inside_tree() and main.park_active and is_instance_valid(main.park_service) and main.park_service.state == ParkService.State.ACTIVE:
						finish(main, false)
				)

static func finish(main: Control, timeout: bool) -> void:
	if main.park_service == null or main.park_service.state != ParkService.State.ACTIVE or GameState == null:
		return
	var quality: StringName = &"fail" if timeout else main.park_service.finish()
	var success: bool = quality == &"perfect" or quality == &"good"
	var perfect: bool = quality == &"perfect"
	var activity_str: String = String(ParkService.ACTIVITY_NAMES.get(main.park_service.activity, &"ball")) if ParkService.ACTIVITY_NAMES.has(main.park_service.activity) else "ball"
	var reward: Dictionary = {}
	if GameState.has_method("park_complete"):
		reward = GameState.park_complete(activity_str, success, perfect)
	main.park_active = false
	main.park_dragging_ball = false
	if is_instance_valid(main.park_canvas):
		main.park_canvas.visible = false
	if is_instance_valid(main.world):
		main.world.visible = true
	if is_instance_valid(main.queue_row):
		main.queue_row.visible = true
	if is_instance_valid(main.park_choose_panel):
		main.park_choose_panel.visible = false
	update_button(main)
	main._refresh_economy()
	if success:
		show_success(main, quality, reward)
	else:
		show_fail(main)
	if Analytics != null and Analytics.has_method("track"):
		Analytics.track(&"park_finished", {"quality": String(quality), "activity": activity_str})

static func show_success(main: Control, quality: StringName, reward: Dictionary) -> void:
	if not main.is_inside_tree():
		return
	var coins: int = int(reward.get("coins", 0))
	var aff: int = int(reward.get("affection", 0))
	var embers: int = int(reward.get("embers", 0))
	var streak: int = int(reward.get("streak", 0))
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"perfect" if quality == &"perfect" else &"coin")
	if HapticsManager != null and HapticsManager.has_method("success"):
		HapticsManager.success()
	if is_instance_valid(main.park_canvas) and main.park_canvas.has_method("celebrate"):
		main.park_canvas.celebrate(true)
	if is_instance_valid(main.result_title):
		main.result_title.text = Loc.t("PARK_PERFECT") if Loc.has_method("t") and quality == &"perfect" and Loc.t("PARK_PERFECT") != "PARK_PERFECT" else ("⭐ Perfeito no parquinho!" if quality == &"perfect" else "✓ Ótimo cuidado!")
		main.result_title.modulate = Color("ffd54f") if quality == &"perfect" else Color("2e7d32")
	var coins_word: String = Loc.t("COINS") if Loc.has_method("t") else "R$"
	var names: String = ""
	if GameState != null:
		for pid: String in GameState.park_pets:
			var nm: String = pid.capitalize()
			if ContentDB != null and ContentDB.has_method("pet_name"):
				var tmp: String = ContentDB.pet_name(pid)
				if not tmp.is_empty():
					nm = tmp
			names += nm + ", "
		names = names.trim_suffix(", ")
	var streak_line: String = ""
	if streak >= 2:
		streak_line = (Loc.t("PARK_STREAK_BONUS") % streak) if Loc.has_method("t") and Loc.t("PARK_STREAK_BONUS") != "PARK_STREAK_BONUS" else "🔥 %d dias seguidos!" % streak
	var votes: int = int(reward.get("votes", 0))
	var votes_line: String = ""
	if votes > 0:
		votes_line = Loc.t("PARK_VOTES_LINE") % [votes, Contest.placement_label(int(reward.get("rank", 4)))]
	if is_instance_valid(main.result_detail):
		main.result_detail.text = "%s\n%s +%d  •  💗 +%d afeto%s%s%s" % ["★★★★★" if quality == &"perfect" else "★★★★☆", coins_word, coins, aff, "  •  🔥 +%d" % embers if embers > 0 else "", "\n" + votes_line if not votes_line.is_empty() else "", "\n" + streak_line if not streak_line.is_empty() else ""]
	var extra: String = (Loc.t("PARK_SUCCESS_EXTRA") % names) if Loc.has_method("t") and Loc.t("PARK_SUCCESS_EXTRA") != "PARK_SUCCESS_EXTRA" else "%s adoraram o quintal com você!" % names
	if quality == &"perfect":
		extra += "\n" + (Loc.t("PARK_PERFECT_EXTRA") if Loc.has_method("t") and Loc.t("PARK_PERFECT_EXTRA") != "PARK_PERFECT_EXTRA" else "Foto perfeita! As memórias vão para a coleção.")
	extra += "\n" + Loc.t("PARK_NEXT_IN") % format_cooldown(main, GameState.park_remaining_seconds())
	if is_instance_valid(main.result_detail_extra):
		main.result_detail_extra.text = extra
		main.result_detail_extra.visible = false
		main.result_expanded = false
		if is_instance_valid(main.result_expand_btn):
			main.result_expand_btn.text = "ⓘ  Ver"
			main.result_expand_btn.visible = true
	if is_instance_valid(main.share_button):
		main.share_button.visible = false
	if is_instance_valid(main.result_panel):
		main._pop_panel(main.result_panel)
	if is_instance_valid(main.primary_button):
		main.primary_button.text = "✓  " + (Loc.t("REVEAL_OK") if Loc.has_method("t") else "OK")
		main.primary_button.disabled = false
		main.primary_button.show()
	main._animate_coin_fly(coins)
	if EventBus != null and EventBus.has_signal("reveal_requested"):
		EventBus.reveal_requested.emit(&"park", {"quality": String(quality), "coins": coins})

static func show_fail(main: Control) -> void:
	if not main.is_inside_tree():
		return
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"error_soft")
	if is_instance_valid(main.park_canvas):
		main.park_canvas.forced_state = &"sad"
	if is_instance_valid(main.result_title):
		main.result_title.text = Loc.t("PARK_FAIL") if Loc.has_method("t") and Loc.t("PARK_FAIL") != "PARK_FAIL" else "Quase! Tente de novo"
		main.result_title.modulate = Color("ef5350")
	if is_instance_valid(main.result_detail):
		main.result_detail.text = "★★☆☆☆\n" + (Loc.t("PARK_FAIL_HINT") if Loc.has_method("t") and Loc.t("PARK_FAIL_HINT") != "PARK_FAIL_HINT" else "Os pets se distraíram — tente outra brincadeira!")
	if is_instance_valid(main.result_detail_extra):
		main.result_detail_extra.text = Loc.t("PARK_FAIL_EXTRA") if Loc.has_method("t") and Loc.t("PARK_FAIL_EXTRA") != "PARK_FAIL_EXTRA" else "Sem penalidade na fila. Volta quando o cooldown acabar!"
		main.result_detail_extra.visible = false
		main.result_expanded = false
		if is_instance_valid(main.result_expand_btn):
			main.result_expand_btn.visible = true
			main.result_expand_btn.text = "ⓘ  Dica"
	if is_instance_valid(main.share_button):
		main.share_button.visible = false
	if is_instance_valid(main.result_panel):
		main._pop_panel(main.result_panel)
	if is_instance_valid(main.primary_button):
		main.primary_button.text = "↻  " + (Loc.t("TRY_AGAIN") if Loc.has_method("t") else "Tentar novamente")
		main.primary_button.disabled = false
		main.primary_button.show()

static func close(main: Control) -> void:
	if not main.park_active:
		# mesmo fechado, garante hidden se foi chamado por main._input back
		if is_instance_valid(main.park_canvas):
			main.park_canvas.visible = false
		if is_instance_valid(main.park_choose_panel):
			main.park_choose_panel.visible = false
		return
	main.park_active = false
	main.park_dragging_ball = false
	if is_instance_valid(main.park_canvas):
		main.park_canvas.visible = false
	if is_instance_valid(main.world):
		main.world.visible = true
	if is_instance_valid(main.queue_row):
		main.queue_row.visible = true
	if is_instance_valid(main.park_choose_panel):
		main.park_choose_panel.visible = false
	if main.park_service != null:
		main.park_service.state = ParkService.State.IDLE
	if is_instance_valid(main.instruction_label):
		main.instruction_label.text = Loc.t("CHOOSE_CLIENT") if Loc.has_method("t") else "Escolha um cliente"
		if main._instr_styles != null and main._instr_styles.has(&"hint"):
			main.instruction_label.add_theme_stylebox_override("normal", main._instr_styles[&"hint"] as StyleBoxFlat)
		else:
			main.instruction_label.add_theme_stylebox_override("normal", main._style(Color("263238", 0.82), 34, 14, Color("ffffff", 0.42), 2))
	main._last_instr_key = &""
	update_button(main)
	if AudioManager != null and AudioManager.has_method("play"):
		AudioManager.play(&"tap")
