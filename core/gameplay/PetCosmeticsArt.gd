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
	"bandana_green": {"h": 104.0, "dy": 60.0, "anchor": "neck"},
	"bandana_pink": {"h": 104.0, "dy": 60.0, "anchor": "neck"},
	"scarf_caramel": {"h": 112.0, "dy": 52.0, "anchor": "neck"},
	"scarf_winter": {"h": 112.0, "dy": 52.0, "anchor": "neck"},
	"bow_tie": {"h": 56.0, "dy": 34.0, "anchor": "neck"},
	"glasses_cool": {"h": 48.0, "dy": -22.0, "anchor": "crown"},
	"hat_party": {"h": 96.0, "dy": 18.0, "anchor": "crown"},
	"collar_gold": {"h": 36.0, "dy": 42.0, "anchor": "neck"},
	"flower_crown": {"h": 64.0, "dy": 12.0, "anchor": "crown"},
	"crown_gold": {"h": 100.0, "dy": 26.0, "anchor": "crown"},
	"crown_bubbles": {"h": 110.0, "dy": 23.0, "anchor": "crown"},
	"crown_silver": {"h": 100.0, "dy": 26.0, "anchor": "crown"},
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
	elif wall == "wall_forest":
		_draw_wall_forest(shop)
	elif wall == "wall_city":
		_draw_wall_city(shop)
	elif wall == "wall_space":
		_draw_wall_space(shop)
	elif wall == "wall_retro":
		_draw_wall_retro(shop)
	elif wall == "wall_ocean":
		_draw_wall_ocean(shop)
	elif wall == "wall_sunset":
		_draw_wall_sunset(shop)
	elif wall == "wall_achievement":
		_draw_wall_achievement(shop)
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
	if accessory == "bandana_blue" or accessory == "bandana_red" or accessory == "bandana_green" or accessory == "bandana_pink":
		var bandana_colors: Dictionary = {
			"bandana_blue": ["4a7bd0", "3a63ad"],
			"bandana_red": ["d84f4f", "a83838"],
			"bandana_green": ["5db86a", "2e7d32"],
			"bandana_pink": ["f48fb1", "ad1457"],
		}
		var pair: Array = bandana_colors.get(accessory, ["4a7bd0", "3a63ad"])
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
	elif accessory == "scarf_caramel" or accessory == "scarf_winter":
		var neck: Vector2 = (
			Vector2(0.0, -140.0 * fit) if texture_local else center + Vector2(0, 98)
		) + sway
		var half: float = 66.0 * fit
		var is_winter: bool = accessory == "scarf_winter"
		var scarf: Color = Color("7fb8ff") if is_winter else Color("c98b5b")
		var shade: Color = Color("3a6ea5") if is_winter else Color("8d5a33")
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
	elif accessory == "crown_bubbles" or accessory == "crown_gold" or accessory == "crown_silver":
		var crown_palettes: Dictionary = {
			"crown_bubbles": ["f6c445", "b3e5fc"],
			"crown_gold": ["ffd75e", "ff6f91"],
			"crown_silver": ["e0e0e0", "90caf9"],
		}
		var gems: Array = crown_palettes.get(accessory, ["ffd75e", "ff6f91"])
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
	elif accessory == "bow_tie":
		var neck: Vector2 = (Vector2(0.0, -130.0 * fit) if texture_local else center + Vector2(0, 108)) + sway
		shop.draw_colored_polygon(PackedVector2Array([neck + Vector2(-42*fit, -16*fit), neck + Vector2(-10*fit,0), neck + Vector2(-42*fit,16*fit)]), Color("e53935"))
		shop.draw_colored_polygon(PackedVector2Array([neck + Vector2(42*fit, -16*fit), neck + Vector2(10*fit,0), neck + Vector2(42*fit,16*fit)]), Color("e53935"))
		shop.draw_circle(neck, 14*fit, Color("263238"))
	elif accessory == "glasses_cool":
		var crown: Vector2 = (Vector2(-6*fit, -210*fit) if texture_local else center + Vector2(-6, -42)) + sway*0.5
		shop.draw_rect(Rect2(crown+Vector2(-48*fit,-16*fit), Vector2(38*fit,22*fit)), Color("212121"), false, 3*fit)
		shop.draw_rect(Rect2(crown+Vector2(10*fit,-16*fit), Vector2(38*fit,22*fit)), Color("212121"), false, 3*fit)
		shop.draw_line(crown+Vector2(-10*fit, -5*fit), crown+Vector2(10*fit,-5*fit), Color("212121"), 3*fit)
		shop.draw_circle(crown+Vector2(-29*fit, -5*fit), 10*fit, Color("00e5ff", 0.35))
		shop.draw_circle(crown+Vector2(29*fit, -5*fit), 10*fit, Color("00e5ff", 0.35))
	elif accessory == "hat_party":
		var crown: Vector2 = (Vector2(0.0, -390.0*fit*shop.PET_TEXTURE_BASELINE-18*fit) if texture_local else center+Vector2(0,-168)) + sway*0.5
		shop.draw_colored_polygon(PackedVector2Array([crown+Vector2(-46*fit,18*fit), crown+Vector2(46*fit,18*fit), crown+Vector2(0,-58*fit)]), Color("ff6f91"))
		shop.draw_circle(crown+Vector2(0,-58*fit), 10*fit, Color("ffd54f"))
		for i: int in 3:
			shop.draw_circle(crown+Vector2(-30*fit+i*30*fit, 6*fit), 6*fit, Color("ffd54f"))
	elif accessory == "collar_gold":
		var neck: Vector2 = (Vector2(0.0,-138*fit) if texture_local else center+Vector2(0,100)) + sway
		shop.draw_line(neck+Vector2(-56*fit,0), neck+Vector2(56*fit,0), Color("ffd54f"), 12*fit)
		shop.draw_circle(neck+Vector2(0,14*fit), 14*fit, Color("ffd700"))
		shop.draw_circle(neck+Vector2(0,14*fit), 7*fit, Color("fff9c4"))
	elif accessory == "flower_crown":
		var crown: Vector2 = (Vector2(-12*fit,-322*fit) if texture_local else center+Vector2(-12,-152)) + sway*0.5
		var cols: Array[Color] = [Color("ff8fb1"), Color("ffd54f"), Color("ce93d8"), Color("ffcc80")]
		for i: int in 5:
			var cx: float = -44*fit + float(i)*22*fit
			shop.draw_circle(crown+Vector2(cx,0), 11*fit, cols[i % cols.size()])
			shop.draw_circle(crown+Vector2(cx,0), 5*fit, Color("fff59d"))


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


## Floresta: troncos + copas balançando suave.
static func _draw_wall_forest(shop) -> void:
	for i: int in 6:
		var x: float = 120.0 + float(i) * 160.0
		var sway: float = sin(shop.shake_phase * 1.2 + float(i)) * 4.0
		shop.draw_rect(Rect2(Vector2(x-14, 300), Vector2(28, 80)), Color("5d4037"))
		shop.draw_circle(Vector2(x+sway, 270), 44.0, Color("2e7d32"))
		shop.draw_circle(Vector2(x+sway-18, 285), 32.0, Color("43a047"))
		shop.draw_circle(Vector2(x+sway+16, 285), 32.0, Color("66bb6a"))


## Cidade: skyline com janelas acesas piscando.
static func _draw_wall_city(shop) -> void:
	shop.draw_rect(Rect2(Vector2(40, 280), Vector2(1000, 80)), Color("263238"))
	for i: int in 7:
		var x: float = 60.0 + float(i)*140.0
		var h: float = 48.0 + fmod(float(i)*37.0, 40.0)
		shop.draw_rect(Rect2(Vector2(x, 280-h), Vector2(86, h)), Color("37474f"))
		for wy: int in 2:
			for wx: int in 3:
				var on: bool = sin(shop.shake_phase*2.0 + float(i*6+wy*3+wx)) > -0.3
				shop.draw_rect(Rect2(Vector2(x+12+float(wx)*24, 286-h+float(wy)*18), Vector2(14,10)), Color("ffd54f") if on else Color("455a64"))


## Espaço: estrelas densas + planeta.
static func _draw_wall_space(shop) -> void:
	shop.draw_rect(Rect2(Vector2(40,240), Vector2(1000,120)), Color("0d1b2a"))
	for i: int in 22:
		var sx: float = 70.0 + fmod(float(i)*151.0, 940.0)
		var sy: float = 248.0 + fmod(float(i)*97.0, 110.0)
		var tw: float = 0.6 + 0.4*sin(shop.shake_phase*1.8 + float(i))
		shop.draw_circle(Vector2(sx,sy), 2.5+1.5*tw, Color("ffffff", tw))
	shop.draw_circle(Vector2(860, 290), 38.0, Color("7e57c2"))
	shop.draw_circle(Vector2(876, 282), 30.0, Color("b39ddb", 0.9))


## Retrô: padrão geométrico + vinil girando.
static func _draw_wall_retro(shop) -> void:
	for i: int in 8:
		var x: float = 70.0 + float(i)*125.0
		var c: Color = Color("ff6f91") if i%2==0 else Color("4fc3f7")
		shop.draw_rect(Rect2(Vector2(x, 258), Vector2(90, 90)), c, false, 4)
		shop.draw_line(Vector2(x,258), Vector2(x+90,348), c, 3)
		shop.draw_line(Vector2(x+90,258), Vector2(x,348), c, 3)
	var spin: float = shop.shake_phase * 1.6
	shop.draw_circle(Vector2(540, 304), 42.0, Color("212121"))
	shop.draw_circle(Vector2(540,304), 14.0, Color("ffd54f"))
	shop.draw_line(Vector2(540,304)+Vector2(cos(spin), sin(spin))*16, Vector2(540,304)+Vector2(cos(spin), sin(spin))*38, Color("e0e0e0"), 4)


## Oceano: ondas + bolhas subindo.
static func _draw_wall_ocean(shop) -> void:
	shop.draw_rect(Rect2(Vector2(40,310), Vector2(1000,50)), Color("0288d1"))
	for i: int in 4:
		var wy: float = 322.0 + sin(shop.shake_phase*1.4 + float(i)*1.9)*6.0
		shop.draw_arc(Vector2(180+float(i)*220, wy+40), 70, PI+0.2, TAU-0.2, 14, Color("4fc3f7",0.85), 8)
	for i: int in 9:
		var x: float = 90.0 + fmod(float(i)*167.0, 920.0)
		var y: float = 360.0 - fmod(shop.shake_phase*26.0+float(i)*44.0, 90.0)
		shop.draw_circle(Vector2(x+sin(shop.shake_phase+float(i))*8, y), 5.0+float(i%3)*2.0, Color("b3e5fc", 0.85))


## Pôr-do-sol: degradê + sol.
static func _draw_wall_sunset(shop) -> void:
	for i: int in 6:
		var t: float = float(i)/5.0
		var col: Color = Color("ff6f91").lerp(Color("ffd54f"), t).lerp(Color("4fc3f7"), t*0.35)
		shop.draw_rect(Rect2(Vector2(40, 242+float(i)*20), Vector2(1000, 20)), col)
	shop.draw_circle(Vector2(540, 310), 44.0, Color("ffd54f"))
	shop.draw_circle(Vector2(540,310), 28.0, Color("ff8a65"))


## Conquista: troféus dourados alinhados.
static func _draw_wall_achievement(shop) -> void:
	shop.draw_rect(Rect2(Vector2(40,260), Vector2(1000,100)), Color("263238"))
	for i: int in 5:
		var x: float = 180.0 + float(i)*170.0
		shop.draw_circle(Vector2(x, 300), 22.0, Color("ffd700"))
		shop.draw_rect(Rect2(Vector2(x-18,300), Vector2(36,24)), Color("ffd700"))
		shop.draw_rect(Rect2(Vector2(x-28,324), Vector2(56,8)), Color("b8860b"))
		shop.draw_circle(Vector2(x, 268), 6.0, Color("fffde7"))
