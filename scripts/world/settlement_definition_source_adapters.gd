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
	# These are preloaded Script resources. Read their named constants directly;
	# .new() creates RefCounted instances, which do not expose Script reflection.
	var source: Dictionary = HOLLOWMERE_PRESENTATION.DEFINITION
	var terrain_definition: Dictionary = HOLLOWMERE_TERRAIN.DEFINITION
	var character_starts: Dictionary = HOLLOWMERE_PLACEMENTS.CHARACTER_STARTS
	var farm_animals: Array = HOLLOWMERE_PLACEMENTS.FARM_ANIMALS
	var wilderness_animals: Array = HOLLOWMERE_PLACEMENTS.WILDERNESS_ANIMALS
	var feature_data: Dictionary = source.get("features", {}).get("data", {})
	var placements: Dictionary = character_starts.duplicate(true)
	var characters: Array = []
	characters.append({"id": "player_start", "character_id": "player", "position": HOLLOWMERE_PLACEMENTS.PLAYER_START_HEX})
	for character_id in placements:
		characters.append({"id": String(character_id), "character_id": String(character_id), "position": placements[character_id]})
	var creatures: Array = []
	for placement in farm_animals + wilderness_animals:
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
		"terrain": terrain_definition,
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
		if path.has("from"):
			path["from"] = _read_axial(path["from"])
		if path.has("to"):
			path["to"] = _read_axial(path["to"])
		if path.get("points") is Array:
			var converted_points: Array = []
			for point in path["points"]:
				converted_points.append(_read_axial(point))
			path["points"] = converted_points
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
	var creatures: Array = []
	for source_creature in layout.get("creatures", []):
		if not source_creature is Dictionary:
			continue
		var creature: Dictionary = source_creature.duplicate(true)
		creature["position"] = _read_axial(creature.get("position", creature.get("hex", {})))
		creature.erase("hex")
		creatures.append(creature)
	var interiors: Array = []
	for source_interior in layout.get("interiors", []):
		if not source_interior is Dictionary:
			continue
		var interior: Dictionary = source_interior.duplicate(true)
		if interior.has("center"):
			interior["center"] = _read_axial(interior["center"])
		interiors.append(interior)
	var fields: Array = []
	for source_field in layout.get("fields", []):
		if not source_field is Dictionary:
			continue
		var field: Dictionary = _adapt_feature_coordinates(source_field)
		field["feature_type"] = String(field.get("feature_type", "field"))
		fields.append(field)
	for source_row in layout.get("crop_rows", []):
		if not source_row is Dictionary:
			continue
		var crop_row: Dictionary = _adapt_feature_coordinates(source_row)
		crop_row["feature_type"] = "crop_row"
		fields.append(crop_row)
	for source_fence in layout.get("fences", []):
		if not source_fence is Dictionary:
			continue
		var fence: Dictionary = _adapt_feature_coordinates(source_fence)
		fence["feature_type"] = "fence"
		fields.append(fence)
	var props: Array = []
	for source_prop in layout.get("props", []):
		if not source_prop is Dictionary:
			continue
		var prop: Dictionary = _adapt_feature_coordinates(source_prop)
		prop["feature_type"] = String(prop.get("feature_type", "quest_props"))
		props.append(prop)
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
	for creature in creatures:
		var point: Dictionary = creature.get("position", {})
		min_q = mini(min_q, int(point.get("q", 0)))
		max_q = maxi(max_q, int(point.get("q", 0)))
		min_r = mini(min_r, int(point.get("r", 0)))
		max_r = maxi(max_r, int(point.get("r", 0)))
	for path in paths:
		for endpoint_name in ["from", "to"]:
			if not path.has(endpoint_name):
				continue
			var point: Dictionary = path[endpoint_name]
			min_q = mini(min_q, int(point.get("q", 0)))
			max_q = maxi(max_q, int(point.get("q", 0)))
			min_r = mini(min_r, int(point.get("r", 0)))
			max_r = maxi(max_r, int(point.get("r", 0)))
		for point_value in path.get("points", []):
			var point: Dictionary = point_value
			min_q = mini(min_q, int(point.get("q", 0)))
			max_q = maxi(max_q, int(point.get("q", 0)))
			min_r = mini(min_r, int(point.get("r", 0)))
			max_r = maxi(max_r, int(point.get("r", 0)))
	for feature in fields:
		for position_key in ["anchor"]:
			if feature.has(position_key):
				var point: Vector2i = feature[position_key]
				min_q = mini(min_q, point.x)
				max_q = maxi(max_q, point.x)
				min_r = mini(min_r, point.y)
				max_r = maxi(max_r, point.y)
		for point_key in ["corners", "points"]:
			for point_value in feature.get(point_key, []):
				var point: Vector2i = point_value
				min_q = mini(min_q, point.x)
				max_q = maxi(max_q, point.x)
				min_r = mini(min_r, point.y)
				max_r = maxi(max_r, point.y)
	for prop in props:
		if prop.has("anchor"):
			var point: Vector2i = prop.anchor
			min_q = mini(min_q, point.x)
			max_q = maxi(max_q, point.x)
			min_r = mini(min_r, point.y)
			max_r = maxi(max_r, point.y)
	var canonical := {
		"schema_version": 1,
		"id": String(layout.get("id", "")),
		"name": String(layout.get("name", layout.get("id", ""))),
		"source": String(layout.get("source", layout.get("source_builder", "campaign2 settlement layout"))),
		"coordinate_system": "campaign2_local_axial_qr",
		"origin": {"q": 0, "r": 0},
		"bounds": {"min_q": min_q - 2, "max_q": max_q + 2, "min_r": min_r - 2, "max_r": max_r + 2},
		"terrain": {},
		"layout": {"buildings": buildings, "paths": paths, "bridges": [], "fields": fields, "props": props},
		# Only placement references survive this adapter. Identity, appearance,
		# class progression, equipment and dialogue remain character-owned.
		"placements": {"characters": characters, "creatures": creatures},
		"presentation": {"mode": "chunked", "hex_radius": HexGrid.DEFAULT_RADIUS_M, "ground": {}, "palette": layout.get("presentation", {}).get("palette", {}), "materials": layout.get("presentation", {}).get("materials", {}), "vegetation": {}},
		"interiors": interiors
	}
	return canonical

func _adapt_feature_coordinates(source: Dictionary) -> Dictionary:
	var feature: Dictionary = source.duplicate(true)
	for key in ["anchor", "center", "centre"]:
		if feature.has(key):
			feature[key] = _read_axial_vector(feature[key])
	for key in ["corners", "points"]:
		if feature.get(key) is Array:
			var points: Array = []
			for point in feature[key]:
				points.append(_read_axial_vector(point))
			feature[key] = points
	for part in feature.get("parts", []):
		if not part is Dictionary:
			continue
		if part.has("axial"):
			part["axial"] = _read_axial_vector(part["axial"])
		for vector_key in ["position", "size"]:
			if part.get(vector_key) is Dictionary:
				var vector_value: Dictionary = part[vector_key]
				part[vector_key] = Vector3(float(vector_value.get("x", 0.0)), float(vector_value.get("y", 0.0)), float(vector_value.get("z", 0.0)))
	return feature

func _read_axial_vector(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
	return Vector2i.ZERO

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
