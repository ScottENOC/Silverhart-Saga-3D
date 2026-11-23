class_name Campaign2SettlementDefinitionRegistry
extends RefCounted
## One catalogue and validated canonical-definition provider for authored settlements.
## Source formats are handled only by registered adapters at this boundary.

const MANIFEST_PATH := "res://data/world/settlement_catalogue.json"
const COORDINATE_SYSTEM := "campaign2_local_axial_qr"
const VALIDATOR = preload("res://scripts/world/settlement_definition_validator.gd")

var _entries: Array[Dictionary] = []
var validation_errors: Array[String] = []
var _resolve_cache: Dictionary = {}

func _init(manifest_path: String = MANIFEST_PATH) -> void:
	if not FileAccess.file_exists(manifest_path):
		validation_errors.append("Settlement catalogue is missing: %s" % manifest_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		validation_errors.append("Settlement catalogue must be a JSON object.")
		return
	configure(parsed)

func configure(manifest: Dictionary) -> Dictionary:
	_entries.clear()
	_resolve_cache.clear()
	validation_errors.clear()
	if int(manifest.get("schema_version", 0)) != 1:
		validation_errors.append("Unsupported settlement catalogue schema version.")
	if String(manifest.get("coordinate_system", "")) != COORDINATE_SYSTEM:
		validation_errors.append("Settlement catalogue coordinate system is invalid.")
	var sources: Variant = manifest.get("settlements", [])
	if not sources is Array:
		validation_errors.append("Settlement catalogue settlements must be an array.")
		return {"ok": false, "errors": validation_errors.duplicate()}
	var seen_ids: Dictionary = {}
	for index in range(sources.size()):
		var source: Variant = sources[index]
		if not source is Dictionary:
			validation_errors.append("Settlement catalogue entry %d must be an object." % index)
			continue
		var settlement_id := String(source.get("id", "")).strip_edges()
		var adapter_path := String(source.get("adapter_script", "")).strip_edges()
		var adapter_method := String(source.get("adapter_method", "")).strip_edges()
		if settlement_id.is_empty() or adapter_path.is_empty() or adapter_method.is_empty():
			validation_errors.append("Settlement catalogue entry %d requires id, adapter_script and adapter_method." % index)
			continue
		if seen_ids.has(settlement_id):
			validation_errors.append("Duplicate settlement catalogue ID: %s" % settlement_id)
			continue
		seen_ids[settlement_id] = true
		if not ResourceLoader.exists(adapter_path):
			validation_errors.append("Settlement source adapter does not exist: %s" % adapter_path)
			continue
		var adapter_script: Variant = load(adapter_path)
		if not adapter_script is Script:
			validation_errors.append("Settlement source adapter is not a script: %s" % adapter_path)
			continue
		var adapter: Variant = adapter_script.new()
		if not adapter.has_method(adapter_method):
			validation_errors.append("Settlement source adapter has no method %s: %s" % [adapter_method, adapter_path])
			continue
		var arguments: Array = []
		if source.has("source_path"):
			var source_record := _read_source_record(source)
			if not bool(source_record.get("ok", false)):
				validation_errors.append(String(source_record.get("error", "Settlement source record could not be read.")))
				continue
			arguments.append(source_record.get("record", {}))
		var definition_value: Variant = adapter.callv(adapter_method, arguments)
		if not definition_value is Dictionary:
			validation_errors.append("Settlement adapter %s did not return a Dictionary for %s." % [adapter_method, settlement_id])
			continue
		var definition: Dictionary = definition_value
		if String(definition.get("id", "")) != settlement_id:
			validation_errors.append("Canonical settlement ID does not match catalogue entry: %s" % settlement_id)
			continue
		var validation: Dictionary = VALIDATOR.validate(definition)
		if not bool(validation.get("ok", false)):
			for message in validation.get("errors", []):
				validation_errors.append("%s: %s" % [settlement_id, String(message)])
			continue
		var origin: Dictionary = definition.get("origin", {})
		_entries.append({
			"id": settlement_id,
			"priority": int(source.get("priority", 0)),
			"definition": definition,
			"origin": Vector2i(int(origin.get("q", 0)), int(origin.get("r", 0)))
		})
	if not validation_errors.is_empty():
		_entries.clear()
		return {"ok": false, "errors": validation_errors.duplicate()}
	_entries.sort_custom(_entry_precedes)
	return {"ok": true, "errors": []}

func _read_source_record(source: Dictionary) -> Dictionary:
	var source_path := String(source.get("source_path", ""))
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		return {"ok": false, "error": "Settlement source file is missing: %s" % source_path}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if not parsed is Dictionary:
		return {"ok": false, "error": "Settlement source file is not a JSON object: %s" % source_path}
	var collection_name := String(source.get("source_collection", ""))
	var collection: Variant = parsed.get(collection_name, [])
	if not collection is Array:
		return {"ok": false, "error": "Settlement source collection is not an array: %s" % collection_name}
	var wanted_id := String(source.get("source_record_id", ""))
	for record in collection:
		if record is Dictionary and String(record.get("id", "")) == wanted_id:
			return {"ok": true, "record": record}
	return {"ok": false, "error": "Settlement source record %s was not found in %s." % [wanted_id, source_path]}

func get_definition(settlement_id: String) -> Dictionary:
	for entry in _entries:
		if String(entry.get("id", "")) == settlement_id:
			return (entry.get("definition", {}) as Dictionary).duplicate(true)
	return {}

## Returns the validated definitions with their world-space origin and catalogue
## priority. Consumers use this instead of reopening a legacy source file.
func get_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		result.append(entry.duplicate(true))
	return result

func resolve(global_hex: Vector2i) -> Dictionary:
	var cache_key := "%d,%d" % [global_hex.x, global_hex.y]
	if _resolve_cache.has(cache_key):
		return (_resolve_cache[cache_key] as Dictionary).duplicate(false)
	for entry in _entries:
		var definition: Dictionary = entry.get("definition", {})
		var local_hex: Vector2i = global_hex - entry.get("origin", Vector2i.ZERO)
		var bounds: Dictionary = definition.get("bounds", {})
		if local_hex.x < int(bounds.get("min_q", 1)) or local_hex.x > int(bounds.get("max_q", -1)):
			continue
		if local_hex.y < int(bounds.get("min_r", 1)) or local_hex.y > int(bounds.get("max_r", -1)):
			continue
		var terrain: Dictionary = definition.get("terrain", {})
		var terrain_radius := int(terrain.get("map_radius", 0))
		if terrain_radius > 0 and HexGrid.distance(Vector2i.ZERO, local_hex) > terrain_radius:
			continue
		# The canonical definition is immutable here. A shallow copy gives each
		# caller its own local_hex without recursively copying hundreds of props.
		var result := entry.duplicate(false)
		result["local_hex"] = local_hex
		_resolve_cache[cache_key] = result
		return result.duplicate(false)
	_resolve_cache[cache_key] = {}
	return {}

func settlement_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in _entries:
		ids.append(String(entry.get("id", "")))
	return ids

func _entry_precedes(a: Dictionary, b: Dictionary) -> bool:
	var priority_a := int(a.get("priority", 0))
	var priority_b := int(b.get("priority", 0))
	if priority_a != priority_b:
		return priority_a > priority_b
	return String(a.get("id", "")) < String(b.get("id", ""))
