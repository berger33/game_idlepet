class_name PetShopCanvas
extends Control
## Cenário ilustrado + personagens/VFX vetoriais em runtime.

const BATH_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_quintal.png")
const GROOM_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_tosa.png")
const DRY_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_secagem.png")
const PERFUME_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_perfume.png")
const STYLE_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_estilo.png")
const TOOL_TEXTURES: Dictionary = {
	&"soap": preload("res://art/props/tool_soap.png"),
	&"clipper": preload("res://art/props/tool_clipper.png"),
	&"dryer": preload("res://art/props/tool_dryer.png"),
	&"perfume": preload("res://art/props/tool_perfume.png"),
	&"bow": preload("res://art/props/tool_bow.png"),
}
const TOOL_LEVELS: Dictionary = {&"soap": 1, &"clipper": 3, &"dryer": 5, &"perfume": 7, &"bow": 10}
const TOOL_ORDER: Array[StringName] = [&"soap", &"clipper", &"dryer", &"perfume", &"bow"]
const SERVICE_TOOLS: Dictionary = {
	&"bath": &"soap",
	&"groom": &"clipper",
	&"dry": &"dryer",
	&"perfume": &"perfume",
	&"style": &"bow"
}
const PET_STATE_NAMES: Array[StringName] = [
	&"dirty",
	&"wet",
	&"messy",
	&"tilt_left",
	&"tilt_right",
	&"happy_squash",
	&"happy_air",
	&"dizzy",
	&"sad",
	&"blink",
	# Variantes de piscada por estado: permitem piscar molhado/sujo/peludo/etc.
	# sem trocar o pet para a versão seca (carregadas só se existirem no disco).
	&"dirty_blink",
	&"wet_blink",
	&"messy_blink",
	&"sad_blink",
	&"dizzy_blink"
]
const PET_TEXTURE_BASELINE: float = 479.0 / 512.0
const UI_TITLE_FONT: Font = preload("res://art/fonts/DejaVuSans-Bold.ttf")
## Alturas das prateleiras do serviço atual (fonte única:
## data/service_layouts.json via ContentDB; fallback uniforme do HUD).
const DEFAULT_SHELF_LEVELS: Array[float] = [560.0, 730.0, 900.0, 1070.0, 1240.0]
var service_shelf_levels: Array[float] = DEFAULT_SHELF_LEVELS.duplicate()

## Nível de afeto do pet atual (0-50): desenha 3 corações de marcos na cena,
## tornando visível o investimento emocional (retenção D7).
var affection_level: int = 0

## Capítulo do estabelecimento (1=quintal … 10=império, via career_track):
## muda o título da placa e o mobiliário da banheira conforme a progressão.
var establishment_tier: int = 1

## Ancora dos PÉS do pet (a superfície da estação fica neste Y).
var pet_position: Vector2 = Vector2(540, 1160)
## Sala sem cliente (aguardando escolha na fila): não desenha pet.
var room_empty: bool = true
var pet_happy: bool = false
## Cosméticos equipados por slot; mudam VFX, cenário e o pet na hora.
var room_cosmetics: Dictionary = {}
var pet_wet: bool = false
var progress: float = 0.0
var service_time_ratio: float = 1.0
var bubbles: Array[Dictionary] = []
var celebration: float = 0.0
var shake_phase: float = 0.0
var service_mode: StringName = &"bath"
var upgrade_level: int = 0
var arrival_time: float = 1.0
var level_box: StyleBoxFlat
var fur_color: Color = Color("c98b5b")
var ear_color: Color = Color("9c623f")
var muzzle_color: Color = Color("f1c49f")
var species: StringName = &"dog"
var pet_id: String = "caramelo"
var pet_texture: Texture2D
var pet_state_textures: Dictionary = {}
var breed_name: String = "Vira-lata caramelo"
var temperament: StringName = &"happy"
var rarity: StringName = &"common"
var reaction_time: float = 0.0
var reaction_kind: StringName = &"idle"
## Piscada forçada por reação (carinho/serviço confortável), em segundos.
var blink_force_time: float = 0.0
## Desloca a fase da piscada por pet para o elenco não piscar em uníssono.
var blink_offset: float = 0.0
var hearts: Array[Dictionary] = []
var player_level: int = 1
var active_tool: StringName = &""
var tool_position: Vector2 = Vector2.ZERO
var tool_visible: bool = false
var tool_contact_valid: bool = false
var service_active: bool = false
var service_condition_complete: bool = false
var condition_release: float = 0.0
var special_reward_active: bool = false
var departure_time: float = -1.0
## Onda 1 (docs/DESIGN_ENGAJAMENTO.md): UI de gesto por serviço, estados
## forçados (consequência de erro/acerto), pulinho do pet brincalhão, pico
## do bairro, banheira dupla (buddy em paralelo) e selo de maestria por
## ferramenta (aro prata/ouro nos marcos 10/20).
var gesture_ui: Dictionary = {}
var forced_state: StringName = &""
var forced_state_time: float = 0.0
var playful_hop: bool = false
var rush_active: bool = false
var buddy_pet_id: String = ""
var buddy_active: bool = false
var buddy_texture: Texture2D
var buddy_texture_id: String = ""
var tool_levels: Dictionary = {}


func _ready() -> void:
	level_box = _box(Color("ffd54f", 0.94), 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	shake_phase += delta
	blink_force_time = maxf(0.0, blink_force_time - delta)
	arrival_time = minf(1.0, arrival_time + delta * 2.8)
	if departure_time >= 0.0:
		departure_time = minf(1.0, departure_time + delta * 2.4)
	celebration = maxf(0.0, celebration - delta)
	condition_release = maxf(0.0, condition_release - delta * 1.6)
	if celebration <= 0.0:
		special_reward_active = false
	reaction_time = maxf(0.0, reaction_time - delta)
	forced_state_time = maxf(0.0, forced_state_time - delta)
	if forced_state_time <= 0.0:
		forced_state = &""
	if reaction_time <= 0.0 and celebration <= 0.0:
		reaction_kind = &"idle"
		pet_happy = false
	for heart: Dictionary in hearts:
		heart["p"] = heart["p"] + Vector2(0, -90.0 * delta)
		heart["life"] = float(heart["life"]) - delta
	for index: int in range(hearts.size() - 1, -1, -1):
		if float(hearts[index]["life"]) <= 0.0:
			hearts.remove_at(index)
	for bubble: Dictionary in bubbles:
		bubble["p"] = bubble["p"] + Vector2(0, -float(bubble["speed"]) * delta)
		bubble["life"] = float(bubble["life"]) - delta
	for index: int in range(bubbles.size() - 1, -1, -1):
		if float(bubbles[index]["life"]) <= 0.0:
			bubbles.remove_at(index)
	queue_redraw()


func set_service_layout(next_service: StringName) -> void:
	service_mode = next_service
	service_active = false
	tool_contact_valid = false
	service_condition_complete = false
	condition_release = 0.0
	# Fonte única: data/service_layouts.json (via ContentDB). pet_position é a
	# âncora dos pés; a estação do StationArt usa a mesma superfície.
	var layout: Dictionary = ContentDB.service_layout(next_service)
	var position_entry: Array = layout.get("pet_position", [540, 1160])
	pet_position = Vector2(float(position_entry[0]), float(position_entry[1]))
	service_shelf_levels = []
	for level: Variant in layout.get("shelf_y", DEFAULT_SHELF_LEVELS):
		service_shelf_levels.append(float(level))
	queue_redraw()


func begin_service() -> void:
	service_active = true
	progress = 0.0
	pet_wet = service_mode == &"bath" or service_mode == &"dry"


func complete_service() -> void:
	service_active = false
	bubbles.clear()
	service_condition_complete = true
	condition_release = 1.0 if service_mode == &"bath" else 0.0
	pet_wet = false
	progress = 1.0


func spawn_bubble(at: Vector2) -> void:
	tool_position = at
	tool_visible = true
	if bubbles.size() >= 42 or bool(GameState.settings.get("reduced_particles", false)):
		return
	bubbles.append(
		{
			"p": at + Vector2(randf_range(-35, 35), randf_range(-20, 20)),
			"r": randf_range(9, 23),
			"speed": randf_range(35, 80),
			"life": randf_range(0.5, 1.2)
		}
	)


func celebrate(is_special_reward: bool = false) -> void:
	pet_happy = true
	celebration = 1.8
	special_reward_active = is_special_reward


func set_pet_profile(profile: Dictionary) -> void:
	pet_id = String(profile.get("id", "caramelo"))
	blink_offset = float(int(String(pet_id).hash()) % 47) * 0.1
	var texture_path: String = "res://art/pets/%s.png" % pet_id
	pet_texture = null
	pet_state_textures.clear()
	if ResourceLoader.exists(texture_path):
		pet_texture = load(texture_path) as Texture2D
	for state_name: StringName in PET_STATE_NAMES:
		var state_path: String = "res://art/pet_animations/%s/%s.png" % [pet_id, state_name]
		if ResourceLoader.exists(state_path):
			pet_state_textures[state_name] = load(state_path) as Texture2D
	var colors: Array = profile.get("colors", ["c98b5b", "9c623f", "f1c49f"])
	if colors.size() >= 3:
		fur_color = Color(String(colors[0]))
		ear_color = Color(String(colors[1]))
		muzzle_color = Color(String(colors[2]))
	species = StringName(profile.get("species", "dog"))
	breed_name = String(profile.get("breed", "Pet especial"))
	temperament = StringName(profile.get("temperament", "happy"))
	rarity = StringName(profile.get("rarity", "common"))


func set_cosmetics(active: Dictionary) -> void:
	room_cosmetics = active.duplicate()
	queue_redraw()


## Cosmético de banheira troca a cor da espuma e das bolhas em todo o banho.
func _bath_foam_color() -> Color:
	return PetCosmeticsArt.bath_foam_color(self)


func _draw_room_cosmetics() -> void:
	PetCosmeticsArt.draw_room_cosmetics(self)


func _draw_pet_accessories(center: Vector2, fit: float, texture_local: bool) -> void:
	PetCosmeticsArt.draw_pet_accessories(self, center, fit, texture_local)


## Posição de foco do pet (peito/corpo) para hit test e destaques: os pés
## ficam em pet_position; o corpo ocupa ~340px acima.
func pet_focus() -> Vector2:
	return pet_position + Vector2(0.0, -170.0)


func react_to_touch() -> String:
	var reactions: PackedStringArray
	if temperament == &"fearful" or temperament == &"anxious":
		reactions = ["Carinho ajuda!", "Agora estou tranquilo!", "Mais devagarzinho!"]
	elif temperament == &"irritated":
		reactions = ["Ei! ...tá, gostei.", "Só mais um carinho!", "Au! Que surpresa!"]
	elif species == &"cat":
		reactions = ["Prrrrr...", "Miau! Gostei!", "Carinho aprovado!"]
	else:
		reactions = ["Amei o carinho!", "Au au! De novo!", "Você é meu humano favorito!"]
	reaction_kind = &"love"
	reaction_time = 1.25
	pet_happy = true
	for index: int in 3:
		(
			hearts
			. append(
				{
					"p":
							pet_position + Vector2(-65.0 + index * 65.0, -300.0 - abs(index - 1) * 22.0),
					"life": 0.9 + index * 0.12,
					"size": 16.0 + index * 3.0,
				}
			)
		)
	return reactions[randi() % reactions.size()]


func react_to_service(service_progress: float) -> void:
	if service_progress > 0.78:
		reaction_kind = &"excited"
		pet_happy = true
	else:
		reaction_kind = &"blink" if int(service_progress * 20.0) % 5 == 0 else &"focused"
		pet_happy = false
	reaction_time = 0.22


func react_to_dizziness() -> void:
	# Reserved for explicit overload/stun; normal service completion never causes dizziness.
	reaction_kind = &"dizzy"
	reaction_time = 1.0
	pet_happy = false


func _service_effect_active() -> bool:
	return (
		service_active
		and tool_visible
		and tool_contact_valid
		and active_tool == StringName(SERVICE_TOOLS.get(service_mode, &""))
	)


func _tool_position(tool: StringName) -> Vector2:
	var index: int = TOOL_ORDER.find(tool)
	var shelf_levels: Array[float] = service_shelf_levels
	if index < 0 or index >= shelf_levels.size():
		return Vector2(910, 545)
	return Vector2(910, shelf_levels[index])


## Posição da prateleira de um utensílio (para spotlight do tutorial).
func tool_shelf_position(tool: StringName) -> Vector2:
	return _tool_position(tool)


func tool_at(point: Vector2) -> StringName:
	for tool: StringName in TOOL_ORDER:
		if (
			player_level >= int(TOOL_LEVELS[tool])
			and point.distance_to(_tool_position(tool)) < 72.0
		):
			return tool
	return &""


func grab_tool(tool: StringName, at: Vector2) -> void:
	active_tool = tool
	tool_position = at
	tool_visible = true


func move_tool(at: Vector2) -> void:
	tool_position = at
	tool_visible = true


func set_tool_contact(is_valid: bool) -> void:
	tool_contact_valid = is_valid


func release_tool() -> void:
	tool_visible = false
	tool_contact_valid = false
	active_tool = &""


func react_to_failure() -> void:
	tool_visible = false
	tool_contact_valid = false
	service_active = false
	bubbles.clear()
	reaction_kind = &"sad"
	reaction_time = 1.5
	pet_happy = false


func arrive() -> void:
	room_empty = false
	arrival_time = 0.0
	departure_time = -1.0
	pet_happy = false


func clear_room() -> void:
	room_empty = true
	reset_pet()
	pet_texture = null
	pet_state_textures.clear()


func depart() -> void:
	service_active = false
	tool_visible = false
	tool_contact_valid = false
	departure_time = 0.0


func reset_pet() -> void:
	pet_happy = false
	pet_wet = false
	service_active = false
	service_condition_complete = false
	condition_release = 0.0
	special_reward_active = false
	progress = 0.0
	service_time_ratio = 1.0
	tool_visible = false
	tool_contact_valid = false
	reaction_time = 0.0
	reaction_kind = &"idle"
	bubbles.clear()
	hearts.clear()


func _draw() -> void:
	var background: Texture2D = BATH_BACKGROUND
	if service_mode == &"groom":
		background = GROOM_BACKGROUND
	elif service_mode == &"dry":
		background = DRY_BACKGROUND
	elif service_mode == &"perfume":
		background = PERFUME_BACKGROUND
	elif service_mode == &"style":
		background = STYLE_BACKGROUND
	var source_height: float = float(background.get_height())
	draw_texture_rect_region(
		background,
		Rect2(Vector2.ZERO, size),
		Rect2(0.0, 0.0, float(background.get_width()), source_height)
	)
	# A placa da ilustração permanece sem texto; o título é localizado em runtime.
	# O nome da sala é neutro; a localização vem do capítulo do estabelecimento
	# (quintal humilde no início → império no fim) exibida logo abaixo.
	var room_title: String = (
		{
			&"bath": "BANHO & ESPUMA",
			&"groom": "TOSA & APARO",
			&"dry": "SECAGEM ACONCHEGANTE",
			&"perfume": "SPA PERFUMADO",
			&"style": "ATELIÊ DE LAÇOS",
		}
		. get(service_mode, "PET SHOP")
	)
	var establishment_name: String = ContentDB.establishment_name(clampi(establishment_tier, 1, 10))
	StationArt.draw_title_plaque(self)
	draw_string(
		UI_TITLE_FONT,
		Vector2(330, 214),
		room_title,
		HORIZONTAL_ALIGNMENT_CENTER,
		430,
		38,
		Color("263238")
	)
	draw_string(
		UI_TITLE_FONT,
		Vector2(330, 248),
		"★ " + establishment_name.to_upper() + " ★",
		HORIZONTAL_ALIGNMENT_CENTER,
		430,
		20,
		Color("8d5a77")
	)
	StationArt.draw_shelf_unit(self)
	_draw_room_cosmetics()
	_draw_tool_shelf()
	# O selo de estação é informativo; elementos que parecem botões não são desenhados no cenário.
	if upgrade_level > 0:
		draw_style_box(level_box, Rect2(70, 500, 250, 78))
		draw_string(
			UI_TITLE_FONT,
			Vector2(95, 552),
			"ESTAÇÃO  Nv.%d" % upgrade_level,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			28,
			Color("263238")
		)
	# Entrada e saída usam easing independente; movimento emocional acontece sobre o pivô dos pés.
	# Pulso visual ancorado no ÁUDIO REAL: fase do compasso da música em execução.
	var beat_pulse: float = pow(1.0 - AudioManager.beat_phase(), 3.0)
	var idle_bob: float = sin(shake_phase * 5.0) * (3.0 if pet_happy else 1.2)
	var eased_arrival: float = 1.0 - pow(1.0 - arrival_time, 3.0)
	var exit_offset: float = 0.0
	if departure_time >= 0.0:
		exit_offset = (departure_time * departure_time) * 480.0
	var pet_center: Vector2 = (
		pet_position + Vector2((1.0 - eased_arrival) * -430.0 + exit_offset, idle_bob)
	)
	# pet_position é a âncora dos PÉS; auras e estação usam o centro do corpo.
	var body_center: Vector2 = pet_center + Vector2(0.0, -170.0)
	StationArt.draw_station(self)
	if not room_empty:
		if rarity == &"legendary":
			draw_circle(body_center, 205.0 + beat_pulse * 14.0, Color("ffd54f", 0.22))
			draw_arc(body_center, 190.0 + beat_pulse * 8.0, 0, TAU, 40, Color("ffd54f", 0.8), 7)
		elif rarity == &"epic":
			draw_circle(body_center, 185.0, Color("ce93d8", 0.16))
		_draw_pet(pet_center)
		StationArt.draw_station_foreground(self)
		_draw_affection_hearts(body_center)
		GestureArt.draw_gesture_ui(self, body_center)
		GestureArt.draw_buddy(self)
	# VFX de serviço só existe enquanto o utensílio correto está ativo sobre o pet.
	var effect_count: int = int(progress * 18.0) if _service_effect_active() else 0
	for i: int in effect_count:
		var angle: float = float(i) * 2.4
		var radius: float = 70.0 + float(i % 5) * 23.0
		var effect_pos: Vector2 = (
			pet_position + Vector2(cos(angle), sin(angle) * 0.5) * radius + Vector2(0, 70)
		)
		if service_mode == &"bath":
			var foam: Color = _bath_foam_color()
			draw_circle(effect_pos, 30 + (i % 3) * 6, Color(foam, 0.95))
			draw_arc(effect_pos, 25 + (i % 3) * 6, 0, TAU, 20, foam.darkened(0.18), 4)
		elif service_mode == &"groom":
			draw_line(effect_pos - Vector2(14, 10), effect_pos + Vector2(14, 10), ear_color, 8)
			draw_line(effect_pos + Vector2(-12, 12), effect_pos + Vector2(12, -12), fur_color, 6)
		elif service_mode == &"dry":
			draw_arc(effect_pos, 34, -0.8, 0.8, 12, Color("e1f5fe", 0.85), 7)
		elif service_mode == &"perfume":
			draw_circle(effect_pos, 14 + i % 3 * 4, Color("ce93d8", 0.62))
		else:
			# Styling uses soft ribbon glints; stars remain exclusive to special rewards.
			draw_circle(effect_pos, 8 + i % 3 * 3, Color("ff8fb1", 0.78))
			draw_arc(effect_pos, 18 + i % 3 * 2, -0.7, 0.7, 8, Color("ffffff", 0.8), 3)
	for particle: Dictionary in bubbles:
		var particle_alpha: float = clampf(float(particle["life"]), 0.0, 0.75)
		if service_mode == &"bath":
			var bubble_foam: Color = _bath_foam_color()
			draw_circle(
				particle["p"], particle["r"], Color(bubble_foam.lightened(0.35), particle_alpha)
			)
			draw_arc(particle["p"], particle["r"], 0, TAU, 18, bubble_foam.darkened(0.3), 3)
		elif service_mode == &"groom":
			var tuft_size: float = float(particle["r"]) * 0.7
			var tuft_color: Color = fur_color
			tuft_color.a = particle_alpha
			draw_line(
				particle["p"] - Vector2(tuft_size, 8),
				particle["p"] + Vector2(tuft_size, -8),
				tuft_color,
				6
			)
		elif service_mode == &"dry":
			draw_line(
				particle["p"] - Vector2(42, 0),
				particle["p"] + Vector2(24, 0),
				Color("e1f5fe", particle_alpha),
				6
			)
		elif service_mode == &"perfume":
			draw_circle(particle["p"], float(particle["r"]) * 0.55, Color("ce93d8", particle_alpha))
		else:
			draw_circle(particle["p"], float(particle["r"]) * 0.45, Color("ff8fb1", particle_alpha))
	for heart: Dictionary in hearts:
		_draw_heart(
			heart["p"],
			float(heart["size"]),
			Color("ff6f91", clampf(float(heart["life"]), 0.0, 1.0))
		)
	if tool_visible and service_active:
		_draw_tool(active_tool, tool_position, 1.0, true)
		# Aro de dosagem: faixa verde fixa = janela do Perfect; o preenchimento
		# cru avança com a esfregada e soltar decide a qualidade (sem auto-complete).
		var band_min: float = RemoteConfig.get_float("bath_target_min")
		var band_max: float = RemoteConfig.get_float("bath_target_max")
		var fill: float = clampf(progress, 0.0, 1.0)
		draw_arc(tool_position, 66.0, 0.0, TAU, 40, Color("263238", 0.25), 6.0)
		draw_arc(
			tool_position,
			66.0,
			-PI / 2.0 + TAU * band_min,
			-PI / 2.0 + TAU * band_max,
			40,
			Color("7ed957", 0.5),
			14.0,
		)
		var ring_color: Color = Color.WHITE
		if fill > band_max:
			ring_color = Color("ef5350")
		elif fill >= band_min:
			ring_color = Color("7ed957")
		elif fill >= 0.62:
			ring_color = Color("ffd54f")
		if fill > 0.005:
			draw_arc(tool_position, 66.0, -PI / 2.0, -PI / 2.0 + TAU * fill, 40, ring_color, 10.0)
	if service_active:
		# Barra de paciência (tempo restante do atendimento).
		var patience_rect: Rect2 = Rect2(270, 128, 540, 14)
		draw_rect(patience_rect, Color("263238", 0.55))
		var patience_ratio: float = clampf(service_time_ratio, 0.0, 1.0)
		var patience_fill: Vector2 = Vector2(
			patience_rect.size.x * patience_ratio, patience_rect.size.y
		)
		var patience_color: Color = Color("7ed957")
		if patience_ratio <= 0.25:
			patience_color = Color("ef5350")
		elif patience_ratio <= 0.5:
			patience_color = Color("ffd54f")
		draw_rect(Rect2(patience_rect.position, patience_fill), patience_color)
	if celebration > 0.0 and special_reward_active:
		for i: int in 14:
			var angle: float = TAU * float(i) / 14.0 + shake_phase
			var star_pos: Vector2 = (
				pet_position
				+ Vector2(cos(angle), sin(angle))
					* (190.0 + beat_pulse * 26.0 + 12.0 * sin(shake_phase * 6.0 + i))
			)
			_star(star_pos, 18.0, Color("ffd54f" if i % 2 == 0 else "ff8fb1"))
	if rush_active:
		# Pico do bairro (onda 2): faixa dourada pulsante no topo da cena.
		var rush_glow: float = 0.42 + 0.18 * sin(shake_phase * 5.0)
		draw_rect(Rect2(0.0, 0.0, 1080.0, 22.0), Color("ffb300", rush_glow))
		draw_rect(Rect2(0.0, 22.0, 1080.0, 8.0), Color("ffd54f", 0.28))
		draw_rect(Rect2(0.0, 0.0, 1080.0, 1920.0), Color("ffd54f", 0.04))


func _draw_pet(center: Vector2) -> void:
	if is_instance_valid(pet_texture):
		_draw_illustrated_pet(center)
		return
	# Fallback vetorial: center é a âncora dos pés; o corpo é desenhado acima.
	center += Vector2(0.0, -170.0)
	var fur: Color = fur_color if not pet_wet else fur_color.darkened(0.24)
	# Cauda reage continuamente e torna cães/gatos legíveis pela silhueta.
	var wag: float = sin(shake_phase * (9.0 if pet_happy else 3.0)) * 0.35
	if species == &"cat":
		draw_arc(center + Vector2(125, 105), 105, -1.4 + wag, 1.1 + wag, 20, fur, 24)
	else:
		draw_arc(center + Vector2(125, 100), 82, -1.2 + wag, 0.7 + wag, 16, fur, 30)
	# Corpo, cabeça e contorno com peso compatível com a ilustração do ambiente.
	var small_breed: bool = _breed_contains_any(
		["Pinscher", "Yorkshire", "Pug", "Maltês", "Munchkin"]
	)
	var large_breed: bool = _breed_contains_any(
		["Golden", "Labrador", "Samoieda", "Bernês", "Maine Coon"]
	)
	var body_scale: float = 0.84 if small_breed else (1.12 if large_breed else 1.0)
	_draw_pet_ellipse(center + Vector2(8, 226), Vector2(154 * body_scale, 38), Color("263238", 0.2))
	_draw_pet_ellipse(
		center + Vector2(0, 105), Vector2(158 * body_scale, 133 * body_scale), fur.darkened(0.55)
	)
	_draw_pet_ellipse(center + Vector2(0, 105), Vector2(150 * body_scale, 125 * body_scale), fur)
	draw_circle(center, 153, fur.darkened(0.55))
	draw_circle(center, 145, fur)
	draw_arc(center + Vector2(-25, -35), 92, 3.65, 5.05, 18, fur.lightened(0.16), 13)
	var ear_drop: float = 35.0 if pet_wet else 0.0
	if species == &"cat":
		draw_colored_polygon(
			PackedVector2Array(
				[
					center + Vector2(-122, -78),
					center + Vector2(-92, -190 + ear_drop),
					center + Vector2(-24, -125),
				]
			),
			ear_color
		)
		draw_colored_polygon(
			PackedVector2Array(
				[
					center + Vector2(122, -78),
					center + Vector2(92, -190 + ear_drop),
					center + Vector2(24, -125),
				]
			),
			ear_color
		)
		draw_arc(center + Vector2(-120, 58), 74, -0.4, 0.5, 12, Color("263238"), 4)
		draw_arc(center + Vector2(120, 58), 74, PI - 0.5, PI + 0.4, 12, Color("263238"), 4)
	else:
		var upright_ears: bool = _breed_contains_any(
			["Husky", "Akita", "Corgi", "Spitz", "Doberman", "Pinscher"]
		)
		if upright_ears:
			draw_colored_polygon(
				PackedVector2Array(
					[
						center + Vector2(-125, -75),
						center + Vector2(-100, -195 + ear_drop),
						center + Vector2(-30, -120)
					]
				),
				ear_color
			)
			draw_colored_polygon(
				PackedVector2Array(
					[
						center + Vector2(125, -75),
						center + Vector2(100, -195 + ear_drop),
						center + Vector2(30, -120)
					]
				),
				ear_color
			)
		else:
			var ear_width: float = (
				225.0 if _breed_contains_any(["Basset", "Beagle", "Dachshund"]) else 190.0
			)
			draw_colored_polygon(
				PackedVector2Array(
					[
						center + Vector2(-105, -80),
						center + Vector2(-ear_width, -55 + ear_drop),
						center + Vector2(-140, 85)
					]
				),
				ear_color
			)
			draw_colored_polygon(
				PackedVector2Array(
					[
						center + Vector2(105, -80),
						center + Vector2(ear_width, -55 + ear_drop),
						center + Vector2(140, 85)
					]
				),
				ear_color
			)
	if (
		breed_name.contains("Poodle")
		or breed_name.contains("Samoieda")
		or breed_name.contains("Maine Coon")
	):
		for curl: int in 8:
			var curl_angle: float = TAU * curl / 8.0
			draw_circle(
				center + Vector2(cos(curl_angle), sin(curl_angle)) * 140.0, 28, fur.lightened(0.08)
			)
	if reaction_kind == &"dizzy":
		for eye_x: float in [-52.0, 52.0]:
			draw_line(
				center + Vector2(eye_x - 12.0, -34.0),
				center + Vector2(eye_x + 12.0, -10.0),
				Color("263238"),
				7,
			)
			draw_line(
				center + Vector2(eye_x + 12.0, -34.0),
				center + Vector2(eye_x - 12.0, -10.0),
				Color("263238"),
				7,
			)
	elif reaction_kind == &"blink":
		draw_line(center + Vector2(-70, -20), center + Vector2(-36, -20), Color("263238"), 8)
		draw_line(center + Vector2(36, -20), center + Vector2(70, -20), Color("263238"), 8)
	else:
		draw_circle(center + Vector2(-52, -22), 17, Color("263238"))
		draw_circle(center + Vector2(52, -22), 17, Color("263238"))
		draw_circle(center + Vector2(-46, -29), 5, Color.WHITE)
		draw_circle(center + Vector2(58, -29), 5, Color.WHITE)
	_draw_pet_ellipse(center + Vector2(0, 38), Vector2(67, 55), muzzle_color)
	if species == &"cat":
		for side: float in [-1.0, 1.0]:
			for row: int in 3:
				draw_line(
					center + Vector2(side * 42.0, 43.0 + row * 12.0),
					center + Vector2(side * (105.0 + row * 7.0), 34.0 + row * 17.0),
					Color("263238", 0.72),
					3,
				)
	draw_circle(center + Vector2(0, 20), 20, Color("263238"))
	if pet_happy:
		draw_arc(center + Vector2(0, 52), 38, 0.12, PI - 0.12, 22, Color("263238"), 8)
		draw_circle(center + Vector2(0, 87), 17, Color("ff6f91"))
	else:
		draw_arc(center + Vector2(0, 68), 28, PI + 0.2, TAU - 0.2, 18, Color("263238"), 7)
	draw_circle(center + Vector2(-92, 28), 17, Color("ff8fb1", 0.42))
	draw_circle(center + Vector2(92, 28), 17, Color("ff8fb1", 0.42))
	_draw_pet_accessories(center, 1.0, false)


func _draw_illustrated_pet(center: Vector2) -> void:
	var small_breed: bool = _breed_contains_any(
		["Pinscher", "Yorkshire", "Pug", "Maltês", "Munchkin", "Shih-tzu"]
	)
	var large_breed: bool = _breed_contains_any(
		["Golden", "Labrador", "Samoieda", "Bernês", "Maine Coon"]
	)
	var sprite_size: float = 390.0
	if small_breed:
		sprite_size = 330.0
	elif large_breed:
		sprite_size = 445.0

	# pet_position é a âncora dos PÉS: o centro recebido já está na superfície
	# da estação e a deformação (squash/breath) pivota nesse ponto.
	var foot_anchor: Vector2 = center
	var breathe_x: float = 1.0 - sin(shake_phase * 2.2) * 0.004
	var breathe_y: float = 1.0 + sin(shake_phase * 2.2) * 0.012
	var reaction_scale: Vector2 = Vector2(breathe_x, breathe_y)
	var spin: float = 0.0
	var jump_height: float = 0.0
	var overlay_state: StringName = &""
	var overlay_alpha: float = 0.0
	var second_state: StringName = &""
	var second_alpha: float = 0.0

	if forced_state != &"" and forced_state_time > 0.0:
		# Consequência visível (onda 1): exagero = tonto, tempo esgotado =
		# triste, sequência perfeita = feliz. O pet REAGE ao jeito de jogar.
		overlay_state = forced_state
		overlay_alpha = clampf(forced_state_time, 0.0, 1.0)
		if forced_state == &"dizzy":
			foot_anchor.x += sin(shake_phase * 30.0) * 6.0
			spin = sin(shake_phase * 16.0) * 0.02
		elif forced_state == &"happy_squash":
			jump_height = abs(sin(shake_phase * 8.0)) * 20.0
	elif playful_hop:
		overlay_state = &"happy_air"
		overlay_alpha = 0.9
		jump_height = 34.0
	elif celebration > 0.0:
		var celebration_phase: float = 1.0 - celebration / 1.8
		if celebration_phase < 0.2:
			overlay_state = &"happy_squash"
			overlay_alpha = smoothstep(0.0, 0.08, celebration_phase)
		elif celebration_phase < 0.72:
			overlay_state = &"happy_air"
			overlay_alpha = 1.0 - smoothstep(0.62, 0.72, celebration_phase)
			jump_height = sin(PI * (celebration_phase - 0.2) / 0.52) * 72.0
		else:
			overlay_state = &"happy_squash"
			overlay_alpha = 1.0 - smoothstep(0.72, 0.9, celebration_phase)
	elif reaction_kind == &"sad":
		overlay_state = &"sad"
		overlay_alpha = minf(1.0, reaction_time * 3.0)
		reaction_scale += Vector2(0.018, -0.035)
	elif reaction_kind == &"dizzy":
		overlay_state = &"dizzy"
		overlay_alpha = minf(1.0, reaction_time * 4.0)
		foot_anchor.x += sin(shake_phase * 32.0) * 7.0
		spin = sin(shake_phase * 18.0) * 0.025
	elif reaction_kind == &"blink":
		# Piscada não substitui mais o estado atual: vira pulso da camada
		# independente, que escolhe a variante certa (molhado pisca molhado).
		blink_force_time = maxf(blink_force_time, 0.22)
	elif reaction_kind == &"love" or reaction_kind == &"excited":
		overlay_state = &"happy_squash"
		overlay_alpha = minf(1.0, reaction_time * 4.0)
		jump_height = abs(sin(shake_phase * 8.0)) * 18.0
	elif service_active:
		if service_mode == &"bath":
			overlay_state = &"dirty"
			overlay_alpha = 1.0 - smoothstep(0.05, 0.36, progress)
			second_state = &"wet"
			second_alpha = smoothstep(0.12, 0.38, progress)
		elif service_mode == &"groom":
			overlay_state = &"messy"
			overlay_alpha = 1.0 - smoothstep(0.08, 0.92, progress)
		elif service_mode == &"dry":
			overlay_state = &"wet"
			overlay_alpha = 1.0 - smoothstep(0.08, 0.95, progress)
	elif condition_release > 0.0:
		overlay_state = &"wet"
		overlay_alpha = condition_release
	elif not service_condition_complete and service_mode == &"bath":
		overlay_state = &"dirty"
		overlay_alpha = 1.0
	elif not service_condition_complete and service_mode == &"groom":
		overlay_state = &"messy"
		overlay_alpha = 1.0
	elif not service_condition_complete and service_mode == &"dry":
		overlay_state = &"wet"
		overlay_alpha = 1.0
	else:
		var idle_phase: float = fmod(shake_phase, 8.0)
		if idle_phase >= 1.2 and idle_phase < 2.8:
			overlay_state = &"tilt_left"
			overlay_alpha = sin(PI * (idle_phase - 1.2) / 1.6)
		elif idle_phase >= 4.6 and idle_phase < 6.2:
			overlay_state = &"tilt_right"
			overlay_alpha = sin(PI * (idle_phase - 4.6) / 1.6)
		# A piscada de idle saiu daqui: a camada global de blink cobre o idle.

	# Authored expressions receive a small runtime deformation so weight reads between keyframes.
	if overlay_state == &"happy_squash":
		reaction_scale = reaction_scale * Vector2(1.045, 0.94)
	elif overlay_state == &"happy_air":
		reaction_scale = reaction_scale * Vector2(0.97, 1.035)

	# Piscada global: camada independente por cima de qualquer estado, com a
	# variante do estado dominante (pet molhado pisca molhado; seco pisca seco).
	# Sem variante disponível para o estado ativo, não pisca (evita o flash do
	# sprite seco por cima do molhado/sujo/peludo).
	var blink_pulse: float = 0.0
	if blink_force_time > 0.0:
		blink_pulse = minf(1.0, blink_force_time * 6.0)
	elif overlay_state not in [&"happy_squash", &"happy_air"]:
		var blink_phase: float = fmod(shake_phase + blink_offset, 4.7)
		if blink_phase < 0.13:
			blink_pulse = sin(PI * blink_phase / 0.13)
	var blink_layer: StringName = &"blink"
	if blink_pulse > 0.0:
		var dominant: StringName = (
			overlay_state if overlay_alpha >= second_alpha else second_state
		)
		if dominant in [&"wet", &"dirty", &"messy", &"sad", &"dizzy"]:
			var blink_variant: StringName = StringName(String(dominant) + "_blink")
			if pet_state_textures.has(blink_variant):
				blink_layer = blink_variant
			else:
				blink_pulse = 0.0

	var tint: Color = Color.WHITE
	if pet_wet or overlay_state == &"wet" or second_state == &"wet":
		tint = Color("d5edf4")
	if reaction_kind == &"sad":
		tint = tint.darkened(0.18 * minf(1.0, reaction_time * 2.0))

	foot_anchor.y -= jump_height
	draw_set_transform(foot_anchor, spin, reaction_scale)
	# A base seca só preenche o que nenhum estado cobre: os sprites de estado
	# têm poses próprias (orelhas/cauda deslocadas) e, com a base sempre ativa
	# por baixo, ela "vazava" pelas bordas transparentes do estado — duas
	# imagens sobrepostas na mesma ação. Alpha residual = 1 - soma dos estados.
	var covered_alpha: float = 0.0
	if not overlay_state.is_empty() and pet_state_textures.has(overlay_state):
		covered_alpha += clampf(overlay_alpha, 0.0, 1.0)
	if not second_state.is_empty() and pet_state_textures.has(second_state):
		covered_alpha += clampf(second_alpha, 0.0, 1.0)
	var base_alpha: float = clampf(1.0 - covered_alpha, 0.0, 1.0)
	var base_tint: Color = tint
	base_tint.a *= base_alpha
	_draw_pet_texture_layer(pet_texture, sprite_size, base_tint)
	_draw_pet_state_layer(overlay_state, overlay_alpha, sprite_size, tint)
	_draw_pet_state_layer(second_state, second_alpha, sprite_size, Color("c8e8f3"))
	_draw_pet_state_layer(blink_layer, blink_pulse, sprite_size, tint)
	_draw_pet_accessories(Vector2.ZERO, sprite_size / 390.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pet_texture_layer(
	texture: Texture2D, sprite_size: float, tint: Color = Color.WHITE
) -> void:
	if not is_instance_valid(texture) or tint.a <= 0.0:
		return
	draw_texture_rect(
		texture,
		Rect2(-sprite_size * 0.5, -sprite_size * PET_TEXTURE_BASELINE, sprite_size, sprite_size),
		false,
		tint,
	)


func _draw_pet_state_layer(
	state_name: StringName, alpha: float, sprite_size: float, tint: Color = Color.WHITE
) -> void:
	if state_name.is_empty() or alpha <= 0.0 or not pet_state_textures.has(state_name):
		return
	var layer_tint: Color = tint
	layer_tint.a *= clampf(alpha, 0.0, 1.0)
	_draw_pet_texture_layer(pet_state_textures[state_name] as Texture2D, sprite_size, layer_tint)


func _breed_contains_any(labels: Array[String]) -> bool:
	for label: String in labels:
		if breed_name.contains(label):
			return true
	return false


func _draw_pet_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 32:
		var angle: float = TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _box(color: Color, radius: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = int(radius)
	box.corner_radius_top_right = int(radius)
	box.corner_radius_bottom_left = int(radius)
	box.corner_radius_bottom_right = int(radius)
	return box


func _draw_tool_shelf() -> void:
	# As prateleiras pertencem à arte raster; aqui são desenhados somente utensílios interativos.
	for tool: StringName in TOOL_ORDER:
		var unlocked: bool = player_level >= int(TOOL_LEVELS[tool])
		var shelf_alpha: float = (
			0.12 if tool_visible and tool == active_tool else (1.0 if unlocked else 0.28)
		)
		var shelf_position: Vector2 = _tool_position(tool)
		_draw_tool(tool, shelf_position, shelf_alpha)
		if not unlocked:
			draw_circle(shelf_position, 29, Color("263238", 0.76))
			draw_string(
				UI_TITLE_FONT,
				shelf_position + Vector2(-28, 10),
				"Nv.%d" % int(TOOL_LEVELS[tool]),
				HORIZONTAL_ALIGNMENT_CENTER,
				56,
				20,
				Color.WHITE,
			)


func _draw_tool(tool: StringName, at: Vector2, alpha: float, is_dragged: bool = false) -> void:
	if not TOOL_TEXTURES.has(tool):
		return
	var texture: Texture2D = TOOL_TEXTURES[tool]
	var bob: float = (
		sin(shake_phase * 2.4 + float(String(tool).hash() % 7)) * (4.0 if is_dragged else 2.0)
	)
	var spin: float = sin(shake_phase * 4.8) * 0.055 if is_dragged else 0.0
	var active_pulse: float = 1.0 + sin(shake_phase * 6.0) * 0.025 if is_dragged else 1.0
	var draw_size: float = (138.0 if is_dragged else 116.0) * active_pulse
	var item_modulate: Color = Color(1.0, 1.0, 1.0, alpha)
	draw_set_transform(at + Vector2(0, bob), spin)
	draw_texture_rect(
		texture,
		Rect2(-draw_size * 0.5, -draw_size * 0.5, draw_size, draw_size),
		false,
		item_modulate
	)
	if is_dragged:
		draw_arc(Vector2.ZERO, draw_size * 0.48, -2.7, -0.45, 20, Color("ffffff", 0.38), 4.0)
	# Maestria (onda 3): aro prata no marco 10, ouro no 20 — progresso visível.
	var milestone: int = 0
	var tool_level: int = int(tool_levels.get(String(tool), 0))
	if tool_level >= 20:
		milestone = 2
	elif tool_level >= 10:
		milestone = 1
	if milestone > 0:
		draw_arc(
			Vector2.ZERO,
			draw_size * 0.56,
			0.0,
			TAU,
			36,
			Color("ffd54f", 0.9) if milestone == 2 else Color("cfd8dc", 0.9),
			5.0
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Três corações de marcos de afeto (10/25/50) flutuando sobre o pet: o jogador
## vê o laço crescer na própria cena, não só num toast.
func _draw_affection_hearts(body_center: Vector2) -> void:
	var thresholds: Array[int] = [10, 25, 50]
	for i: int in 3:
		var filled: bool = affection_level >= thresholds[i]
		var heart_center: Vector2 = (
			body_center + Vector2(float(i - 1) * 62.0, -268.0)
		)
		_draw_heart(
			heart_center, 20.0, Color("ff8fb1") if filled else Color("263238", 0.18)
		)


func _draw_heart(center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in 24:
		var angle: float = TAU * float(index) / 24.0
		var x: float = 16.0 * pow(sin(angle), 3.0)
		var y: float = -(
			13.0 * cos(angle) - 5.0 * cos(2.0 * angle) - 2.0 * cos(3.0 * angle) - cos(4.0 * angle)
		)
		points.append(center + Vector2(x, y) * radius / 18.0)
	draw_colored_polygon(points, color)


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var r: float = radius if i % 2 == 0 else radius * 0.42
		var angle: float = -PI / 2.0 + float(i) * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)

