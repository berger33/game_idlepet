extends Node
## Agenda semanal local previsível; configuração remota futura só complementa.

const NAMES: PackedStringArray = [
	"Domingo da Família",
	"Segunda do Banho",
	"Terça da Tosa",
	"Quarta da Vacina",
	"Quinta do Pet Raro",
	"Sexta do VIP",
	"Sábado do Combo"
]


func current_event_name() -> String:
	var date: Dictionary = Time.get_datetime_dict_from_system()
	return NAMES[int(date.get("weekday", 0))]


func multiplier_for(service_id: StringName) -> float:
	var weekday: int = int(Time.get_datetime_dict_from_system().get("weekday", 0))
	if weekday == 1 and service_id == &"bath":
		return 2.0
	if weekday == 2 and service_id == &"groom":
		return 2.0
	return 1.0
