class_name Campaign2WorldTerrainData
extends RefCounted
## Deterministic local-hex terrain for the streamed Campaign 2 world.
## The strategic map owns biome/faction placement; local noise adds detail.
## The authored Hollowmere scene remains authoritative inside its radius.

const MANIFEST_PATH := "res://data/world/campaign2_geography.json"
const ROAD_PATHS_PATH := "res://data/world/campaign2_road_paths.json"
const SEED := 2047
const LOCAL_STREAM_BRIDGE := Vector2i(8, -25)
const LOCAL_STREAM_Q_MIN := -90
const LOCAL_STREAM_Q_MAX := 220
const AUTHORED_VILLAGE_RADIUS := 96

var strategic_grid: Array = []
var road_cells: Dictionary = {}
var locations_by_hex: Dictionary = {}
var locations: Array = []
var river_points: Array[Vector3] = []

func _init() -> void:
	strategic_grid = MainCampaignWorldMapData.generate_grid()
	_load_roads()
	_load_locations()
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

func _build_strategic_river() -> void:
	for cell in MainCampaignWorldMapData.RIVER_PATH:
		var local_q := 8 + (cell.x - 6) * MainCampaignWorldMapData.WORLD_HEX_SIZE
		var local_r := 24 + (cell.y - 6) * MainCampaignWorldMapData.WORLD_HEX_SIZE
		river_points.append(HexGrid.axial_to_world(Vector2i(local_q, local_r), HexGrid.DEFAULT_RADIUS_M))

func terrain_for_hex(hex: Vector2i) -> String:
	if HexGrid.distance(Vector2i.ZERO, hex) <= AUTHORED_VILLAGE_RADIUS:
		return "authored"
	if hex == LOCAL_STREAM_BRIDGE:
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
	var roll := _stable_roll(hex, SEED)
	match base_terrain:
		"ocean":
			return "water"
		"mountain":
			return "mountain"
		"forest":
			return "forest"
		"hills":
			return "hills"
		_:
			if faction == "orcs":
				return "badlands" if roll < 0.30 else ("hills" if roll < 0.58 else "grass")
			if roll < 0.11:
				return "forest"
			if roll < 0.22:
				return "hills"
			return "grass"

func elevation_for_hex(hex: Vector2i) -> float:
	var terrain := terrain_for_hex(hex)
	if terrain in ["water", "path", "authored", "void"]:
		return 0.0
	var broad_hex := Vector2i(floori(float(hex.x) / 7.0), floori(float(hex.y) / 7.0))
	var broad := _stable_roll(broad_hex, SEED + 71)
	var detail := _stable_roll(hex, SEED + 193)
	match terrain:
		"mountain":
			return 2.8 + broad * 3.8 + detail * 0.5
		"hills":
			return 0.45 + broad * 1.1 + detail * 0.25
		"badlands":
			return 0.25 + broad * 0.7
		"forest":
			return broad * 0.28
		_:
			return broad * 0.18

func has_tree(hex: Vector2i) -> bool:
	return terrain_for_hex(hex) == "forest" and _stable_roll(hex, SEED + 317) < 0.34

func has_rock_outcrop(hex: Vector2i) -> bool:
	var terrain := terrain_for_hex(hex)
	return terrain in ["hills", "badlands"] and _stable_roll(hex, SEED + 431) < 0.18

func location_at(hex: Vector2i) -> Dictionary:
	return (locations_by_hex.get(_hex_key(hex), {}) as Dictionary).duplicate(true)

func chunk_for_hex(hex: Vector2i, chunk_size: int = 24) -> Vector2i:
	return Vector2i(floori(float(hex.x) / float(chunk_size)), floori(float(hex.y) / float(chunk_size)))

func _is_local_stream(hex: Vector2i) -> bool:
	if hex.x < LOCAL_STREAM_Q_MIN or hex.x > LOCAL_STREAM_Q_MAX:
		return false
	var q := float(hex.x)
	var centre_r := -25.0 + sin(q * 0.045) * 1.8 + sin(q * 0.11) * 0.7
	return absf(float(hex.y) - centre_r) <= 1.5

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
	return cell.x >= 0 and cell.x < MainCampaignWorldMapData.WORLD_SIZE and cell.y >= 0 and cell.y < MainCampaignWorldMapData.WORLD_SIZE

static func _stable_roll(hex: Vector2i, seed_value: int) -> float:
	var value := posmod(hex.x * 92837111 + hex.y * 689287499 + seed_value * 104729 + 1013904223, 2147483647)
	return float(value) / 2147483647.0

static func _hex_key(hex: Vector2i) -> String:
	return "%d,%d" % [hex.x, hex.y]
