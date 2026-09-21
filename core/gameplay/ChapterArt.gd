class_name ChapterArt
extends RefCounted
## Progresso visível por capítulo (auditoria §3): os 10 tiers do
## estabelecimento mudavam só o nome na placa. Agora a parede da sala ganha um
## "mural" que cresce a cada dois capítulos (foto, relógio, prêmio, letreiro,
## coroa) e a luz do ambiente muda de quintal quente para clínica/rede.
## Desenho procedural sobre o fundo (nada de PNG novo); tudo estático.

const WALL_Y: float = 615.0
const ITEM_X: Array[float] = [380.0, 470.0, 560.0, 650.0, 740.0]
const FRAME: Color = Color("8d6e63")
const CREAM: Color = Color("fff8ef")
const GOLD: Color = Color("ffd54f")
const PINK: Color = Color("ff8fb1")
const CHARCOAL: Color = Color("263238")


## Tinta ambiente por tier: quintal quente → clínica clara → rede dourada.
static func tint_for(tier: int) -> Color:
	if tier >= 7:
		return Color(1.0, 0.93, 0.78, 0.07)
	if tier >= 4:
		return Color(0.86, 0.94, 1.0, 0.07)
	return Color(0.0, 0.0, 0.0, 0.0)


static func draw_wall(shop) -> void:
	var tier: int = clampi(int(shop.establishment_tier), 1, 10)
	var tint: Color = tint_for(tier)
	if tint.a > 0.0:
		shop.draw_rect(Rect2(Vector2.ZERO, shop.size), tint)
	if tier >= 2:
		_draw_photo(shop, Vector2(ITEM_X[0], WALL_Y))
	if tier >= 4:
		_draw_clock(shop, Vector2(ITEM_X[1], WALL_Y))
	if tier >= 6:
		_draw_award(shop, Vector2(ITEM_X[2], WALL_Y))
	if tier >= 8:
		_draw_neon(shop, Vector2(ITEM_X[3], WALL_Y))
	if tier >= 10:
		_draw_crown(shop, Vector2(ITEM_X[4], WALL_Y))


## Tier 2: foto emoldurada de uma patinha (primeiro cliente feliz).
static func _draw_photo(shop, center: Vector2) -> void:
	shop.draw_rect(Rect2(center - Vector2(38, 38), Vector2(76, 76)), FRAME)
	shop.draw_rect(Rect2(center - Vector2(30, 30), Vector2(60, 60)), CREAM)
	shop.draw_circle(center + Vector2(0, 8), 13.0, Color("a1887f"))
	for i: int in 4:
		var angle: float = -PI * 0.85 + float(i) * (PI * 0.7 / 3.0)
		var toe: Vector2 = center + Vector2(cos(angle), sin(angle)) * 21.0 + Vector2(0, 4)
		shop.draw_circle(toe, 6.0, Color("a1887f"))


## Tier 4: relógio de parede com ponteiros vivos (clínica moderna).
static func _draw_clock(shop, center: Vector2) -> void:
	shop.draw_circle(center, 38.0, FRAME)
	shop.draw_circle(center, 32.0, CREAM)
	for i: int in 12:
		var angle: float = TAU * float(i) / 12.0
		shop.draw_circle(center + Vector2(cos(angle), sin(angle)) * 26.0, 1.8, CHARCOAL)
	var time: Dictionary = Time.get_time_dict_from_system()
	var minute_angle: float = TAU * float(time.get("minute", 0)) / 60.0 - PI * 0.5
	var hour_angle: float = (
		TAU * (float(int(time.get("hour", 0)) % 12) + float(time.get("minute", 0)) / 60.0) / 12.0
		- PI * 0.5
	)
	shop.draw_line(center, center + Vector2(cos(hour_angle), sin(hour_angle)) * 15.0, CHARCOAL, 4)
	shop.draw_line(center, center + Vector2(cos(minute_angle), sin(minute_angle)) * 23.0, CHARCOAL, 3)
	var second_angle: float = fmod(shop.shake_phase, 60.0) / 60.0 * TAU - PI * 0.5
	shop.draw_line(center, center + Vector2(cos(second_angle), sin(second_angle)) * 24.0, PINK, 2)


## Tier 6: prêmio "5 estrelas" do bairro.
static func _draw_award(shop, center: Vector2) -> void:
	shop.draw_rect(Rect2(center - Vector2(38, 34), Vector2(76, 68)), Color("5d4037"))
	shop.draw_rect(Rect2(center - Vector2(32, 28), Vector2(64, 56)), GOLD)
	shop.draw_rect(Rect2(center - Vector2(26, 22), Vector2(52, 44)), Color("fff3c4"))
	for i: int in 5:
		var angle: float = -PI * 0.5 + TAU * float(i) / 5.0
		shop.draw_circle(center + Vector2(cos(angle), sin(angle)) * 12.0, 3.5, Color("ffb300"))
	shop.draw_circle(center, 5.0, Color("ffb300"))


## Tier 8: letreiro neon pulsando (rede nacional).
static func _draw_neon(shop, center: Vector2) -> void:
	var glow: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(shop.shake_phase * 3.0))
	var neon: Color = Color("4fc3f7", glow)
	shop.draw_rect(Rect2(center - Vector2(40, 26), Vector2(80, 52)), Color("263238", 0.85))
	shop.draw_rect(Rect2(center - Vector2(34, 20), Vector2(68, 40)), Color("4fc3f7", 0.12 * glow))
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 12:
		var t: float = float(i) / 11.0
		points.append(center + Vector2(-26.0 + t * 52.0, sin(t * TAU) * 9.0))
	shop.draw_polyline(points, neon, 4)
	shop.draw_circle(center + Vector2(0, -22), 4.0, Color(PINK, glow))


## Tier 10: coroa do império com brilhos girando.
static func _draw_crown(shop, center: Vector2) -> void:
	var base: Vector2 = center + Vector2(0, 14)
	shop.draw_colored_polygon(
		PackedVector2Array(
			[
				base + Vector2(-32, 0), base + Vector2(-32, -22), base + Vector2(-16, -8),
				base + Vector2(0, -34), base + Vector2(16, -8), base + Vector2(32, -22),
				base + Vector2(32, 0),
			]
		),
		GOLD
	)
	shop.draw_rect(Rect2(base + Vector2(-32, 0), Vector2(64, 12)), Color("ffb300"))
	shop.draw_circle(base + Vector2(0, -34), 5.0, PINK)
	for i: int in 3:
		var angle: float = shop.shake_phase * 1.5 + TAU * float(i) / 3.0
		var sparkle: Vector2 = center + Vector2(cos(angle), sin(angle)) * 46.0
		shop.draw_line(sparkle - Vector2(6, 0), sparkle + Vector2(6, 0), Color(GOLD, 0.8), 2)
		shop.draw_line(sparkle - Vector2(0, 6), sparkle + Vector2(0, 6), Color(GOLD, 0.8), 2)
