extends Node
## Save atômico, XOR+Base64, SHA-256, três backups e migração versionada.

const SAVE_PATH: String = "user://save.dat"
const TEMP_PATH: String = "user://save.tmp"
const BACKUP_COUNT: int = 3
const KEY: String = "petshop-local-v1"
var elapsed: float = 0.0
var save_requested: bool = false
var pending_offline_reward: float = 0.0
var pending_offline_seconds: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _process(delta: float) -> void:
	elapsed += delta
	if save_requested or elapsed >= RemoteConfig.get_float("autosave_seconds"):
		save_game()


func request_save() -> void:
	save_requested = true


func save_game() -> bool:
	var payload: Dictionary = GameState.to_dictionary()
	var json: String = JSON.stringify(payload)
	var envelope: Dictionary = {"hash": _sha256(json + KEY), "payload": json}
	var encoded: String = Marshalls.raw_to_base64(_xor(JSON.stringify(envelope).to_utf8_buffer()))
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(encoded)
	file.flush()
	file.close()
	_rotate_backups()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var rename_error: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_error != OK:
		return false
	elapsed = 0.0
	save_requested = false
	EventBus.save_completed.emit()
	return true


func load_game() -> bool:
	var candidates: Array[String] = [SAVE_PATH]
	for index: int in range(BACKUP_COUNT):
		candidates.append(SAVE_PATH + ".bak" + str(index + 1))
	for path: String in candidates:
		var data: Dictionary = _read_save(path)
		if not data.is_empty():
			GameState.apply_dictionary(_migrate(data))
			_grant_offline_reward()
			return true
	return false


## Código de transferência (sem cloud save): o envelope assinado do save em
## Base64, para copiar/colar entre aparelhos. O mesmo hash+chave do arquivo
## protege contra edição; a versão passa pela migração normal.
func export_code() -> String:
	var json: String = JSON.stringify(GameState.to_dictionary())
	var envelope: Dictionary = {"hash": _sha256(json + KEY), "payload": json}
	return Marshalls.raw_to_base64(_xor(JSON.stringify(envelope).to_utf8_buffer()))


func import_code(code: String) -> bool:
	var data: Dictionary = _decode_envelope(code.strip_edges())
	if data.is_empty():
		return false
	GameState.apply_dictionary(_migrate(data))
	Analytics.track(&"save_imported", {"version": int(data.get("version", 0))})
	save_game()
	return true


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return _decode_envelope(FileAccess.get_file_as_string(path))


func _decode_envelope(encoded: String) -> Dictionary:
	if encoded.is_empty():
		return {}
	var decoded: PackedByteArray = _xor(Marshalls.base64_to_raw(encoded))
	var parsed: Variant = JSON.parse_string(decoded.get_string_from_utf8())
	if not parsed is Dictionary:
		return {}
	var envelope: Dictionary = parsed
	var payload_json: String = String(envelope.get("payload", ""))
	if String(envelope.get("hash", "")) != _sha256(payload_json + KEY):
		return {}
	var payload: Variant = JSON.parse_string(payload_json)
	if not payload is Dictionary:
		return {}
	var payload_dict: Dictionary = payload
	var version: int = int(payload_dict.get("version", 0))
	if version < 0 or version > GameState.SAVE_VERSION:
		return {}
	return payload_dict


func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	if version == 0:
		data["version"] = 1
		data["settings"] = data.get("settings", {})
		version = 1
	if version == 1:
		data["version"] = 2
		data["unlocked_pets"] = ["caramelo"]
		data["hired_staff"] = ["player"]
		data["achievement_ids"] = []
		data["mission_progress"] = {
			"services": int(data.get("services_completed", 0)),
			"perfect": int(data.get("best_combo", 0)),
			"upgrades": int(data.get("bath_upgrade_level", 0))
		}
		data["claimed_missions"] = []
		data["missions_date"] = ""
		data["last_daily_claim"] = ""
		data["daily_streak"] = 0
		data["establishment_tier"] = 1
		version = 2
	if version == 2:
		data["version"] = 3
		data["player_level"] = 1 + floori(int(data.get("services_completed", 0)) / 5.0)
		data["player_xp"] = 0
		version = 3
	if version == 3:
		data["version"] = 4
		data["active_play_seconds"] = 0.0
		data["pet_affection"] = {}
		version = 4
	if version == 4:
		data["version"] = 5
		data["five_star_reviews"] = 0
		data["total_perfect_services"] = int(data.get("best_combo", 0))
		data["offline_seconds_collected"] = 0.0
		data["unlocked_cosmetics"] = []
		version = 5
	if version == 5:
		data["version"] = 6
		data["tool_upgrade_levels"] = {"soap": 0, "clipper": 0, "dryer": 0, "perfume": 0, "bow": 0}
		version = 6
	if version == 6:
		data["version"] = 7
		data["streak_freezes"] = int(data.get("streak_freezes", 1))
		data["pass_day_unlocked"] = int(data.get("pass_day_unlocked", 0))
		data["pass_day_claimed"] = int(data.get("pass_day_claimed", 0))
		version = 7
	if version == 7:
		data["version"] = 8
		data["active_cosmetics"] = data.get("active_cosmetics", {})
		version = 8
	if version == 8:
		# v9: maestria de ferramenta (C2) — usos por ferramenta persistidos.
		data["version"] = 9
		data["tool_uses"] = data.get("tool_uses", {})
		version = 9
	if version == 9:
		# v10: pesquisa da franquia (sink dos tokens de prestígio).
		data["version"] = 10
		data["research_ids"] = data.get("research_ids", [])
		version = 10
	if version == 10:
		# v11: tokens de prestígio contados de forma cumulativa (bug do dobro) e
		# missões diárias sorteadas do catálogo.
		data["version"] = 11
		data["prestige_tokens_collected"] = int(
			data.get("prestige_tokens_collected", data.get("prestige_level", 0))
		)
		data["daily_mission_ids"] = data.get("daily_mission_ids", [])
		version = 11
	if version == 11:
		# v12: visitantes misteriosos (descoberta de pets pela fila).
		data["version"] = 12
		data["visitor_progress"] = data.get("visitor_progress", {})
		data["event_goal_date"] = data.get("event_goal_date", "")
		data["event_goal_count"] = int(data.get("event_goal_count", 0))
		data["event_goal_claimed"] = bool(data.get("event_goal_claimed", false))
		version = 12
	return data


func _grant_offline_reward() -> void:
	var elapsed_seconds: float = TimeManager.offline_elapsed(GameState.last_seen_unix)
	# Primeira noite generosa D1: cap mínimo 8h + dobro se primeira coleta (evita frustração sono)
	var is_first: bool = GameState.offline_seconds_collected == 0.0 and GameState.services_completed >= 1
	var effective_elapsed: float = elapsed_seconds
	if is_first:
		effective_elapsed = maxf(elapsed_seconds, minf(elapsed_seconds, 8.0 * 3600.0))
	# Cofre relevante (auditoria): renda ATIVA estimada × parcela offline (+ equipe).
	var reward: float = Economy.offline_earnings(
		Rewards.income_per_second(),
		effective_elapsed,
		GameState.prestige_level,
		Research.bonus(&"offline_rate"),
		Rewards.automation_share()
	)
	if is_first and reward > 0.0:
		reward *= 2.0
	if reward > 0.0:
		GameState.add_coins(reward, &"offline")
		GameState.register_offline_collection(elapsed_seconds)
		pending_offline_reward = reward
		pending_offline_seconds = elapsed_seconds
		Analytics.track(&"offline_reward", {"seconds": elapsed_seconds, "amount": reward, "first_double": is_first})


func consume_pending_offline_reward() -> Dictionary:
	if pending_offline_reward <= 0.0:
		return {}
	var result: Dictionary = {
		"reward": pending_offline_reward,
		"seconds": pending_offline_seconds,
	}
	pending_offline_reward = 0.0
	pending_offline_seconds = 0.0
	return result


func _rotate_backups() -> void:
	for index: int in range(BACKUP_COUNT, 1, -1):
		var source: String = SAVE_PATH + ".bak" + str(index - 1)
		var target: String = SAVE_PATH + ".bak" + str(index)
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		if FileAccess.file_exists(source):
			DirAccess.rename_absolute(source, target)
	if FileAccess.file_exists(SAVE_PATH):
		var first: String = SAVE_PATH + ".bak1"
		if FileAccess.file_exists(first):
			DirAccess.remove_absolute(first)
		DirAccess.copy_absolute(SAVE_PATH, first)


func _xor(bytes: PackedByteArray) -> PackedByteArray:
	var key_bytes: PackedByteArray = KEY.to_utf8_buffer()
	var result: PackedByteArray = bytes.duplicate()
	for index: int in result.size():
		result[index] = result[index] ^ key_bytes[index % key_bytes.size()]
	return result


func _sha256(value: String) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
