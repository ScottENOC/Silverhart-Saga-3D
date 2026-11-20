class_name Campaign2WorldTerrainData
extends RefCounted
## Deterministic local-hex terrain for the streamed Campaign 2 world.
## The strategic map owns biome/faction placement; local noise adds detail.
## The authored Hollowmere scene remains authoritative inside its radius.

const MANIFEST_PATH := "res://data/world/campaign2_geography.json"
const ROAD_PATHS_PATH := "res://data/world/campaign2_road_paths.json"
const SETTLEMENT_LAYOUTS_PATH := "res://data/world/campaign2_settlement_layouts.json"
const REGIONAL_HYDROLOGY = preload("res://data/world/regions/silverhart_heartland/hydrology.gd")
const LOCAL_TERRAIN_RULES = preload("res://data/world/terrain/campaign2_local_terrain.gd")
const AUTHORED_VILLAGE_RADIUS := 96

var strategic_grid: Array = []
var road_cells: Dictionary = {}
var locations_by_hex: Dictionary = {}
var locations: Array = []
var settlement_layouts: Array = []
var settlement_building_cells: Dictionary = {}
var settlement_path_cells: Dictionary = {}
var river_points: Array[Vector3] = []

func _init() -> void:
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

func _load_settlement_layouts() -> void:
	if not FileAccess.file_exists(SETTLEMENT_LAYOUTS_PATH):
		push_warning("Campaign 2 settlement layouts are missing.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTLEMENT_LAYOUTS_PATH))
	if not parsed is Dictionary:
		push_warning("Campaign 2 settlement layouts could not be parsed.")
		return
	settlement_layouts = parsed.get("settlements", [])
	for settlement in settlement_layouts:
		for building in settlement.get("buildings", []):
			var centre := Vector2i(int(building.get("center", {}).get("q", 0)), int(building.get("center", {}).get("r", 0)))
			var half_q := int(building.get("half_q", 0))
			var half_r := int(building.get("half_r", 0))
			for q in range(centre.x - half_q, centre.x + half_q + 1):
				for r in range(centre.y - half_r, centre.y + half_r + 1):
					settlement_building_cells[_hex_key(Vector2i(q, r))] = true
		for path in settlement.get("paths", []):
			var start := Vector2i(int(path.get("from", {}).get("q", 0)), int(path.get("from", {}).get("r", 0)))
			var finish := Vector2i(int(path.get("to", {}).get("q", 0)), int(path.get("to", {}).get("r", 0)))
			var steps := maxi(1, HexGrid.distance(start, finish))
			for step in range(steps + 1):
				var t := float(step) / float(steps)
				var cell := Vector2i(roundi(lerpf(float(start.x), float(finish.x), t)), roundi(lerpf(float(start.y), float(finish.y), t)))
				settlement_path_cells[_hex_key(cell)] = true

func _build_strategic_river() -> void:
	var origin_cell := MainCampaignWorldMapData.hollowmere_origin_cell()
	var origin_hex := MainCampaignWorldMapData.hollowmere_local_reference()
	var scale := MainCampaignWorldMapData.local_hexes_per_strategic_cell()
	for cell in MainCampaignWorldMapData.strategic_river_path():
		var local_q := origin_hex.x + (cell.x - origin_cell.x) * scale
		var local_r := origin_hex.y + (cell.y - origin_cell.y) * scale
		river_points.append(HexGrid.axial_to_world(Vector2i(local_q, local_r), HexGrid.DEFAULT_RADIUS_M))

func terrain_for_hex(hex: Vector2i) -> String:
	if HexGrid.distance(Vector2i.ZERO, hex) <= AUTHORED_VILLAGE_RADIUS:
		return "authored"
	if settlement_building_cells.has(_hex_key(hex)):
		return "authored"
	if settlement_path_cells.has(_hex_key(hex)):
		return "path"
	if _is_local_stream(hex) or _is_strategic_river(hex):
		return "water"
	if road_cells.has(_hex_key(hex)):
		return "path"
	var strategic_cell := MainCampaignWorldMapData.world_cell_from_local_hex(hex)
	if not _inside_strategic_map(strategic_cell):
		return "void"
	var source_cell: Dictionary = strategic_grid[strategic_cell.y][strategic_cell.x]
	var base_terrain := String(source_cell.get("terrain", "grass"))
	var faction := String(source_cell.get("faction", ""))
	return LOCAL_TERRAIN_RULES.terrain_for_hex(hex, base_terrain, faction)

func elevation_for_hex(hex: Vector2i) -> float:
	return LOCAL_TERRAIN_RULES.elevation_for_hex(hex, terrain_for_hex(hex))

func has_tree(hex: Vector2i) -> bool:
	return LOCAL_TERRAIN_RULES.has_tree(hex, terrain_for_hex(hex))

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
