class_name PetShopCanvas
extends Control
## Cenário ilustrado + personagens/VFX vetoriais em runtime.

const BATH_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_quintal.png")
const GROOM_BACKGROUND: Texture2D = preload("res://art/backgrounds/petshop_tosa.png")

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
var queue_box: StyleBoxFlat
var level_box: StyleBoxFlat
var fur_color: Color = Color("c98b5b")
var ear_color: Color = Color("9c623f")
var muzzle_color: Color = Color("f1c49f")
var species: StringName = &"dog"
var temperament: StringName = &"happy"
var rarity: StringName = &"common"
var reaction_time: float = 0.0
var reaction_kind: StringName = &"idle"
var hearts: Array[Dictionary] = []
var tool_position: Vector2 = Vector2.ZERO
var tool_visible: bool = false


func _ready() -> void:
	queue_box = _box(Color("ffffff", 0.92), 28)
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


func release_tool() -> void:
	tool_visible = false


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
	var background: Texture2D = GROOM_BACKGROUND if service_mode == &"groom" else BATH_BACKGROUND
	var source_height: float = minf(981.0, background.get_height())
	draw_texture_rect_region(
		background,
		Rect2(Vector2.ZERO, size),
		Rect2(0.0, 0.0, float(background.get_width()), source_height)
	)
	# A placa da ilustração permanece sem texto; o título é localizado em runtime.
	var room_title: String = "TOSA DO BAIRRO" if service_mode == &"groom" else "BANHO DO BAIRRO"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(430, 225),
		room_title,
		HORIZONTAL_ALIGNMENT_CENTER,
		500,
		42,
		Color.WHITE
	)
	# Progressão visual e fila mantêm decisões visíveis sem abrir menus.
	draw_style_box(queue_box, Rect2(805, 315, 220, 92))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(830, 374),
		"FILA  2  ••",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		30,
		Color("263238")
	)
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
		else:
			draw_line(effect_pos - Vector2(14, 10), effect_pos + Vector2(14, 10), ear_color, 8)
			draw_line(effect_pos + Vector2(-12, 12), effect_pos + Vector2(12, -12), fur_color, 6)
	for particle: Dictionary in bubbles:
		var particle_alpha: float = clampf(float(particle["life"]), 0.0, 0.75)
		if service_mode == &"bath":
			draw_circle(particle["p"], particle["r"], Color("e9fbff", particle_alpha))
			draw_arc(particle["p"], particle["r"], 0, TAU, 18, Color("4fc3f7", 0.65), 3)
		else:
			var tuft_size: float = float(particle["r"]) * 0.7
			var tuft_color: Color = fur_color
			tuft_color.a = particle_alpha
			draw_line(
				particle["p"] - Vector2(tuft_size, tuft_size * 0.5),
				particle["p"] + Vector2(tuft_size, tuft_size * 0.5),
				tuft_color,
				6,
			)
	for heart: Dictionary in hearts:
		_draw_heart(
			heart["p"],
			float(heart["size"]),
			Color("ff6f91", clampf(float(heart["life"]), 0.0, 1.0))
		)
	if tool_visible:
		_draw_service_tool(tool_position)
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
	# Corpo, cabeça e orelhas.
	draw_ellipse(center + Vector2(0, 105), Vector2(150, 125), fur)
	draw_circle(center, 145, fur)
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
		draw_colored_polygon(
			PackedVector2Array(
				[
					center + Vector2(-105, -80),
					center + Vector2(-190, -55 + ear_drop),
					center + Vector2(-140, 85),
				]
			),
			ear_color
		)
		draw_colored_polygon(
			PackedVector2Array(
				[
					center + Vector2(105, -80),
					center + Vector2(190, -55 + ear_drop),
					center + Vector2(140, 85),
				]
			),
			ear_color
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
	draw_ellipse(center + Vector2(0, 38), Vector2(67, 55), muzzle_color)
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


func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
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


func _draw_service_tool(at: Vector2) -> void:
	if service_mode == &"bath":
		draw_rect(Rect2(at + Vector2(-34, -24), Vector2(68, 48)), Color("ff8fb1"))
		draw_circle(at + Vector2(25, -18), 13, Color("f8ffff", 0.95))
		draw_arc(at, 40, 0, TAU, 20, Color("ffffff", 0.8), 4)
	else:
		draw_rect(Rect2(at + Vector2(-25, -48), Vector2(50, 82)), Color("4fc3f7"))
		draw_rect(Rect2(at + Vector2(-34, -60), Vector2(68, 18)), Color("b0bec5"))
		for tooth: int in 5:
			draw_line(
				at + Vector2(-28 + tooth * 14, -60),
				at + Vector2(-28 + tooth * 14, -72),
				Color("263238"),
				3,
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
