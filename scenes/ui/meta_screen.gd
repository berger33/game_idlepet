class_name MetaScreen
extends Control
## Casca .tscn das telas meta: o conteúdo dinâmico é preenchido pelo MetaPanel.

var backdrop: TextureRect
var panel: PanelContainer
var title_label: Label
var close_button: Button
var content_box: VBoxContainer


func _ready() -> void:
	backdrop = get_node("Backdrop")
	panel = get_node("Panel")
	title_label = get_node("Panel/Column/Header/Title")
	close_button = get_node("Panel/Column/Header/Close")
	content_box = get_node("Panel/Column/Scroll/Content")
	title_label.add_theme_font_size_override("font_size", 46)
	title_label.add_theme_color_override("font_color", Color("263238"))
	panel.add_theme_stylebox_override(
		"panel", StyleFactory.box(Color("fffaf3", 0.98), 50, 42, Color("ff8fb1"), 7)
	)
	hide()
	backdrop.hide()
