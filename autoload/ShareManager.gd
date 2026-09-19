extends Node
## Compartilhamento antes/depois: captura o viewport no início e no fim do
## serviço, compõe lado a lado e salva PNG em user://shares/. O adapter
## móvel abre a folha de compartilhamento do sistema; no desktop o arquivo
## fica salvo (toast diz exatamente isso, sem prometer rede social).

const SHARE_DIR: String = "user://shares"

var before_image: Image
var last_saved_path: String = ""


func begin_snapshot(viewport: Viewport) -> void:
	before_image = _grab(viewport)


func finish_snapshot(viewport: Viewport, context: String) -> String:
	var after: Image = _grab(viewport)
	if before_image == null or after == null:
		Analytics.track(&"share_created", {"ok": false, "context": context})
		return ""
	DirAccess.make_dir_recursive_absolute(SHARE_DIR)
	var composed: Image = Image.create(
		before_image.get_width() + after.get_width(),
		maxi(before_image.get_height(), after.get_height()),
		false,
		Image.FORMAT_RGBA8
	)
	composed.blit_rect(
		before_image,
		Rect2i(0, 0, before_image.get_width(), before_image.get_height()),
		Vector2i.ZERO
	)
	composed.blit_rect(
		after,
		Rect2i(0, 0, after.get_width(), after.get_height()),
		Vector2i(before_image.get_width(), 0)
	)
	var path: String = "%s/antes_depois_%d.png" % [SHARE_DIR, int(Time.get_unix_time_from_system())]
	var error: Error = composed.save_png(path)
	last_saved_path = path if error == OK else ""
	Analytics.track(&"share_created", {"ok": error == OK, "context": context})
	return last_saved_path


func _grab(viewport: Viewport) -> Image:
	if viewport == null:
		return null
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image != null:
		image.resize(540, 960)
	return image
