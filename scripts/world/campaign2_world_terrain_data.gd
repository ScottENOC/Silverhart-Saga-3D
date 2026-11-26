class_name Campaign2WorldTerrainData
extends RefCounted
## Deterministic local-hex terrain for the streamed Campaign 2 world.
## The strategic map owns biome/faction placement; local noise adds detail.
## Settlement terrain and layout occupancy are read from one canonical registry.

const MANIFEST_PATH := "res://data/world/campaign2_geography.json"
const ROAD_PATHS_PATH := "res://data/world/campaign2_road_paths.json"
const REGIONAL_HYDROLOGY = preload("res://data/world/regions/silverhart_heartland/hydrology.gd")
const REGIONAL_FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")
const LOCAL_TERRAIN_RULES = preload("res://data/world/terrain/campaign2_local_terrain.gd")
const WATER_SURFACE_ELEVATION := 0.0
const AUTHORED_SETTLEMENT_TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")
const SETTLEMENT_DEFINITION_REGISTRY = preload("res://scripts/world/campaign2_settlement_definition_registry.gd")

var strategic_grid: Array = []
var road_cells: Dictionary = {}
var locations_by_hex: Dictionary = {}
var locations: Array = []
var encounter_sites: Array[Dictionary] = []
var encounter_sites_by_id: Dictionary = {}
var encounter_sites_by_hex: Dictionary = {}
## Transitional property name retained for current builder callers. Values are
## canonical registry entries, never decoded legacy layout records.
var settlement_layouts: Array = []
var settlement_definition_registry: Campaign2SettlementDefinitionRegistry
var settlement_building_cells: Dictionary = {}
var settlement_path_cells: Dictionary = {}
var settlement_wall_cells: Dictionary = {}
var settlement_ladder_cells: Dictionary = {}
var river_points: Array[Vector3] = []

# Terrain queries are deterministic and heavily reused by mesh generation.
# Cache per-hex results so neighbouring vertices do not repeat full geography,
# settlement-registry and river-path resolution.
var _terrain_cache: Dictionary = {}
var _elevation_cache: Dictionary = {}
var _shared_vertex_cache: Dictionary = {}
var _tree_cache: Dictionary = {}

## The two neighbouring cell centres that share each flat-top hex vertex.
## This table is indexed by the corner offsets returned by HexGrid.corner_offsets().
const SHARED_VERTEX_NEIGHBOURS := [
	[Vector2i(1, 0), Vector2i(1, -1)],
	[Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(0, 1), Vector2i(-1, 1)],
	[Vector2i(-1, 1), Vector2i(-1, 0)],
	[Vector2i(-1, 0), Vector2i(0, -1)],
	[Vector2i(0, -1), Vector2i(1, -1)],
]

func _init() -> void:
	settlement_definition_registry = SETTLEMENT_DEFINITION_REGISTRY.new()
	for validation_error in settlement_definition_registry.validation_errors:
		push_error(String(validation_error))
	strategic_grid = MainCampaignWorldMapData.generate_grid()
	_load_roads()
	_load_locations()
	_load_settlement_layouts()
	_build_strategic_river()

func _load_roads() -> void:
	if not FileAccess.file_exists(ROAD_PATHS_PATH):
		push_warning("Campaign 2 road reference is missing.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROAD_PATHS_PATH))
	if not parsed is Dictionary:
		push_warning("Campaign 2 road reference could not be parsed.")
		return
	var roads: Dictionary = parsed.get("roads", {})
	for road_name in roads:
		var road: Dictionary = roads[road_name]
		for cell in road.get("cells", []):
			var hex := Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0)))
			road_cells[_hex_key(hex)] = true

func _load_locations() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("Campaign 2 geography manifest is missing.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_warning("Campaign 2 geography manifest could not be parsed.")
		return
	locations = parsed.get("locations", [])
	for location in locations:
		var hex := Vector2i(int(location.get("q", 8)), int(location.get("r", 24)))
		locations_by_hex[_hex_key(hex)] = location
	encounter_sites.clear()
	encounter_sites_by_id.clear()
	encounter_sites_by_hex.clear()
	# Encounter sites are a view over the canonical geography locations, not
	# a second authored list that can drift away from the world map.
	for location in locations:
		if not location is Dictionary:
			continue
		var kind := String(location.get("kind", ""))
		if kind not in ["wolf_den", "quest_site", "dungeon", "dragon_lair", "haunted_house", "grave", "roaming_encounter_area", "cave_network"]:
			continue
		var site_id := String(location.get("id", "")).strip_edges()
		if site_id.is_empty() or encounter_sites_by_id.has(site_id):
			push_warning("Campaign 2 encounter site has a missing or duplicate ID: %s" % site_id)
			continue
		var site_hex := Vector2i(int(location.get("q", 0)), int(location.get("r", 0)))
		var site_record: Dictionary = location.duplicate(true)
		encounter_sites.append(site_record)
		encounter_sites_by_id[site_id] = site_record
		encounter_sites_by_hex[_hex_key(site_hex)] = site_record

func encounter_site(site_id: String) -> Dictionary:
	return (encounter_sites_by_id.get(site_id, {}) as Dictionary).duplicate(true)

func encounter_site_at(hex: Vector2i) -> Dictionary:
	return (encounter_sites_by_hex.get(_hex_key(hex), {}) as Dictionary).duplicate(true)

func _load_settlement_layouts() -> void:
	settlement_layouts.clear()
	settlement_building_cells.clear()
	settlement_path_cells.clear()
	settlement_wall_cells.clear()
	settlement_ladder_cells.clear()
	if settlement_definition_registry == null:
		return
	settlement_layouts = settlement_definition_registry.get_definitions()
	for entry in settlement_layouts:
		var definition: Dictionary = entry.get("definition", {})
		var origin: Vector2i = entry.get("origin", Vector2i.ZERO)
		var layout: Dictionary = definition.get("layout", {})
		for building in layout.get("buildings", []):
			if not building is Dictionary or not bool(building.get("blocks_movement", true)):
				continue
			var centre := _read_axial(building.get("center", Vector2i.ZERO)) + origin
			var half_q := int(building.get("half_q", 0))
			var half_r := int(building.get("half_r", 0))
			for q in range(centre.x - half_q, centre.x + half_q + 1):
				for r in range(centre.y - half_r, centre.y + half_r + 1):
					settlement_building_cells[_hex_key(Vector2i(q, r))] = true
		for prop in layout.get("props", []):
			if not prop is Dictionary:
				continue
			var prop_id := String(prop.get("id", ""))
			var anchor := _read_axial(prop.get("anchor", Vector2i.ZERO)) + origin
			if prop_id.begins_with("silverhart_curtain_wall_") or prop_id.begins_with("silverhart_city_wall_"):
				settlement_wall_cells[_hex_key(anchor)] = true
			elif prop_id.begins_with("silverhart_wall_ladder_"):
				settlement_ladder_cells[_hex_key(anchor)] = true
		for path in layout.get("paths", []):
			if not path is Dictionary:
				continue
			if path.has("points") and path.get("points") is Array:
				var points: Array = path.get("points", [])
				for index in range(points.size() - 1):
					_rasterize_path_segment(_read_axial(points[index]) + origin, _read_axial(points[index + 1]) + origin)
			elif path.has("from") and path.has("to"):
				_rasterize_path_segment(
					_read_axial(path.get("from", Vector2i.ZERO)) + origin,
					_read_axial(path.get("to", Vector2i.ZERO)) + origin
				)

func _rasterize_path_segment(start: Vector2i, finish: Vector2i) -> void:
	# Interpolate in cube coordinates and correct the largest rounding error.
	# Rounding q/r independently can create skipped or non-adjacent cells on
	# diagonal roads, especially the long middle-ring house spurs.
	var x1 := start.x
	var z1 := start.y
	var y1 := -x1 - z1
	var x2 := finish.x
	var z2 := finish.y
	var y2 := -x2 - z2
	var steps := maxi(1, HexGrid.distance(start, finish))
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var x := lerpf(float(x1), float(x2), t)
		var y := lerpf(float(y1), float(y2), t)
		var z := lerpf(float(z1), float(z2), t)
		var rx := roundi(x)
		var ry := roundi(y)
		var rz := roundi(z)
		var dx := absf(float(rx) - x)
		var dy := absf(float(ry) - y)
		var dz := absf(float(rz) - z)
		if dx > dy and dx > dz:
			rx = -ry - rz
		elif dy > dz:
			ry = -rx - rz
		else:
			rz = -rx - ry
		settlement_path_cells[_hex_key(Vector2i(rx, rz))] = true

func _read_axial(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
	return Vector2i.ZERO

func _build_strategic_river() -> void:
	var origin_cell := MainCampaignWorldMapData.hollowmere_origin_cell()
	var origin_hex := MainCampaignWorldMapData.hollowmere_local_reference()
	var scale := MainCampaignWorldMapData.local_hexes_per_strategic_cell()
	for cell in MainCampaignWorldMapData.strategic_river_path():
		var local_q := origin_hex.x + (cell.x - origin_cell.x) * scale
		var local_r := origin_hex.y + (cell.y - origin_cell.y) * scale
		river_points.append(HexGrid.axial_to_world(Vector2i(local_q, local_r), HexGrid.DEFAULT_RADIUS_M))

func terrain_for_hex(hex: Vector2i) -> String:
	var key := _hex_key(hex)
	if _terrain_cache.has(key):
		return String(_terrain_cache[key])
	var result := _terrain_for_hex_uncached(hex)
	_terrain_cache[key] = result
	return result

func _terrain_for_hex_uncached(hex: Vector2i) -> String:
	# Regional authored sites take precedence over underlying settlement terrain.
	var regional_override := REGIONAL_FEATURES.terrain_override_at(hex)
	if not regional_override.is_empty():
		var feature_id := String(regional_override.get("feature_id", ""))
		if feature_id.ends_with("_clearing"):
			if settlement_building_cells.has(_hex_key(hex)):
				return "authored"
			if road_cells.has(_hex_key(hex)):
				return "path"
		return String(regional_override.get("terrain", "grass"))
	if settlement_wall_cells.has(_hex_key(hex)):
		return "palisade_wall"
	var authored_settlement := settlement_definition_registry.resolve(hex)
	var terrain_definition := _authored_terrain_definition(authored_settlement)
	var authored_terrain := ""
	if not terrain_definition.is_empty():
		authored_terrain = AUTHORED_SETTLEMENT_TERRAIN_PROVIDER.terrain_id_at(authored_settlement.local_hex, terrain_definition)
	# Explicit source roads can cross authored streams, but must not erase
	# authored settlement paths or building footprints. Stream water wins over
	# incidental path rasterisation; the bridge is excluded by the provider.
	if authored_terrain == "water" and not road_cells.has(_hex_key(hex)):
		return "water"
	if settlement_path_cells.has(_hex_key(hex)):
		return "path"
	if settlement_building_cells.has(_hex_key(hex)):
		return "authored"
	if road_cells.has(_hex_key(hex)):
		return "path"
	if not authored_terrain.is_empty():
		return authored_terrain
	if _is_local_stream(hex) or _is_strategic_river(hex):
		return "water"
	var strategic_cell := MainCampaignWorldMapData.world_cell_from_local_hex(hex)
	if not _inside_strategic_map(strategic_cell):
		return "void"
	var source_cell: Dictionary = strategic_grid[strategic_cell.y][strategic_cell.x]
	var base_terrain := String(source_cell.get("terrain", "grass"))
	var faction := String(source_cell.get("faction", ""))
	if base_terrain == "grass" and faction != "orcs":
		return LOCAL_TERRAIN_RULES.source_local_terrain(hex)
	return LOCAL_TERRAIN_RULES.terrain_for_hex(hex, base_terrain, faction)

## Gameplay terrain follows the same precedence as the visual terrain query.
func gameplay_terrain_for_hex(hex: Vector2i) -> String:
	var regional_override := REGIONAL_FEATURES.terrain_override_at(hex)
	if not regional_override.is_empty():
		var feature_id := String(regional_override.get("feature_id", ""))
		if feature_id.ends_with("_clearing"):
			if settlement_building_cells.has(_hex_key(hex)):
				return "building"
			if road_cells.has(_hex_key(hex)):
				return "path"
		return String(regional_override.get("terrain", "grass"))
	if settlement_wall_cells.has(_hex_key(hex)):
		return "palisade_wall"
	var authored_settlement := settlement_definition_registry.resolve(hex)
	var terrain_definition := _authored_terrain_definition(authored_settlement)
	var authored_terrain := ""
	if not terrain_definition.is_empty():
		authored_terrain = AUTHORED_SETTLEMENT_TERRAIN_PROVIDER.terrain_id_at(authored_settlement.local_hex, terrain_definition)
	if authored_terrain == "water" and not road_cells.has(_hex_key(hex)):
		return "water"
	if settlement_path_cells.has(_hex_key(hex)):
		return "path"
	if settlement_building_cells.has(_hex_key(hex)):
		return "building"
	if road_cells.has(_hex_key(hex)):
		return "path"
	if not authored_terrain.is_empty():
		return authored_terrain
	var terrain := terrain_for_hex(hex)
	return "building" if terrain == "authored" else terrain

func is_walkable_for_hex(hex: Vector2i) -> bool:
	var regional_override := REGIONAL_FEATURES.terrain_override_at(hex)
	if not regional_override.is_empty():
		var feature_id := String(regional_override.get("feature_id", ""))
		if feature_id.ends_with("_clearing"):
			if settlement_building_cells.has(_hex_key(hex)):
				return false
			if road_cells.has(_hex_key(hex)):
				return true
		var override_terrain := String(regional_override.get("terrain", "grass"))
		return override_terrain not in ["water", "building", "keep_wall", "climbable_wall"]
	# Strategic roads are explicit source-painted crossings, including roads
	# over streams. Settlement palisades remain climbable at their movement cost.
	if road_cells.has(_hex_key(hex)):
		return true
	var authored_settlement := settlement_definition_registry.resolve(hex)
	var terrain_definition := _authored_terrain_definition(authored_settlement)
	if not terrain_definition.is_empty():
		var authored_terrain := AUTHORED_SETTLEMENT_TERRAIN_PROVIDER.terrain_id_at(authored_settlement.local_hex, terrain_definition)
		if authored_terrain == "water":
			return false
		if settlement_path_cells.has(_hex_key(hex)):
			return true
		if settlement_building_cells.has(_hex_key(hex)):
			return false
		return not AUTHORED_SETTLEMENT_TERRAIN_PROVIDER.is_blocked(authored_settlement.local_hex, terrain_definition)
	if settlement_path_cells.has(_hex_key(hex)):
		return true
	if settlement_building_cells.has(_hex_key(hex)):
		return false
	var terrain := gameplay_terrain_for_hex(hex)
	return terrain != "water" and terrain != "building" and terrain != "keep_wall"


func movement_multiplier_for_hex(hex: Vector2i) -> float:
	var key := _hex_key(hex)
	if settlement_ladder_cells.has(key):
		return 2.0
	if settlement_wall_cells.has(key):
		return 15.0
	return -1.0

func elevation_for_hex(hex: Vector2i) -> float:
	var key := _hex_key(hex)
	if _elevation_cache.has(key):
		return float(_elevation_cache[key])
	var result := _elevation_for_hex_uncached(hex)
	_elevation_cache[key] = result
	return result

func _elevation_for_hex_uncached(hex: Vector2i) -> float:
	var authored_settlement := settlement_definition_registry.resolve(hex)
	var terrain_definition := _authored_terrain_definition(authored_settlement)
	if not terrain_definition.is_empty():
		return AUTHORED_SETTLEMENT_TERRAIN_PROVIDER.elevation_for_hex(authored_settlement.local_hex, terrain_definition)
	var terrain := terrain_for_hex(hex)
	if terrain == "path" and road_cells.has(_hex_key(hex)):
		return _road_surface_elevation(hex)
	return LOCAL_TERRAIN_RULES.elevation_for_hex(hex, terrain)


## Strategic roads are painted over the source terrain, not cut into a zero-height
## plane. Grade each road cell from its surrounding non-road land so routes follow
## the local hills while retaining a deterministic profile across streamed chunks.
## Settlement-authored paths keep their existing authored elevation.
func _road_surface_elevation(hex: Vector2i) -> float:
	var total := 0.0
	var samples := 0
	for direction in HexGrid.DIRECTIONS:
		var neighbour := hex + direction
		var neighbour_terrain := terrain_for_hex(neighbour)
		if neighbour_terrain in ["water", "path", "authored", "void"]:
			continue
		total += LOCAL_TERRAIN_RULES.elevation_for_hex(neighbour, neighbour_terrain)
		samples += 1
	if samples == 0:
		return 0.0
	return total / float(samples)

## Returns a deterministic height shared by all cells meeting at one vertex.
## Sampling the same three global cells makes independently streamed chunks
## produce identical boundary vertices, rather than exposing vertical seams.
func shared_vertex_elevation(hex: Vector2i, corner_index: int) -> float:
	var key := "%s:%d" % [_hex_key(hex), corner_index]
	if _shared_vertex_cache.has(key):
		return float(_shared_vertex_cache[key])
	var result := _shared_vertex_elevation_uncached(hex, corner_index)
	_shared_vertex_cache[key] = result
	return result

func _shared_vertex_elevation_uncached(hex: Vector2i, corner_index: int) -> float:
	if corner_index < 0 or corner_index >= SHARED_VERTEX_NEIGHBOURS.size():
		return elevation_for_hex(hex)
	var neighbours: Array = SHARED_VERTEX_NEIGHBOURS[corner_index]
	# A shoreline vertex belongs to three cells. If any of them is water,
	# keep the shared vertex at the water datum so the water surface stays flat
	# and the adjoining land mesh forms the bank without a crack.
	if terrain_for_hex(hex) == "water":
		return WATER_SURFACE_ELEVATION
	for offset in neighbours:
		if terrain_for_hex(hex + offset) == "water":
			return WATER_SURFACE_ELEVATION
	var total := elevation_for_hex(hex)
	for offset in neighbours:
		total += elevation_for_hex(hex + offset)
	return total / 3.0

func has_tree(hex: Vector2i) -> bool:
	var key := _hex_key(hex)
	if _tree_cache.has(key):
		return bool(_tree_cache[key])
	var result := _has_tree_uncached(hex)
	_tree_cache[key] = result
	return result

func _has_tree_uncached(hex: Vector2i) -> bool:
	var authored_settlement := settlement_definition_registry.resolve(hex)
	var terrain_definition := _authored_terrain_definition(authored_settlement)
	if not terrain_definition.is_empty():
		return AUTHORED_SETTLEMENT_TERRAIN_PROVIDER.has_tree(authored_settlement.local_hex, terrain_definition)
	return LOCAL_TERRAIN_RULES.has_tree(hex, terrain_for_hex(hex))

func _authored_terrain_definition(entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return {}
	var definition: Dictionary = entry.get("definition", {})
	var terrain: Variant = definition.get("terrain", {})
	return terrain if terrain is Dictionary else {}

func has_rock_outcrop(hex: Vector2i) -> bool:
	return LOCAL_TERRAIN_RULES.has_rock_outcrop(hex, terrain_for_hex(hex))

func location_at(hex: Vector2i) -> Dictionary:
	return (locations_by_hex.get(_hex_key(hex), {}) as Dictionary).duplicate(true)

func chunk_for_hex(hex: Vector2i, chunk_size: int = 24) -> Vector2i:
	return Vector2i(floori(float(hex.x) / float(chunk_size)), floori(float(hex.y) / float(chunk_size)))

func _is_local_stream(hex: Vector2i) -> bool:
	return REGIONAL_HYDROLOGY.is_stream_hex(hex)

func _is_strategic_river(hex: Vector2i) -> bool:
	if river_points.size() < 2:
		return false
	var point := HexGrid.axial_to_world(hex, HexGrid.DEFAULT_RADIUS_M)
	for index in range(river_points.size() - 1):
		if _distance_to_segment(point, river_points[index], river_points[index + 1]) <= 3.4:
			return true
	return false

func _distance_to_segment(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var segment := finish - start
	var denominator := segment.length_squared()
	if denominator <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / denominator, 0.0, 1.0)
	return point.distance_to(start + segment * t)

func _inside_strategic_map(cell: Vector2i) -> bool:
	var dimensions := MainCampaignWorldMapData.strategic_grid_size()
	return cell.x >= 0 and cell.x < dimensions.x and cell.y >= 0 and cell.y < dimensions.y

static func _hex_key(hex: Vector2i) -> String:
	return "%d,%d" % [hex.x, hex.y]


## Only public destinations receive map-style POI markers. Quest and exploration
## sites remain discoverable through the world itself rather than being given
## away by permanent floating labels.
func is_location_marker_visible(location: Dictionary) -> bool:
	var visibility := String(location.get("visibility", "")).strip_edges()
	return visibility in ["settlement", "outpost", "fort", "stronghold", "capital", "local"]
