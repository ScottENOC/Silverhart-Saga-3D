class_name Campaign2MultiStoryLocationState
extends RefCounted
## Persistent traversal state for a source-authored multi-story location.
## Presentation and map swapping are handled by the location runtime.

signal floor_changed(previous_floor: int, current_floor: int, stair_position: Vector2i)

var location_id: String = ""
var current_floor: int = 0
var _definition: Dictionary = {}
var _floor_ids: Dictionary = {}
var _transitions: Array[Dictionary] = []
var _available_transitions: Dictionary = {}
var _secret_ids: Dictionary = {}
var _discovered_secrets: Dictionary = {}

func configure(location_definition: Dictionary, saved_state: Dictionary = {}) -> Dictionary:
	location_id = String(location_definition.get("id", "")).strip_edges()
	if location_id.is_empty():
		return {"ok": false, "reason": "missing_location_id"}
	_definition = location_definition.duplicate(true)
	_floor_ids.clear()
	_transitions.clear()
	_available_transitions.clear()
	_secret_ids.clear()
	_discovered_secrets.clear()
	for floor_variant in _definition.get("floors", []):
		if floor_variant is Dictionary:
			_floor_ids[int(floor_variant.get("floor", 999999))] = true
	if not _floor_ids.has(0):
		return {"ok": false, "reason": "missing_surface_floor"}
	for floor_variant in _definition.get("floors", []):
		if not floor_variant is Dictionary:
			continue
		for object_variant in floor_variant.get("tile_objects", []):
			if not object_variant is Dictionary or String(object_variant.get("type", "")) != "secret_door":
				continue
			var secret_id := String(object_variant.get("id", "")).strip_edges()
			if secret_id.is_empty() or _secret_ids.has(secret_id):
				return {"ok": false, "reason": "missing_or_duplicate_secret_door_id"}
			_secret_ids[secret_id] = true
	for transition_variant in _definition.get("transitions", []):
		if not transition_variant is Dictionary:
			continue
		var transition: Dictionary = transition_variant.duplicate(true)
		var from_floor := int(transition.get("from_floor", 999999))
		var to_floor := int(transition.get("to_floor", 999999))
		if not _floor_ids.has(from_floor) or not _floor_ids.has(to_floor):
			return {"ok": false, "reason": "transition_references_missing_floor"}
		if not _is_axial(transition.get("position", {})):
			return {"ok": false, "reason": "transition_has_invalid_position"}
		_transitions.append(transition)
		var key := _transition_key(transition)
		_available_transitions[key] = bool(transition.get("initially_available", true))
	current_floor = 0
	if not saved_state.is_empty() and not restore(saved_state):
		return {"ok": false, "reason": "invalid_saved_location_state"}
	return {"ok": true, "location_id": location_id, "current_floor": current_floor}

func try_transition(to_floor: int, stair_position: Vector2i) -> Dictionary:
	if not _floor_ids.has(current_floor) or not _floor_ids.has(to_floor):
		return {"ok": false, "reason": "unknown_floor"}
	for transition in _transitions:
		if int(transition.get("from_floor", 999999)) != current_floor:
			continue
		if int(transition.get("to_floor", 999999)) != to_floor:
			continue
		var position: Dictionary = transition.get("position", {})
		if Vector2i(int(position.get("q", 0)), int(position.get("r", 0))) != stair_position:
			continue
		var key := _transition_key(transition)
		if not bool(_available_transitions.get(key, false)):
			return {
				"ok": false,
				"reason": "transition_locked",
				"quest_id": String(transition.get("unlocked_by_quest", ""))
			}
		var previous_floor := current_floor
		current_floor = to_floor
		floor_changed.emit(previous_floor, current_floor, stair_position)
		return {"ok": true, "from_floor": previous_floor, "to_floor": current_floor, "position": stair_position}
	return {"ok": false, "reason": "no_stair_at_position"}

## Called by the campaign journal bridge when a quest reaches completed.
## Repeated calls are safe and only report newly revealed transitions.
func complete_quest(quest_id: String) -> Dictionary:
	if quest_id.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_quest_id"}
	var revealed: Array[Dictionary] = []
	for transition in _transitions:
		if String(transition.get("unlocked_by_quest", "")) != quest_id:
			continue
		var key := _transition_key(transition)
		if bool(_available_transitions.get(key, false)):
			continue
		_available_transitions[key] = true
		revealed.append(transition.duplicate(true))
	return {"ok": true, "revealed": revealed, "already_revealed": revealed.is_empty()}

func discover_secret(secret_id: String) -> Dictionary:
	var stable_id := secret_id.strip_edges()
	if not _secret_ids.has(stable_id):
		return {"ok": false, "reason": "unknown_secret_door"}
	if _discovered_secrets.has(stable_id):
		return {"ok": true, "already_discovered": true}
	_discovered_secrets[stable_id] = true
	return {"ok": true, "already_discovered": false}

func is_secret_discovered(secret_id: String) -> bool:
	return bool(_discovered_secrets.get(secret_id, false))

func is_transition_available(from_floor: int, to_floor: int, stair_position: Vector2i) -> bool:
	for transition in _transitions:
		if int(transition.get("from_floor", 999999)) != from_floor or int(transition.get("to_floor", 999999)) != to_floor:
			continue
		var position: Dictionary = transition.get("position", {})
		if Vector2i(int(position.get("q", 0)), int(position.get("r", 0))) == stair_position:
			return bool(_available_transitions.get(_transition_key(transition), false))
	return false

func to_dict() -> Dictionary:
	var unlocked: Array[String] = []
	var discovered_secrets: Array[String] = []
	for key in _available_transitions:
		if bool(_available_transitions[key]):
			var transition := _transition_by_key(String(key))
			if not transition.is_empty() and transition.has("unlocked_by_quest"):
				unlocked.append(String(key))
	unlocked.sort()
	for secret_id in _discovered_secrets:
		if bool(_discovered_secrets[secret_id]):
			discovered_secrets.append(String(secret_id))
	discovered_secrets.sort()
	return {
		"schema_version": 1,
		"location_id": location_id,
		"current_floor": current_floor,
		"unlocked_transitions": unlocked,
		"discovered_secrets": discovered_secrets
	}

func restore(saved_state: Dictionary) -> bool:
	if String(saved_state.get("location_id", "")) != location_id or int(saved_state.get("schema_version", 0)) != 1:
		return false
	var restored_floor := int(saved_state.get("current_floor", 999999))
	if not _floor_ids.has(restored_floor):
		return false
	var unlocked_variant: Variant = saved_state.get("unlocked_transitions", [])
	if not unlocked_variant is Array:
		return false
	var restored_secrets_variant: Variant = saved_state.get("discovered_secrets", [])
	if not restored_secrets_variant is Array:
		return false
	var restored_secrets: Dictionary = {}
	for secret_variant in restored_secrets_variant:
		var secret_id := String(secret_variant)
		if not _secret_ids.has(secret_id) or restored_secrets.has(secret_id):
			return false
		restored_secrets[secret_id] = true
	var restored_unlocks: Dictionary = {}
	for key_variant in unlocked_variant:
		var key := String(key_variant)
		var transition := _transition_by_key(key)
		if transition.is_empty() or not transition.has("unlocked_by_quest"):
			return false
		restored_unlocks[key] = true
	for key in _available_transitions:
		var transition := _transition_by_key(String(key))
		var initially_available := bool(transition.get("initially_available", true))
		if int(transition.get("to_floor", 999999)) == restored_floor and not initially_available and not restored_unlocks.has(String(key)):
			return false
		_available_transitions[key] = initially_available or restored_unlocks.has(String(key))
	_discovered_secrets = restored_secrets
	current_floor = restored_floor
	return true

func _transition_by_key(key: String) -> Dictionary:
	for transition in _transitions:
		if _transition_key(transition) == key:
			return transition
	return {}

func _transition_key(transition: Dictionary) -> String:
	var position: Dictionary = transition.get("position", {})
	return "%d>%d@%d,%d" % [
		int(transition.get("from_floor", 999999)),
		int(transition.get("to_floor", 999999)),
		int(position.get("q", 0)),
		int(position.get("r", 0))
	]

func _is_axial(value: Variant) -> bool:
	return value is Dictionary and value.has("q") and value.has("r") and int(value.get("q", 0)) == float(value.get("q", 0)) and int(value.get("r", 0)) == float(value.get("r", 0))
