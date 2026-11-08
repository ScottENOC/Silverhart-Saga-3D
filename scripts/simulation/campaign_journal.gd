class_name CampaignJournal
extends RefCounted
## Simulation-owned quest, objective, decision and faction-standing state.
## Quest definitions are data; this class stores only the player's changing state.

signal journal_event(event: Dictionary)

var quest_definitions: Dictionary = {}
var quests: Dictionary = {}
var faction_standings: Dictionary = {}


func register_quest_definition(definition: Dictionary) -> Dictionary:
    var quest_id := String(definition.get("id", "")).strip_edges()
    if quest_id.is_empty():
        return {"ok": false, "reason": "missing_quest_id"}
    if quest_definitions.has(quest_id):
        return {"ok": false, "reason": "duplicate_quest_definition"}

    var objectives: Variant = definition.get("objectives", [])
    if not objectives is Array:
        return {"ok": false, "reason": "invalid_objectives"}
    var seen_ids: Dictionary = {}
    for objective_value in objectives:
        if not objective_value is Dictionary:
            return {"ok": false, "reason": "invalid_objective"}
        var objective: Dictionary = objective_value
        var objective_id := String(objective.get("id", "")).strip_edges()
        var target := float(objective.get("target", 1.0))
        if objective_id.is_empty() or seen_ids.has(objective_id):
            return {"ok": false, "reason": "invalid_or_duplicate_objective_id"}
        if not is_finite(target) or target <= 0.0:
            return {"ok": false, "reason": "invalid_objective_target"}
        seen_ids[objective_id] = true

    quest_definitions[quest_id] = definition.duplicate(true)
    return {"ok": true, "quest_id": quest_id}


func start_quest(quest_id: String) -> Dictionary:
    if not quest_definitions.has(quest_id):
        return {"ok": false, "reason": "unknown_quest"}
    if quests.has(quest_id):
        return {"ok": false, "reason": "quest_already_started"}

    var definition: Dictionary = quest_definitions[quest_id]
    for prerequisite_value in definition.get("prerequisites", []):
        var prerequisite_id := String(prerequisite_value)
        if not quests.has(prerequisite_id) or String(quests[prerequisite_id].get("status", "")) != "completed":
            return {"ok": false, "reason": "prerequisite_incomplete", "prerequisite_id": prerequisite_id}

    var objective_states: Dictionary = {}
    for objective_value in definition.get("objectives", []):
        var objective: Dictionary = objective_value
        var objective_id := String(objective["id"])
        objective_states[objective_id] = {
            "progress": 0.0,
            "target": float(objective.get("target", 1.0)),
            "required": bool(objective.get("required", true)),
            "completed": false
        }

    quests[quest_id] = {
        "status": "active",
        "objectives": objective_states,
        "decisions": {},
        "started_at": 0.0,
        "completed_at": null,
        "failed_at": null,
        "failure_reason": ""
    }
    _emit_event("quest_started", {"quest_id": quest_id})
    return {"ok": true, "quest_id": quest_id}


func set_objective_progress(quest_id: String, objective_id: String, progress: float) -> Dictionary:
    if not quests.has(quest_id):
        return {"ok": false, "reason": "quest_not_started"}
    var quest: Dictionary = quests[quest_id]
    if String(quest.get("status", "")) != "active":
        return {"ok": false, "reason": "quest_not_active"}
    var objectives: Dictionary = quest.get("objectives", {})
    if not objectives.has(objective_id):
        return {"ok": false, "reason": "unknown_objective"}

    var objective: Dictionary = objectives[objective_id]
    var target := float(objective.get("target", 1.0))
    if not is_finite(progress):
        return {"ok": false, "reason": "invalid_progress"}
    var next_progress := clampf(progress, 0.0, target)
    objective["progress"] = next_progress
    objective["completed"] = next_progress >= target
    objectives[objective_id] = objective
    quest["objectives"] = objectives
    quests[quest_id] = quest
    _emit_event("quest_objective_updated", {
        "quest_id": quest_id,
        "objective_id": objective_id,
        "progress": next_progress,
        "target": target,
        "completed": bool(objective["completed"])
    })
    return {"ok": true, "completed": bool(objective["completed"]), "progress": next_progress, "target": target}


func record_decision(quest_id: String, decision_id: String, choice_id: String) -> Dictionary:
    if not quests.has(quest_id):
        return {"ok": false, "reason": "quest_not_started"}
    if String(quests[quest_id].get("status", "")) != "active":
        return {"ok": false, "reason": "quest_not_active"}
    if decision_id.strip_edges().is_empty() or choice_id.strip_edges().is_empty():
        return {"ok": false, "reason": "missing_decision_or_choice"}
    var decisions: Dictionary = quests[quest_id].get("decisions", {})
    if decisions.has(decision_id):
        return {"ok": false, "reason": "decision_already_recorded"}
    decisions[decision_id] = choice_id
    quests[quest_id]["decisions"] = decisions
    _emit_event("quest_decision_recorded", {
        "quest_id": quest_id,
        "decision_id": decision_id,
        "choice_id": choice_id
    })
    return {"ok": true, "choice_id": choice_id}


func complete_quest(quest_id: String) -> Dictionary:
    if not quests.has(quest_id):
        return {"ok": false, "reason": "quest_not_started"}
    var quest: Dictionary = quests[quest_id]
    if String(quest.get("status", "")) != "active":
        return {"ok": false, "reason": "quest_not_active"}
    for objective_value in quest.get("objectives", {}).values():
        var objective: Dictionary = objective_value
        if bool(objective.get("required", true)) and not bool(objective.get("completed", false)):
            return {"ok": false, "reason": "required_objectives_incomplete"}

    quest["status"] = "completed"
    quests[quest_id] = quest
    _emit_event("quest_completed", {"quest_id": quest_id})
    return {"ok": true, "quest_id": quest_id}


func fail_quest(quest_id: String, reason: String = "") -> Dictionary:
    if not quests.has(quest_id):
        return {"ok": false, "reason": "quest_not_started"}
    var quest: Dictionary = quests[quest_id]
    if String(quest.get("status", "")) != "active":
        return {"ok": false, "reason": "quest_not_active"}
    quest["status"] = "failed"
    quest["failure_reason"] = reason
    quests[quest_id] = quest
    _emit_event("quest_failed", {"quest_id": quest_id, "failure_reason": reason})
    return {"ok": true, "quest_id": quest_id}


func adjust_faction_standing(faction_id: String, amount: int, reason: String = "") -> Dictionary:
    if faction_id.strip_edges().is_empty():
        return {"ok": false, "reason": "missing_faction_id"}
    var previous := int(faction_standings.get(faction_id, 0))
    var next_value := previous + amount
    faction_standings[faction_id] = next_value
    _emit_event("faction_standing_changed", {
        "faction_id": faction_id,
        "previous": previous,
        "current": next_value,
        "delta": amount,
        "reason": reason
    })
    return {"ok": true, "previous": previous, "current": next_value}


func faction_standing(faction_id: String) -> int:
    return int(faction_standings.get(faction_id, 0))


func quest_state(quest_id: String) -> Dictionary:
    if not quests.has(quest_id):
        return {}
    return (quests[quest_id] as Dictionary).duplicate(true)


func to_dict() -> Dictionary:
    return {
        "quests": quests.duplicate(true),
        "faction_standings": faction_standings.duplicate(true)
    }


func load_dict(data: Dictionary) -> void:
    quests.clear()
    faction_standings.clear()
    var saved_quests: Variant = data.get("quests", {})
    if saved_quests is Dictionary:
        for quest_id_value in saved_quests.keys():
            var quest_id := String(quest_id_value)
            var saved_state: Variant = saved_quests[quest_id_value]
            if saved_state is Dictionary and quest_definitions.has(quest_id):
                quests[quest_id] = saved_state.duplicate(true)
    var saved_standings: Variant = data.get("faction_standings", {})
    if saved_standings is Dictionary:
        for faction_id_value in saved_standings.keys():
            faction_standings[String(faction_id_value)] = int(saved_standings[faction_id_value])


func _emit_event(event_type: String, payload: Dictionary) -> void:
    var event := {"event_type": event_type}
    for key in payload:
        event[key] = payload[key]
    journal_event.emit(event)
