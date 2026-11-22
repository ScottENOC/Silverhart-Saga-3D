class_name CompanionRelationshipState
extends RefCounted
## Source-faithful persistent companion relationship state.
## Approval, familiarity, trust, friendship, romantic bond and attraction are
## independent dimensions. Relationship/sexual agreements are explicit state,
## never inferred from a meter. This class is deliberately presentation-agnostic.

const AXES: Array[String] = [
	"approval",
	"familiarity",
	"trust",
	"friendship",
	"romantic_bond",
	"attraction"
]

const PROFILES := {
	"wren_talbot": {
		"name": "Wren Talbot",
		"orientation_label": "straight",
		"affinity_mode": "full",
		"familiarity_start": 35,
		"trust_start": 25,
		"approval_start": 50,
		"friendship_start": 38,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.18,
		"attraction_caps": {"masculine": 100, "feminine": 30, "androgynous": 45, "unknown": 35},
		"romantic_caps": {"masculine": 100, "feminine": 85, "androgynous": 90, "unknown": 75},
		"relationship_style": {"romantic_exclusivity": "exclusive", "sexual_exclusivity": "exclusive", "casual_sex": false, "friends_with_benefits": false, "group_relationships": false, "breach_response": "wren"}
	},
	"ser_aldric_thorne": {
		"name": "Ser Aldric Thorne",
		"orientation_label": "straight",
		"affinity_mode": "full",
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 18,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.10,
		"attraction_caps": {"masculine": 5, "feminine": 100, "androgynous": 20, "unknown": 20},
		"romantic_caps": {"masculine": 10, "feminine": 100, "androgynous": 30, "unknown": 25},
		"relationship_style": {"romantic_exclusivity": "exclusive", "sexual_exclusivity": "exclusive", "casual_sex": false, "friends_with_benefits": false, "group_relationships": false, "breach_response": "aldric", "can_reconcile_once": true}
	},
	"fenn_oakheart": {
		"name": "Fenn Oakheart",
		"orientation_label": "bisexual",
		"affinity_mode": "full",
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 16,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.12,
		"attraction_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 90},
		"romantic_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 95},
		"relationship_style": {"romantic_exclusivity": "open", "sexual_exclusivity": "open", "casual_sex": true, "friends_with_benefits": true, "group_relationships": true, "breach_response": "cnm"}
	},
	"reyna_fletcher": {
		"name": "Reyna Fletcher",
		"orientation_label": "lesbian",
		"affinity_mode": "full",
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 16,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.12,
		"attraction_caps": {"masculine": 5, "feminine": 100, "androgynous": 75, "unknown": 50},
		"romantic_caps": {"masculine": 10, "feminine": 100, "androgynous": 85, "unknown": 60},
		"relationship_style": {"romantic_exclusivity": "open", "sexual_exclusivity": "open", "casual_sex": true, "friends_with_benefits": true, "group_relationships": true, "breach_response": "cnm"}
	},
	"mirabel_quill": {
		"name": "Mirabel Quill",
		"orientation_label": "bisexual",
		"affinity_mode": "full",
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 12,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.12,
		"attraction_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 90},
		"romantic_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 95},
		"relationship_style": {"romantic_exclusivity": "open", "sexual_exclusivity": "open", "casual_sex": true, "friends_with_benefits": true, "group_relationships": true, "breach_response": "cnm"}
	},
	"brother_alden": {
		"name": "Brother Alden",
		"orientation_label": "asexual, biromantic",
		"affinity_mode": "full",
		"familiarity_start": 10,
		"trust_start": 10,
		"approval_start": 50,
		"friendship_start": 18,
		"romantic_bond_start": 0,
		"initial_attraction_fraction": 0.0,
		"attraction_caps": {"masculine": 0, "feminine": 0, "androgynous": 0, "unknown": 0},
		"romantic_caps": {"masculine": 100, "feminine": 100, "androgynous": 100, "unknown": 100},
		"relationship_style": {"romantic_exclusivity": "exclusive", "sexual_exclusivity": "open", "casual_sex": false, "friends_with_benefits": false, "group_relationships": false, "seeks_sex": false, "breach_response": "alden"}
	}
}

var states: Dictionary = {}


func has_profile(companion_id: String) -> bool:
	return PROFILES.has(companion_id)


func profile_for(companion_id: String) -> Dictionary:
	return (PROFILES.get(companion_id, {}) as Dictionary).duplicate(true)


func ensure(companion_id: String, presentation: String = "masculine") -> Dictionary:
	if not PROFILES.has(companion_id):
		return {}
	if states.has(companion_id):
		var existing: Dictionary = states[companion_id]
		if existing.get("presentation", "") == "unknown" and presentation != "unknown":
			existing["presentation"] = _normalise_presentation(presentation)
			_apply_caps(companion_id, existing)
			states[companion_id] = existing
		return existing
	var profile: Dictionary = PROFILES[companion_id]
	var normalized_presentation := _normalise_presentation(presentation)
	var attraction_caps: Dictionary = profile["attraction_caps"]
	var attraction_cap := float(attraction_caps.get(normalized_presentation, attraction_caps.get("unknown", 0)))
	var state := {
		"companion_id": companion_id,
		"presentation": normalized_presentation,
		"approval": float(profile["approval_start"]),
		"familiarity": float(profile["familiarity_start"]),
		"trust": float(profile["trust_start"]),
		"friendship": float(profile["friendship_start"]),
		"romantic_bond": float(profile["romantic_bond_start"]),
		"attraction": attraction_cap * float(profile["initial_attraction_fraction"]),
		"romance_state": "none",
		"agreement": {
			"state": "none",
			"romantic_exclusivity": String(profile["relationship_style"].get("romantic_exclusivity", "unspoken")),
			"sexual_exclusivity": String(profile["relationship_style"].get("sexual_exclusivity", "unspoken")),
			"group_relationships": bool(profile["relationship_style"].get("group_relationships", false)),
			"established_world_seconds": 0.0,
			"breaches": [],
			"reconciliation_used": false
		},
		"known_conversation_keys": [],
		"known_event_keys": [],
		"known_trust_event_keys": [],
		"history": []
	}
	_apply_caps(companion_id, state)
	states[companion_id] = state
	return state


func snapshot(companion_id: String) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {}
	var result := state.duplicate(true)
	result.erase("known_conversation_keys")
	result.erase("known_event_keys")
	result.erase("known_trust_event_keys")
	result.erase("history")
	return result


func set_presentation(companion_id: String, presentation: String) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	state["presentation"] = _normalise_presentation(presentation)
	_apply_caps(companion_id, state)
	states[companion_id] = state
	return {"ok": true, "state": snapshot(companion_id)}


func adjust(companion_id: String, changes: Dictionary, reason: String = "") -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	var before := snapshot(companion_id)
	for axis_value in changes.keys():
		var axis := String(axis_value)
		if not AXES.has(axis):
			continue
		if axis == "romantic_bond" or axis == "attraction":
			if String(PROFILES[companion_id]["affinity_mode"]) != "full":
				continue
		state[axis] = clampf(float(state.get(axis, 0.0)) + float(changes[axis_value]), 0.0, 100.0)
	_apply_caps(companion_id, state)
	states[companion_id] = state
	var after := snapshot(companion_id)
	if not reason.is_empty() and before != after:
		_append_history(state, {"reason": reason, "state": after})
		states[companion_id] = state
	return {"ok": true, "state": after}


func note_conversation(companion_id: String, conversation_key: String, familiarity_gain: float = 2.0) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	if conversation_key.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_conversation_key"}
	var keys: Array = state["known_conversation_keys"]
	if keys.has(conversation_key):
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	keys.append(conversation_key)
	state["known_conversation_keys"] = keys
	states[companion_id] = state
	var result := adjust(companion_id, {"familiarity": maxf(0.0, familiarity_gain)}, "conversation:" + conversation_key)
	result["changed"] = true
	return result


func record_event(companion_id: String, event_key: String, changes: Dictionary, reason: String = "") -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	if event_key.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_event_key"}
	var keys: Array = state["known_event_keys"]
	if keys.has(event_key):
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	keys.append(event_key)
	state["known_event_keys"] = keys
	states[companion_id] = state
	var result := adjust(companion_id, changes, reason if not reason.is_empty() else "event:" + event_key)
	result["changed"] = true
	return result


func record_trust_event(companion_id: String, event_key: String, trust_delta: float, reason: String = "") -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	if event_key.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_event_key"}
	var keys: Array = state["known_trust_event_keys"]
	if keys.has(event_key):
		return {"ok": true, "changed": false, "state": snapshot(companion_id)}
	keys.append(event_key)
	state["known_trust_event_keys"] = keys
	states[companion_id] = state
	var result := adjust(companion_id, {"trust": trust_delta}, reason if not reason.is_empty() else "trust:" + event_key)
	result["changed"] = true
	return result


func set_agreement(companion_id: String, updates: Dictionary, world_seconds: float = 0.0) -> Dictionary:
	var state := ensure(companion_id)
	if state.is_empty():
		return {"ok": false, "reason": "unknown_companion"}
	var agreement: Dictionary = state["agreement"]
	for key in ["state", "romantic_exclusivity", "sexual_exclusivity", "group_relationships", "reconciliation_used"]:
		if updates.has(key):
			agreement[key] = updates[key]
	if updates.has("breaches") and updates["breaches"] is Array:
		agreement["breaches"] = updates["breaches"].duplicate(true)
	if String(agreement.get("state", "none")) != "none" and float(agreement.get("established_world_seconds", 0.0)) <= 0.0:
		agreement["established_world_seconds"] = world_seconds
	state["agreement"] = agreement
	if updates.has("state"):
		state["romance_state"] = String(updates["state"])
	states[companion_id] = state
	return {"ok": true, "agreement": agreement.duplicate(true)}


func to_dict() -> Dictionary:
	return {"version": 1, "companions": states.duplicate(true)}


func load_dict(data: Dictionary) -> void:
	states.clear()
	var saved: Variant = data.get("companions", {})
	if not saved is Dictionary:
		return
	for companion_id_value in saved.keys():
		var companion_id := String(companion_id_value)
		if not PROFILES.has(companion_id) or not saved[companion_id_value] is Dictionary:
			continue
		var state: Dictionary = saved[companion_id_value].duplicate(true)
		var defaults := ensure(companion_id, String(state.get("presentation", "unknown")))
		for key in defaults.keys():
			if not state.has(key):
				state[key] = defaults[key]
		_apply_caps(companion_id, state)
		states[companion_id] = state


func _apply_caps(companion_id: String, state: Dictionary) -> void:
	var profile: Dictionary = PROFILES[companion_id]
	var presentation := _normalise_presentation(String(state.get("presentation", "unknown")))
	var attraction_caps: Dictionary = profile["attraction_caps"]
	var romantic_caps: Dictionary = profile["romantic_caps"]
	state["attraction"] = clampf(float(state.get("attraction", 0.0)), 0.0, float(attraction_caps.get(presentation, attraction_caps.get("unknown", 0))))
	state["romantic_bond"] = clampf(float(state.get("romantic_bond", 0.0)), 0.0, float(romantic_caps.get(presentation, romantic_caps.get("unknown", 0))))


func _append_history(state: Dictionary, entry: Dictionary) -> void:
	var history: Array = state.get("history", [])
	history.append(entry)
	if history.size() > 40:
		history = history.slice(history.size() - 40)
	state["history"] = history


func _normalise_presentation(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return normalized if ["masculine", "feminine", "androgynous", "unknown"].has(normalized) else "unknown"
