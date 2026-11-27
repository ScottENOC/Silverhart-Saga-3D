class_name MainCampaignWorldMapData
extends RefCounted
## Runtime adapter for the authoritative Campaign 2 geography manifest.
## The strategic grid is a coarse index into the continuous axial world.

const MANIFEST_PATH := "res://data/world/campaign2_geography.json"
static var _manifest_cache: Dictionary = {}

static func _manifest_data() -> Dictionary:
	if _manifest_cache.is_empty():
		if not FileAccess.file_exists(MANIFEST_PATH):
			push_error("Campaign 2 geography manifest is missing: " + MANIFEST_PATH)
			return {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if not parsed is Dictionary:
			push_error("Campaign 2 geography manifest could not be parsed.")
			return {}
		_manifest_cache = parsed
	return _manifest_cache

static func _coordinate_data() -> Dictionary:
	return _manifest_data().get("coordinate_system", {})

static func _geography_data() -> Dictionary:
	return _manifest_data().get("geography", {})

static func strategic_grid_size() -> Vector2i:
	var dimensions: Dictionary = _coordinate_data().get("strategic_grid_dimensions", {})
	return Vector2i(int(dimensions.get("columns", 0)), int(dimensions.get("rows", 0)))

static func local_hexes_per_strategic_cell() -> int:
	return int(_coordinate_data().get("local_hexes_per_strategic_cell", 0))

static func hollowmere_origin_cell() -> Vector2i:
	var origin: Dictionary = _coordinate_data().get("origin", {})
	return Vector2i(int(origin.get("column", 0)), int(origin.get("row", 0)))

static func hollowmere_local_reference() -> Vector2i:
	var origin: Dictionary = _coordinate_data().get("origin", {})
	return Vector2i(int(origin.get("local_q", 0)), int(origin.get("local_r", 0)))

static func world_cell_from_local_hex(local_hex: Vector2i) -> Vector2i:
	# Return Vector2i(column, row), matching the original odd-q strategic map.
	var origin_cell := hollowmere_origin_cell()
	var origin_hex := hollowmere_local_reference()
	var scale := local_hexes_per_strategic_cell()
	if scale <= 0:
		return Vector2i(-1, -1)
	var column := origin_cell.x + roundi(float(local_hex.x - origin_hex.x) / float(scale))
	var row := origin_cell.y + roundi(float(local_hex.y - origin_hex.y) / float(scale))
	return Vector2i(column, row)

static func strategic_river_path() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var path: Array = _geography_data().get("river_path", [])
	for pair in path:
		if pair is Array and pair.size() == 2:
			result.append(Vector2i(int(pair[0]), int(pair[1])))
	return result

static func strategic_locations() -> Array[Dictionary]:
	var locations_by_id: Dictionary = {}
	for location in _manifest_data().get("locations", []):
		locations_by_id[String(location.get("id", ""))] = location
	var result: Array[Dictionary] = []
	var occupied_cells: Dictionary = {}
	var dimensions := strategic_grid_size()
	for marker in _manifest_data().get("strategic_markers", []):
		var id := String(marker.get("id", ""))
		if not locations_by_id.has(id):
			continue
		var location: Dictionary = locations_by_id[id].duplicate(true)
		location["short"] = String(marker.get("short", ""))
		location["source_marker_name"] = String(marker.get("source_name", location.get("name", id)))
		var desired := world_cell_from_local_hex(Vector2i(int(location.get("q", 0)), int(location.get("r", 0))))
		# Mirror Hex-crpg's setWorldMapMarker collision policy: retain the
		# source cell where possible, otherwise try east, south, west, then north.
		var candidates: Array[Vector2i] = [
			desired,
			Vector2i(desired.x + 1, desired.y),
			Vector2i(desired.x, desired.y + 1),
			Vector2i(desired.x - 1, desired.y),
			Vector2i(desired.x, desired.y - 1)
		]
		var placed := desired
		for candidate in candidates:
			if candidate.x < 0 or candidate.x >= dimensions.x or candidate.y < 0 or candidate.y >= dimensions.y:
				continue
			if occupied_cells.has(candidate):
				continue
			placed = candidate
			break
		location["cell"] = placed
		occupied_cells[placed] = id
		result.append(location)
	return result

static func generate_grid() -> Array:
	var geography := _geography_data()
	var dimensions := strategic_grid_size()
	var grid: Array = []
	var ocean_columns: Array = geography.get("ocean_columns", [])
	var human_lands: Dictionary = geography.get("human_lands", {})
	var orc_lands: Dictionary = geography.get("orc_lands", {})
	var mountain_range: Dictionary = geography.get("dwarven_mountains", {})
	var forest_range: Dictionary = geography.get("elven_forest", {})
	var terrain_variation: Dictionary = geography.get("terrain_variation", {})
	var hash_config: Dictionary = terrain_variation.get("strategic_hash", {})
	var faction_overrides: Array = geography.get("faction_overrides", [])

	for row in range(dimensions.y):
		var cells: Array = []
		for column in range(dimensions.x):
			# JSON numeric values may be decoded as floats; compare the authored
			# column indices numerically rather than relying on Variant type equality.
			var is_ocean := false
			for ocean_column in ocean_columns:
				if int(ocean_column) == column:
					is_ocean = true
					break
			var is_orc_lands := _inside_range(column, row, orc_lands)
			var is_mountain_range := _inside_range(column, row, mountain_range)
			var is_forest := not is_ocean and _inside_range(column, row, forest_range)
			var rough := _pseudo_random(
				float(column) * float(hash_config.get("x_scale", 2.3)) + float(hash_config.get("x_offset", 5.0)),
				float(row) * float(hash_config.get("y_scale", 1.7)) + float(hash_config.get("y_offset", 3.0))
			)

			var terrain := "grass"
			if is_ocean:
				terrain = "ocean"
			elif is_mountain_range:
				terrain = "mountain"
			elif is_forest:
				terrain = "forest"
			elif is_orc_lands and rough > float(terrain_variation.get("orc_mountain_threshold", 0.8)):
				terrain = "mountain"
			elif is_orc_lands and rough > float(terrain_variation.get("orc_hills_threshold", 0.6)):
				terrain = "hills"

			var faction := ""
			if not is_ocean:
				if is_mountain_range:
					faction = "dwarves"
				elif is_forest:
					faction = "elves"
				elif is_orc_lands:
					faction = "orcs"
				elif _inside_range(column, row, human_lands):
					faction = "humans"

			for override in faction_overrides:
				if _inside_range(column, row, override):
					faction = String(override.get("faction", faction))

			cells.append({
				"terrain": terrain,
				"faction": faction,
				"poi": {}
			})
		grid.append(cells)

	for location in strategic_locations():
		var cell: Vector2i = location["cell"]
		if cell.x >= 0 and cell.x < dimensions.x and cell.y >= 0 and cell.y < dimensions.y:
			grid[cell.y][cell.x]["poi"] = location.duplicate(true)
	return grid

## Display names for every source-authored strategic marker, kept in the same
## order as the marker collision-resolution pass. The UI must not maintain a
## second hand-written list that can drift from the geography manifest.
static func strategic_location_legend() -> String:
	var names := PackedStringArray()
	for location in strategic_locations():
		var location_name := String(location.get("name", "")).strip_edges()
		if not location_name.is_empty():
			names.append(location_name)
	if names.is_empty():
		return "No strategic locations recorded"
	var rows := PackedStringArray()
	for start in range(0, names.size(), 3):
		var row := PackedStringArray()
		for index in range(start, mini(start + 3, names.size())):
			row.append(names[index])
		rows.append(row.join("   •   "))
	return "\n".join(rows)

static func location_at(cell: Vector2i) -> Dictionary:
	for location in strategic_locations():
		if location["cell"] == cell:
			return location.duplicate(true)
	return {}

static func _inside_range(column: int, row: int, definition: Dictionary) -> bool:
	var columns: Array = definition.get("columns", [])
	var rows: Array = definition.get("rows", [])
	return columns.size() >= 2 and rows.size() >= 2 \
		and column >= int(columns[0]) and column <= int(columns[1]) \
		and row >= int(rows[0]) and row <= int(rows[1])

static func _pseudo_random(x: float, y: float) -> float:
	# Same deterministic hash used by the original browser game.
	var value := sin(x * 12.9898 + y * 78.233) * 43758.5453
	return value - floorf(value)
