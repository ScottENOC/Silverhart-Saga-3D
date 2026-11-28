class_name Campaign2InteriorExteriorLinkRegistry
extends RefCounted
## Explicit stable-ID join between Campaign 2 interior locations and exterior buildings/sites.

const MANIFEST_PATH := "res://data/world/campaign2_interior_exterior_links.json"
const COORDINATE_SYSTEM := "campaign2_local_axial_qr"
const VALID_STATUSES := [
	"linked",
	"geometry_incomplete",
	"review_required",
	"exterior_missing",
	"site_transition"
]
const VALID_KINDS := [
	"building",
	"cave_site",
	"settlement_site",
	"special_network",
	"dungeon_site",
	"fort_site"
]

var _links: Dictionary = {}
var validation_errors: Array[String] = []

func _init(manifest_path: String = MANIFEST_PATH) -> void:
	if not FileAccess.file_exists(manifest_path):
		validation_errors.append("Interior/exterior link manifest is missing: %s" % manifest_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		validation_errors.append("Interior/exterior link manifest must be a JSON object.")
		return
	configure(parsed)

func configure(manifest: Dictionary) -> Dictionary:
	_links.clear()
	validation_errors.clear()
	if int(manifest.get("schema_version", 0)) != 1:
		validation_errors.append("Unsupported interior/exterior link schema version.")
	if String(manifest.get("coordinate_system", "")) != COORDINATE_SYSTEM:
		validation_errors.append("Interior/exterior link coordinate system is invalid.")
	var records: Variant = manifest.get("links", [])
	if not records is Array:
		validation_errors.append("Interior/exterior links must be an array.")
		return {"ok": false, "errors": validation_errors.duplicate()}
	var seen_buildings: Dictionary = {}
	for record_variant in records:
		if not record_variant is Dictionary:
			validation_errors.append("Interior/exterior link entry must be an object.")
			continue
		var record: Dictionary = record_variant
		var location_id := String(record.get("location_id", "")).strip_edges()
		if location_id.is_empty() or _links.has(location_id):
			validation_errors.append("Interior/exterior location ID is empty or duplicated: %s" % location_id)
			continue
		var status := String(record.get("status", ""))
		if status not in VALID_STATUSES:
			validation_errors.append("%s: invalid link status %s." % [location_id, status])
		var kind := String(record.get("integration_kind", ""))
		if kind not in VALID_KINDS:
			validation_errors.append("%s: invalid integration kind %s." % [location_id, kind])
		var building_ids: Variant = record.get("building_ids", [])
		if not building_ids is Array:
			validation_errors.append("%s: building_ids must be an array." % location_id)
			building_ids = []
		if status == "linked" and building_ids.is_empty():
			validation_errors.append("%s: linked status requires at least one exterior building ID." % location_id)
		var candidate_ids: Variant = record.get("candidate_building_ids", [])
		if not candidate_ids is Array:
			validation_errors.append("%s: candidate_building_ids must be an array." % location_id)
			candidate_ids = []
		if status == "review_required" and (not building_ids.is_empty() or candidate_ids.is_empty()):
			validation_errors.append("%s: review_required must expose candidates without binding them." % location_id)
		if status == "exterior_missing" and not building_ids.is_empty():
			validation_errors.append("%s: exterior_missing cannot bind exterior building IDs." % location_id)
		var local_ids: Dictionary = {}
		for building_variant in building_ids:
			var building_id := String(building_variant).strip_edges()
			if building_id.is_empty() or local_ids.has(building_id):
				validation_errors.append("%s: building ID is empty or duplicated: %s." % [location_id, building_id])
				continue
			local_ids[building_id] = true
			if seen_buildings.has(building_id):
				validation_errors.append("%s: exterior building ID %s is already assigned to %s." % [location_id, building_id, seen_buildings[building_id]])
			else:
				seen_buildings[building_id] = location_id
		var room_links: Variant = record.get("room_links", [])
		if not room_links is Array:
			validation_errors.append("%s: room_links must be an array." % location_id)
			room_links = []
		var seen_rooms: Dictionary = {}
		for room_variant in room_links:
			if not room_variant is Dictionary:
				validation_errors.append("%s: room link must be an object." % location_id)
				continue
			var room_link: Dictionary = room_variant
			var room_id := String(room_link.get("room_id", "")).strip_edges()
			var building_id := String(room_link.get("building_id", "")).strip_edges()
			var room_key := "%d:%s" % [int(room_link.get("floor", 999999)), room_id]
			if room_id.is_empty() or seen_rooms.has(room_key):
				validation_errors.append("%s: room link ID is empty or duplicated: %s." % [location_id, room_key])
			else:
				seen_rooms[room_key] = true
			if not local_ids.has(building_id):
				validation_errors.append("%s: room %s references unbound building ID %s." % [location_id, room_id, building_id])
			if String(room_link.get("source_catalogue", "")).is_empty() or String(room_link.get("basis", "")).is_empty():
				validation_errors.append("%s: room %s requires source catalogue and link basis." % [location_id, room_id])
		if not String(record.get("transition_policy", "")).is_empty() and not VALID_STATUSES.has(status):
			validation_errors.append("%s: transition policy cannot compensate for an invalid status." % location_id)
		_links[location_id] = record.duplicate(true)
	if not validation_errors.is_empty():
		_links.clear()
		return {"ok": false, "errors": validation_errors.duplicate()}
	return {"ok": true, "errors": []}

func get_link(location_id: String) -> Dictionary:
	var record: Variant = _links.get(location_id, {})
	return record.duplicate(true) if record is Dictionary else {}

func location_ids() -> Array[String]:
	var result: Array[String] = []
	for location_id in _links:
		result.append(String(location_id))
	result.sort()
	return result
