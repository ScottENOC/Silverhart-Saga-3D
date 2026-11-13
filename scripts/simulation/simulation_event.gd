class_name SimulationEvent
extends RefCounted

var event_type: String
var actor_id: String
var target_id: String
var payload: Dictionary

func _init(requested_event_type: String, requested_actor_id: String = "", requested_target_id: String = "", event_payload: Dictionary = {}) -> void:
    event_type = requested_event_type
    actor_id = requested_actor_id
    target_id = requested_target_id
    payload = event_payload.duplicate(true)

func to_dict() -> Dictionary:
    return {
        "event_type": event_type,
        "actor_id": actor_id,
        "target_id": target_id,
        "payload": payload.duplicate(true)
    }
