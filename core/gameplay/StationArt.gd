class_name StationArt
extends RefCounted
## Mobiliário da sala: arte raster (art/stations) com fallback vetorial.
## A geometria continua ancorada em pet_position.y (pés do pet) e nas
## pranchas de data/service_layouts.json — o layout validado é o mesmo da
## arte vetorial anterior; as caixas vêm de tools/normalize_station_art.py.
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

## Caixas das artes (canvas 1080x1920, surface=1160). Origem Y das
## mesas/pedestal/otomana é a própria surface; banheiras são posicionadas
## para que o ARO FRONTAL cruze o pet em surface-36 (RIM_LINE).
const SURFACE_REF: float = 1160.0
const RIM_LINE_OFFSET: float = -36.0
const STATION_ART_BOXES: Dictionary = {
	&"bathtub_rustic": Rect2(320.0, SURFACE_REF - 87.0, 440.0, 314.0),
	&"bathtub_spa": Rect2(320.0, SURFACE_REF - 109.0, 440.0, 305.0),
	&"groom": Rect2(340.0, SURFACE_REF, 400.0, 121.0),
	&"dry": Rect2(330.0, SURFACE_REF, 420.0, 169.0),
	&"perfume": Rect2(390.0, SURFACE_REF, 300.0, 179.0),
	&"style": Rect2(370.0, SURFACE_REF, 340.0, 110.0),
}
## Fração da altura da banheira onde começa o aro frontal (fatia que oclui
## as patas do pet) — medida pela ferramenta de normalização.
const BATHTUB_RIM_FRACS: Dictionary = {
	&"bathtub_rustic": 0.1624,
	&"bathtub_spa": 0.2393,
}
## Estante: arte de 216x786; a 1ª prancha fica a 18.38% da altura.
const SHELF_X: float = 812.0
const SHELF_W: float = 216.0
const SHELF_ART_H: float = 780.0
const SHELF_PLANK0_FRAC: float = 0.1853
const SHELF_PLANK_COUNT: int = 5

## Cache estático: o canvas redesenha a cada frame, a textura carrega uma vez.
static var _art_cache: Dictionary = {}


static func _art_texture(asset: StringName) -> Texture2D:
	if _art_cache.has(asset):
		return _art_cache[asset]
	var path: String = "res://art/stations/%s.png" % String(asset)
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_art_cache[asset] = texture
	return texture


static func _station_box(shop, key: StringName) -> Rect2:
	var box: Rect2 = STATION_ART_BOXES[key]
	# Segue a âncora dos pés caso o layout do serviço mude o pet_position.
	box.position.y += shop.pet_position.y - SURFACE_REF
	return box


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


## Estante da direita: arte raster posicionada pelas pranchas do layout
## (desenhada antes dos sprites das ferramentas, que apoiam sobre elas).
static func draw_shelf_unit(shop) -> void:
	var levels: Array = shop.service_shelf_levels
	if levels.is_empty():
		return
	var left_handed: bool = bool(GameState.settings.get("left_handed", false))
	var shelf_x: float = 52.0 if left_handed else SHELF_X
	# cada cenário tem a sua estante (mesma geometria, material temático)
	var texture: Texture2D = _art_texture(StringName("shelf_" + String(shop.service_mode)))
	if texture == null:
		texture = _art_texture(&"shelf_unit")
	if texture != null and levels.size() == SHELF_PLANK_COUNT:
		var first_plank_top: float = float(levels[0]) + PLANK_DROP
		var top: float = first_plank_top - SHELF_PLANK0_FRAC * SHELF_ART_H
		shop.draw_texture_rect(texture, Rect2(shelf_x, top, SHELF_W, SHELF_ART_H), false)
		# Espelhamento simples quando canhoto: desenha a mesma textura no lado esquerdo
		# (a arte é simétrica o suficiente; evita duplicar PNGs)
		return
	_draw_shelf_fallback(shop, levels, shelf_x)


## Placa de título da sala atrás do texto localizado desenhado pelo canvas.
## Duas linhas: serviço + capítulo do estabelecimento (progressão visível).
static func draw_title_plaque(shop) -> void:
	shop.draw_style_box(
		_panel_box(Color(CREAM, 0.94), 26, PINK, 4), Rect2(310, 160, 460, 106)
	)
	shop.draw_line(Vector2(330, 170), Vector2(750, 170), Color(1.0, 1.0, 1.0, 0.5), 3)


## Estação de trabalho (desenhada ANTES do pet): sombra de contato + arte.
## A banheira acompanha o capítulo do estabelecimento: rústica no quintal
## (tier 1) e porcelana dourada a partir do tier 2.
## Endgame Rede Regional (P1): segunda estação visual quando tier>=6 ou level>=10.
static func draw_station(shop) -> void:
	if shop.room_empty:
		return
	var surface: float = shop.pet_position.y
	var cx: float = shop.pet_position.x
	_ellipse(shop, Vector2(cx, surface + 10), 216.0, 26.0, Color(CHARCOAL, 0.16))
	var key: StringName = _station_key(shop)
	var texture: Texture2D = _art_texture(key) if key != &"" else null
	if texture != null:
		shop.draw_texture_rect(texture, _station_box(shop, key), false)
		_draw_station_evolution(shop, cx, surface)
		_draw_second_station(shop, cx, surface, key, texture)
		return
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
	_draw_station_evolution(shop, cx, surface)
	_draw_second_station(shop, cx, surface, key, texture)

static func _draw_second_station(shop, cx: float, surface: float, key: StringName, tex: Texture2D) -> void:
	var tier: int = int(shop.establishment_tier)
	var lvl: int = int(shop.player_level)
	if tier < 6 and lvl < 10:
		return
	# Segunda estação: deslocada à esquerda, 70% tamanho, alpha reduzido, indica Rede Regional
	var second_cx: float = cx - 420.0
	var second_surface: float = surface + 18.0
	_ellipse(shop, Vector2(second_cx, second_surface + 8), 150.0, 18.0, Color(CHARCOAL, 0.10))
	if tex != null and key != &"":
		var box: Rect2 = _station_box(shop, key)
		var w: float = box.size.x * 0.68
		var h: float = box.size.y * 0.68
		var second_box: Rect2 = Rect2(second_cx - w * 0.5, second_surface - h + (box.size.y - h), w, h)
		shop.draw_texture_rect(tex, second_box, false)
		# Faixa "FILIAL 2" sobre segunda estação
		shop.draw_style_box(_panel_box(Color("ffd54f", 0.85), 8, Color("263238", 0.2), 2), Rect2(second_cx - 70, second_surface - h - 18, 140, 28))
	else:
		# Fallback vetorial segunda estação
		shop.draw_style_box(_panel_box(Color(CREAM, 0.72), 24, Color(CHARCOAL, 0.22), 2), Rect2(second_cx - 110, second_surface - 24, 220, 36))
	# Brilho de rede regional quando tier alto
	if tier >= 8:
		_ellipse(shop, Vector2(second_cx, second_surface), 120.0, 12.0, Color("ffd54f", 0.18))
	# Texto FILIAL 2 (usa fonte do sistema se disponível)
	var font: Font = preload("res://art/fonts/DejaVuSans-Bold.ttf") as Font
	if font != null:
		shop.draw_string(font, Vector2(second_cx - 42, second_surface - 58), "FILIAL 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("263238", 0.85))


## Evolução visual a cada 10 níveis de estação (antes só o texto mudava).
## Tier 0 = base; a cada 10 níveis ganha um detalhe: toalha, patinho, planta,
## troféu, luz dourada — vende progresso de 120 níveis sem nova arte raster.
static func _draw_station_evolution(shop, cx: float, surface: float) -> void:
	var level: int = int(shop.upgrade_level)
	var evo: int = clampi(level / 10, 0, 12)
	if evo <= 0:
		return
	# Nível 10: toalha dobrada ao lado da estação
	if evo >= 1:
		shop.draw_style_box(
			_panel_box(Color("e1f5fe", 0.9), 8, Color(CHARCOAL, 0.18), 2),
			Rect2(cx + 210, surface + 20, 44, 28)
		)
	# Nível 20: patinho de borracha (banho) ou tesoura dourada (tosa)
	if evo >= 2:
		shop.draw_circle(Vector2(cx + 232, surface - 18), 12, Color("ffd54f", 0.95))
		shop.draw_circle(Vector2(cx + 228, surface - 22), 3, Color(CHARCOAL))
	# Nível 30: plantinha (vida no salão)
	if evo >= 3:
		shop.draw_rect(Rect2(cx - 260, surface + 10, 18, 36), Color(WOOD, 0.9))
		shop.draw_circle(Vector2(cx - 251, surface - 8), 18, Color("7ed957", 0.85))
	# Nível 40+: brilho dourado sutil na borda da estação
	if evo >= 4:
		var glow: float = 0.12 + 0.04 * float(evo - 4)
		_ellipse(shop, Vector2(cx, surface + 2), 200 + evo * 4, 18 + evo, Color("ffd54f", glow))
	# Nível 60+: faixa de campeão
	if evo >= 6:
		shop.draw_style_box(
			_panel_box(Color("ffd54f", 0.22), 6), Rect2(cx - 190, surface - 62, 380, 10)
		)
	# Nível 100+: coroa pequena no canto da estação
	if evo >= 10:
		var crown_x: float = cx + 190
		var crown_y: float = surface - 46
		var crown: PackedVector2Array = PackedVector2Array([
			Vector2(crown_x - 14, crown_y + 8),
			Vector2(crown_x - 10, crown_y - 6),
			Vector2(crown_x, crown_y + 2),
			Vector2(crown_x + 10, crown_y - 6),
			Vector2(crown_x + 14, crown_y + 8)
		])
		shop.draw_colored_polygon(crown, Color("ffd54f", 0.95))


## Primeiro plano da banheira (desenhada DEPOIS do pet): a parede frontal
## (fatia da MESMA textura) oclui as patas e vende a leitura "pet dentro
## da banheira"; uma elipse de água translúcida na linha do aro molha as
## patinhas que ficam visíveis.
static func draw_station_foreground(shop) -> void:
	if shop.room_empty or shop.service_mode != &"bath":
		return
	var surface: float = shop.pet_position.y
	var cx: float = shop.pet_position.x
	var key: StringName = _station_key(shop)
	var texture: Texture2D = _art_texture(key) if key != &"" else null
	if texture != null:
		var rim_y: float = surface + RIM_LINE_OFFSET
		_ellipse(
			shop, Vector2(cx, rim_y + 6.0), 168.0, 14.0, Color(WATER_BLUE, 0.35)
		)
		var box: Rect2 = _station_box(shop, key)
		var frac: float = BATHTUB_RIM_FRACS[key]
		var tex_h: float = float(texture.get_height())
		var tex_w: float = float(texture.get_width())
		shop.draw_texture_rect_region(
			texture,
			Rect2(box.position.x, rim_y, box.size.x, box.end.y - rim_y),
			Rect2(0.0, frac * tex_h, tex_w, tex_h * (1.0 - frac))
		)
		return
	shop.draw_style_box(
		_panel_box(Color(CREAM, 0.99), 24, Color(CHARCOAL, 0.30), 4),
		Rect2(cx - 210.0, surface - 32.0, 420.0, 58.0)
	)
	shop.draw_line(
		Vector2(cx - 190.0, surface - 24.0), Vector2(cx + 190.0, surface - 24.0),
		Color(1.0, 1.0, 1.0, 0.55), 4
	)
	_ellipse(shop, Vector2(cx, surface + 26.0), 176.0, 12.0, Color(WATER_BLUE, 0.35))


static func _station_key(shop) -> StringName:
	match shop.service_mode:
		&"bath":
			return &"bathtub_rustic" if shop.establishment_tier <= 1 else &"bathtub_spa"
		&"groom", &"dry", &"perfume", &"style":
			return shop.service_mode
	return &""


## ---------------------------- fallback vetorial ----------------------------


static func _draw_shelf_fallback(shop, levels: Array, shelf_x: float = SHELF_X) -> void:
	var top: float = float(levels[0]) + PLANK_DROP - 26.0
	var bottom: float = float(levels[levels.size() - 1]) + PLANK_DROP + 48.0
	var board: StyleBoxFlat = _panel_box(Color(CREAM, 0.42), 22, Color(CHARCOAL, 0.16), 3)
	shop.draw_style_box(board, Rect2(shelf_x + 12, top, 192, bottom - top))
	for level: float in levels:
		var y: float = level + PLANK_DROP
		shop.draw_style_box(
			_panel_box(WOOD, 9, Color(CHARCOAL, 0.32), 3),
			Rect2(shelf_x + 12, y, 192, 22)
		)
		var x1: float = shelf_x + 22.0
		var x2: float = shelf_x + 184.0
		shop.draw_line(Vector2(x1, y + 4.0), Vector2(x2, y + 4.0), WOOD_LIGHT.lightened(0.22), 4)
		shop.draw_line(Vector2(x1, y + 24.0), Vector2(x2, y + 24.0), Color(CHARCOAL, 0.16), 3)


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
