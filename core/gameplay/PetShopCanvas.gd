class_name PetShopCanvas
extends Control
## Arte vetorial procedural coesa; substituível por atlas sem mudar gameplay.

var pet_position: Vector2 = Vector2(540, 930)
var pet_happy: bool = false
var pet_wet: bool = false
var progress: float = 0.0
var bubbles: Array[Dictionary] = []
var celebration: float = 0.0
var shake_phase: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func _process(delta: float) -> void:
    shake_phase += delta
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
    bubbles.append({"p": at + Vector2(randf_range(-35, 35), randf_range(-20, 20)), "r": randf_range(9, 23), "speed": randf_range(35, 80), "life": randf_range(0.5, 1.2)})

func celebrate() -> void:
    pet_happy = true
    celebration = 1.8

func reset_pet() -> void:
    pet_happy = false
    pet_wet = false
    progress = 0.0

func _draw() -> void:
    # Parede ensolarada e piso pseudo-isométrico.
    draw_rect(Rect2(0, 0, size.x, size.y), Color("fff3e0"))
    draw_circle(Vector2(130, 130), 210, Color("ffe0a3"))
    draw_rect(Rect2(0, 670, size.x, size.y - 670), Color("d9b89c"))
    for y: int in range(690, int(size.y), 120):
        draw_line(Vector2(0, y), Vector2(size.x, y), Color("c79e82"), 5)
    for x: int in range(-200, int(size.x) + 200, 220):
        draw_line(Vector2(x, 670), Vector2(x + 240, size.y), Color("c79e82", 0.5), 3)
    # Janela e plantas.
    _rounded(Rect2(75, 125, 300, 340), Color("4fc3f7"), 32)
    draw_circle(Vector2(165, 245), 65, Color("fff3bf", 0.85))
    draw_line(Vector2(225, 125), Vector2(225, 465), Color.WHITE, 18)
    draw_line(Vector2(75, 295), Vector2(375, 295), Color.WHITE, 18)
    _rounded(Rect2(735, 380, 230, 210), Color("8d6e63"), 28)
    draw_circle(Vector2(850, 370), 105, Color("7ed957"))
    draw_circle(Vector2(780, 410), 75, Color("63c947"))
    # Placa.
    _rounded(Rect2(410, 105, 560, 175), Color("ff8fb1"), 52)
    draw_string(ThemeDB.fallback_font, Vector2(475, 210), "BANHO DO BAIRRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color.WHITE)
    # Banheira.
    draw_set_transform(Vector2.ZERO)
    _rounded(Rect2(260, 780, 560, 390), Color("e8fbff"), 85)
    _rounded(Rect2(230, 760, 620, 115), Color("4fc3f7"), 50)
    draw_rect(Rect2(300, 1130, 70, 95), Color("8d6e63"))
    draw_rect(Rect2(710, 1130, 70, 95), Color("8d6e63"))
    draw_line(Vector2(750, 755), Vector2(750, 650), Color("90a4ae"), 26)
    draw_arc(Vector2(700, 650), 50, PI, TAU, 20, Color("90a4ae"), 25)
    # Pet.
    var bounce: float = sin(shake_phase * 5.0) * (7.0 if pet_happy else 2.0)
    _draw_pet(pet_position + Vector2(0, bounce))
    # Espuma progride visualmente.
    var foam_count: int = int(progress * 18.0)
    for i: int in foam_count:
        var angle: float = float(i) * 2.4
        var radius: float = 70.0 + float(i % 5) * 23.0
        draw_circle(pet_position + Vector2(cos(angle), sin(angle) * 0.5) * radius + Vector2(0, 70), 30 + (i % 3) * 6, Color("f8ffff", 0.95))
        draw_arc(pet_position + Vector2(cos(angle), sin(angle) * 0.5) * radius + Vector2(0, 70), 25 + (i % 3) * 6, 0, TAU, 20, Color("b5ecfa"), 4)
    for bubble: Dictionary in bubbles:
        draw_circle(bubble["p"], bubble["r"], Color("e9fbff", clampf(float(bubble["life"]), 0.0, 0.75)))
        draw_arc(bubble["p"], bubble["r"], 0, TAU, 18, Color("4fc3f7", 0.65), 3)
    if celebration > 0.0:
        for i: int in 14:
            var angle: float = TAU * float(i) / 14.0 + shake_phase
            var star_pos: Vector2 = pet_position + Vector2(cos(angle), sin(angle)) * (190.0 + 35.0 * sin(shake_phase * 6.0 + i))
            _star(star_pos, 18.0, Color("ffd54f" if i % 2 == 0 else "ff8fb1"))

func _draw_pet(center: Vector2) -> void:
    var fur: Color = Color("c98b5b") if not pet_wet else Color("986849")
    # Corpo, cabeça e orelhas de vira-lata caramelo.
    draw_ellipse(center + Vector2(0, 105), Vector2(150, 125), fur)
    draw_circle(center, 145, fur)
    var ear_drop: float = 35.0 if pet_wet else 0.0
    draw_colored_polygon(PackedVector2Array([center + Vector2(-105, -80), center + Vector2(-190, -55 + ear_drop), center + Vector2(-140, 85)]), Color("9c623f"))
    draw_colored_polygon(PackedVector2Array([center + Vector2(105, -80), center + Vector2(190, -55 + ear_drop), center + Vector2(140, 85)]), Color("9c623f"))
    draw_circle(center + Vector2(-52, -22), 17, Color("263238"))
    draw_circle(center + Vector2(52, -22), 17, Color("263238"))
    draw_circle(center + Vector2(-46, -29), 5, Color.WHITE)
    draw_circle(center + Vector2(58, -29), 5, Color.WHITE)
    draw_ellipse(center + Vector2(0, 38), Vector2(67, 55), Color("f1c49f"))
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

func _rounded(rect: Rect2, color: Color, radius: float) -> void:
    draw_style_box(_box(color, radius), rect)

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
