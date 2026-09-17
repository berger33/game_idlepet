class_name PetShopCanvas
extends Control
## Cenário ilustrado + personagens/VFX vetoriais em runtime.

const BATH_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_quintal.png")
const GROOM_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_tosa.png")
const DRY_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_secagem.png")
const PERFUME_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_perfume.png")
const STYLE_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_estilo.png")
const TOOL_LEVELS: Dictionary = {&"soap": 1, &"clipper": 3, &"dryer": 5, &"perfume": 7, &"bow": 10}
const TOOL_POSITIONS: Dictionary = {
	&"soap": Vector2(910, 500),
	&"clipper": Vector2(910, 650),
	&"dryer": Vector2(910, 800),
	&"perfume": Vector2(910, 950),
	&"bow": Vector2(910, 1100),
}

var pet_position: Vector2 = Vector2(540, 930)
var pet_happy: bool = false
var pet_wet: bool = false
var progress: float = 0.0
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
var breed_name: String = "Vira-lata caramelo"
var temperament: StringName = &"happy"
var rarity: StringName = &"common"
var reaction_time: float = 0.0
var reaction_kind: StringName = &"idle"
var hearts: Array[Dictionary] = []
var player_level: int = 1
var active_tool: StringName = &""
var tool_position: Vector2 = Vector2.ZERO
var tool_visible: bool = false


func _ready() -> void:
	level_box = _box(Color("ffd54f", 0.94), 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	shake_phase += delta
	arrival_time = minf(1.0, arrival_time + delta * 2.8)
	celebration = maxf(0.0, celebration - delta)
	reaction_time = maxf(0.0, reaction_time - delta)
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


func celebrate() -> void:
	pet_happy = true
	celebration = 1.8


func set_pet_profile(profile: Dictionary) -> void:
	var colors: Array = profile.get("colors", ["c98b5b", "9c623f", "f1c49f"])
	if colors.size() >= 3:
		fur_color = Color(String(colors[0]))
		ear_color = Color(String(colors[1]))
		muzzle_color = Color(String(colors[2]))
	species = StringName(profile.get("species", "dog"))
	breed_name = String(profile.get("breed", "Pet especial"))
	temperament = StringName(profile.get("temperament", "happy"))
	rarity = StringName(profile.get("rarity", "common"))


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
					pet_position + Vector2(-65.0 + index * 65.0, -130.0 - abs(index - 1) * 22.0),
					"life": 0.9 + index * 0.12,
					"size": 16.0 + index * 3.0,
				}
			)
		)
	return reactions[randi() % reactions.size()]


func react_to_service(service_progress: float) -> void:
	if service_progress > 0.96:
		reaction_kind = &"dizzy"
		pet_happy = false
	elif service_progress > 0.78:
		reaction_kind = &"excited"
		pet_happy = true
	else:
		reaction_kind = &"blink" if int(service_progress * 20.0) % 5 == 0 else &"focused"
		pet_happy = false
	reaction_time = 0.22


func tool_at(point: Vector2) -> StringName:
	for tool: StringName in TOOL_POSITIONS:
		if (
			player_level >= int(TOOL_LEVELS[tool])
			and point.distance_to(TOOL_POSITIONS[tool]) < 72.0
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


func release_tool() -> void:
	tool_visible = false
	active_tool = &""


func react_to_failure() -> void:
	tool_visible = false
	reaction_kind = &"sad"
	reaction_time = 1.5
	pet_happy = false


func arrive() -> void:
	arrival_time = 0.0
	pet_happy = false


func reset_pet() -> void:
	pet_happy = false
	pet_wet = false
	progress = 0.0
	tool_visible = false
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
	var room_title: String = (
		{
			&"bath": "BANHO DO BAIRRO",
			&"groom": "TOSA DO BAIRRO",
			&"dry": "SECAGEM ACONCHEGANTE",
			&"perfume": "SPA PERFUMADO",
			&"style": "ATELIÊ DE LAÇOS",
		}
		. get(service_mode, "PET SHOP DO BAIRRO")
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(430, 225),
		room_title,
		HORIZONTAL_ALIGNMENT_CENTER,
		500,
		42,
		Color.WHITE
	)
	_draw_tool_shelf()
	# O selo de estação é informativo; elementos que parecem botões não são desenhados no cenário.
	if upgrade_level > 0:
		draw_style_box(level_box, Rect2(70, 500, 250, 78))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(95, 552),
			"ESTAÇÃO  Nv.%d" % upgrade_level,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			28,
			Color("263238")
		)
	# Pet entra com antecipação lateral e passa a reagir no centro da estação.
	var bounce: float = sin(shake_phase * 5.0) * (7.0 if pet_happy else 2.0)
	var eased_arrival: float = 1.0 - pow(1.0 - arrival_time, 3.0)
	var pet_center: Vector2 = pet_position + Vector2((1.0 - eased_arrival) * -430.0, bounce)
	if rarity == &"legendary":
		draw_circle(pet_center, 205.0 + sin(shake_phase * 3.0) * 8.0, Color("ffd54f", 0.22))
		draw_arc(pet_center, 190.0, 0, TAU, 40, Color("ffd54f", 0.8), 7)
	elif rarity == &"epic":
		draw_circle(pet_center, 185.0, Color("ce93d8", 0.16))
	_draw_pet(pet_center)
	# Espuma ou tufos respondem à mecânica ativa.
	var effect_count: int = int(progress * 18.0)
	for i: int in effect_count:
		var angle: float = float(i) * 2.4
		var radius: float = 70.0 + float(i % 5) * 23.0
		var effect_pos: Vector2 = (
			pet_position + Vector2(cos(angle), sin(angle) * 0.5) * radius + Vector2(0, 70)
		)
		if service_mode == &"bath":
			draw_circle(effect_pos, 30 + (i % 3) * 6, Color("f8ffff", 0.95))
			draw_arc(effect_pos, 25 + (i % 3) * 6, 0, TAU, 20, Color("b5ecfa"), 4)
		elif service_mode == &"groom":
			draw_line(effect_pos - Vector2(14, 10), effect_pos + Vector2(14, 10), ear_color, 8)
			draw_line(effect_pos + Vector2(-12, 12), effect_pos + Vector2(12, -12), fur_color, 6)
		elif service_mode == &"dry":
			draw_arc(effect_pos, 34, -0.8, 0.8, 12, Color("e1f5fe", 0.85), 7)
		elif service_mode == &"perfume":
			draw_circle(effect_pos, 14 + i % 3 * 4, Color("ce93d8", 0.62))
		else:
			_star(effect_pos, 16 + i % 3 * 3, Color("ffd54f", 0.9))
	for particle: Dictionary in bubbles:
		var particle_alpha: float = clampf(float(particle["life"]), 0.0, 0.75)
		if service_mode == &"bath":
			draw_circle(particle["p"], particle["r"], Color("e9fbff", particle_alpha))
			draw_arc(particle["p"], particle["r"], 0, TAU, 18, Color("4fc3f7", 0.65), 3)
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
			_star(particle["p"], float(particle["r"]), Color("ffd54f", particle_alpha))
	for heart: Dictionary in hearts:
		_draw_heart(
			heart["p"],
			float(heart["size"]),
			Color("ff6f91", clampf(float(heart["life"]), 0.0, 1.0))
		)
	if tool_visible:
		_draw_tool(active_tool, tool_position, 1.0)
		var ring_color: Color = Color("7ed957") if progress >= 0.72 else Color("ffffff")
		draw_arc(tool_position, 66.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, ring_color, 11.0)
		draw_arc(tool_position, 66.0, 0.0, TAU, 40, Color("263238", 0.22), 4.0)
	if celebration > 0.0:
		for i: int in 14:
			var angle: float = TAU * float(i) / 14.0 + shake_phase
			var star_pos: Vector2 = (
				pet_position
				+ Vector2(cos(angle), sin(angle)) * (190.0 + 35.0 * sin(shake_phase * 6.0 + i))
			)
			_star(star_pos, 18.0, Color("ffd54f" if i % 2 == 0 else "ff8fb1"))


func _draw_pet(center: Vector2) -> void:
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
	for tool: StringName in TOOL_POSITIONS:
		var unlocked: bool = player_level >= int(TOOL_LEVELS[tool])
		var shelf_alpha: float = (
			0.12 if tool_visible and tool == active_tool else (1.0 if unlocked else 0.28)
		)
		_draw_tool(tool, TOOL_POSITIONS[tool], shelf_alpha)
		if not unlocked:
			draw_circle(TOOL_POSITIONS[tool], 29, Color("263238", 0.76))
			draw_string(
				ThemeDB.fallback_font,
				TOOL_POSITIONS[tool] + Vector2(-28, 10),
				"Nv.%d" % int(TOOL_LEVELS[tool]),
				HORIZONTAL_ALIGNMENT_CENTER,
				56,
				20,
				Color.WHITE,
			)


func _draw_tool(tool: StringName, at: Vector2, alpha: float) -> void:
	var pink: Color = Color("ff8fb1", alpha)
	var blue: Color = Color("4fc3f7", alpha)
	var dark: Color = Color("263238", alpha)
	var white: Color = Color("f8ffff", alpha)
	var shadow: Color = Color("263238", alpha * 0.24)
	_draw_pet_ellipse(at + Vector2(7, 11), Vector2(52, 44), shadow)
	if tool == &"soap":
		_draw_pet_ellipse(at + Vector2(0, 5), Vector2(39, 47), dark)
		_draw_pet_ellipse(at + Vector2(0, 4), Vector2(34, 42), pink)
		draw_rect(Rect2(at + Vector2(-12, -55), Vector2(24, 18)), dark, true)
		draw_line(at + Vector2(0, -55), at + Vector2(29, -55), dark, 8)
		draw_circle(at + Vector2(-11, -8), 9, Color("ffffff", alpha * 0.7))
		draw_arc(at + Vector2(0, 5), 27, 0, TAU, 24, white, 4)
	elif tool == &"clipper":
		draw_rect(Rect2(at + Vector2(-31, -49), Vector2(62, 90)), dark, true)
		draw_rect(Rect2(at + Vector2(-27, -45), Vector2(54, 82)), blue, true)
		draw_rect(Rect2(at + Vector2(-38, -58), Vector2(76, 18)), Color("b0bec5", alpha), true)
		for tooth: int in 6:
			draw_line(
				at + Vector2(-32 + tooth * 13, -58), at + Vector2(-32 + tooth * 13, -73), dark, 4
			)
	elif tool == &"dryer":
		draw_circle(at + Vector2(-10, -8), 43, dark)
		draw_circle(at + Vector2(-10, -8), 38, pink)
		draw_circle(at + Vector2(-18, -16), 11, Color("ffffff", alpha * 0.55))
		draw_colored_polygon(
			PackedVector2Array(
				[
					at + Vector2(14, -27),
					at + Vector2(65, -16),
					at + Vector2(65, 10),
					at + Vector2(14, 14)
				]
			),
			blue
		)
		draw_line(at + Vector2(-12, 20), at + Vector2(-30, 59), dark, 19)
	elif tool == &"perfume":
		_draw_pet_ellipse(at + Vector2(0, 17), Vector2(35, 40), dark)
		_draw_pet_ellipse(at + Vector2(0, 16), Vector2(30, 35), Color("ce93d8", alpha))
		draw_circle(at + Vector2(-10, 5), 8, Color("ffffff", alpha * 0.6))
		draw_rect(Rect2(at + Vector2(-20, -46), Vector2(40, 33)), dark, true)
		draw_rect(Rect2(at + Vector2(-16, -42), Vector2(32, 25)), Color("ffd54f", alpha), true)
		draw_line(at + Vector2(0, -42), at + Vector2(45, -50), dark, 8)
		for spray: int in 3:
			draw_circle(at + Vector2(62 + spray * 15, -52 - spray * 5), 5, Color("e1f5fe", alpha))
	else:
		draw_colored_polygon(
			PackedVector2Array([at, at + Vector2(-65, -44), at + Vector2(-62, 44)]), dark
		)
		draw_colored_polygon(
			PackedVector2Array([at, at + Vector2(65, -44), at + Vector2(62, 44)]), dark
		)
		draw_colored_polygon(
			PackedVector2Array([at, at + Vector2(-58, -38), at + Vector2(-55, 38)]), pink
		)
		draw_colored_polygon(
			PackedVector2Array([at, at + Vector2(58, -38), at + Vector2(55, 38)]), pink
		)
		draw_circle(at, 25, dark)
		draw_circle(at, 20, Color("ffd54f", alpha))
		draw_circle(at + Vector2(-7, -7), 6, Color("ffffff", alpha * 0.65))


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
