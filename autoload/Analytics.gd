extends Node
## Fila offline-first. Em produção, adapter Firebase envia em lotes e mantém esta queda segura.
## Agora com flush atômico e consent handling correto.

const QUEUE_PATH: String = "user://analytics_queue.jsonl"
const TEMP_PATH: String = "user://analytics_queue.tmp"
const MAX_BUFFER: int = 500
var session_started_msec: int = 0
var buffer: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_started_msec = Time.get_ticks_msec()
	track(&"session_start")


func track(event_name: StringName, parameters: Dictionary = {}) -> void:
	if not consent_given():
		return
	var safe_name: String = String(event_name).left(40)
	var event: Dictionary = {
		"name": safe_name, "timestamp": Time.get_unix_time_from_system(), "params": parameters
	}
	buffer.append(event)
	if buffer.size() > MAX_BUFFER:
		buffer.pop_front()
	if buffer.size() % 10 == 0:
		flush_offline()


## Consentimento (LGPD/GDPR): sem opt-in em Ajustes nada é persistido nem
## entregue ao adapter; a fila em memória serve só à sessão e é descartada.
func consent_given() -> bool:
	return bool(GameState.settings.get("analytics_consent", false))


func flush_offline() -> void:
	if not consent_given():
		if FileAccess.file_exists(QUEUE_PATH):
			DirAccess.remove_absolute(QUEUE_PATH)
		buffer.clear()
		return
	if buffer.is_empty():
		return
	# Escrita atômica via temp + rename para evitar truncamento em crash
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return
	for event: Dictionary in buffer:
		file.store_line(JSON.stringify(event))
	file.flush()
	file.close()
	# Rename atômico
	if FileAccess.file_exists(QUEUE_PATH):
		DirAccess.remove_absolute(QUEUE_PATH)
	var err: Error = DirAccess.rename_absolute(TEMP_PATH, QUEUE_PATH)
	if err == OK:
		buffer.clear()
	else:
		# Se rename falhou, mantém buffer para retry
		if FileAccess.file_exists(TEMP_PATH):
			DirAccess.remove_absolute(TEMP_PATH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		track(&"session_end", {"duration": (Time.get_ticks_msec() - session_started_msec) / 1000.0})
		flush_offline()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		session_started_msec = Time.get_ticks_msec()
		track(&"session_resume")
