class_name CompanionBondState
extends RefCounted
## Directional relationship values between companions. Existing companion-to-player
## relationships remain authoritative for those pairs; this store fills the
## missing companion-to-companion layer without assuming feelings are reciprocal.

const AXES: Array[String] = ["familiarity", "trust", "friendship", "romantic_bond", "attraction"]
const MIN_VALUE := 0.0
const MAX_VALUE := 100.0
const HISTORY_LIMIT := 40

var _directions: Dictionary = {}
var _history: Array[Dictionary] = []


func _direction_key(from_id: String, to_id: String) -> String:
	return "%s>%s" % [from_id.strip_edges(), to_id.strip_edges()]


func snapshot(from_id: String, to_id: String) -> Dictionary:
	if from_id.is_empty() or to_id.is_empty() or from_id == to_id:
		return {}
	var key := _direction_key(from_id, to_id)
	if not _directions.has(key):
		return _default_state()
	return (_directions[key] as Dictionary).duplicate(true)


func _default_state() -> Dictionary:
	return {
		"familiarity": 0.0,
		"trust": 0.0,
		"friendship": 0.0,
		"romantic_bond": 0.0,
		"attraction": 0.0,
		"last_event_key": "",
		"applied_event_keys": []
	}


func adjust(from_id: String, to_id: String, changes: Dictionary, event_key: String = "", reason: String = "") -> Dictionary:
	if from_id.strip_edges().is_empty() or to_id.strip_edges().is_empty() or from_id == to_id:
		return {"ok": false, "reason": "invalid_pair"}
	for axis in changes:
		if not AXES.has(String(axis)) or not (changes[axis] is int or changes[axis] is float):
			return {"ok": false, "reason": "invalid_relationship_change", "axis": String(axis)}
	var key := _direction_key(from_id, to_id)
	var state: Dictionary = _directions.get(key, _default_state()).duplicate(true)
	var applied_keys: Array = state.get("applied_event_keys", [])
	if not event_key.is_empty() and applied_keys.has(event_key):
		return {"ok": true, "changed": false, "state": state}
	for axis in changes:
		state[axis] = clampf(float(state.get(axis, 0.0)) + float(changes[axis]), MIN_VALUE, MAX_VALUE)
	if not event_key.is_empty():
		state["last_event_key"] = event_key
		applied_keys.append(event_key)
		while applied_keys.size() > 120:
			applied_keys.pop_front()
		state["applied_event_keys"] = applied_keys
	_directions[key] = state
	_history.append({
		"from_id": from_id, "to_id": to_id, "event_key": event_key,
		"reason": reason, "changes": changes.duplicate(true)
	})
	while _history.size() > HISTORY_LIMIT:
		_history.pop_front()
	return {"ok": true, "changed": true, "state": state.duplicate(true)}


func set_relationship(from_id: String, to_id: String, values: Dictionary) -> Dictionary:
	if from_id.strip_edges().is_empty() or to_id.strip_edges().is_empty() or from_id == to_id:
		return {"ok": false, "reason": "invalid_pair"}
	var state := _default_state()
	for axis in values:
		if not AXES.has(String(axis)) or not (values[axis] is int or values[axis] is float):
			return {"ok": false, "reason": "invalid_relationship_value", "axis": String(axis)}
		state[axis] = clampf(float(values[axis]), MIN_VALUE, MAX_VALUE)
	_directions[_direction_key(from_id, to_id)] = state
	return {"ok": true, "state": state.duplicate(true)}


func compatibility_score(a_id: String, b_id: String) -> float:
	var a_to_b := snapshot(a_id, b_id)
	var b_to_a := snapshot(b_id, a_id)
	if a_to_b.is_empty() or b_to_a.is_empty():
		return 0.0
	var friendship := (float(a_to_b.friendship) + float(b_to_a.friendship)) * 0.5
	var trust := (float(a_to_b.trust) + float(b_to_a.trust)) * 0.5
	var familiarity := (float(a_to_b.familiarity) + float(b_to_a.familiarity)) * 0.5
	var romance := (float(a_to_b.romantic_bond) + float(b_to_a.romantic_bond)) * 0.5
	return friendship * 0.45 + trust * 0.30 + familiarity * 0.15 + romance * 0.10


func to_dict() -> Dictionary:
	return {"directions": _directions.duplicate(true), "history": _history.duplicate(true)}


func from_dict(data: Dictionary) -> bool:
	var directions: Variant = data.get("directions", {})
	var history: Variant = data.get("history", [])
	if not directions is Dictionary or not history is Array:
		return false
	var validated: Dictionary = {}
	for key_variant in directions:
		var key := String(key_variant)
		var state: Variant = directions[key_variant]
		if key.is_empty() or not state is Dictionary:
			return false
		var clean := _default_state()
		for axis in AXES:
			var value: Variant = state.get(axis, 0.0)
			if not (value is int or value is float):
				return false
			clean[axis] = clampf(float(value), MIN_VALUE, MAX_VALUE)
		clean["last_event_key"] = String(state.get("last_event_key", ""))
		var applied: Variant = state.get("applied_event_keys", [])
		if not applied is Array:
			return false
		clean["applied_event_keys"] = applied.duplicate()
		while clean["applied_event_keys"].size() > 120:
			clean["applied_event_keys"].pop_front()
		validated[key] = clean
	_directions = validated
	_history.clear()
	for entry in history:
		if entry is Dictionary:
			_history.append(entry.duplicate(true))
	while _history.size() > HISTORY_LIMIT:
		_history.pop_front()
	return true
