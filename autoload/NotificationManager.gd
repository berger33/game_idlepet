extends Node
## Scheduler local em memória; adapter Android recebe estes pedidos após opt-in.

const DAILY_CAP: int = 2

var permission_granted: bool = false
var scheduled: Array[Dictionary] = []


func schedule_return_reminders() -> void:
	scheduled.clear()
	if not permission_granted:
		return
	scheduled.append(
		{"id": "offline_ready", "delay_seconds": 7200, "title": "O cofre está ficando cheio!"}
	)
	scheduled.append(
		{"id": "pets_waiting", "delay_seconds": 28800, "title": "Caramelo sentiu sua falta"}
	)
	if scheduled.size() > DAILY_CAP:
		scheduled.resize(DAILY_CAP)
	Analytics.track(&"notification_scheduled", {"count": scheduled.size()})
