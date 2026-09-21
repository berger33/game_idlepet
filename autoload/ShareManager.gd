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
	var text: String = Loc.t("SHARE_CAPTION") % [
		String(profile.get("name", "Pet")), "★".repeat(stars)
	]
	if not SHARE_URL.is_empty():
		text += " " + SHARE_URL
	return text


## Canal de compartilhamento da plataforma. Retorna o que aconteceu:
## &"web_share" (folha nativa/download no navegador), &"clipboard" (imagem na
## galeria + legenda copiada) ou &"none" (nada para compartilhar).
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
	root.add_child(_text(Loc.t("GAME_TITLE").to_upper(), 56, Color.WHITE, 60, TITLE_FONT))
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
