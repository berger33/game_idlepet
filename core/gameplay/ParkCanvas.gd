extends Control
## Canvas do Parquinho / Creche — 3 pets soltos no quintal, 3 mini-jogos.
## Visual: quintal (petshop_quintal.png) + pets amigos + overlay de gesto.

const PARK_BG: Texture2D = preload("res://art/backgrounds/petshop_quintal.png")
const FONT: Font = preload("res://art/fonts/DejaVuSans-Bold.ttf")
const PET_TEXTURES: Dictionary = {
	"caramelo": preload("res://art/pets/caramelo.png"),
	"bento_beagle": preload("res://art/pets/bento_beagle.png"),
	"mel_golden": preload("res://art/pets/mel_golden.png"),
}
# Cache de texturas do parquinho — evita hitch do hitch na primeira abertura
static var _pet_tex_cache: Dictionary = {}

var pet_ids: Array[String] = ["caramelo", "caramelo", "caramelo"]
var pet_textures: Array[Texture2D] = []
var activity: StringName = &"ball"
var progress: float = 0.0
var time_ratio: float = 1.0
var score: int = 0
var playful_hop: bool = false

var ball_pos: Vector2 = Vector2(540, 1080)
var treat_choice: int = -1
var treat_revealed: bool = false
var treat_hidden_slot: int = 1
var photo_align: float = 0.5
var celebration: float = 0.0
var forced_state: StringName = &""

var _time: float = 0.0
var _bubbles: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(1080, 1920)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func set_pets(ids: Array[String]) -> void:
	pet_ids = ids.duplicate()
	pet_textures.clear()
	for pid: String in pet_ids:
		var tex: Texture2D = PET_TEXTURES.get(pid, null)
		if tex == null:
			tex = _pet_tex_cache.get(pid, null)
		if tex == null and ResourceLoader.exists("res://art/pets/%s.png" % pid):
			tex = load("res://art/pets/%s.png" % pid) as Texture2D
			if tex != null:
				_pet_tex_cache[pid] = tex
		if tex == null:
			tex = PET_TEXTURES["caramelo"]
		pet_textures.append(tex)
	queue_redraw()

func set_activity(id: StringName) -> void:
	activity = id
	progress = 0.0
	time_ratio = 1.0
	score = 0
	treat_choice = -1
	treat_revealed = false
	photo_align = 0.5
	ball_pos = Vector2(540, 1080)
	queue_redraw()

func set_state(p: float, t_ratio: float, s: int) -> void:
	progress = p
	time_ratio = t_ratio
	score = s
	queue_redraw()

func spawn_bubble(at: Vector2) -> void:
	_bubbles.append({"pos": at, "t": 0.0, "vel": Vector2(randf_range(-40, 40), -90)})

func celebrate(success: bool) -> void:
	celebration = 2.2 if success else 0.0

func _process(delta: float) -> void:
	_time += delta
	if celebration > 0.0:
		celebration = maxf(0.0, celebration - delta)
	for b: Dictionary in _bubbles:
		b["t"] = float(b["t"]) + delta
		b["pos"] = Vector2(b["pos"]) + Vector2(b["vel"]) * delta
	_bubbles = _bubbles.filter(func(d): return float(d["t"]) < 1.6)
	queue_redraw()

func pet_focus(idx: int = 0) -> Vector2:
	# 3 pets espalhados no quintal, centro da tela vert. 700-950
	match idx:
		0: return Vector2(300, 820)
		1: return Vector2(540, 760)
		2: return Vector2(780, 820)
		_: return Vector2(540, 800)

func ball_hit(pos: Vector2) -> bool:
	return pos.distance_to(ball_pos) < 96.0

func treat_slot_at(pos: Vector2) -> int:
	for i: int in 3:
		var c: Vector2 = Vector2(260 + i * 280, 1050)
		if pos.distance_to(c) < 110.0:
			return i
	return -1

func photo_hit(pos: Vector2) -> bool:
	return Rect2(Vector2(340, 1180), Vector2(400, 110)).has_point(pos)

func _draw() -> void:
	# fundo quintal
	var bg_rect: Rect2 = Rect2(Vector2.ZERO, size)
	if PARK_BG != null:
		draw_texture_rect(PARK_BG, bg_rect, false)
	else:
		draw_rect(bg_rect, Color("a5d6a7"))
	# vinheta creme no topo para legibilidade do HUD do parque
	draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 170)), Color("fff3e0", 0.88))
	# chao
	draw_rect(Rect2(Vector2(0, 980), Vector2(size.x, size.y - 980)), Color("81c784", 0.95))
	# pets — com variação de porte via PetAnimationTuning + respiração sutil + sombra reativa
	for i: int in 3:
		var pid: String = pet_ids[i] if i < pet_ids.size() else "caramelo"
		var tex: Texture2D = pet_textures[i] if i < pet_textures.size() else PET_TEXTURES["caramelo"]
		var center: Vector2 = pet_focus(i)
		var hop: float = 0.0
		if playful_hop or celebration > 0.0:
			hop = abs(sin(_time * 6.0 + float(i) * 1.1)) * 18.0
		center.y -= hop
		# porte do pet: pequeno 0.66 / médio 0.72 / grande 0.80 — mantém proporção do PetShopCanvas
		var pname_raw: String = pid
		var profile: Dictionary = ContentDB.pet(pid) if ContentDB.has_pet(pid) else {}
		var breed_for_scale: String = String(profile.get("breed", ""))
		var is_small_p: bool = PetAnimationTuning.is_small_breed(breed_for_scale)
		var is_large_p: bool = PetAnimationTuning.is_large_breed(breed_for_scale)
		var scale: float = 0.66 if is_small_p else (0.80 if is_large_p else 0.72)
		# respiração sutil no parquinho (fora da banheira) — 1/3 da amplitude normal
		var breath: float = sin(_time * (1.6 if is_small_p else 2.2) + float(i)) * (1.6 if celebration <= 0.0 else 3.0)
		center.y += breath
		if tex != null:
			var sz: Vector2 = Vector2(tex.get_width(), tex.get_height()) * scale
			# sombra reativa ao salto: encolhe e clareia no ar
			var sh_alpha: float = 0.18 - clampf(hop / 72.0, 0.0, 1.0) * 0.10
			var sh_scale: Vector2 = Vector2(80, 22) * (1.0 - clampf(hop / 72.0, 0.0, 1.0) * 0.35)
			draw_ellipse(center + Vector2(0, 90 - breath * 0.2), sh_scale, Color("263238", sh_alpha))
			var rect: Rect2 = Rect2(center - sz * 0.5, sz)
			draw_texture_rect(tex, rect, false)
		# nome do pet (legível) — pill branca arredondada atrás do texto
		var pname: String = ContentDB.pet_name(pid) if ContentDB.has_pet(pid) else pid.capitalize()
		var font: Font = FONT
		var fsz: int = 26
		var txt_sz: Vector2 = font.get_string_size(pname, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz)
		var pill_pos: Vector2 = center + Vector2(-txt_sz.x * 0.5 - 10, 118)
		draw_rect(Rect2(pill_pos, Vector2(txt_sz.x + 20, 32)), Color.WHITE, true, 16.0)
		draw_rect(Rect2(pill_pos, Vector2(txt_sz.x + 20, 32)), Color("263238", 0.08), false, 1.5)
		draw_string(font, center + Vector2(-txt_sz.x * 0.5, 140), pname, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color("263238", 0.95))
	# atividade overlay
	if activity == &"ball":
		# bolinha — cor pulsa no beat quando perto do pet, brilho interno
		var dist_to_pet: float = ball_pos.distance_to(pet_focus(1))
		var near: bool = dist_to_pet < 110
		var pulse_ball: float = 0.5 + 0.5 * sin(_time * 5.0) if near else 0.0
		var ball_col: Color = Color("ff3d57").lerp(Color("ff1744"), pulse_ball * 0.25) if near else Color("ff6f8a")
		draw_circle(ball_pos, 46.0 + pulse_ball * 4.0, ball_col)
		draw_circle(ball_pos, 42.0, Color.WHITE)
		draw_circle(ball_pos, 34.0 + pulse_ball * 2.0, ball_col)
		draw_circle(ball_pos + Vector2(-10, -10), 10.0, Color.WHITE)
		if near:
			draw_circle(ball_pos, 52.0, Color("ffd54f", 0.14 + pulse_ball * 0.08))
		# rastro: tracejado quando longe, sólido fino quando perto
		var dash_len: float = 12.0 if not near else 0.0
		var dash_alpha: float = clampf(1.0 - dist_to_pet / 420.0, 0.25, 0.92)
		if dash_len > 0.5:
			draw_dashed_line(ball_pos, pet_focus(1), Color(Color.WHITE, dash_alpha), 3.0, dash_len)
		else:
			draw_line(ball_pos, pet_focus(1), Color(Color.WHITE, 0.92), 2.0)
	elif activity == &"treat":
		for i: int in 3:
			var c: Vector2 = Vector2(260 + i * 280, 1050)
			var chosen: bool = treat_choice == i
			var has_treat: bool = treat_revealed and i == _hidden_slot()
			var base: Color = Color("ffd54f") if chosen else Color("fff3e0")
			if has_treat:
				base = Color("a5d6a7")
			draw_circle(c, 86.0, Color("263238", 0.18))
			draw_circle(c, 82.0, base)
			draw_circle(c, 76.0, Color.WHITE)
			if treat_revealed:
				if has_treat:
					draw_string(FONT, c + Vector2(-18, 14), "🦴", HORIZONTAL_ALIGNMENT_CENTER, -1, 48, Color("2e7d32"))
				elif chosen:
					draw_string(FONT, c + Vector2(-14, 14), "✕", HORIZONTAL_ALIGNMENT_CENTER, -1, 44, Color("ef5350"))
			else:
				draw_string(FONT, c + Vector2(-18, 14), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, 44, Color("90a4ae"))
	elif activity == &"photo":
		var frame: Rect2 = Rect2(Vector2(140, 1000), Vector2(800, 260))
		draw_rect(frame, Color.WHITE, false, 6.0)
		draw_rect(frame.grow(-6), Color("263238", 0.08))
		# viewfinder pips — estabilizado: sway determinístico por _time + photo_align (não rand() por frame)
		for i: int in 3:
			# desfaz o jitter de randf_range: sway suave 2 Hz + phase por pet, amplitude cai com alinhamento
			var sway: Vector2 = Vector2(sin(_time * 2.1 + float(i) * 1.9), cos(_time * 1.6 + float(i) * 2.3)) * (10.0 * (1.0 - photo_align))
			var pip: Vector2 = Vector2(220 + i * 240, 1130) + sway
			var ok: bool = photo_align > 0.72
			# pulso sutil no beat quando ok (vindo do AudioManager.beat_phase via _time local)
			var pip_pulse: float = (0.5 + 0.5 * sin(_time * 6.0 + i)) * 3.0 if ok else 0.0
			draw_circle(pip, 34.0 + pip_pulse, Color("a5d6a7") if ok else Color("ffcc80"))
			draw_circle(pip, 30.0 + pip_pulse * 0.5, Color.WHITE)
			draw_string(FONT, pip + Vector2(-12, 10), "●", HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color("2e7d32") if ok else Color("ef6c00"))
		# botão shutter
		var btn: Rect2 = Rect2(Vector2(340, 1180), Vector2(400, 110))
		var shutter_col: Color = Color("ef5350") if photo_align > 0.72 else Color("90a4ae")
		draw_rect(btn, shutter_col, true, 28.0)
		draw_rect(btn, Color.WHITE, false, 3.0)
		var label: String = Loc.t("PARK_SHUTTER") if Loc.t("PARK_SHUTTER") != "PARK_SHUTTER" else "FOTO!"
		var lb: Font = FONT
		draw_string(lb, Vector2(540 - lb.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 36).x * 0.5, 1250), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
		# barra de alinhamento
		var bar_bg: Rect2 = Rect2(Vector2(160, 1330), Vector2(760, 18))
		draw_rect(bar_bg, Color("263238", 0.22), true, 9.0)
		draw_rect(Rect2(bar_bg.position, Vector2(bar_bg.size.x * clampf(photo_align, 0.0, 1.0), bar_bg.size.y)), Color("4fc3f7") if photo_align < 0.72 else Color("2e7d32"), true, 9.0)
		var sweet: Rect2 = Rect2(Vector2(160 + 760 * 0.72, 1326), Vector2(760 * 0.28, 26))
		draw_rect(sweet, Color("2e7d32", 0.18), true, 6.0)
		draw_rect(sweet, Color("2e7d32", 0.65), false, 2.0)
	# HUD progresso/tempo (fora da banheira, discreto mas legível)
	var hud_bg: Rect2 = Rect2(Vector2(40, 1400), Vector2(1000, 84))
	draw_rect(hud_bg, Color("263238", 0.82), true, 24.0)
	draw_rect(hud_bg, Color.WHITE, false, 2.0)
	var fill_w: float = hud_bg.size.x * clampf(progress, 0.0, 1.0) - 8.0
	if fill_w > 0:
		draw_rect(Rect2(hud_bg.position + Vector2(4, 4), Vector2(fill_w, hud_bg.size.y - 8)), Color("2e7d32") if progress >= 0.72 else Color("4fc3f7"), true, 20.0)
	# marcas de alvo
	var mark_x: float = hud_bg.position.x + hud_bg.size.x * 0.72
	draw_line(Vector2(mark_x, hud_bg.position.y + 8), Vector2(mark_x, hud_bg.position.y + hud_bg.size.y - 8), Color.WHITE, 3.0)
	draw_line(Vector2(hud_bg.position.x + hud_bg.size.x * 0.95, hud_bg.position.y + 8), Vector2(hud_bg.position.x + hud_bg.size.x * 0.95, hud_bg.position.y + hud_bg.size.y - 8), Color.WHITE, 3.0)
	# tempo
	var time_bar: Rect2 = Rect2(Vector2(40, 1496), Vector2(1000, 14))
	draw_rect(time_bar, Color("263238", 0.22), true, 7.0)
	draw_rect(Rect2(time_bar.position, Vector2(time_bar.size.x * clampf(time_ratio, 0.0, 1.0), time_bar.size.y)), Color("ffd54f"), true, 7.0)
	# bolhas
	for b: Dictionary in _bubbles:
		var a: float = clampf(1.0 - float(b["t"]) / 1.6, 0.0, 1.0)
		draw_circle(Vector2(b["pos"]), 18.0 * a + 6.0, Color("ffffff", 0.85 * a))
		draw_circle(Vector2(b["pos"]) + Vector2(-4, -4), 6.0 * a, Color.WHITE)
	if celebration > 0.0:
		var s: float = 1.0 + sin(_time * 10.0) * 0.04
		draw_string(FONT, Vector2(540 - FONT.get_string_size("★", HORIZONTAL_ALIGNMENT_CENTER, -1, 96).x * 0.5, 620) * s, "★", HORIZONTAL_ALIGNMENT_LEFT, -1, int(96 * s), Color("ffd54f", celebration / 2.2))

func _hidden_slot() -> int:
	return treat_hidden_slot
