class_name SimulationActionResult
extends RefCounted

var action_type: String
var ok: bool
var reason: String
var actor_id: String
var target_id: String
var payload: Dictionary

func _init(requested_action_type: String, succeeded: bool, failure_reason: String = "", requested_actor_id: String = "", requested_target_id: String = "", result_payload: Dictionary = {}) -> void:
    action_type = requested_action_type
    ok = succeeded
    reason = failure_reason
    actor_id = requested_actor_id
    target_id = requested_target_id
    payload = result_payload.duplicate(true)

func to_dict() -> Dictionary:
    var result := payload.duplicate(true)
    result["action_type"] = action_type
    result["ok"] = ok
    result["reason"] = reason
    result["actor_id"] = actor_id
    result["target_id"] = target_id
    return result
