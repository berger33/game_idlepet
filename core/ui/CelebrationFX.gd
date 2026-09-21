class_name CelebrationFX
extends RefCounted
## Efeitos de celebração (moedas voando + confete primeiro perfect)
## Extraído do Main para manter Main <1100 linhas.

static func coin_fly(main, amount: int) -> void:
	if not is_instance_valid(main.coin_label) or not is_instance_valid(main.world): return
	if bool(GameState.settings.get("reduced_particles", false)): return
	var start: Vector2 = main.world.pet_focus()
	var end: Vector2 = main.coin_label.global_position + main.coin_label.size * 0.5
	var fly: Label = Label.new()
	fly.text = "🪙 +%d" % amount
	fly.add_theme_font_size_override("font_size", int(32 * SalonTuning.font_scale()))
	fly.add_theme_color_override("font_color", Color("ffd54f"))
	fly.position = start
	fly.z_index = 100
	main.add_child(fly)
	var tw: Tween = fly.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fly, "position", end, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(fly, "scale", Vector2(0.6, 0.6), 0.7)
	tw.tween_property(fly, "modulate:a", 0.0, 0.7).set_delay(0.4)
	tw.chain().tween_callback(fly.queue_free)
	main.coin_label.scale = Vector2(1.15, 1.15)
	main.coin_label.create_tween().tween_property(main.coin_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

static func first_perfect(main) -> void:
	if bool(GameState.settings.get("reduced_particles", false)): return
	if not is_instance_valid(main.world): return
	var center: Vector2 = main.world.pet_focus()
	var emojis: Array[String] = ["🎉", "✨", "🎊", "⭐", "💖", "🌟"]
	for i: int in 14:
		var lbl: Label = Label.new()
		lbl.text = emojis[i % emojis.size()]
		lbl.add_theme_font_size_override("font_size", int(34 + randf() * 14))
		lbl.position = center + Vector2(randf_range(-50, 50), randf_range(-30, 30))
		lbl.z_index = 110
		lbl.pivot_offset = Vector2(18, 18)
		main.add_child(lbl)
		var peak: Vector2 = center + Vector2(randf_range(-260, 260), randf_range(-420, -180))
		var fall: Vector2 = peak + Vector2(randf_range(-80, 80), randf_range(500, 800))
		var tw: Tween = lbl.create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "position", peak, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.25)
		tw.tween_property(lbl, "rotation", randf_range(-1.2, 1.2), 0.45)
		tw.chain().set_parallel(true)
		tw.tween_property(lbl, "position", fall, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.2)
		tw.tween_property(lbl, "rotation", randf_range(-3.0, 3.0), 0.9)
		tw.chain().tween_callback(lbl.queue_free)
