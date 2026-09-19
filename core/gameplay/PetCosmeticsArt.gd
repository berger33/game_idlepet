class_name PetCosmeticsArt
extends RefCounted
## Desenho dos cosméticos equipados (parede, banheira e acessórios do pet).
## Recebe o PetShopCanvas para reusar shake_phase, _box e as primitivas de
## draw; mantém o canvas de gameplay abaixo do limite de 1000 linhas.


## Cosmético de banheira troca a cor da espuma e das bolhas em todo o banho.
static func bath_foam_color(shop) -> Color:
	match String(shop.room_cosmetics.get("bath", "")):
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
			draw_colored_polygon(
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
			draw_line(
				sun + Vector2(cos(ray_angle), sin(ray_angle)) * 58.0,
				sun + Vector2(cos(ray_angle), sin(ray_angle)) * 84.0,
				Color("ffd54f", 0.75),
				9
			)
		draw_circle(sun, 52, Color("ffe082"))
		draw_circle(sun, 44, Color("ffd54f"))
		for wave: int in 3:
			var wave_x: float = 380.0 + float(wave) * 240.0
			var wave_y: float = 336.0 + sin(shop.shake_phase * 2.4 + float(wave) * 2.1) * 9.0
			draw_arc(
				Vector2(wave_x, wave_y + 60.0), 70.0, PI + 0.25, TAU - 0.25, 16,
				Color("81d4fa", 0.9), 10
			)
	if String(shop.room_cosmetics.get("bath", "")).is_empty():
		return
	var tub_color: Color = _bath_foam_color().darkened(0.08)
	draw_styleshop._box(shop._box(tub_color, 14), Rect2(70, 592, 250, 44))
	draw_styleshop._box(shop._box(Color.WHITE, 6), Rect2(86, 606, 218, 16))


static func draw_pet_accessories(shop, center: Vector2, fit: float, texture_local: bool) -> void:
	# texture_local: coordenadas locais ao pivô dos pés do sprite texturizado.
	var accessory: String = String(shop.room_cosmetics.get("pet_accessory", ""))
	if accessory == "bandana_blue" or accessory == "bandana_red":
		var bandana_colors: Dictionary = {
			"bandana_blue": ["4a7bd0", "3a63ad"],
			"bandana_red": ["d84f4f", "a83838"],
		}
		var pair: Array = bandana_colors[accessory]
		var neck: Vector2 = (
			Vector2(0.0, -140.0 * fit) if texture_local else center + Vector2(0, 98)
		)
		var half: float = 68.0 * fit
		draw_colored_polygon(
			PackedVector2Array(
				[neck + Vector2(-half, 0), neck + Vector2(half, 0), neck + Vector2(0, 84 * fit)]
			),
			Color(String(pair[0]))
		)
		draw_circle(neck + Vector2(-half * 0.7, 4.0 * fit), 11.0 * fit, Color(String(pair[1])))
		draw_circle(neck + Vector2(half * 0.7, 4.0 * fit), 11.0 * fit, Color(String(pair[1])))
	elif accessory == "scarf_caramel":
		var neck: Vector2 = (
			Vector2(0.0, -140.0 * fit) if texture_local else center + Vector2(0, 98)
		)
		var half: float = 66.0 * fit
		var scarf: Color = Color("c98b5b")
		var shade: Color = Color("8d5a33")
		draw_colored_polygon(
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
		draw_colored_polygon(
			PackedVector2Array(
				[
					neck + Vector2(-half * 0.55, 24.0 * fit),
					neck + Vector2(-half * 0.05, 24.0 * fit),
					neck + Vector2(-half * 0.25, 132.0 * fit)
				]
			),
			scarf
		)
		draw_line(
			neck + Vector2(-half * 0.4, 34.0 * fit),
			neck + Vector2(-half * 0.28, 108.0 * fit),
			shade,
			6.0 * fit
		)
		draw_circle(neck + Vector2(-half * 0.55, 24.0 * fit), 13.0 * fit, shade)
		draw_circle(neck + Vector2(half * 0.8, 6.0 * fit), 13.0 * fit, shade)
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
		)
		var width: float = 72.0 * fit
		var band_h: float = 18.0 * fit
		var tip_h: float = 58.0 * fit
		draw_colored_polygon(
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
			draw_colored_polygon(
				PackedVector2Array(
					[
						crown + Vector2(point_x - 16.0 * fit, -band_h),
						crown + Vector2(point_x + 16.0 * fit, -band_h),
						crown + Vector2(point_x, -tip_h)
					]
				),
				Color(String(gems[0]))
			)
		for bubble_x: float in [-width * 0.8, 0.0, width * 0.8]:
			draw_circle(
				crown + Vector2(bubble_x, -tip_h - 20.0 * fit),
				13.0 * fit,
				Color(String(gems[1]), 0.9)
			)
