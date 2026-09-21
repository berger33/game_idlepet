extends Node
## Agenda semanal local previsível, 7/7 com efeito real de gameplay, dirigida
## por data/events.json (fonte única: serviço em destaque + modificador do dia).
## Temporadas (sazonal) vêm do mesmo arquivo: cada uma pode presentear um
## cosmético de edição enquanto o mês estiver ativo.
## Kill switch remoto: events_enabled = 0 desliga tudo; event_boost_scale
## (0..1) dosifica a intensidade sem quebrar a economia.
## Nomes dos eventos vivem na localização: EVENT_0..EVENT_6 / SEASON_<id>.

const GIFT_COLOR: Color = Color("ffd54f")
## Meta do dia: atendimentos do serviço em destaque (ou de qualquer serviço
## nos dias sem destaque) que pagam um baú — o evento vira motivo de sessão.
const EVENT_GOAL_FEATURED: int = 20
const EVENT_GOAL_ANY: int = 30
const EVENT_GOAL_EMBERS: int = 2


## Entrada da agenda para hoje ({} com eventos desligados).
func today() -> Dictionary:
	if not events_on():
		return {}
	return ContentDB.weekly_event_for(weekday())


## Serviço que domina a fila hoje (dia temático); &"" se não houver.
func featured_service() -> StringName:
	return StringName(String(today().get("service", "")))


func events_on() -> bool:
	return RemoteConfig.get_float(&"events_enabled") > 0.5


func boost_scale() -> float:
	return clampf(RemoteConfig.get_float(&"event_boost_scale"), 0.0, 1.0)


func weekday() -> int:
	return clampi(int(Time.get_datetime_dict_from_system().get("weekday", 0)), 0, 6)


func current_event_name() -> String:
	if not events_on():
		return Loc.t("EVENTS_OFF")
	return Loc.t("EVENT_%d" % weekday())


## Nome do evento de um dia específico (0-6) — usado no cartão "até amanhã".
func event_name_for(day: int) -> String:
	return Loc.t("EVENT_%d" % clampi(day, 0, 6))


## O que o dia faz, em uma linha (mapa e cartão "amanhã").
func event_description_for(day: int) -> String:
	return Loc.t("EVENT_DESC_%d" % clampi(day, 0, 6))


## Multiplicador de renda do serviço hoje: dia temático dobra o serviço em
## destaque; "all_income" (domingo) rende um pouco mais em tudo.
func multiplier_for(service_id: StringName) -> float:
	var entry: Dictionary = today()
	if entry.is_empty():
		return 1.0
	var bonus: float = 0.0
	if String(entry.get("modifier", "")) == "all_income":
		bonus = float(entry.get("multiplier", 1.0)) - 1.0
	elif service_id != &"" and StringName(String(entry.get("service", ""))) == service_id:
		bonus = float(entry.get("service_multiplier", 2.0)) - 1.0
	return 1.0 + maxf(0.0, bonus) * boost_scale()


## Sábado do Combo: Perfect vale +50% (dosificado pelo mesmo kill switch).
func bonus_for_quality(quality: StringName) -> float:
	if quality != &"perfect":
		return 1.0
	return modifier_multiplier(&"perfect_bonus")


## Multiplicador do modificador extra do dia (vip_frequency, rare_chance,
## perfect_bonus...); 1.0 quando hoje não é esse modificador ou eventos off.
func modifier_multiplier(modifier: StringName) -> float:
	var entry: Dictionary = today()
	if String(entry.get("modifier", "")) != String(modifier):
		return 1.0
	return 1.0 + maxf(0.0, float(entry.get("multiplier", 1.0)) - 1.0) * boost_scale()


## Meta de atendimentos de hoje (0 com eventos desligados).
func event_goal_target() -> int:
	if not events_on():
		return 0
	return EVENT_GOAL_FEATURED if featured_service() != &"" else EVENT_GOAL_ANY


## Este atendimento conta para a meta do dia?
func event_goal_counts(service_id: StringName) -> bool:
	if not events_on():
		return false
	var featured: StringName = featured_service()
	return featured == &"" or featured == service_id


## Texto da meta do dia: "Segunda do Banho: banho 12/20".
func event_goal_text() -> String:
	var featured: StringName = featured_service()
	var subject: String = (
		Loc.t(String(Goals.SERVICE_LABEL_KEY.get(String(featured), "SERVICE_BATH")))
		if featured != &""
		else Loc.t("EVENT_GOAL_ANY")
	)
	return Loc.t("EVENT_GOAL_DESC") % [
		subject, mini(GameState.event_goal_count, event_goal_target()), event_goal_target()
	]


## Temporada ativa neste mês ({} fora de temporada ou com eventos desligados).
func active_seasonal() -> Dictionary:
	if not events_on():
		return {}
	return ContentDB.seasonal_for_month(
		int(Time.get_datetime_dict_from_system().get("month", 1))
	)


func seasonal_name(season_id: String) -> String:
	return Loc.t("SEASON_" + season_id)


## Rótulo da origem de um cosmético sem preço (loja): temporada com período,
## ou conquista. Nunca expõe o id cru ao jogador.
func source_label(source: String) -> String:
	if ContentDB.seasonal(source).is_empty():
		return Loc.t("SOURCE_" + source)
	return "%s • %s" % [seasonal_name(source), Loc.t("SEASON_WHEN_" + source)]


func weekly_reset_label() -> String:
	var w: int = weekday()
	var days_left: int = (8 - w) % 7
	if days_left == 0:
		days_left = 7
	# Nota10: urgência domingo + horas restantes
	if days_left == 1:
		var hours_left: int = 24 - int(Time.get_datetime_dict_from_system().get("hour", 12))
		# Se domingo e progresso baixo, mensagem de urgência
		if w == 0:
			return Loc.t("WEEKLY_LAST_DAY") % [0, 7, hours_left] if not Loc.t("WEEKLY_LAST_DAY").begins_with("WEEKLY") else "⏰ ÚLTIMO DIA! %dh restantes" % hours_left
		return Loc.t("WEEKLY_RESET_TOMORROW")
	return Loc.t("WEEKLY_RESET_DAYS") % days_left

func weekly_hours_remaining() -> int:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var w: int = weekday()
	var days_left: int = (8 - w) % 7
	if days_left == 0:
		days_left = 7
	var hours_today: int = 24 - int(now.get("hour", 12))
	return (days_left - 1) * 24 + hours_today

func weekly_is_last_day() -> bool:
	return weekday() == 0 # Domingo = último dia (reset segunda)

func weekly_progress_summary() -> Dictionary:
	var done: int = 0
	for weekly in ContentDB.weekly_missions:
		if GameState.claimed_weeklies.has(String(weekly.get("id", ""))):
			done += 1
	var total: int = ContentDB.weekly_missions.size()
	return {"done": done, "total": total, "hours_left": weekly_hours_remaining(), "is_last": weekly_is_last_day()}


## Presente de temporada: o cosmético da temporada ativa entra na coleção no
## primeiro boot do período ("exclusivo" = edição; volta no ano seguinte).
## Idempotente: unlocked_cosmetics já persiste, então nunca presenteia duas vezes.
func claim_seasonal_gift() -> bool:
	var season: Dictionary = active_seasonal()
	var cosmetic_id: String = String(season.get("cosmetic", ""))
	if cosmetic_id.is_empty() or ContentDB.cosmetic(cosmetic_id).is_empty():
		return false
	if GameState.unlocked_cosmetics.has(cosmetic_id):
		return false
	GameState.unlocked_cosmetics.append(cosmetic_id)
	var season_id: String = String(season.get("id", ""))
	Analytics.track(
		&"collection_unlock", {"id": cosmetic_id, "category": "cosmetic", "source": season_id}
	)
	EventBus.reveal_requested.emit(
		&"cosmetic",
		{
			"id": cosmetic_id,
			"detail": Loc.t("SEASON_GIFT") % [
				seasonal_name(season_id),
				String(ContentDB.cosmetic(cosmetic_id).get("name", cosmetic_id))
			],
		}
	)
	SaveManager.request_save()
	return true
