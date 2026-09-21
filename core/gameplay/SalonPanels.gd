class_name SalonPanels
extends RefCounted
## Construção de painéis e cartões do salão (padrão GestureArt/StationArt):
## o Main monta o fluxo do jogo, este arquivo monta a UI. Tudo estático e
## sem estado — `style` e `button` são os helpers visuais do Main (Callables).

const PINK: Color = Color("ff8fb1")
const BLUE: Color = Color("4fc3f7")
const GREEN: Color = Color("43a047")
const CHARCOAL: Color = Color("263238")


## Painel de resultado: reposicionado para ver pet celebrando + XP bar + hierarquia + autowrap para thanks/memória
static func build_result_panel(
	parent: Control,
	style: Callable,
	button: Callable,
	on_primary: Callable,
	on_share: Callable
) -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(80, 580)
	panel.size = Vector2(920, 900)
	panel.add_theme_stylebox_override(
		"panel", style.call(Color("263238", 0.96), 40, 28, PINK, 8)
	)
	parent.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title: Label = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(860, 0)
	column.add_child(title)
	var detail: Label = Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 28)
	detail.add_theme_color_override("font_color", Color.WHITE)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(840, 0)
	column.add_child(detail)
	var xp_bar: ColorRect = ColorRect.new()
	xp_bar.custom_minimum_size = Vector2(760, 14)
	xp_bar.color = Color("4fc3f7", 0.35)
	column.add_child(xp_bar)
	var actions: VBoxContainer = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var primary: Button = button.call("✓  " + Loc.t("REVEAL_OK"), GREEN, 0, 96)
	primary.pressed.connect(on_primary)
	actions.add_child(primary)
	var share: Button = button.call("📤 " + Loc.t("SHARE_BUTTON"), Color("90a4ae"), 0, 64)
	share.pressed.connect(on_share)
	actions.add_child(share)
	panel.hide()
	return {
		"panel": panel, "title": title, "detail": detail, "primary": primary, "share": share, "xp_bar": xp_bar,
	}


## Painel de pedido especial: mostra recompensa extra exata + reposicionado.
static func build_upsell_panel(
	parent: Control, style: Callable, button: Callable, on_accept: Callable, on_decline: Callable
) -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(80, 620)
	panel.size = Vector2(920, 720)
	panel.add_theme_stylebox_override(
		"panel", style.call(Color("263238", 0.96), 48, 36, Color("ce93d8"), 8)
	)
	parent.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var title: Label = Label.new()
	title.text = Loc.t("SPECIAL_ORDER_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("ce93d8"))
	column.add_child(title)
	var body: Label = Label.new()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 36)
	body.add_theme_color_override("font_color", Color.WHITE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(800, 0)
	column.add_child(body)
	var note: Label = Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 28)
	note.add_theme_color_override("font_color", Color("ffd54f"))
	note.text = Loc.t("SPECIAL_ORDER_NOTE")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(800, 0)
	column.add_child(note)
	var actions: VBoxContainer = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	var accept: Button = button.call(Loc.t("SPECIAL_ACCEPT"), GREEN, 0, 110)
	accept.pressed.connect(on_accept)
	actions.add_child(accept)
	var decline: Button = button.call(Loc.t("SPECIAL_DECLINE"), Color("78909c"), 0, 80)
	decline.pressed.connect(on_decline)
	actions.add_child(decline)
	panel.hide()
	return {"panel": panel, "body": body, "accept": accept, "decline": decline}


## Cartão da fila: nome, pedido, trade-offs com $ + barra mais alta 14px + fundo + autowrap para storytelling
static func build_queue_card(style: Callable, button: Callable) -> Dictionary:
	var card: Button = button.call("", Color("ffffff", 0.96), 320, 210)
	card.add_theme_stylebox_override(
		"panel", style.call(Color("ffffff", 0.97), 26, 14, PINK, 4)
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12.0
	column.offset_right = -12.0
	column.offset_top = 10.0
	column.offset_bottom = -10.0
	card.add_child(column)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", CHARCOAL)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(296, 0)
	column.add_child(name_label)
	var service_label: Label = Label.new()
	service_label.add_theme_font_size_override("font_size", 20)
	service_label.add_theme_color_override("font_color", Color("37474f"))
	service_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(service_label)
	var info_label: Label = Label.new()
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.add_theme_color_override("font_color", Color("4e342e"))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(296, 0)
	column.add_child(info_label)
	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(296, 14)
	bar_bg.color = Color("263238", 0.22)
	column.add_child(bar_bg)
	var bar: ColorRect = ColorRect.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.color = Color("7ed957")
	bar_bg.add_child(bar)
	return {
		"card": card, "name": name_label, "service": service_label,
		"info": info_label, "bar": bar, "bar_bg": bar_bg,
	}
