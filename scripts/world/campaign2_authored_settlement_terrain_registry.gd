class_name Campaign2AuthoredSettlementTerrainRegistry
extends RefCounted
## Loads authored settlement terrain definitions without naming any settlement.
## Higher priority wins when authored settlement bounds overlap; ID breaks ties.

const MANIFEST_PATH := "res://data/world/authored_settlement_terrain.json"
const TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")
const COORDINATE_SYSTEM := "campaign2_local_axial_qr"

var _entries: Array[Dictionary] = []
var validation_errors: Array[String] = []

func _init(manifest_path: String = MANIFEST_PATH) -> void:
	if not FileAccess.file_exists(manifest_path):
		validation_errors.append("Authored settlement terrain manifest is missing: %s" % manifest_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		validation_errors.append("Authored settlement terrain manifest must be a JSON object.")
		return
	configure(parsed)

func configure(manifest: Dictionary) -> Dictionary:
	_entries.clear()
	validation_errors.clear()
	if int(manifest.get("schema_version", 0)) != 1:
		validation_errors.append("Unsupported authored settlement terrain schema version.")
	if String(manifest.get("coordinate_system", "")) != COORDINATE_SYSTEM:
		validation_errors.append("Authored settlement terrain coordinate system is invalid.")
	var settlements: Variant = manifest.get("settlements", [])
	if not settlements is Array:
		validation_errors.append("Authored settlement terrain settlements must be an array.")
		return {"ok": false, "errors": validation_errors.duplicate()}
	var seen_ids: Dictionary = {}
	for index in range(settlements.size()):
		var entry: Variant = settlements[index]
		if not entry is Dictionary:
			validation_errors.append("Settlement terrain entry %d must be an object." % index)
			continue
		var settlement_id := String(entry.get("id", "")).strip_edges()
		var script_path := String(entry.get("definition_script", "")).strip_edges()
		var origin_value: Variant = entry.get("origin")
		if settlement_id.is_empty() or script_path.is_empty() or not origin_value is Dictionary:
			validation_errors.append("Settlement terrain entry %d requires an ID, definition script and axial origin." % index)
			continue
		if not origin_value.has("q") or not origin_value.has("r"):
			validation_errors.append("Settlement terrain entry %d has an incomplete axial origin." % index)
			continue
		var origin := Vector2i(int(origin_value.get("q", 0)), int(origin_value.get("r", 0)))
		if seen_ids.has(settlement_id):
			validation_errors.append("Duplicate settlement terrain ID: %s" % settlement_id)
			continue
		seen_ids[settlement_id] = true
		var definition_script: Variant = load(script_path)
		if not definition_script is Script:
			validation_errors.append("Settlement terrain definition is not a loadable script: %s" % script_path)
			continue
		var constants: Dictionary = definition_script.get_script_constant_map()
		var definition: Variant = constants.get("DEFINITION")
		if not definition is Dictionary:
			validation_errors.append("Settlement terrain script has no Dictionary DEFINITION: %s" % script_path)
			continue
		if String(definition.get("id", "")) != settlement_id:
			validation_errors.append("Settlement terrain ID does not match its definition: %s" % settlement_id)
			continue
		if int(definition.get("map_radius", 0)) <= 0:
			validation_errors.append("Settlement terrain definition has an invalid map radius: %s" % settlement_id)
			continue
		if not definition.has("stream") or not definition.has("path") or not definition.has("buildings"):
			validation_errors.append("Settlement terrain definition is missing required terrain domains: %s" % settlement_id)
			continue
		_entries.append({
			"id": settlement_id,
			"priority": int(entry.get("priority", 0)),
			"definition": definition,
			"definition_script": script_path,
			"origin": origin
		})
	if not validation_errors.is_empty():
		_entries.clear()
		return {"ok": false, "errors": validation_errors.duplicate()}
	_entries.sort_custom(_entry_precedes)
	return {"ok": true, "errors": []}

func resolve(hex: Vector2i) -> Dictionary:
	for entry in _entries:
		var definition: Dictionary = entry.get("definition", {})
		var origin: Vector2i = entry.get("origin", Vector2i.ZERO)
		var local_hex := hex - origin
		if TERRAIN_PROVIDER.is_in_bounds(local_hex, definition):
			var resolved := entry.duplicate()
			resolved["local_hex"] = local_hex
			return resolved
	return {}

func settlement_ids() -> Array[String]:
	var result: Array[String] = []
	for entry in _entries:
		result.append(String(entry.get("id", "")))
	return result

func _entry_precedes(a: Dictionary, b: Dictionary) -> bool:
	var priority_a := int(a.get("priority", 0))
	var priority_b := int(b.get("priority", 0))
	if priority_a != priority_b:
		return priority_a > priority_b
	return String(a.get("id", "")) < String(b.get("id", ""))
