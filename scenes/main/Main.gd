extends Control
## Playable Core: chegada → servir → esfregar → timing → moedas/review/save.

const BathServiceScript: Script = preload("res://core/gameplay/BathService.gd")
const PetShopCanvasScript: Script = preload("res://core/gameplay/PetShopCanvas.gd")
const PINK: Color = Color("ff8fb1")
const BLUE: Color = Color("4fc3f7")
const GREEN: Color = Color("7ed957")
const CREAM: Color = Color("fff3e0")
const CHARCOAL: Color = Color("263238")

var bath: BathService
var world: PetShopCanvas
var coin_label: Label
var combo_label: Label
var review_label: Label
var order_card: PanelContainer
var instruction_label: Label
var progress_bar: ProgressBar
var timer_label: Label
var primary_button: Button
var upgrade_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var dragging: bool = false
var next_client_timer: float = 0.0
var bubble_sound_gate: float = 0.0
var toast_layer: Control

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bath = BathServiceScript.new()
    _build_interface()
    _connect_events()
    _refresh_economy()
    Analytics.track(&"first_open" if GameState.services_completed == 0 else &"session_resume")
    Analytics.track(&"pet_arrived", {"rarity": "common", "pet_id": "caramelo"})
    EventBus.pet_arrived.emit(&"caramelo")

func _process(delta: float) -> void:
    bubble_sound_gate = maxf(0.0, bubble_sound_gate - delta)
    if bath.state == BathService.State.ACTIVE:
        if bath.tick(delta):
            _fail(&"timeout")
        progress_bar.value = bath.progress * 100.0
        timer_label.text = "%.1fs" % bath.time_left
        world.progress = bath.progress
        primary_button.disabled = bath.progress < 0.35
        if bath.progress >= RemoteConfig.get_float("bath_target_min") and bath.progress <= RemoteConfig.get_float("bath_target_max"):
            progress_bar.modulate = GREEN
            instruction_label.text = "PERFEITO! Finalize agora!"
        elif bath.progress > RemoteConfig.get_float("bath_target_max"):
            progress_bar.modulate = Color("ef5350")
            instruction_label.text = "Espuma demais! Finalize!"
        else:
            progress_bar.modulate = Color.WHITE
    elif next_client_timer > 0.0:
        next_client_timer -= delta
        if next_client_timer <= 0.0:
            _new_client()

func _input(event: InputEvent) -> void:
    if bath.state != BathService.State.ACTIVE:
        return
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        dragging = touch.pressed and _pet_hit(touch.position)
        if not touch.pressed:
            bath.release_pointer()
    elif event is InputEventScreenDrag and dragging:
        _rub((event as InputEventScreenDrag).position)
    elif event is InputEventMouseButton:
        var mouse_button: InputEventMouseButton = event
        if mouse_button.button_index == MOUSE_BUTTON_LEFT:
            dragging = mouse_button.pressed and _pet_hit(mouse_button.position)
            if not mouse_button.pressed:
                bath.release_pointer()
    elif event is InputEventMouseMotion and dragging:
        _rub((event as InputEventMouseMotion).position)

func _pet_hit(point: Vector2) -> bool:
    return point.distance_to(world.pet_position) < 245.0

func _rub(point: Vector2) -> void:
    bath.rub(point)
    world.spawn_bubble(point)
    if bubble_sound_gate <= 0.0:
        AudioManager.play(&"bubble")
        bubble_sound_gate = 0.12
    EventBus.service_progress.emit(bath.progress)

func _on_primary_pressed() -> void:
    AudioManager.play(&"tap")
    HapticsManager.light()
    if bath.state == BathService.State.WAITING:
        _start_bath()
    elif bath.state == BathService.State.ACTIVE:
        _finish_bath()
    elif bath.state == BathService.State.COMPLETE or bath.state == BathService.State.FAILED:
        _dismiss_result()

func _start_bath() -> void:
    bath.start_service()
    world.pet_wet = true
    instruction_label.text = "Esfregue o pet em círculos e pare na faixa verde"
    primary_button.text = "FINALIZAR BANHO"
    primary_button.disabled = true
    progress_bar.value = 0
    progress_bar.show()
    timer_label.show()
    order_card.hide()
    Analytics.track(&"service_start", {"type": "bath"})
    EventBus.service_started.emit(&"bath")

func _finish_bath() -> void:
    var quality: StringName = bath.finish()
    if quality == &"perfect" or quality == &"good":
        var reward: float = Economy.service_reward(RemoteConfig.get_float("bath_base_reward"), quality, GameState.bath_upgrade_level, GameState.combo)
        var stars: int = 5 if quality == &"perfect" else 4
        GameState.register_review(stars)
        EventBus.service_completed.emit(&"bath", quality, reward)
        Analytics.track(&"service_complete", {"type": "bath", "quality": String(quality), "reward": reward})
        if quality == &"perfect":
            Analytics.track(&"perfect_service")
        _show_success(quality, reward, stars)
    else:
        _fail(quality)

func _show_success(quality: StringName, reward: float, stars: int) -> void:
    world.celebrate()
    AudioManager.play(&"perfect" if quality == &"perfect" else &"coin")
    HapticsManager.success()
    result_title.text = "PERFEITO!" if quality == &"perfect" else "MUITO BOM!"
    result_title.modulate = Color("ffd54f") if quality == &"perfect" else GREEN
    result_detail.text = "%s\n+%d moedas  •  %d estrelas\nCaramelo saiu limpinho!" % ["★".repeat(stars), int(reward), stars]
    result_panel.show()
    primary_button.text = "PRÓXIMO CLIENTE"
    primary_button.disabled = false
    progress_bar.hide()
    timer_label.hide()
    _refresh_economy()

func _fail(reason: StringName) -> void:
    bath.state = BathService.State.FAILED
    dragging = false
    EventBus.service_failed.emit(&"bath", reason)
    Analytics.track(&"service_fail", {"type": "bath", "reason": String(reason)})
    AudioManager.play(&"error")
    HapticsManager.error()
    result_title.text = "QUASE LÁ!"
    result_title.modulate = Color("ef5350")
    var hint: String = "O tempo acabou. Esfregue mais rápido!" if reason == &"timeout" else "Mire a espuma na faixa verde."
    result_detail.text = "★★☆☆☆\n%s\nSem punição — tente de novo." % hint
    result_panel.show()
    primary_button.text = "TENTAR NOVAMENTE"
    primary_button.disabled = false
    progress_bar.hide()
    timer_label.hide()

func _dismiss_result() -> void:
    result_panel.hide()
    world.reset_pet()
    bath = BathServiceScript.new()
    order_card.hide()
    instruction_label.text = "Novo cliente chegando..."
    primary_button.text = "SERVIR CARAMELO"
    primary_button.disabled = true
    next_client_timer = 1.1

func _new_client() -> void:
    order_card.show()
    primary_button.disabled = false
    instruction_label.text = "Caramelo quer um banho. Toque em SERVIR."
    world.pet_happy = false
    Analytics.track(&"pet_arrived", {"rarity": "common", "pet_id": "caramelo"})

func _on_upgrade_pressed() -> void:
    var cost: float = Economy.upgrade_cost(GameState.bath_upgrade_level)
    if GameState.buy_bath_upgrade():
        AudioManager.play(&"coin")
        HapticsManager.success()
        EventBus.toast_requested.emit("Banheira nível %d! Recompensa maior." % GameState.bath_upgrade_level, GREEN)
    else:
        EventBus.toast_requested.emit("Faltam %d moedas" % int(cost - GameState.coins), Color("ef5350"))
    _refresh_economy()

func _refresh_economy(_currency: StringName = &"coins", _amount: float = 0.0) -> void:
    coin_label.text = "%d" % int(GameState.coins)
    combo_label.text = "COMBO ×%d" % maxi(1, GameState.combo)
    review_label.text = "★ %.1f" % GameState.review_average()
    var cost: float = Economy.upgrade_cost(GameState.bath_upgrade_level)
    upgrade_button.text = "MELHORAR BANHEIRA  Nv.%d\n%d moedas" % [GameState.bath_upgrade_level, int(cost)]

func _show_toast(message: String, color: Color) -> void:
    var label: Label = Label.new()
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 34)
    label.add_theme_color_override("font_color", Color.WHITE)
    label.add_theme_stylebox_override("normal", _style(color, 24, 16))
    label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    label.position = Vector2(-360, 120)
    label.size = Vector2(720, 78)
    toast_layer.add_child(label)
    var tween: Tween = create_tween()
    tween.tween_property(label, "position:y", 165.0, 0.22).set_trans(Tween.TRANS_BACK)
    tween.tween_interval(1.4)
    tween.tween_property(label, "modulate:a", 0.0, 0.3)
    tween.tween_callback(label.queue_free)

func _connect_events() -> void:
    EventBus.currency_changed.connect(_refresh_economy)
    EventBus.combo_changed.connect(func(_value: int) -> void: _refresh_economy())
    EventBus.toast_requested.connect(_show_toast)

func _build_interface() -> void:
    world = PetShopCanvasScript.new()
    world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    world.offset_bottom = -470
    add_child(world)

    var top_bar: HBoxContainer = HBoxContainer.new()
    top_bar.position = Vector2(45, 35)
    top_bar.size = Vector2(990, 100)
    top_bar.add_theme_constant_override("separation", 18)
    add_child(top_bar)
    coin_label = _pill(top_bar, "0", Color("ffd54f"), 280)
    review_label = _pill(top_bar, "★ 5.0", PINK, 235)
    combo_label = _pill(top_bar, "COMBO ×1", GREEN, 300)
    var record: Button = _button("● MOMENTO", Color("ef5350"), 155, 74)
    record.tooltip_text = "Exportação de clipe entra no Vertical Slice"
    record.pressed.connect(func() -> void: _show_toast("Momento marcado! Export no Vertical Slice.", PINK); Analytics.track(&"clip_marker", {"type": "bath"}))
    top_bar.add_child(record)

    order_card = PanelContainer.new()
    order_card.position = Vector2(65, 310)
    order_card.size = Vector2(560, 175)
    order_card.add_theme_stylebox_override("panel", _style(Color("ffffff", 0.94), 36, 24, Color("ff8fb1"), 6))
    add_child(order_card)
    var order_text: Label = Label.new()
    order_text.text = "CARAMELO\nBanho simples  •  12+ moedas"
    order_text.add_theme_font_size_override("font_size", 38)
    order_text.add_theme_color_override("font_color", CHARCOAL)
    order_card.add_child(order_text)

    var bottom: PanelContainer = PanelContainer.new()
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.size.y = 500
    bottom.position.y = 1420
    bottom.add_theme_stylebox_override("panel", _style(Color("fffaf3"), 54, 42, Color("e6cbb5"), 4))
    add_child(bottom)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 18)
    bottom.add_child(column)
    instruction_label = Label.new()
    instruction_label.text = "Caramelo quer um banho. Toque em SERVIR."
    instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    instruction_label.add_theme_font_size_override("font_size", 34)
    instruction_label.add_theme_color_override("font_color", CHARCOAL)
    instruction_label.custom_minimum_size.y = 52
    column.add_child(instruction_label)
    var progress_row: HBoxContainer = HBoxContainer.new()
    progress_row.add_theme_constant_override("separation", 20)
    column.add_child(progress_row)
    progress_bar = ProgressBar.new()
    progress_bar.min_value = 0
    progress_bar.max_value = 100
    progress_bar.show_percentage = false
    progress_bar.custom_minimum_size = Vector2(790, 55)
    progress_bar.add_theme_stylebox_override("background", _style(Color("dbe6e8"), 25, 0))
    progress_bar.add_theme_stylebox_override("fill", _style(BLUE, 25, 0))
    var perfect_zone: ColorRect = ColorRect.new()
    perfect_zone.color = Color("7ed957", 0.42)
    perfect_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    perfect_zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    perfect_zone.anchor_left = 0.82
    perfect_zone.anchor_right = 0.96
    perfect_zone.offset_left = 0.0
    perfect_zone.offset_right = 0.0
    progress_bar.add_child(perfect_zone)
    progress_row.add_child(progress_bar)
    timer_label = Label.new()
    timer_label.text = "6.0s"
    timer_label.add_theme_font_size_override("font_size", 34)
    timer_label.add_theme_color_override("font_color", CHARCOAL)
    timer_label.custom_minimum_size = Vector2(110, 55)
    progress_row.add_child(timer_label)
    progress_bar.hide()
    timer_label.hide()
    primary_button = _button("SERVIR CARAMELO", PINK, 0, 105)
    primary_button.pressed.connect(_on_primary_pressed)
    column.add_child(primary_button)
    upgrade_button = _button("MELHORAR BANHEIRA", BLUE, 0, 98)
    upgrade_button.pressed.connect(_on_upgrade_pressed)
    column.add_child(upgrade_button)

    result_panel = PanelContainer.new()
    result_panel.position = Vector2(130, 505)
    result_panel.size = Vector2(820, 510)
    result_panel.add_theme_stylebox_override("panel", _style(Color("263238", 0.96), 52, 42, PINK, 7))
    add_child(result_panel)
    var result_column: VBoxContainer = VBoxContainer.new()
    result_column.alignment = BoxContainer.ALIGNMENT_CENTER
    result_column.add_theme_constant_override("separation", 25)
    result_panel.add_child(result_column)
    result_title = Label.new()
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.add_theme_font_size_override("font_size", 72)
    result_column.add_child(result_title)
    result_detail = Label.new()
    result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_detail.add_theme_font_size_override("font_size", 39)
    result_detail.add_theme_color_override("font_color", Color.WHITE)
    result_column.add_child(result_detail)
    result_panel.hide()

    toast_layer = Control.new()
    toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(toast_layer)

func _pill(parent: Container, text: String, color: Color, width: float) -> Label:
    var label: Label = Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size = Vector2(width, 82)
    label.add_theme_font_size_override("font_size", 33)
    label.add_theme_color_override("font_color", CHARCOAL)
    label.add_theme_stylebox_override("normal", _style(Color("ffffff", 0.95), 35, 12, color, 5))
    parent.add_child(label)
    return label

func _button(text: String, color: Color, width: float, height: float) -> Button:
    var button: Button = Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(width, height)
    button.add_theme_font_size_override("font_size", 34)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", _style(color, 34, 14))
    button.add_theme_stylebox_override("hover", _style(color.lightened(0.08), 34, 14))
    button.add_theme_stylebox_override("pressed", _style(color.darkened(0.12), 30, 18))
    button.add_theme_stylebox_override("disabled", _style(Color("b0bec5"), 34, 14))
    return button

func _style(color: Color, radius: int, content_margin: int, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
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
