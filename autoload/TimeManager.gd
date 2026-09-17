extends Node
## Tempo monotônico de sessão + parede apenas para offline, com clamp anti-abuso.

func offline_elapsed(last_seen_unix: int) -> float:
    if last_seen_unix <= 0:
        return 0.0
    var now: int = int(Time.get_unix_time_from_system())
    var delta: int = now - last_seen_unix
    if delta < 0:
        Analytics.track(&"churn_risk_signal", {"reason": "clock_rollback"})
        return 0.0
    return float(mini(delta, 48 * 3600))
