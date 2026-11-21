extends RefCounted
## Runtime structural validation for canonical authored settlement envelopes.
## This validator deliberately has no dependency on a settlement or a presenter.

const SCHEMA_VERSION := 1
const COORDINATE_SYSTEM := "campaign2_local_axial_qr"
const LAYOUT_COLLECTIONS := ["buildings", "paths", "bridges", "fields", "props"]
const PLACEMENT_COLLECTIONS := ["characters", "creatures"]
const POSITION_KEYS := ["center", "centre", "door", "from", "to", "position", "hex", "anchor"]

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
				_validate_axial_position(record[position_key], "%s record %s %s" % [collection_name, String(record.get("id", "")), position_key], bounds, errors)
			for point_collection in ["points", "corners"]:
				if not record.has(point_collection):
					continue
				var points: Variant = record[point_collection]
				if not points is Array:
					errors.append("%s record %s %s must be an array." % [collection_name, String(record.get("id", "")), point_collection])
					continue
				for point_index in range(points.size()):
					_validate_axial_position(points[point_index], "%s record %s %s[%d]" % [collection_name, String(record.get("id", "")), point_collection, point_index], bounds, errors)

static func _validate_axial_position(position: Variant, label: String, bounds: Dictionary, errors: Array[String]) -> void:
	if not _is_axial(position):
		errors.append("%s has invalid axial coordinates." % label)
		return
	var q := int(position.x) if position is Vector2i else int(position.get("q", 0))
	var r := int(position.y) if position is Vector2i else int(position.get("r", 0))
	if q < int(bounds.min_q) or q > int(bounds.max_q) or r < int(bounds.min_r) or r > int(bounds.max_r):
		errors.append("%s is outside settlement bounds." % label)

static func _validate_record_array(value: Variant, label: String, errors: Array[String]) -> bool:
	if not value is Array:
		errors.append("%s must be an array." % label)
		return false
	var seen: Dictionary = {}
	var valid := true
	for index in range(value.size()):
		var record: Variant = value[index]
		if not record is Dictionary:
			errors.append("%s[%d] must be an object." % [label, index])
			valid = false
			continue
		var record_id := String(record.get("id", "")).strip_edges()
		if record_id.is_empty():
			errors.append("%s[%d] requires a stable id." % [label, index])
			valid = false
		elif seen.has(record_id):
			errors.append("%s contains duplicate id %s." % [label, record_id])
			valid = false
		else:
			seen[record_id] = true
	return valid

static func _is_axial(value: Variant) -> bool:
	return value is Vector2i or (value is Dictionary and value.has("q") and value.has("r") and value.q is int and value.r is int)

static func _is_valid_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
		return false
	for character in value:
		if not (character == "_" or character.is_valid_identifier() or character.is_valid_int()):
			return false
	return value[0].is_valid_identifier() and not value[0].is_valid_int()
