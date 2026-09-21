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
	var fav_name: String = ContentDB.pet_name(GameState.favorite_pet) if ContentDB.has_pet(GameState.favorite_pet) else "Caramelo"
	var offline_est: int = Rewards.scaled(3600.0 * 2.0, 50)
	var absence_hours: float = (
		(Time.get_unix_time_from_system() - last_seen_unix) / 3600.0
		if last_seen_unix > 0
		else 0.0
	)
	scheduled.append(
		{
			"id": "offline_ready",
			"delay_seconds": 7200,
			"title": Loc.t("NOTIF_OFFLINE_TITLE"),
			"body": Loc.t("NOTIF_OFFLINE_BODY") % [fav_name, offline_est],
			"deep_link": "--section=map",
		}
	)
	scheduled.append(
		{
			"id": "pets_waiting",
			"delay_seconds": 28800,
			"title": Loc.t("NOTIF_PETS_TITLE") % fav_name,
			"body": Loc.t("NOTIF_PETS_BODY") % [fav_name, GameState.unlocked_pets.size(), GameState.daily_streak],
			"deep_link": "--section=missions",
		}
	)
	if scheduled.size() > DAILY_CAP:
		scheduled.resize(DAILY_CAP)
	Analytics.track(
		&"notification_scheduled",
		{"count": scheduled.size(), "absence_hours": absence_hours, "pet": fav_name}
	)
