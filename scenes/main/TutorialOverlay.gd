extends Control
## Tutorial spotlight não-bloqueante: escurece a tela ao redor do alvo
## (sem shader, com 4 retângulos de dim) e pulsa a borda + instrução.
## Avança apenas com eventos reais do jogo; sempre pulável.

const GUIDE_FONT: Font = preload("res://art/fonts/DejaVuSans-Bold.ttf")

var spotlight_rect: Rect2 = Rect2(0, 0, 0, 0)
var message: String = ""
var pulse: float = 0.0
var active: bool = false


func show_step(rect: Rect2, text: String) -> void:
	active = true
	visible = true
	spotlight_rect = rect
	message = text
	pulse = 0.0
	queue_redraw()


func finish() -> void:
	active = false
	visible = false


func _process(delta: float) -> void:
	if active:
		pulse += delta
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var dim: Color = Color("263238", 0.52)
	var r: Rect2 = spotlight_rect
	draw_rect(Rect2(0.0, 0.0, size.x, maxf(0.0, r.position.y)), dim)
	draw_rect(Rect2(0.0, r.end.y, size.x, maxf(0.0, size.y - r.end.y)), dim)
	draw_rect(Rect2(0.0, r.position.y, maxf(0.0, r.position.x), r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, maxf(0.0, size.x - r.end.x), r.size.y), dim)
	var glow: float = 0.55 + 0.35 * sin(pulse * 5.0)
	draw_rect(r, Color("ffd54f", glow), false, 9.0)
	draw_rect(r.grow(6.0), Color("ffd54f", glow * 0.22), false, 4.0)
	# Label reposiciona se sair da tela (pet embaixo) + safe area
	var safe_top: float = 0.0
	if OS.has_feature("mobile") or OS.has_feature("web"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		if safe.position.y > 0:
			safe_top = clampf(float(safe.position.y) * 0.5, 0.0, 80.0)
	var label_y: float = r.end.y + 20.0
	var arrow_up: bool = true
	if label_y + 110.0 > size.y - 90.0 - safe_top:
		label_y = r.position.y - 116.0
		arrow_up = false
		if label_y < safe_top + 20.0:
			label_y = safe_top + 20.0
	var label_rect: Rect2 = Rect2(60.0, label_y, 960.0, 96.0)
	draw_rect(label_rect, Color("263238", 0.96), true)
	draw_rect(label_rect, Color("ffd54f", 0.85), false, 3.0)
	# Seta apontando para o spotlight
	var arrow_center: Vector2 = Vector2(r.position.x + r.size.x * 0.5, label_y + (96.0 if arrow_up else 0.0))
	var arrow_tip: Vector2 = Vector2(r.position.x + r.size.x * 0.5, r.end.y + 6.0 if arrow_up else r.position.y - 6.0)
	var arrow_dir: float = 1.0 if arrow_up else -1.0
	var tri: PackedVector2Array = PackedVector2Array([
		arrow_tip,
		arrow_center + Vector2(-18.0, 14.0 * arrow_dir),
		arrow_center + Vector2(18.0, 14.0 * arrow_dir)
	])
	draw_colored_polygon(tri, Color("ffd54f", 0.95))
	draw_string(
		GUIDE_FONT,
		Vector2(80.0, label_y + 62.0),
		message,
		HORIZONTAL_ALIGNMENT_CENTER,
		920.0,
		32,
		Color("ffd54f"),
	)
