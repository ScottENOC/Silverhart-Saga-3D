class_name AmbientChatter
extends RefCounted
## Lightweight, state-aware overheard NPC conversation selection.
## Presentation is owned by HollowTankard; this class only selects content.

const PAIR_COOLDOWN_SECONDS := 120.0
const RECENT_EXCHANGE_LIMIT := 10
const RECENT_TOPIC_LIMIT := 5

var recent_exchange_ids: Array[String] = []
var recent_topics: Array[String] = []
var pair_last_spoken: Dictionary = {}


func choose_exchange(first_id: String, second_id: String, first_role: String, second_role: String,
        world_seconds: float, hour: int, security: int, shakedown_resolved: bool,
        rng: RandomNumberGenerator, shakedown_choice: String = "") -> Dictionary:
    var pair_key := _pair_key(first_id, second_id)
    if pair_last_spoken.has(pair_key) and world_seconds - float(pair_last_spoken[pair_key]) < PAIR_COOLDOWN_SECONDS:
        return {}

    var eligible: Array[Dictionary] = []
    for exchange_value in HollowmereCampaignContent.ambient_exchanges():
        var exchange: Dictionary = exchange_value
        if not _is_eligible(exchange, first_role, second_role, hour, security, shakedown_resolved, shakedown_choice):
            continue
        eligible.append(exchange)
    if eligible.is_empty():
        return {}

    var pool: Array[Dictionary] = []
    for exchange in eligible:
        if not recent_exchange_ids.has(String(exchange.get("id", ""))) and not recent_topics.has(String(exchange.get("topic", ""))):
            pool.append(exchange)
    if pool.is_empty():
        for exchange in eligible:
            if not recent_exchange_ids.has(String(exchange.get("id", ""))):
                pool.append(exchange)
    if pool.is_empty():
        pool = eligible

    var weighted: Array[Dictionary] = []
    for exchange in pool:
        var weight := maxi(1, int(exchange.get("priority", 1)))
        for _i in range(weight):
            weighted.append(exchange)
    return weighted[rng.randi_range(0, weighted.size() - 1)].duplicate(true)


func record_exchange(exchange: Dictionary, first_id: String, second_id: String, world_seconds: float) -> void:
    if exchange.is_empty():
        return
    var exchange_id := String(exchange.get("id", ""))
    var topic := String(exchange.get("topic", ""))
    recent_exchange_ids.append(exchange_id)
    recent_topics.append(topic)
    while recent_exchange_ids.size() > RECENT_EXCHANGE_LIMIT:
        recent_exchange_ids.pop_front()
    while recent_topics.size() > RECENT_TOPIC_LIMIT:
        recent_topics.pop_front()
    pair_last_spoken[_pair_key(first_id, second_id)] = world_seconds


func _is_eligible(exchange: Dictionary, first_role: String, second_role: String,
        hour: int, security: int, shakedown_resolved: bool, shakedown_choice: String = "") -> bool:
    var roles: Array = exchange.get("roles", ["any"])
    if not roles.has("any") and not roles.has(first_role) and not roles.has(second_role):
        return false
    if bool(exchange.get("requires_shakedown", false)) and not shakedown_resolved:
        return false
    var required_choice := String(exchange.get("shakedown_choice", ""))
    if not required_choice.is_empty() and required_choice != shakedown_choice:
        return false
    if exchange.has("security_below") and security >= int(exchange["security_below"]):
        return false
    if exchange.has("security_above") and security <= int(exchange["security_above"]):
        return false
    if exchange.has("hour_start"):
        var start_hour := int(exchange["hour_start"])
        var end_hour := int(exchange["hour_end"])
        var in_range := hour >= start_hour and hour < end_hour if start_hour <= end_hour else hour >= start_hour or hour < end_hour
        if not in_range:
            return false
    return true


func _pair_key(first_id: String, second_id: String) -> String:
    var ids := [first_id, second_id]
    ids.sort()
    return "%s|%s" % [ids[0], ids[1]]
