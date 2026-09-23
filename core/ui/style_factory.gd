class_name StyleFactory
extends RefCounted
## StyleBoxes compartilhados entre código e cenas .tscn (uma só receita visual).


static func box(
	color: Color,
	radius: int,
	content_margin: int,
	border_color: Color = Color(0, 0, 0, 0),
	border_width: int = 0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	return style
