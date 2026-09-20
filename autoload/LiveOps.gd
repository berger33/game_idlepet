extends Node
## Agenda semanal local previsível, 7/7 com efeito real de gameplay.
## Kill switch remoto: events_enabled = 0 desliga tudo; event_boost_scale
## (0..1) dosifica a intensidade sem quebrar a economia.

## Serviço em destaque de cada dia (0 = domingo: todos ganham bônus família).
## Nomes dos eventos vivem na localização: EVENT_0..EVENT_6.
const DAY_SERVICE: Array[StringName] = [
	&"", &"bath", &"groom", &"dry", &"style", &"perfume", &""
]


## Serviço que domina a fila hoje (dia temático); &"" se não houver.
func featured_service() -> StringName:
	if not events_on():
		return &""
	return DAY_SERVICE[weekday()]


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


func multiplier_for(service_id: StringName) -> float:
	if not events_on():
		return 1.0
	var day: int = weekday()
	var bonus: float = 0.0
	if day == 0:
		bonus = 0.25  # Família: tudo rende um pouco mais.
	elif DAY_SERVICE[day] == service_id:
		bonus = 1.0  # Dia temático: serviço em destaque dobra.
	return 1.0 + bonus * boost_scale()


## Sábado do Combo: Perfect vale +50% (dosificado pelo mesmo kill switch).
func bonus_for_quality(quality: StringName) -> float:
	if not events_on() or quality != &"perfect" or weekday() != 6:
		return 1.0
	return 1.0 + 0.5 * boost_scale()
