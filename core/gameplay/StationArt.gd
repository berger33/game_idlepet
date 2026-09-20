class_name StationArt
extends RefCounted
## Mobiliário funcional desenhado por código: estante de utensílios, estação de
## trabalho por serviço e placa do título. Determinístico e idêntico em todos
## os cenários — o alinhamento pet/banheira e utensílio/prateleira nunca
## depende da arte do background (fonte única: data/service_layouts.json).
## pet_position.y é a ANCORA DOS PÉS: a superfície da estação fica nesse Y.

const WOOD: Color = Color("8d6e63")
const WOOD_LIGHT: Color = Color("a1887f")
const CREAM: Color = Color("fff3e0")
const CHARCOAL: Color = Color("263238")
const WATER_BLUE: Color = Color("4fc3f7")
const PINK: Color = Color("ff8fb1")
const METAL: Color = Color("90a4ae")

## Largura/altura das pranchas da estante (tool center y = prancha y - 34).
const PLANK_DROP: float = 34.0


static func _panel_box(
	color: Color, radius: float, border: Color = Color.TRANSPARENT, border_width: float = 0.0
) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = int(radius)
	box.corner_radius_top_right = int(radius)
	box.corner_radius_bottom_left = int(radius)
	box.corner_radius_bottom_right = int(radius)
	box.border_color = border
	box.border_width_left = int(border_width)
	box.border_width_right = int(border_width)
	box.border_width_top = int(border_width)
	box.border_width_bottom = int(border_width)
	return box


static func _ellipse(shop, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 32:
		var angle: float = TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	shop.draw_colored_polygon(points, color)


## Estante da direita: fundo creme translúcido + pranchas de madeira nas
## posições exatas dos utensílios (desenhada antes dos sprites das ferramentas).
static func draw_shelf_unit(shop) -> void:
	var levels: Array = shop.service_shelf_levels
	if levels.is_empty():
		return
	var top: float = float(levels[0]) + PLANK_DROP - 26.0
	var bottom: float = float(levels[levels.size() - 1]) + PLANK_DROP + 48.0
	var board: StyleBoxFlat = _panel_box(Color(CREAM, 0.42), 22, Color(CHARCOAL, 0.16), 3)
	shop.draw_style_box(board, Rect2(824, top, 192, bottom - top))
	for level: float in levels:
		var y: float = level + PLANK_DROP
		shop.draw_style_box(
			_panel_box(WOOD, 9, Color(CHARCOAL, 0.32), 3), Rect2(824, y, 192, 22)
		)
		shop.draw_line(Vector2(834.0, y + 4.0), Vector2(1006.0, y + 4.0), WOOD_LIGHT.lightened(0.22), 4)
		shop.draw_line(Vector2(834.0, y + 24.0), Vector2(1006.0, y + 24.0), Color(CHARCOAL, 0.16), 3)


## Placa de título da sala atrás do texto localizado desenhado pelo canvas.
static func draw_title_plaque(shop) -> void:
	shop.draw_style_box(
		_panel_box(Color(CREAM, 0.94), 26, PINK, 4), Rect2(320, 168, 450, 84)
	)
	shop.draw_line(Vector2(340, 178), Vector2(750, 178), Color(1.0, 1.0, 1.0, 0.5), 3)


## Estação de trabalho (desenhada ANTES do pet): sombra de contato + corpo.
static func draw_station(shop) -> void:
	if shop.room_empty:
		return
	var surface: float = shop.pet_position.y
	var cx: float = shop.pet_position.x
	_ellipse(shop, Vector2(cx, surface + 10), 216.0, 26.0, Color(CHARCOAL, 0.16))
	match shop.service_mode:
		&"bath":
			_draw_bathtub(shop, cx, surface)
		&"groom":
			_draw_groom_table(shop, cx, surface)
		&"dry":
			_draw_drying_table(shop, cx, surface)
		&"perfume":
			_draw_spa_pedestal(shop, cx, surface)
		&"style":
			_draw_ottoman(shop, cx, surface)


## Primeira plano da banheira (desenhada DEPOIS do pet): a borda frontal
## oclui as patas e vende a leitura "pet dentro da banheira".
static func draw_station_foreground(shop) -> void:
	if shop.room_empty or shop.service_mode != &"bath":
		return
	var surface: float = shop.pet_position.y
	var cx: float = shop.pet_position.x
	shop.draw_style_box(
		_panel_box(Color(CREAM, 0.99), 24, Color(CHARCOAL, 0.30), 4),
		Rect2(cx - 210.0, surface - 32.0, 420.0, 58.0)
	)
	shop.draw_line(
		Vector2(cx - 190.0, surface - 24.0), Vector2(cx + 190.0, surface - 24.0),
		Color(1.0, 1.0, 1.0, 0.55), 4
	)
	_ellipse(shop, Vector2(cx, surface + 26.0), 176.0, 12.0, Color(WATER_BLUE, 0.35))


static func _draw_bathtub(shop, cx: float, surface: float) -> void:
	shop.draw_style_box(
		_panel_box(Color(CREAM, 0.97), 48, Color(CHARCOAL, 0.32), 4),
		Rect2(cx - 190.0, surface - 52.0, 380.0, 240.0)
	)
	shop.draw_style_box(
		_panel_box(Color(WATER_BLUE, 0.16), 40, Color.TRANSPARENT),
		Rect2(cx - 170.0, surface - 28.0, 340.0, 198.0)
	)
	_ellipse(shop, Vector2(cx, surface - 36.0), 178.0, 16.0, Color(WATER_BLUE, 0.45))
	shop.draw_style_box(
		_panel_box(CREAM, 22, PINK, 4), Rect2(cx - 210.0, surface - 58.0, 420.0, 44.0)
	)
	shop.draw_line(
		Vector2(cx - 192.0, surface - 50.0), Vector2(cx + 192.0, surface - 50.0),
		Color(1.0, 1.0, 1.0, 0.6), 4
	)
	for foot_x: float in [cx - 150.0, cx + 114.0]:
		shop.draw_style_box(
			_panel_box(WOOD, 10, Color(CHARCOAL, 0.3), 3),
			Rect2(foot_x, surface + 180.0, 36.0, 26.0)
		)


static func _draw_groom_table(shop, cx: float, surface: float) -> void:
	shop.draw_style_box(
		_panel_box(WOOD_LIGHT, 13, Color(CHARCOAL, 0.32), 4),
		Rect2(cx - 200.0, surface, 400.0, 26.0)
	)
	shop.draw_line(
		Vector2(cx - 186.0, surface + 6.0), Vector2(cx + 186.0, surface + 6.0),
		WOOD_LIGHT.lightened(0.24), 4
	)
	for leg_x: float in [cx - 176.0, cx - 64.0, cx + 40.0, cx + 152.0]:
		shop.draw_style_box(
			_panel_box(Color(METAL, 0.95), 8, Color(CHARCOAL, 0.28), 3),
			Rect2(leg_x, surface + 26.0, 24.0, 118.0)
		)
	shop.draw_style_box(
		_panel_box(Color(METAL, 0.8), 7, Color.TRANSPARENT),
		Rect2(cx - 160.0, surface + 100.0, 320.0, 14.0)
	)


static func _draw_drying_table(shop, cx: float, surface: float) -> void:
	shop.draw_style_box(
		_panel_box(CREAM, 23, WATER_BLUE, 4), Rect2(cx - 210.0, surface, 420.0, 46.0)
	)
	for stitch_x: float in [cx - 104.0, cx, cx + 104.0]:
		shop.draw_line(
			Vector2(stitch_x, surface + 9.0), Vector2(stitch_x, surface + 38.0),
			Color(CHARCOAL, 0.14), 3
		)
	for leg_x: float in [cx - 182.0, cx - 56.0, cx + 32.0, cx + 158.0]:
		shop.draw_style_box(
			_panel_box(Color(METAL, 0.95), 8, Color(CHARCOAL, 0.28), 3),
			Rect2(leg_x, surface + 46.0, 24.0, 124.0)
		)


static func _draw_spa_pedestal(shop, cx: float, surface: float) -> void:
	shop.draw_style_box(
		_panel_box(Color(CREAM, 0.97), 36, Color(CHARCOAL, 0.30), 4),
		Rect2(cx - 150.0, surface, 300.0, 168.0)
	)
	_ellipse(shop, Vector2(cx, surface + 4.0), 148.0, 20.0, Color(PINK, 0.85))
	_ellipse(shop, Vector2(cx, surface + 2.0), 148.0, 20.0, Color(CHARCOAL, 0.10))
	for band_y: float in [surface + 66.0, surface + 126.0]:
		shop.draw_line(
			Vector2(cx - 132.0, band_y), Vector2(cx + 132.0, band_y),
			Color(WATER_BLUE, 0.4), 5
		)


static func _draw_ottoman(shop, cx: float, surface: float) -> void:
	shop.draw_style_box(
		_panel_box(Color(PINK, 0.92), 46, Color(CHARCOAL, 0.30), 4),
		Rect2(cx - 170.0, surface, 340.0, 92.0)
	)
	shop.draw_line(
		Vector2(cx - 146.0, surface + 12.0), Vector2(cx + 146.0, surface + 12.0),
		Color(1.0, 1.0, 1.0, 0.4), 4
	)
	for tuft_x: float in [cx - 90.0, cx, cx + 90.0]:
		shop.draw_circle(Vector2(tuft_x, surface + 46.0), 7.0, Color(CHARCOAL, 0.20))
	for leg_x: float in [cx - 138.0, cx + 102.0]:
		shop.draw_style_box(
			_panel_box(WOOD, 9, Color(CHARCOAL, 0.3), 3),
			Rect2(leg_x, surface + 92.0, 36.0, 34.0)
		)
