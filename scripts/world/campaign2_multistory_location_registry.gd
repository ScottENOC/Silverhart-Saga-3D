class_name Campaign2MultiStoryLocationRegistry
extends RefCounted
## Validated source-authored floor stacks for Campaign 2 locations.
## This registry preserves floor geometry and transition data; runtime traversal
## and presentation are separate consumers.

const MANIFEST_PATH := "res://data/world/campaign2_multistory_locations.json"
const COORDINATE_SYSTEM := "campaign2_local_axial_qr"

var _locations: Dictionary = {}
var validation_errors: Array[String] = []

func _init(manifest_path: String = MANIFEST_PATH) -> void:
	if not FileAccess.file_exists(manifest_path):
		validation_errors.append("Multi-story location manifest is missing: %s" % manifest_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		validation_errors.append("Multi-story location manifest must be a JSON object.")
		return
	configure(parsed)

func configure(manifest: Dictionary) -> Dictionary:
	_locations.clear()
	validation_errors.clear()
	if int(manifest.get("schema_version", 0)) != 1:
		validation_errors.append("Unsupported multi-story location schema version.")
	if String(manifest.get("coordinate_system", "")) != COORDINATE_SYSTEM:
		validation_errors.append("Multi-story location coordinate system is invalid.")
	var source_locations: Variant = manifest.get("locations", [])
	if not source_locations is Array:
		validation_errors.append("Multi-story locations must be an array.")
		return {"ok": false, "errors": validation_errors.duplicate()}
	for location_variant in source_locations:
		if not location_variant is Dictionary:
			validation_errors.append("Multi-story location entry must be an object.")
			continue
		var location: Dictionary = location_variant
		var location_id := String(location.get("id", "")).strip_edges()
		if location_id.is_empty() or _locations.has(location_id):
			validation_errors.append("Multi-story location ID is empty or duplicated: %s" % location_id)
			continue
		if not _is_axial(location.get("anchor", {})):
			validation_errors.append("%s: anchor must contain integer q/r coordinates." % location_id)
			continue
		var floors: Variant = location.get("floors", [])
		if not floors is Array or floors.is_empty():
			validation_errors.append("%s: floors must be a non-empty array." % location_id)
			continue
		var floor_ids: Dictionary = {}
		var secret_ids: Dictionary = {}
		for floor_variant in floors:
			if not floor_variant is Dictionary:
				validation_errors.append("%s: floor entry must be an object." % location_id)
				continue
			var floor_definition: Dictionary = floor_variant
			var floor_number := int(floor_definition.get("floor", 999999))
			if floor_number == 999999 or floor_ids.has(floor_number):
				validation_errors.append("%s: floor number is missing or duplicated." % location_id)
				continue
			floor_ids[floor_number] = true
			for collection_name in ["rooms", "corridors", "tile_objects", "actors", "creatures"]:
				var collection: Variant = floor_definition.get(collection_name, [])
				if not collection is Array:
					validation_errors.append("%s floor %d: %s must be an array." % [location_id, floor_number, collection_name])
					continue
				for record in collection:
					if not record is Dictionary:
						validation_errors.append("%s floor %d: invalid %s record." % [location_id, floor_number, collection_name])
						continue
					if record.has("position") and not _is_axial(record.get("position", {})):
						validation_errors.append("%s floor %d: %s has invalid position." % [location_id, floor_number, collection_name])
					if collection_name == "tile_objects" and String(record.get("type", "")) == "secret_door":
						var secret_id := String(record.get("id", "")).strip_edges()
						if secret_id.is_empty() or secret_ids.has(secret_id) or not _is_axial(record.get("position", {})):
							validation_errors.append("%s floor %d: secret door requires a unique ID and valid position." % [location_id, floor_number])
						else:
							secret_ids[secret_id] = true
					if collection_name == "rooms":
						if not _is_axial(record.get("center", {})) or int(record.get("half_width", 0)) < 1 or int(record.get("half_height", 0)) < 1:
							validation_errors.append("%s floor %d: room geometry is invalid." % [location_id, floor_number])
						var row_shift_mode := String(record.get("row_shift_mode", "flat"))
						if row_shift_mode not in ["flat", "source_building"]:
							validation_errors.append("%s floor %d: room row-shift mode is invalid." % [location_id, floor_number])
					if collection_name == "corridors":
						if not _is_axial(record.get("from", {})) or not _is_axial(record.get("to", {})):
							validation_errors.append("%s floor %d: corridor endpoints are invalid." % [location_id, floor_number])
		for floor_variant in floors:
			if not floor_variant is Dictionary:
				continue
			for coordinate_collection_name in ["floor_hexes", "wall_hexes"]:
				var coordinate_collection: Variant = floor_variant.get(coordinate_collection_name, [])
				if not coordinate_collection is Array:
					validation_errors.append("%s floor %s: %s must be an array." % [location_id, floor_variant.get("floor", 0), coordinate_collection_name])
					continue
				for coordinate_variant in coordinate_collection:
					if not _is_axial(coordinate_variant):
						validation_errors.append("%s floor %s: %s contains an invalid axial coordinate." % [location_id, floor_variant.get("floor", 0), coordinate_collection_name])
			for room_variant in floor_variant.get("rooms", []):
				if room_variant is Dictionary:
					var hidden_by_secret := String(room_variant.get("hidden_by_secret", "")).strip_edges()
					if not hidden_by_secret.is_empty() and not secret_ids.has(hidden_by_secret):
						validation_errors.append("%s: hidden room references unknown secret door %s." % [location_id, hidden_by_secret])
		if not floor_ids.has(0):
			validation_errors.append("%s: surface floor 0 is required." % location_id)
		for transition_variant in location.get("transitions", []):
			if not transition_variant is Dictionary:
				validation_errors.append("%s: transition entry must be an object." % location_id)
				continue
			var transition: Dictionary = transition_variant
			var from_floor := int(transition.get("from_floor", 999999))
			var to_floor := int(transition.get("to_floor", 999999))
			if not floor_ids.has(from_floor) or not floor_ids.has(to_floor) or not _is_axial(transition.get("position", {})):
				validation_errors.append("%s: transition references a missing floor or invalid position." % location_id)
			if transition.has("unlocked_by_quest") and String(transition.get("unlocked_by_quest", "")).is_empty():
				validation_errors.append("%s: quest-gated transition requires a quest ID." % location_id)
		for gate_variant in location.get("quest_gates", []):
			if not gate_variant is Dictionary:
				validation_errors.append("%s: quest gate entry must be an object." % location_id)
				continue
			var gate: Dictionary = gate_variant
			if not floor_ids.has(int(gate.get("from_floor", 999999))) or not floor_ids.has(int(gate.get("to_floor", 999999))) or String(gate.get("quest_id", "")).is_empty():
				validation_errors.append("%s: quest gate references missing floor(s) or quest ID." % location_id)
			if bool(gate.get("initially_available", true)):
				validation_errors.append("%s: source quest gate must remain initially unavailable." % location_id)
		if validation_errors.is_empty():
			_locations[location_id] = location.duplicate(true)
	if not validation_errors.is_empty():
		_locations.clear()
		return {"ok": false, "errors": validation_errors.duplicate()}
	return {"ok": true, "errors": []}

func get_definition(location_id: String) -> Dictionary:
	return (_locations.get(location_id, {}) as Dictionary).duplicate(true)

func get_floor_definition(location_id: String, floor_number: int) -> Dictionary:
	var location := _locations.get(location_id, {}) as Dictionary
	for floor_variant in location.get("floors", []):
		if floor_variant is Dictionary and int(floor_variant.get("floor", 999999)) == floor_number:
			return (floor_variant as Dictionary).duplicate(true)
	return {}

func location_ids() -> Array[String]:
	var result: Array[String] = []
	for location_id in _locations:
		result.append(String(location_id))
	result.sort()
	return result

func _is_axial(value: Variant) -> bool:
	return value is Dictionary and value.has("q") and value.has("r") and int(value.get("q", 0)) == float(value.get("q", 0)) and int(value.get("r", 0)) == float(value.get("r", 0))
