class_name HudBadges
extends RefCounted
## Badges dos botões flutuantes da top-right: contagem de melhorias compráveis
## e prêmios do álbum (🏆 coleta / 📰 rival). Extraído do Main para manter o
## hub sob o teto de linhas do gdlint (padrão ParkFlow/SalonPanels).


static func update(main: Control, pulse_time: float) -> void:
	if is_instance_valid(main.upgrades_button):
		var count: int = 0 if not GameState.tutorial_complete else SalonTuning.affordable_upgrades_count()
		if count > 0:
			var pulse: float = 0.5 + 0.5 * sin(pulse_time * 3.2)
			main.upgrades_button.modulate = Color.WHITE.lerp(Color("d7ffb8"), pulse * 0.6)
			_set_badge(main, main.upgrades_button, str(count), 28, Vector2(44, 44), Vector2(52, -12))
		else:
			main.upgrades_button.modulate = Color.WHITE
			_hide_badge(main.upgrades_button)
		D1Retention.update_missions_badge(main, pulse_time)
	# Álbum badge: 🏆 prêmio do concurso a coletar / 📰 rival ultrapassou
	if is_instance_valid(main.album_button) and not main.album_button.disabled:
		var contest_badge: String = Contest.badge_text()
		if not contest_badge.is_empty():
			var pulse: float = 0.5 + 0.5 * sin(pulse_time * 3.0)
			main.album_button.modulate = Color.WHITE.lerp(Color("ffd54f"), pulse * 0.45)
			_set_badge(main, main.album_button, contest_badge, 26, Vector2(38, 38), Vector2(44, -10), 18)
		else:
			main.album_button.modulate = Color.WHITE
			_hide_badge(main.album_button)


static func _set_badge(
	main: Control, button: Button, text: String, font_size: int, sz: Vector2, pos: Vector2, corner: int = 20
) -> void:
	var badge: Label = button.get_node_or_null("Badge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "Badge"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", Color.WHITE)
		button.add_child(badge)
	badge.add_theme_font_size_override("font_size", font_size)
	badge.add_theme_stylebox_override("normal", main._style(Color("ef5350"), corner, 6))
	badge.custom_minimum_size = sz
	badge.position = pos
	badge.text = text
	badge.visible = true


static func _hide_badge(button: Button) -> void:
	var badge: Label = button.get_node_or_null("Badge") as Label
	if is_instance_valid(badge):
		badge.visible = false
