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


func _ready() -> void:
	queue_box = _box(Color("ffffff", 0.92), 28)
	level_box = _box(Color("ffd54f", 0.94), 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	shake_phase += delta
	arrival_time = minf(1.0, arrival_time + delta * 2.8)
	celebration = maxf(0.0, celebration - delta)
	for bubble: Dictionary in bubbles:
		bubble["p"] = bubble["p"] + Vector2(0, -float(bubble["speed"]) * delta)
		bubble["life"] = float(bubble["life"]) - delta
	for index: int in range(bubbles.size() - 1, -1, -1):
		if float(bubbles[index]["life"]) <= 0.0:
			bubbles.remove_at(index)
	queue_redraw()


func spawn_bubble(at: Vector2) -> void:
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


func set_pet_identity(pet_name: String) -> void:
	if pet_name == "Luna":
		fur_color = Color("f2dfcf")
		ear_color = Color("c9a58d")
		muzzle_color = Color("fff3e0")
	elif pet_name == "Thor":
		fur_color = Color("8d5a3b")
		ear_color = Color("5d4037")
		muzzle_color = Color("d8b08c")
	else:
		fur_color = Color("c98b5b")
		ear_color = Color("9c623f")
		muzzle_color = Color("f1c49f")


func arrive() -> void:
	arrival_time = 0.0
	pet_happy = false


func reset_pet() -> void:
	pet_happy = false
	pet_wet = false
	progress = 0.0


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
			draw_line(
				effect_pos - Vector2(14, 10), effect_pos + Vector2(14, 10), Color("9c623f"), 8
			)
			draw_line(
				effect_pos + Vector2(-12, 12), effect_pos + Vector2(12, -12), Color("c98b5b"), 6
			)
	for bubble: Dictionary in bubbles:
		draw_circle(
			bubble["p"], bubble["r"], Color("e9fbff", clampf(float(bubble["life"]), 0.0, 0.75))
		)
		draw_arc(bubble["p"], bubble["r"], 0, TAU, 18, Color("4fc3f7", 0.65), 3)
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
	# Corpo, cabeça e orelhas de vira-lata caramelo.
	draw_ellipse(center + Vector2(0, 105), Vector2(150, 125), fur)
	draw_circle(center, 145, fur)
	var ear_drop: float = 35.0 if pet_wet else 0.0
	draw_colored_polygon(
		PackedVector2Array(
			[
				center + Vector2(-105, -80),
				center + Vector2(-190, -55 + ear_drop),
				center + Vector2(-140, 85)
			]
		),
		ear_color
	)
	draw_colored_polygon(
		PackedVector2Array(
			[
				center + Vector2(105, -80),
				center + Vector2(190, -55 + ear_drop),
				center + Vector2(140, 85)
			]
		),
		ear_color
	)
	draw_circle(center + Vector2(-52, -22), 17, Color("263238"))
	draw_circle(center + Vector2(52, -22), 17, Color("263238"))
	draw_circle(center + Vector2(-46, -29), 5, Color.WHITE)
	draw_circle(center + Vector2(58, -29), 5, Color.WHITE)
	draw_ellipse(center + Vector2(0, 38), Vector2(67, 55), muzzle_color)
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


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var r: float = radius if i % 2 == 0 else radius * 0.42
		var angle: float = -PI / 2.0 + float(i) * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)
