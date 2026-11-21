extends RefCounted
## Read-only migration adapters from legacy authored sources to the canonical
## settlement envelope. These are temporary source-boundary adapters; runtime
## consumers must depend on the canonical provider, not these legacy formats.

const HOLLOWMERE_PRESENTATION = preload("res://data/settlements/hollowmere/presentation.gd")
const HOLLOWMERE_SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const HOLLOWMERE_TERRAIN = preload("res://data/settlements/hollowmere/terrain.gd")
const HOLLOWMERE_PLACEMENTS = preload("res://data/settlements/hollowmere/placements.gd")
const VALIDATOR = preload("res://scripts/world/settlement_definition_validator.gd")

func adapt_hollowmere() -> Dictionary:
	var presentation_constants: Dictionary = HOLLOWMERE_PRESENTATION.new().get_script_constant_map()
	var terrain_constants: Dictionary = HOLLOWMERE_TERRAIN.new().get_script_constant_map()
	var placement_constants: Dictionary = HOLLOWMERE_PLACEMENTS.new().get_script_constant_map()
	var source: Dictionary = presentation_constants.get("DEFINITION", {})
	var feature_data: Dictionary = source.get("features", {}).get("data", {})
	var placements: Dictionary = {}
	for character_id in placement_constants.get("CHARACTER_STARTS", {}):
		placements[character_id] = placement_constants.get("CHARACTER_STARTS", {})[character_id]
	var characters: Array = []
	characters.append({"id": "player_start", "character_id": "player", "position": placement_constants.get("PLAYER_START_HEX", Vector2i.ZERO)})
	for character_id in placements:
		characters.append({"id": String(character_id), "character_id": String(character_id), "position": placements[character_id]})
	var creatures: Array = []
	for placement in placement_constants.get("FARM_ANIMALS", []) + placement_constants.get("WILDERNESS_ANIMALS", []):
		var creature: Dictionary = placement.duplicate(true)
		creature["position"] = creature.get("hex", Vector2i.ZERO)
		creature.erase("hex")
		creatures.append(creature)
	var fields: Array = []
	fields.append_array(_tag_records(feature_data.get("fields", []), "field"))
	fields.append_array(_tag_records(feature_data.get("crop_rows", []), "crop_row"))
	fields.append_array(_tag_records(feature_data.get("fences", []), "fence"))
	var props: Array = []
	for collection_name in ["landmark_props", "quest_props", "wayfinding_props"]:
		props.append_array(_tag_records(feature_data.get(collection_name, []), collection_name))
	var canonical := {
		"schema_version": 1,
		"id": HOLLOWMERE_SETTLEMENT.SETTLEMENT_ID,
		"name": HOLLOWMERE_SETTLEMENT.DISPLAY_NAME,
		"source": "data/settlements/hollowmere domain modules",
		"coordinate_system": "campaign2_local_axial_qr",
		# Existing authored feature and terrain coordinates are already expressed
		# in the Campaign 2 axial frame. Keep a zero transform until a separately
		# tested rebase converts every source domain together.
		"origin": {"q": 0, "r": 0},
		"bounds": {"min_q": -HOLLOWMERE_SETTLEMENT.MAP_RADIUS, "max_q": HOLLOWMERE_SETTLEMENT.MAP_RADIUS, "min_r": -HOLLOWMERE_SETTLEMENT.MAP_RADIUS, "max_r": HOLLOWMERE_SETTLEMENT.MAP_RADIUS},
		"terrain": terrain_constants.get("DEFINITION", {}),
		"layout": {
			"buildings": _tag_records(feature_data.get("buildings", []), "building"),
			"paths": _tag_records(feature_data.get("routes", []), "route"),
			"bridges": _tag_records([feature_data.get("bridge", {})], "bridge"),
			"fields": fields,
			"props": props
		},
		"placements": {"characters": characters, "creatures": creatures},
		"presentation": {
			"mode": "location_presenter",
			"hex_radius": source.get("hex_radius", HexGrid.DEFAULT_RADIUS_M),
			"ground": source.get("ground", {}),
			"palette": source.get("palette", {}),
			"vegetation": source.get("vegetation", {}),
			"materials": source.get("features", {}).get("materials", {})
		},
		"interiors": []
	}
	return canonical

func adapt_campaign2_layout(layout: Dictionary) -> Dictionary:
	var centre: Dictionary = layout.get("center", {"q": 0, "r": 0})
	var buildings: Array = []
	for source_building in layout.get("buildings", []):
		var building: Dictionary = source_building.duplicate(true)
		building["center"] = _read_axial(building.get("center", {}))
		if building.has("door"):
			building["door"] = _read_axial(building["door"])
		buildings.append(building)
	var paths: Array = []
	for source_path in layout.get("paths", []):
		var path: Dictionary = source_path.duplicate(true)
		path["from"] = _read_axial(path.get("from", {}))
		path["to"] = _read_axial(path.get("to", {}))
		paths.append(path)
	var characters: Array = []
	for npc in layout.get("npcs", []):
		if not npc is Dictionary:
			continue
		var character_id := String(npc.get("character_id", npc.get("id", ""))).strip_edges()
		if character_id.is_empty():
			continue
		characters.append({
			"id": character_id,
			"character_id": character_id,
			"position": _read_axial(npc.get("position", {}))
		})
	var min_q := int(centre.get("q", 0))
	var max_q := min_q
	var min_r := int(centre.get("r", 0))
	var max_r := min_r
	for building in buildings:
		var point: Dictionary = building.get("center", {})
		min_q = mini(min_q, int(point.get("q", 0)) - int(building.get("half_q", 0)) - 2)
		max_q = maxi(max_q, int(point.get("q", 0)) + int(building.get("half_q", 0)) + 2)
		min_r = mini(min_r, int(point.get("r", 0)) - int(building.get("half_r", 0)) - 2)
		max_r = maxi(max_r, int(point.get("r", 0)) + int(building.get("half_r", 0)) + 2)
	for character in characters:
		var point: Dictionary = character.get("position", {})
		min_q = mini(min_q, int(point.get("q", 0)))
		max_q = maxi(max_q, int(point.get("q", 0)))
		min_r = mini(min_r, int(point.get("r", 0)))
		max_r = maxi(max_r, int(point.get("r", 0)))
	for path in paths:
		for endpoint_name in ["from", "to"]:
			var point: Dictionary = path.get(endpoint_name, {})
			min_q = mini(min_q, int(point.get("q", 0)))
			max_q = maxi(max_q, int(point.get("q", 0)))
			min_r = mini(min_r, int(point.get("r", 0)))
			max_r = maxi(max_r, int(point.get("r", 0)))
	var canonical := {
		"schema_version": 1,
		"id": String(layout.get("id", "")),
		"name": String(layout.get("name", layout.get("id", ""))),
		"source": String(layout.get("source", layout.get("source_builder", "campaign2 settlement layout"))),
		"coordinate_system": "campaign2_local_axial_qr",
		"origin": {"q": 0, "r": 0},
		"bounds": {"min_q": min_q - 2, "max_q": max_q + 2, "min_r": min_r - 2, "max_r": max_r + 2},
		"terrain": {},
		"layout": {"buildings": buildings, "paths": paths, "bridges": [], "fields": [], "props": []},
		# Only placement references survive this adapter. Identity, appearance,
		# class progression, equipment and dialogue remain character-owned.
		"placements": {"characters": characters, "creatures": []},
		"presentation": {"mode": "chunked", "hex_radius": HexGrid.DEFAULT_RADIUS_M, "ground": {}, "palette": {}, "vegetation": {}},
		"interiors": []
	}
	return canonical

func validate_adapted(definition: Dictionary) -> Dictionary:
	return VALIDATOR.validate(definition)

func _read_axial(value: Variant) -> Dictionary:
	if value is Vector2i:
		return {"q": value.x, "r": value.y}
	if value is Dictionary:
		return {"q": int(value.get("q", 0)), "r": int(value.get("r", 0))}
	return {"q": 0, "r": 0}

func _tag_records(records: Array, feature_type: String) -> Array:
	var tagged: Array = []
	for source_record in records:
		if not source_record is Dictionary:
			continue
		var record: Dictionary = source_record.duplicate(true)
		record["feature_type"] = feature_type
		tagged.append(record)
	return tagged
