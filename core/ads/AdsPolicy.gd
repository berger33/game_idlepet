class_name AdsPolicy
extends RefCounted
## Política local independente do provider; servidor/config só pode torná-la mais restritiva.

var rewarded_today: int = 0
var last_rewarded_msec: int = -999999999
var session_count: int = 0
var session_seconds: float = 0.0
var last_ad_was_rewarded: bool = false
var purchased_recently: bool = false

func can_show_rewarded() -> bool:
    var cap: int = mini(8, RemoteConfig.get_int("rewarded_daily_cap"))
    var cooldown_ms: int = maxi(180, RemoteConfig.get_int("rewarded_cooldown_seconds")) * 1000
    return rewarded_today < cap and Time.get_ticks_msec() - last_rewarded_msec >= cooldown_ms

func can_show_interstitial() -> bool:
    var minimum: float = maxf(1200.0, RemoteConfig.get_float("interstitial_min_session_seconds"))
    return session_count > 3 and session_seconds >= minimum and not last_ad_was_rewarded and not purchased_recently

func record_rewarded() -> void:
    rewarded_today += 1
    last_rewarded_msec = Time.get_ticks_msec()
    last_ad_was_rewarded = true
