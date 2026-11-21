extends RefCounted
## Runtime structural validation for canonical authored settlement envelopes.
## This validator deliberately has no dependency on a settlement or a presenter.

const SCHEMA_VERSION := 1
const COORDINATE_SYSTEM := "campaign2_local_axial_qr"
const LAYOUT_COLLECTIONS := ["buildings", "paths", "bridges", "fields", "props"]
const PLACEMENT_COLLECTIONS := ["characters", "creatures"]
const POSITION_KEYS := ["center", "door", "from", "to", "position", "hex"]

static func validate(definition: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(definition.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d." % SCHEMA_VERSION)
	var settlement_id := String(definition.get("id", "")).strip_edges()
	if not _is_valid_id(settlement_id):
		errors.append("id must be a stable lowercase identifier.")
	if String(definition.get("name", "")).strip_edges().is_empty():
		errors.append("name is required.")
	if String(definition.get("coordinate_system", "")) != COORDINATE_SYSTEM:
		errors.append("coordinate_system is unsupported.")
	if not _is_axial(definition.get("origin")):
		errors.append("origin must contain integer q and r coordinates.")
	if not _validate_bounds(definition.get("bounds"), errors):
		pass
	_validate_object_section(definition, "terrain", errors, false)
	_validate_object_section(definition, "layout", errors, true)
	_validate_object_section(definition, "placements", errors, true)
	_validate_object_section(definition, "presentation", errors, true)
	_validate_record_array(definition.get("interiors", []), "interiors", errors)
	var bounds: Dictionary = definition.get("bounds", {}) if definition.get("bounds", {}) is Dictionary else {}
	if _is_valid_bounds(bounds):
		_validate_section_records(definition.get("layout", {}), LAYOUT_COLLECTIONS, bounds, "layout", errors)
		_validate_section_records(definition.get("placements", {}), PLACEMENT_COLLECTIONS, bounds, "placements", errors)
		_validate_section_records({"interiors": definition.get("interiors", [])}, ["interiors"], bounds, "interiors", errors)
	return {"ok": errors.is_empty(), "errors": errors}

static func _validate_bounds(value: Variant, errors: Array[String]) -> bool:
	if not value is Dictionary:
		errors.append("bounds must be an object.")
		return false
	for key in ["min_q", "max_q", "min_r", "max_r"]:
		if not value.has(key) or not (value[key] is int):
			errors.append("bounds.%s must be an integer." % key)
			return false
	if int(value.min_q) > int(value.max_q) or int(value.min_r) > int(value.max_r):
		errors.append("bounds minimums must not exceed maximums.")
		return false
	return true

static func _is_valid_bounds(value: Dictionary) -> bool:
	return value.has_all(["min_q", "max_q", "min_r", "max_r"]) and int(value.min_q) <= int(value.max_q) and int(value.min_r) <= int(value.max_r)

static func _validate_object_section(source: Dictionary, key: String, errors: Array[String], required: bool) -> void:
	if not source.has(key):
		if required:
			errors.append("%s is required." % key)
		return
	if not source[key] is Dictionary:
		errors.append("%s must be an object." % key)

static func _validate_section_records(source: Variant, collection_names: Array, bounds: Dictionary, section_name: String, errors: Array[String]) -> void:
	if not source is Dictionary:
		return
	for collection_name in collection_names:
		if not source.has(collection_name):
			continue
		var records: Variant = source[collection_name]
		if not _validate_record_array(records, "%s.%s" % [section_name, collection_name], errors):
			continue
		for record in records:
			for position_key in POSITION_KEYS:
				if not record.has(position_key):
					continue
				var position: Variant = record[position_key]
				if not _is_axial(position):
					errors.append("%s record %s has invalid %s axial coordinates." % [collection_name, String(record.get("id", "")), position_key])
					continue
				if int(position.q) < int(bounds.min_q) or int(position.q) > int(bounds.max_q) or int(position.r) < int(bounds.min_r) or int(position.r) > int(bounds.max_r):
					errors.append("%s record %s has %s outside settlement bounds." % [collection_name, String(record.get("id", "")), position_key])

static func _validate_record_array(value: Variant, label: String, errors: Array[String]) -> bool:
	if not value is Array:
		errors.append("%s must be an array." % label)
		return false
	var seen: Dictionary = {}
	for index in range(value.size()):
		var record: Variant = value[index]
		if not record is Dictionary:
			errors.append("%s[%d] must be an object." % [label, index])
			continue
		var record_id := String(record.get("id", "")).strip_edges()
		if record_id.is_empty():
			errors.append("%s[%d] requires a stable id." % [label, index])
		elif seen.has(record_id):
			errors.append("%s contains duplicate id %s." % [label, record_id])
		else:
			seen[record_id] = true
	return true

static func _is_axial(value: Variant) -> bool:
	return value is Dictionary and value.has("q") and value.has("r") and value.q is int and value.r is int

static func _is_valid_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
		return false
	for character in value:
		if not (character == "_" or character.is_valid_identifier() or character.is_valid_int()):
			return false
	return value[0].is_valid_identifier() and not value[0].is_valid_int()
