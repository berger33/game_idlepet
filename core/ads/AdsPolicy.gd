class_name AdsPolicy
extends RefCounted
## Política local independente do provider; servidor/config só pode torná-la mais restritiva.
## Agora com ciclo de vida completo: session tracking, cooldown, reset diário.

var rewarded_today: int = 0
var last_rewarded_msec: int = -999999999
var last_rewarded_day: String = ""
var session_count: int = 0
var session_seconds: float = 0.0
var last_ad_was_rewarded: bool = false
var purchased_recently: bool = false
var last_purchase_msec: int = -999999999


func _init() -> void:
	# Inicializa dia para reset diário
	last_rewarded_day = Time.get_date_string_from_system()


func _check_daily_reset() -> void:
	var today: String = Time.get_date_string_from_system()
	if today != last_rewarded_day:
		rewarded_today = 0
		last_rewarded_day = today


func can_show_rewarded() -> bool:
	_check_daily_reset()
	var cap: int = mini(8, RemoteConfig.get_int("rewarded_daily_cap"))
	var cooldown_ms: int = maxi(180, RemoteConfig.get_int("rewarded_cooldown_seconds")) * 1000
	return rewarded_today < cap and Time.get_ticks_msec() - last_rewarded_msec >= cooldown_ms


func can_show_interstitial() -> bool:
	_check_daily_reset()
	var minimum: float = maxf(1200.0, RemoteConfig.get_float("interstitial_min_session_seconds"))
	# purchased_recently expira após 24h
	if purchased_recently and Time.get_ticks_msec() - last_purchase_msec > 86400000:
		purchased_recently = false
	return (
		session_count > 3
		and session_seconds >= minimum
		and not last_ad_was_rewarded
		and not purchased_recently
	)


func record_rewarded() -> void:
	_check_daily_reset()
	rewarded_today += 1
	last_rewarded_msec = Time.get_ticks_msec()
	last_ad_was_rewarded = true


func record_interstitial() -> void:
	last_ad_was_rewarded = false


func record_session_start() -> void:
	session_count += 1
	# Não zera session_seconds aqui — acumula na sessão atual


func add_session_seconds(delta: float) -> void:
	session_seconds += delta


func record_purchase() -> void:
	purchased_recently = true
	last_purchase_msec = Time.get_ticks_msec()


func to_dictionary() -> Dictionary:
	return {
		"rewarded_today": rewarded_today,
		"last_rewarded_msec": last_rewarded_msec,
		"last_rewarded_day": last_rewarded_day,
		"session_count": session_count,
		"session_seconds": session_seconds,
		"last_ad_was_rewarded": last_ad_was_rewarded,
		"purchased_recently": purchased_recently,
		"last_purchase_msec": last_purchase_msec,
	}


func from_dictionary(data: Dictionary) -> void:
	rewarded_today = int(data.get("rewarded_today", 0))
	last_rewarded_msec = int(data.get("last_rewarded_msec", -999999999))
	last_rewarded_day = String(data.get("last_rewarded_day", Time.get_date_string_from_system()))
	session_count = int(data.get("session_count", 0))
	session_seconds = float(data.get("session_seconds", 0.0))
	last_ad_was_rewarded = bool(data.get("last_ad_was_rewarded", false))
	purchased_recently = bool(data.get("purchased_recently", false))
	last_purchase_msec = int(data.get("last_purchase_msec", -999999999))
	_check_daily_reset()
