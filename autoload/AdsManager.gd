extends Node
## Fachada segura: gameplay nunca depende de disponibilidade de anúncio.
## Agora com ciclo de vida completo: session tracking, no_ads gating, record_rewarded wiring.

const AdsPolicyScript: Script = preload("res://core/ads/AdsPolicy.gd")
var policy: AdsPolicy
var provider_ready: bool = false
var unavailable_reason: String = "provider_not_installed"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	policy = AdsPolicyScript.new()
	# Session count incrementa a cada boot
	policy.record_session_start()
	# Carrega a política persistida (cap diário, cooldown de compra).
	if GameState.get("ads_policy") is Dictionary:
		policy.from_dictionary(GameState.get("ads_policy"))


func _process(delta: float) -> void:
	if policy != null:
		policy.add_session_seconds(delta)


func is_rewarded_available() -> bool:
	# no_ads não bloqueia rewarded (apenas interstitial) — mas se provider não pronto, bloqueia
	if IAPManager != null and IAPManager.has_entitlement(&"no_ads"):
		# Rewarded continua permitido mesmo com no_ads (é opt-in), mas interstitial não
		pass
	if not provider_ready:
		return false
	return policy.can_show_rewarded()


func request_rewarded(offer_type: StringName, on_reward: Callable) -> bool:
	Analytics.track(
		&"rewarded_offer", {"type": String(offer_type), "eligible": is_rewarded_available()}
	)
	if not policy.can_show_rewarded():
		EventBus.toast_requested.emit(
			Loc.t("ADS_REWARDED_UNAVAILABLE"), Color("b0bec5")
		)
		return false
	if provider_ready:
		# O adapter Android chama on_rewarded_completed apenas no callback de conclusão verificado.
		return false
	# Sem SDK instalado (web/preview/desktop sem adapter): vídeo simulado de
	# SIM_AD_SECONDS para o fluxo recompensado existir de ponta a ponta.
	_show_simulated_ad(offer_type, on_reward)
	return true


const SIM_AD_SECONDS: float = 3.0

var _sim_layer: CanvasLayer = null
var _sim_bar: ProgressBar = null
var _sim_on_reward: Callable = Callable()


func _show_simulated_ad(offer_type: StringName, on_reward: Callable) -> void:
	_sim_on_reward = on_reward
	if _sim_layer == null:
		_build_simulated_ad()
	_sim_layer.visible = true
	_sim_bar.value = 0.0
	Analytics.track(&"rewarded_sim_shown", {"type": String(offer_type)})
	var tween: Tween = _sim_layer.create_tween()
	tween.tween_property(_sim_bar, "value", 100.0, SIM_AD_SECONDS)
	tween.tween_callback(_finish_simulated_ad.bind(offer_type))


func _finish_simulated_ad(offer_type: StringName) -> void:
	_sim_layer.visible = false
	on_rewarded_completed(offer_type)
	if _sim_on_reward.is_valid():
		_sim_on_reward.call()
	_sim_on_reward = Callable()


func _build_simulated_ad() -> void:
	_sim_layer = CanvasLayer.new()
	_sim_layer.layer = 128
	add_child(_sim_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color("000000", 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_sim_layer.add_child(dim)
	var box: PanelContainer = PanelContainer.new()
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color("263238", 0.98)
	box_style.set_corner_radius_all(36)
	box_style.content_margin_left = 48
	box_style.content_margin_right = 48
	box_style.content_margin_top = 40
	box_style.content_margin_bottom = 40
	box.add_theme_stylebox_override("panel", box_style)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(720, 0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_sim_layer.add_child(box)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(column)
	var play: Label = Label.new()
	play.text = "▶"
	play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play.add_theme_font_size_override("font_size", 96)
	play.add_theme_color_override("font_color", Color("ffd54f"))
	column.add_child(play)
	var title: Label = Label.new()
	title.text = Loc.t("AD_SIM_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	column.add_child(title)
	_sim_bar = ProgressBar.new()
	_sim_bar.custom_minimum_size = Vector2(560, 16)
	_sim_bar.max_value = 100.0
	_sim_bar.show_percentage = false
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("ffffff", 0.22)
	bg.set_corner_radius_all(8)
	_sim_bar.add_theme_stylebox_override("background", bg)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color("ffd54f")
	fill.set_corner_radius_all(8)
	_sim_bar.add_theme_stylebox_override("fill", fill)
	column.add_child(_sim_bar)
	var note: Label = Label.new()
	note.text = Loc.t("AD_SIM_NOTE")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 24)
	note.add_theme_color_override("font_color", Color("b0bec5"))
	column.add_child(note)


func on_rewarded_completed(offer_type: StringName) -> void:
	# Chamado pelo provider real após callback verificado
	if policy != null:
		policy.record_rewarded()
	Analytics.track(&"rewarded_complete", {"type": String(offer_type)})
	_persist_policy()


func _persist_policy() -> void:
	# Regressão corrigida (auditoria 2026-09-27): a política era lida do save,
	# mas nunca escrita de volta — caps/cooldowns zeravam a cada boot.
	if policy != null:
		GameState.ads_policy = policy.to_dictionary()
	SaveManager.request_save()


func is_interstitial_allowed() -> bool:
	if IAPManager != null and IAPManager.has_entitlement(&"no_ads"):
		return false
	if not provider_ready:
		return false
	return policy.can_show_interstitial()


func on_interstitial_shown() -> void:
	if policy != null:
		policy.record_interstitial()
	Analytics.track(&"interstitial_shown", {})
	_persist_policy()


func record_purchase_for_policy() -> void:
	if policy != null:
		policy.record_purchase()
	_persist_policy()
