class_name SalonPanels
extends RefCounted
## Construção de painéis e cartões do salão (padrão GestureArt/StationArt):
## o Main monta o fluxo do jogo, este arquivo monta a UI. Tudo estático e
## sem estado — `style` e `button` são os helpers visuais do Main (Callables).

const PINK: Color = Color("ff8fb1")
const BLUE: Color = Color("4fc3f7")
const GREEN: Color = Color("7ed957")
const CHARCOAL: Color = Color("263238")


## Painel de resultado do atendimento (espelhado pelo painel de upsell).
static func build_result_panel(
	parent: Control,
	style: Callable,
	button: Callable,
	on_primary: Callable,
	on_share: Callable
) -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(110, 430)
	panel.size = Vector2(860, 720)
	panel.add_theme_stylebox_override(
		"panel", style.call(Color("263238", 0.96), 52, 42, PINK, 7)
	)
	parent.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 25)
	panel.add_child(column)
	var title: Label = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	column.add_child(title)
	var detail: Label = Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 39)
	detail.add_theme_color_override("font_color", Color.WHITE)
	column.add_child(detail)
	var actions: VBoxContainer = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	var primary: Button = button.call("✓  CONTINUAR", GREEN, 0, 105)
	primary.pressed.connect(on_primary)
	actions.add_child(primary)
	var share: Button = button.call(Loc.t("SHARE_BUTTON"), BLUE, 0, 88)
	share.pressed.connect(on_share)
	actions.add_child(share)
	panel.hide()
	return {
		"panel": panel, "title": title, "detail": detail, "primary": primary, "share": share,
	}


## Painel de pedido especial (Onda 2): decisão antes do resultado.
static func build_upsell_panel(
	parent: Control, style: Callable, button: Callable, on_accept: Callable, on_decline: Callable
) -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(110, 430)
	panel.size = Vector2(860, 720)
	panel.add_theme_stylebox_override(
		"panel", style.call(Color("263238", 0.96), 52, 42, Color("ce93d8"), 7)
	)
	parent.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)
	var title: Label = Label.new()
	title.text = "PEDIDO ESPECIAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 62)
	title.add_theme_color_override("font_color", Color("ce93d8"))
	column.add_child(title)
	var body: Label = Label.new()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 39)
	body.add_theme_color_override("font_color", Color.WHITE)
	column.add_child(body)
	var note: Label = Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 30)
	note.add_theme_color_override("font_color", Color("b0bec5"))
	note.text = "Atender agora rende gorjeta extra no serviço aceito."
	column.add_child(note)
	var actions: VBoxContainer = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	var accept: Button = button.call("✓  ACEITAR", GREEN, 0, 105)
	accept.pressed.connect(on_accept)
	actions.add_child(accept)
	var decline: Button = button.call("AGORA NÃO", Color("78909c"), 0, 88)
	decline.pressed.connect(on_decline)
	actions.add_child(decline)
	panel.hide()
	return {"panel": panel, "body": body, "accept": accept, "decline": decline}


## Cartão da fila: nome, pedido, linha de trade-offs (B1) e barra de paciência.
static func build_queue_card(style: Callable, button: Callable) -> Dictionary:
	var card: Button = button.call("", Color("ffffff", 0.94), 320, 175)
	card.add_theme_stylebox_override(
		"panel", style.call(Color("ffffff", 0.94), 26, 16, PINK, 4)
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14.0
	column.offset_right = -14.0
	column.offset_top = 12.0
	column.offset_bottom = -12.0
	card.add_child(column)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 27)
	name_label.add_theme_color_override("font_color", CHARCOAL)
	column.add_child(name_label)
	var service_label: Label = Label.new()
	service_label.add_theme_font_size_override("font_size", 22)
	service_label.add_theme_color_override("font_color", Color("546e7a"))
	column.add_child(service_label)
	var info_label: Label = Label.new()
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.add_theme_color_override("font_color", Color("8d6e63"))
	column.add_child(info_label)
	var bar: ColorRect = ColorRect.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.color = Color("7ed957")
	column.add_child(bar)
	return {
		"card": card, "name": name_label, "service": service_label,
		"info": info_label, "bar": bar,
	}
