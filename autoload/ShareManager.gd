extends Node
## Compartilhamento antes/depois como ARTEFATO VIRAL (auditoria de viralização):
## um cartão 9:16 com marca — recorte do pet antes e depois, nome/raça,
## estrelas e assinatura do jogo — em vez da tela inteira com HUD.
##
## Onde o arquivo vai parar importa tanto quanto o cartão:
## - Web: navigator.share com o arquivo (folha nativa no celular) ou download.
## - Android/desktop: pasta pública de Imagens (galeria) + legenda no clipboard.
##   user:// é privado no Android — o jogador nunca encontrava a foto.
## Sem plugin de share nativo nesta build; o toast diz exatamente o que houve.

const SHARE_DIR_NAME: String = "PetShopTycoon"
const CARD_SIZE: Vector2i = Vector2i(1080, 1920)
## Lado do recorte em torno do foco do pet (coordenadas do canvas 1080×1920).
const CROP_SIZE: float = 680.0
const PHOTO_SIZE: int = 500
## Link do cartão/legenda (loja ou web). Vazio até o release: nunca inventar URL.
const SHARE_URL: String = ""
const TITLE_FONT: Font = preload("res://art/fonts/DejaVuSans-Bold.ttf")
const BODY_FONT: Font = preload("res://art/fonts/DejaVuSans.ttf")

var before_image: Image
var before_focus: Vector2 = Vector2(540, 990)
var last_saved_path: String = ""
var last_caption: String = ""


## Início do serviço: guarda o recorte "antes" em torno do pet.
func begin_snapshot(viewport: Viewport, focus: Vector2 = Vector2(540, 990)) -> void:
	before_focus = focus
	before_image = _crop(viewport, focus)


## Fim do serviço: recorte "depois", cartão 9:16 e arquivo. meta: {"pet_id", "stars"}.
## Corrotina (renderiza o cartão num SubViewport por um frame); o chamador não
## precisa aguardar — last_saved_path fica pronto antes de qualquer toque.
func finish_snapshot(viewport: Viewport, context: String, meta: Dictionary = {}) -> String:
	var after: Image = _crop(viewport, before_focus)
	if before_image == null or after == null:
		Analytics.track(&"share_created", {"ok": false, "context": context})
		return ""
	var profile: Dictionary = ContentDB.pet(String(meta.get("pet_id", "caramelo")))
	var stars: int = clampi(int(meta.get("stars", 5)), 1, 5)
	var card: Image = await _render_card(before_image, after, profile, stars, context)
	if card == null:
		Analytics.track(&"share_created", {"ok": false, "context": context})
		return ""
	var directory: String = share_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = "%s/antes_depois_%d.png" % [directory, int(Time.get_unix_time_from_system())]
	var error: Error = card.save_png(path)
	last_saved_path = path if error == OK else ""
	last_caption = caption_for(profile, stars)
	Analytics.track(&"share_created", {"ok": error == OK, "context": context})
	return last_saved_path


## Pasta pública de Imagens quando existe (galeria); user:// como fallback.
func share_directory() -> String:
	if OS.has_feature("web"):
		return "user://shares"
	var pictures: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES, true)
	if pictures.is_empty():
		return "user://shares"
	return pictures.path_join(SHARE_DIR_NAME)


## Legenda pronta para colar: pet, estrelas e assinatura (+ link se houver).
func caption_for(profile: Dictionary, stars: int) -> String:
	var pet_id: String = String(profile.get("id", "caramelo"))
	var pet_display: String = String(profile.get("name", "Pet"))
	if ContentDB.has_pet(pet_id):
		pet_display = ContentDB.pet_name(pet_id)
	var text: String = Loc.t("SHARE_CAPTION") % [
		pet_display, "★".repeat(stars)
	]
	if not SHARE_URL.is_empty():
		text += " " + SHARE_URL
	return text


func caption_for_achievement(achievement_id: String) -> String:
	var name: String = ContentDB.achievement_name(achievement_id)
	var text: String = Loc.t("SHARE_ACHIEVEMENT_CAPTION") % name
	if not SHARE_URL.is_empty():
		text += " " + SHARE_URL
	return text


## Compartilha conquista como cartão 9:16 com marca (sem antes/depois).
func share_achievement(achievement_id: String) -> String:
	var card: Image = await _render_achievement_card(achievement_id)
	if card == null:
		Analytics.track(&"share_created", {"ok": false, "context": "achievement"})
		return ""
	var directory: String = share_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var timestamp: int = int(Time.get_unix_time_from_system())
	var path: String = "%s/conquista_%s_%d.png" % [
		directory, achievement_id, timestamp
	]
	var error: Error = card.save_png(path)
	last_saved_path = path if error == OK else ""
	last_caption = caption_for_achievement(achievement_id)
	Analytics.track(&"share_created", {"ok": error == OK, "context": "achievement"})
	return last_saved_path


## Canal de compartilhamento da plataforma. Retorna o que aconteceu:
## &"web_share" (folha nativa/download no navegador), &"clipboard" (imagem na
## galeria + legenda copiada) ou &"none" (nada para compartilhar).
func is_ready() -> bool:
	return not last_saved_path.is_empty() and FileAccess.file_exists(last_saved_path)

func share_last() -> StringName:
	if last_saved_path.is_empty() or not FileAccess.file_exists(last_saved_path):
		return &"none"
	if OS.has_feature("web"):
		_share_on_web(FileAccess.get_file_as_bytes(last_saved_path), last_caption)
		Analytics.track(&"share_opened", {"channel": "web"})
		return &"web_share"
	DisplayServer.clipboard_set(last_caption)
	Analytics.track(&"share_opened", {"channel": "clipboard"})
	return &"clipboard"


## navigator.share com arquivo (celular) ou download (desktop) — tudo no
## navegador; a ativação do toque ainda vale quando isto roda.
func _share_on_web(png: PackedByteArray, caption: String) -> void:
	var script: String = (
		"""
		(async () => {
			const bin = atob("%s");
			const bytes = new Uint8Array(bin.length);
			for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
			const file = new File([bytes], "antes_depois.png", {type: "image/png"});
			try {
				if (navigator.canShare && navigator.canShare({files: [file]})) {
					await navigator.share({files: [file], text: %s});
					return;
				}
			} catch (e) {}
			const url = URL.createObjectURL(file);
			const a = document.createElement("a");
			a.href = url; a.download = "antes_depois.png"; a.click();
			setTimeout(() => URL.revokeObjectURL(url), 5000);
		})();
		"""
		% [Marshalls.raw_to_base64(png), JSON.stringify(caption)]
	)
	JavaScriptBridge.eval(script, true)


## Recorte quadrado em torno do foco (coordenadas do canvas → pixels reais).
func _crop(viewport: Viewport, focus: Vector2) -> Image:
	if viewport == null:
		return null
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	var transform: Transform2D = viewport.get_final_transform()
	var center: Vector2 = transform * focus
	var scale: float = maxf(transform.get_scale().x, 0.01)
	var side: int = maxi(64, int(CROP_SIZE * scale))
	var origin: Vector2i = Vector2i(
		clampi(int(center.x - side * 0.5), 0, maxi(0, image.get_width() - side)),
		clampi(int(center.y - side * 0.5), 0, maxi(0, image.get_height() - side))
	)
	var region: Rect2i = Rect2i(origin, Vector2i(side, side)).intersection(
		Rect2i(Vector2i.ZERO, image.get_size())
	)
	if region.size.x <= 0 or region.size.y <= 0:
		return null
	var crop: Image = image.get_region(region)
	crop.resize(PHOTO_SIZE, PHOTO_SIZE, Image.INTERPOLATE_LANCZOS)
	return crop


## Cartão 9:16 renderizado num SubViewport (Image não desenha texto).
func _render_card(
	before: Image, after: Image, profile: Dictionary, stars: int, context: String
) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = CARD_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var root: Control = Control.new()
	root.size = Vector2(CARD_SIZE)
	viewport.add_child(root)
	var background: ColorRect = ColorRect.new()
	background.color = Color("ffe3ec")
	background.size = Vector2(CARD_SIZE)
	root.add_child(background)
	var band: ColorRect = ColorRect.new()
	band.color = Color("ff8fb1")
	band.position = Vector2(0, 0)
	band.size = Vector2(CARD_SIZE.x, 250)
	root.add_child(band)
	var shop_name: String = String(GameState.settings.get("shop_name", ""))
	var headline: String = shop_name if not shop_name.is_empty() else Loc.t("GAME_TITLE")
	root.add_child(_text(headline.to_upper(), 56, Color.WHITE, 60, TITLE_FONT))
	root.add_child(_text(Loc.t("SHARE_HEADLINE"), 40, Color("fff3f7"), 150, BODY_FONT))
	root.add_child(_photo(before, Vector2(40, 330), Loc.t("SHARE_BEFORE")))
	root.add_child(_photo(after, Vector2(540, 330), Loc.t("SHARE_AFTER")))
	root.add_child(
		_text(
			"%s • %s" % [String(profile.get("name", "Pet")), String(profile.get("breed", ""))],
			54,
			Color("263238"),
			1010,
			TITLE_FONT
		)
	)
	root.add_child(_text("★".repeat(stars), 84, Color("ffb300"), 1090, BODY_FONT))
	root.add_child(
		_text(Loc.t("SHARE_SERVICE_" + context.to_upper()), 42, Color("546e7a"), 1210, BODY_FONT)
	)
	var footer: String = SHARE_URL if not SHARE_URL.is_empty() else Loc.t("SHARE_HASHTAG")
	root.add_child(_text(footer, 40, Color("ff8fb1"), 1780, TITLE_FONT))
	# QR code no share (P1 Nota10): QR real escaneável — URL curta para caber v2/v3 L
	var pet_id_short: String = String(profile.get("id", "caramelo"))
	var shop_short: String = String(GameState.settings.get("shop_name", "PetShop")).left(12)
	var qr_data: String = SHARE_URL if not SHARE_URL.is_empty() else "https://p.tycoon/p/%s?s=%d&sh=%s" % [pet_id_short, stars, shop_short]
	var qr_img: Image = QRCodeArt.generate_image(qr_data, 220)
	var qr_tex: ImageTexture = ImageTexture.create_from_image(qr_img)
	var qr_frame: PanelContainer = PanelContainer.new()
	var qr_style: StyleBoxFlat = StyleBoxFlat.new()
	qr_style.bg_color = Color.WHITE
	qr_style.set_corner_radius_all(18)
	qr_style.set_content_margin_all(10)
	qr_frame.add_theme_stylebox_override("panel", qr_style)
	qr_frame.position = Vector2(430, 1320)
	qr_frame.size = Vector2(220, 260)
	var qr_box: VBoxContainer = VBoxContainer.new()
	qr_box.add_theme_constant_override("separation", 4)
	qr_frame.add_child(qr_box)
	var qr_pic: TextureRect = TextureRect.new()
	qr_pic.texture = qr_tex
	qr_pic.custom_minimum_size = Vector2(200, 200)
	qr_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr_box.add_child(qr_pic)
	var qr_label: Label = Label.new()
	qr_label.text = Loc.t("SHARE_QR_LABEL")
	qr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qr_label.custom_minimum_size = Vector2(200, 40)
	qr_label.add_theme_font_override("font", BODY_FONT)
	qr_label.add_theme_font_size_override("font_size", 22)
	qr_label.add_theme_color_override("font_color", Color("263238"))
	qr_box.add_child(qr_label)
	root.add_child(qr_frame)
	await RenderingServer.frame_post_draw
	var image: Image = null
	var texture: ViewportTexture = viewport.get_texture()
	if texture != null:
		image = texture.get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		return null
	return image


func _render_achievement_card(achievement_id: String) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = CARD_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var root: Control = Control.new()
	root.size = Vector2(CARD_SIZE)
	viewport.add_child(root)
	var background: ColorRect = ColorRect.new()
	background.color = Color("fff8e1")
	background.size = Vector2(CARD_SIZE)
	root.add_child(background)
	var band: ColorRect = ColorRect.new()
	band.color = Color("ffd54f")
	band.position = Vector2(0, 0)
	band.size = Vector2(CARD_SIZE.x, 250)
	root.add_child(band)
	var shop_name: String = String(GameState.settings.get("shop_name", ""))
	var headline: String = shop_name if not shop_name.is_empty() else Loc.t("GAME_TITLE")
	root.add_child(_text(headline.to_upper(), 56, Color.WHITE, 60, TITLE_FONT))
	root.add_child(_text(Loc.t("SHARE_ACHIEVEMENT_HEADLINE"), 40, Color("fff8e1"), 150, BODY_FONT))
	# Centro: troféu + nome da conquista
	var trophy: Label = Label.new()
	trophy.text = "🏆"
	trophy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trophy.position = Vector2(40, 400)
	trophy.size = Vector2(CARD_SIZE.x - 80, 200)
	trophy.add_theme_font_size_override("font_size", 180)
	root.add_child(trophy)
	var achievement_name: String = ContentDB.achievement_name(achievement_id)
	root.add_child(_text(achievement_name, 64, Color("263238"), 650, TITLE_FONT))
	var profile: Dictionary = ContentDB.achievements_by_id.get(achievement_id, {})
	var desc: String = String(profile.get("description", ""))
	if desc.is_empty():
		desc = Loc.t("REVEAL_ACHIEVEMENT_TITLE")
	root.add_child(_text(desc, 42, Color("546e7a"), 780, BODY_FONT))
	# Recompensa
	var reward_text: String = ""
	var reward: Dictionary = profile.get("reward", {})
	var coins: int = int(reward.get("coins", 0))
	var embers: int = int(reward.get("embers", 0))
	if coins > 0 or embers > 0:
		if coins > 0:
			reward_text = "+%d %s" % [coins, Loc.t("COINS")]
		if embers > 0:
			var sep: String = " • " if not reward_text.is_empty() else ""
			reward_text += sep + "+%d %s" % [embers, Loc.t("EMBERS")]
	if not reward_text.is_empty():
		root.add_child(_text(reward_text, 48, Color("ff8f00"), 950, TITLE_FONT))
	var footer: String = SHARE_URL if not SHARE_URL.is_empty() else Loc.t("SHARE_HASHTAG")
	root.add_child(_text(footer, 40, Color("ff8fb1"), 1780, TITLE_FONT))
	# QR code também no cartão de conquista — Nota10 URL curta escaneável
	var qr_data2: String = SHARE_URL if not SHARE_URL.is_empty() else "https://p.tycoon/a/%s" % [achievement_id]
	var qr_img2: Image = QRCodeArt.generate_image(qr_data2, 220)
	var qr_tex2: ImageTexture = ImageTexture.create_from_image(qr_img2)
	var qr_frame2: PanelContainer = PanelContainer.new()
	var qr_style2: StyleBoxFlat = StyleBoxFlat.new()
	qr_style2.bg_color = Color.WHITE
	qr_style2.set_corner_radius_all(18)
	qr_style2.set_content_margin_all(10)
	qr_frame2.add_theme_stylebox_override("panel", qr_style2)
	qr_frame2.position = Vector2(430, 1080)
	qr_frame2.size = Vector2(220, 260)
	var qr_box2: VBoxContainer = VBoxContainer.new()
	qr_box2.add_theme_constant_override("separation", 4)
	qr_frame2.add_child(qr_box2)
	var qr_pic2: TextureRect = TextureRect.new()
	qr_pic2.texture = qr_tex2
	qr_pic2.custom_minimum_size = Vector2(200, 200)
	qr_pic2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr_box2.add_child(qr_pic2)
	var qr_label2: Label = Label.new()
	qr_label2.text = Loc.t("SHARE_QR_LABEL")
	qr_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qr_label2.custom_minimum_size = Vector2(200, 40)
	qr_label2.add_theme_font_override("font", BODY_FONT)
	qr_label2.add_theme_font_size_override("font_size", 22)
	qr_label2.add_theme_color_override("font_color", Color("263238"))
	qr_box2.add_child(qr_label2)
	root.add_child(qr_frame2)
	await RenderingServer.frame_post_draw
	var image: Image = null
	var texture: ViewportTexture = viewport.get_texture()
	if texture != null:
		image = texture.get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		return null
	return image


func _text(text: String, size: int, color: Color, y: float, font: Font) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(40, y)
	label.size = Vector2(CARD_SIZE.x - 80, 120)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## "Polaroid": moldura branca com a foto e a etiqueta ANTES/DEPOIS.
func _photo(image: Image, position: Vector2, tag: String) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(28)
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	frame.position = position
	frame.size = Vector2(PHOTO_SIZE, PHOTO_SIZE + 110)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	frame.add_child(box)
	var picture: TextureRect = TextureRect.new()
	picture.texture = ImageTexture.create_from_image(image)
	picture.custom_minimum_size = Vector2(PHOTO_SIZE, PHOTO_SIZE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(picture)
	var label: Label = Label.new()
	label.text = tag
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(PHOTO_SIZE, 110)
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color("263238"))
	box.add_child(label)
	return frame
