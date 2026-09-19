extends Node
## Scheduler local em memória; adapter Android recebe estes pedidos após opt-in.
## Deep link já funciona no desktop: `godot -- --section=missions` — é o mesmo
## parâmetro que a notificação local carregará no adapter real.

const DAILY_CAP: int = 2
const SECTIONS: Array[String] = [
	"missions", "collection", "staff", "shop", "map", "settings"
]

var permission_granted: bool = false
var scheduled: Array[Dictionary] = []


func deep_link_section() -> StringName:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--section="):
			var section: String = arg.trim_prefix("--section=")
			if SECTIONS.has(section):
				return StringName(section)
	return &""


func schedule_return_reminders(last_seen_unix: int = 0) -> void:
	scheduled.clear()
	if not permission_granted:
		return
	scheduled.append(
		{
			"id": "offline_ready",
			"delay_seconds": 7200,
			"title": "O cofre está ficando cheio!",
			"deep_link": "--section=map",
		}
	)
	var absence_hours: float = (
		(Time.get_unix_time_from_system() - last_seen_unix) / 3600.0
		if last_seen_unix > 0
		else 0.0
	)
	scheduled.append(
		{
			"id": "pets_waiting",
			"delay_seconds": 28800,
			"title": "Caramelo sentiu sua falta",
			"deep_link": "--section=missions",
		}
	)
	if scheduled.size() > DAILY_CAP:
		scheduled.resize(DAILY_CAP)
	Analytics.track(
		&"notification_scheduled",
		{"count": scheduled.size(), "absence_hours": absence_hours}
	)
