extends Node
## Fila offline-first. Em produção, adapter Firebase envia em lotes e mantém esta queda segura.

const QUEUE_PATH: String = "user://analytics_queue.jsonl"
const MAX_BUFFER: int = 500
var session_started_msec: int = 0
var buffer: Array[Dictionary] = []


func _ready() -> void:
	session_started_msec = Time.get_ticks_msec()
	track(&"session_start")


func track(event_name: StringName, parameters: Dictionary = {}) -> void:
	var safe_name: String = String(event_name).left(40)
	var event: Dictionary = {
		"name": safe_name, "timestamp": Time.get_unix_time_from_system(), "params": parameters
	}
	buffer.append(event)
	if buffer.size() > MAX_BUFFER:
		buffer.pop_front()
	if buffer.size() % 10 == 0:
		flush_offline()


func flush_offline() -> void:
	var file: FileAccess = FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if file == null:
		return
	for event: Dictionary in buffer:
		file.store_line(JSON.stringify(event))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		track(&"session_end", {"duration": (Time.get_ticks_msec() - session_started_msec) / 1000.0})
		flush_offline()
