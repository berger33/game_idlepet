class_name PetCosmeticsArt
extends RefCounted
## Desenho dos cosméticos equipados (parede, banheira e acessórios do pet).
## Recebe o PetShopCanvas para reusar shake_phase, _box e as primitivas de
## draw; mantém o canvas de gameplay abaixo do limite de 1000 linhas.

## Especificação de desenho das texturas por peça: altura total em unidades
## de fit, deslocamento vertical do centro do sprite relativo à âncora e a
## âncora usada ("neck" = pescoço, "crown" = topo da cabeça).
const ACCESSORY_TEXTURE_SPEC: Dictionary = {
	"bandana_blue": {"h": 104.0, "dy": 60.0, "anchor": "neck"},
	"bandana_red": {"h": 104.0, "dy": 60.0, "anchor": "neck"},
	"scarf_caramel": {"h": 112.0, "dy": 52.0, "anchor": "neck"},
	"crown_gold": {"h": 100.0, "dy": 26.0, "anchor": "crown"},
	"crown_bubbles": {"h": 110.0, "dy": 23.0, "anchor": "crown"},
}

static var _cosmetic_cache: Dictionary = {}



## Cosmético de banheira troca a cor da espuma e das bolhas em todo o banho.
## A cor vem do catálogo (cosmetics.json "foam"): novas banheiras são só dados.
static func bath_foam_color(shop) -> Color:
	var tub: String = String(shop.room_cosmetics.get("bath", ""))
	var foam: String = String(ContentDB.cosmetic(tub).get("foam", ""))
	if not foam.is_empty() and Color.html_is_valid(foam):
		return Color.html(foam)
	match tub:
		"tub_pink":
			return Color("ffd1e0")
		"tub_ocean":
			return Color("a5e6f2")
		"tub_mint":
			return Color("d9f2e4")
		"tub_lavender":
			return Color("e6dcf7")
		_:
			return Color("f8ffff")


static func draw_room_cosmetics(shop) -> void:
	var wall: String = String(shop.room_cosmetics.get("wall", ""))
	if wall == "wall_junina":
		var flag_colors: Array[Color] = [
			Color("ef5350"), Color("ffd54f"), Color("4fc3f7"), Color("7ed957")
		]
		var sway: float = sin(shop.shake_phase * 2.0) * 6.0
		for i: int in 13:
			var x: float = 90.0 + float(i) * 72.0
			var top_y: float = 292.0 + sway * float(i % 2) * 0.4
			var tip_y: float = 356.0 + sway * float(i % 2) * 0.6
			shop.draw_colored_polygon(
				PackedVector2Array(
					[Vector2(x, top_y), Vector2(x + 36.0, top_y), Vector2(x + 18.0, tip_y)]
				),
				flag_colors[i % flag_colors.size()]
			)
	elif wall == "wall_beach":
		# Sol com raios girando devagar + ondas que sobem e descem.
		var sun: Vector2 = Vector2(160, 250)
		for ray: int in 8:
			var ray_angle: float = TAU * float(ray) / 8.0 + shop.shake_phase * 0.4
			shop.draw_line(
				sun + Vector2(cos(ray_angle), sin(ray_angle)) * 58.0,
				sun + Vector2(cos(ray_angle), sin(ray_angle)) * 84.0,
				Color("ffd54f", 0.75),
				9
			)
		shop.draw_circle(sun, 52, Color("ffe082"))
		shop.draw_circle(sun, 44, Color("ffd54f"))
		for wave: int in 3:
			var wave_x: float = 380.0 + float(wave) * 240.0
			var wave_y: float = 336.0 + sin(shop.shake_phase * 2.4 + float(wave) * 2.1) * 9.0
			shop.draw_arc(
				Vector2(wave_x, wave_y + 60.0), 70.0, PI + 0.25, TAU - 0.25, 16,
				Color("81d4fa", 0.9), 10
			)
	elif wall == "wall_garden":
		_draw_wall_garden(shop)
	elif wall == "wall_stars":
		_draw_wall_stars(shop)
	elif wall == "wall_carnaval":
		_draw_wall_carnaval(shop)
	elif wall == "wall_natal":
		_draw_wall_natal(shop)
	if String(shop.room_cosmetics.get("bath", "")).is_empty():
		return
	var tub_color: Color = bath_foam_color(shop).darkened(0.08)
	shop.draw_style_box(shop._box(tub_color, 14), Rect2(70, 592, 250, 44))
	shop.draw_style_box(shop._box(Color.WHITE, 6), Rect2(86, 606, 218, 16))



static func _cosmetic_texture(accessory: String) -> Texture2D:
	if _cosmetic_cache.has(accessory):
		return _cosmetic_cache[accessory]
	var path: String = "res://art/cosmetics/%s.png" % accessory
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_cosmetic_cache[accessory] = texture
	return texture


static func _accessory_anchor(
	shop, accessory: String, center: Vector2, fit: float, texture_local: bool
) -> Vector2:
	var spec: Dictionary = ACCESSORY_TEXTURE_SPEC.get(accessory, {})
	# Gatos sentados têm o topo da cabeça e o pescoço mais baixos que os cães;
	# âncoras por espécie mantêm a peça "vestida" em ambas as silhuetas.
	var is_cat: bool = shop.species == &"cat"
	if String(spec.get("anchor", "neck")) == "crown":
		var crown_y: float = -335.0 if is_cat else -390.0 * shop.PET_TEXTURE_BASELINE - 16.0
		var crown_x: float = -62.0 if is_cat else 0.0
		return (
			Vector2(crown_x * fit, crown_y * fit)
			if texture_local
			else center + Vector2(crown_x, -164)
		)
	var neck_y: float = -125.0 if is_cat else -140.0
	var neck_x: float = -55.0 if is_cat else 0.0
	return (
		Vector2(neck_x * fit, neck_y * fit)
		if texture_local
		else center + Vector2(neck_x, 98)
	)


static func draw_pet_accessories(shop, center: Vector2, fit: float, texture_local: bool) -> void:
	# texture_local: coordenadas locais ao pivô dos pés do sprite texturizado.
	var accessory: String = String(shop.room_cosmetics.get("pet_accessory", ""))
	var texture: Texture2D = _cosmetic_texture(accessory) if accessory != "" else null
	var sway: Vector2 = Vector2.ZERO
	# acessório flutter 10/10
	var jump_h: float = 0.0
	if float(shop.celebration) > 0.0:
		var c_ph: float = 1.0 - float(shop.celebration) / 1.8
		if c_ph >= 0.2 and c_ph < 0.72:
			jump_h = sin(PI * (c_ph - 0.2) / 0.52) * 72.0
	sway = PetAnimationTuning.accessory_sway(shop.shake_phase, jump_h, fit)
	if texture != null:
		var spec: Dictionary = ACCESSORY_TEXTURE_SPEC[accessory]
		var h: float = float(spec.h) * fit
		var w: float = h * float(texture.get_width()) / float(texture.get_height())
		var anchor: Vector2 = _accessory_anchor(shop, accessory, center, fit, texture_local) + sway
		var sprite_center: Vector2 = anchor + Vector2(0.0, float(spec.dy) * fit)
		shop.draw_texture_rect(
			texture, Rect2(sprite_center.x - w * 0.5, sprite_center.y - h * 0.5, w, h), false
		)
		return
	_draw_accessory_polygons(shop, accessory, center, fit, texture_local, sway)


static func _draw_accessory_polygons(
	shop, accessory: String, center: Vector2, fit: float, texture_local: bool, sway: Vector2 = Vector2.ZERO
) -> void:
	if accessory == "bandana_blue" or accessory == "bandana_red":
		var bandana_colors: Dictionary = {
			"bandana_blue": ["4a7bd0", "3a63ad"],
			"bandana_red": ["d84f4f", "a83838"],
		}
		var pair: Array = bandana_colors[accessory]
		var neck: Vector2 = (
			Vector2(0.0, -140.0 * fit) if texture_local else center + Vector2(0, 98)
		) + sway
		var half: float = 68.0 * fit
		shop.draw_colored_polygon(
			PackedVector2Array(
				[neck + Vector2(-half, 0), neck + Vector2(half, 0), neck + Vector2(0, 84 * fit + sway.y)]
			),
			Color(String(pair[0]))
		)
		shop.draw_circle(neck + Vector2(-half * 0.7, 4.0 * fit), 11.0 * fit, Color(String(pair[1])))
		shop.draw_circle(neck + Vector2(half * 0.7, 4.0 * fit), 11.0 * fit, Color(String(pair[1])))
	elif accessory == "scarf_caramel":
		var neck: Vector2 = (
			Vector2(0.0, -140.0 * fit) if texture_local else center + Vector2(0, 98)
		) + sway
		var half: float = 66.0 * fit
		var scarf: Color = Color("c98b5b")
		var shade: Color = Color("8d5a33")
		shop.draw_colored_polygon(
			PackedVector2Array(
				[
					neck + Vector2(-half, -12.0 * fit),
					neck + Vector2(half, -12.0 * fit),
					neck + Vector2(half * 0.92, 30.0 * fit),
					neck + Vector2(-half * 0.92, 30.0 * fit)
				]
			),
			scarf
		)
		shop.draw_colored_polygon(
			PackedVector2Array(
				[
					neck + Vector2(-half * 0.55, 24.0 * fit),
					neck + Vector2(-half * 0.05, 24.0 * fit),
					neck + Vector2(-half * 0.25, 132.0 * fit + sway.y * 1.5)
				]
			),
			scarf
		)
		shop.draw_line(
			neck + Vector2(-half * 0.4, 34.0 * fit),
			neck + Vector2(-half * 0.28, 108.0 * fit),
			shade,
			6.0 * fit
		)
		shop.draw_circle(neck + Vector2(-half * 0.55, 24.0 * fit), 13.0 * fit, shade)
		shop.draw_circle(neck + Vector2(half * 0.8, 6.0 * fit), 13.0 * fit, shade)
	elif accessory == "crown_bubbles" or accessory == "crown_gold":
		var crown_palettes: Dictionary = {
			"crown_bubbles": ["f6c445", "b3e5fc"],
			"crown_gold": ["ffd75e", "ff6f91"],
		}
		var gems: Array = crown_palettes[accessory]
		var crown: Vector2 = (
			Vector2(0.0, -390.0 * fit * shop.PET_TEXTURE_BASELINE - 16.0 * fit)
			if texture_local
			else center + Vector2(0, -164)
		) + sway * 0.5
		var width: float = 72.0 * fit
		var band_h: float = 18.0 * fit
		var tip_h: float = 58.0 * fit
		shop.draw_colored_polygon(
			PackedVector2Array(
				[
					crown + Vector2(-width, -band_h),
					crown + Vector2(width, -band_h),
					crown + Vector2(width, 0),
					crown + Vector2(-width, 0)
				]
			),
			Color(String(gems[0]))
		)
		for point_x: float in [-width * 0.8, 0.0, width * 0.8]:
			shop.draw_colored_polygon(
				PackedVector2Array(
					[
						crown + Vector2(point_x - 16.0 * fit, -band_h),
						crown + Vector2(point_x + 16.0 * fit, -band_h),
						crown + Vector2(point_x, -tip_h + sway.y * 0.3)
					]
				),
				Color(String(gems[0]))
			)
		for bubble_x: float in [-width * 0.8, 0.0, width * 0.8]:
			shop.draw_circle(
				crown + Vector2(bubble_x, -tip_h - 20.0 * fit),
				13.0 * fit,
				Color(String(gems[1]), 0.9)
			)


## Jardim: canteiro de flores balançando (pétalas em círculo + miolo).
static func _draw_wall_garden(shop) -> void:
	var petals: Array[Color] = [Color("ff8fb1"), Color("ffd54f"), Color("ce93d8"), Color("4fc3f7")]
	for i: int in 9:
		var base: Vector2 = Vector2(110.0 + float(i) * 108.0, 340.0)
		var sway: float = sin(shop.shake_phase * 1.6 + float(i)) * 5.0
		shop.draw_line(base, base + Vector2(sway, -46.0), Color("7ed957"), 6)
		var head: Vector2 = base + Vector2(sway, -52.0)
		for petal: int in 5:
			var angle: float = TAU * float(petal) / 5.0 + shop.shake_phase * 0.3
			shop.draw_circle(head + Vector2(cos(angle), sin(angle)) * 13.0, 11.0, petals[i % petals.size()])
		shop.draw_circle(head, 9.0, Color("fff59d"))


## Estrelada: estrelas piscando em fases diferentes + lua.
static func _draw_wall_stars(shop) -> void:
	shop.draw_circle(Vector2(900, 270), 40.0, Color("fff3c4"))
	shop.draw_circle(Vector2(916, 262), 34.0, Color("ffe3ec"))
	for i: int in 14:
		var seed_x: float = 80.0 + fmod(float(i) * 173.0, 900.0)
		var seed_y: float = 240.0 + fmod(float(i) * 97.0, 110.0)
		var twinkle: float = 0.55 + 0.45 * sin(shop.shake_phase * 2.2 + float(i) * 1.7)
		var radius: float = 5.0 + 5.0 * twinkle
		var glow: Color = Color("fff59d", twinkle)
		var center: Vector2 = Vector2(seed_x, seed_y)
		shop.draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), glow, 3)
		shop.draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), glow, 3)


## Carnaval: chuva de confete e serpentinas (presente da temporada).
static func _draw_wall_carnaval(shop) -> void:
	var colors: Array[Color] = [
		Color("ef5350"), Color("ffd54f"), Color("4fc3f7"), Color("7ed957"), Color("ce93d8")
	]
	for i: int in 36:
		var x: float = 60.0 + fmod(float(i) * 151.0, 960.0)
		var fall: float = fmod(shop.shake_phase * 40.0 + float(i) * 37.0, 130.0)
		var y: float = 236.0 + fall
		var spin: float = shop.shake_phase * 3.0 + float(i)
		var size: Vector2 = Vector2(14.0, 8.0 + 6.0 * absf(sin(spin)))
		shop.draw_rect(Rect2(Vector2(x, y) - size * 0.5, size), colors[i % colors.size()])
	for i: int in 4:
		var start: Vector2 = Vector2(140.0 + float(i) * 260.0, 232.0)
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in 12:
			var t: float = float(step) / 11.0
			points.append(start + Vector2(sin(t * 9.0 + shop.shake_phase) * 14.0, t * 120.0))
		shop.draw_polyline(points, colors[(i + 2) % colors.size()], 5)


## Natal tropical: varal de luzinhas piscando (presente da temporada).
static func _draw_wall_natal(shop) -> void:
	var colors: Array[Color] = [Color("ef5350"), Color("7ed957"), Color("ffd54f"), Color("4fc3f7")]
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 13:
		var t: float = float(i) / 12.0
		points.append(Vector2(60.0 + t * 960.0, 250.0 + sin(t * PI) * 60.0))
	shop.draw_polyline(points, Color("455a64"), 4)
	for i: int in 13:
		var on: bool = sin(shop.shake_phase * 4.0 + float(i) * 1.3) > -0.2
		var color: Color = colors[i % colors.size()]
		shop.draw_circle(points[i] + Vector2(0.0, 16.0), 12.0, color if on else color.darkened(0.55))
		if on:
			shop.draw_circle(points[i] + Vector2(0.0, 16.0), 20.0, Color(color, 0.25))
