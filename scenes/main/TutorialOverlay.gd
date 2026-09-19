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
	var dim: Color = Color("263238", 0.45)
	var r: Rect2 = spotlight_rect
	# Quatro faixas de dim deixam o alvo "recortado" sem shader.
	draw_rect(Rect2(0.0, 0.0, size.x, maxf(0.0, r.position.y)), dim)
	draw_rect(Rect2(0.0, r.end.y, size.x, maxf(0.0, size.y - r.end.y)), dim)
	draw_rect(Rect2(0.0, r.position.y, maxf(0.0, r.position.x), r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, maxf(0.0, size.x - r.end.x), r.size.y), dim)
	var glow: float = 0.55 + 0.35 * sin(pulse * 5.0)
	draw_rect(r, Color("ffd54f", glow), false, 8.0)
	var label_rect: Rect2 = Rect2(90.0, r.end.y + 20.0, 900.0, 96.0)
	draw_rect(label_rect, Color("263238", 0.92))
	draw_string(
		GUIDE_FONT,
		Vector2(120.0, r.end.y + 78.0),
		message,
		HORIZONTAL_ALIGNMENT_CENTER,
		840.0,
		34,
		Color("ffd54f"),
	)
