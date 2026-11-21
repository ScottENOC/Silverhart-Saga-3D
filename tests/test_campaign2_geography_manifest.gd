extends SceneTree

const MANIFEST_PATH := "res://data/world/campaign2_geography.json"
const MAP_DATA = preload("res://scripts/world/main_campaign_world_map_data.gd")

var _diagnostic_started_at := 0

func _checkpoint(label: String) -> void:
	var elapsed := Time.get_ticks_msec() - _diagnostic_started_at
	print("[GEOGRAPHY-DIAG +%dms] %s" % [elapsed, label])

func _initialize() -> void:
	_diagnostic_started_at = Time.get_ticks_msec()
	_checkpoint("test process entered _initialize")
	_checkpoint("reading and parsing geography JSON")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_checkpoint("JSON parsed; validating campaign and coordinate metadata")
	assert(parsed is Dictionary, "Campaign 2 geography manifest must parse as an object")
	assert(int(parsed.get("campaign_id", 0)) == 2, "Manifest must target Campaign 2")
	var coordinates: Dictionary = parsed.get("coordinate_system", {})
	assert(int(coordinates.get("local_hexes_per_strategic_cell", 0)) == 130)
	var dimensions: Dictionary = coordinates.get("strategic_grid_dimensions", {})
	_checkpoint("grid dimensions decoded: columns=%s rows=%s" % [
		str(dimensions.get("columns", "<missing>")),
		str(dimensions.get("rows", "<missing>"))
	])
	assert(int(dimensions.get("columns", 0)) == 16 and int(dimensions.get("rows", 0)) == 16,
		"Strategic grid dimensions must be authored as 16 columns by 16 rows")
	assert(coordinates.get("origin", {}).get("local_q", -1) == 8)
	assert(coordinates.get("origin", {}).get("local_r", -1) == 24)

	_checkpoint("coordinate metadata passed; beginning 24-location validation")
	var locations: Array = parsed.get("locations", [])
	assert(locations.size() == 24, "The current first-pass geography inventory should contain 24 destinations")
	var ids: Dictionary = {}
	var location_by_id: Dictionary = {}
	for location in locations:
		_checkpoint("validating location: " + String(location.get("id", "<missing-id>")))
		assert(location is Dictionary, "Every location must be an object")
		var id := String(location.get("id", ""))
		assert(not id.is_empty(), "Every location needs a stable id")
		assert(not String(location.get("name", "")).is_empty(), "Every location needs a display name: " + id)
		assert(not String(location.get("region", "")).is_empty(), "Every location needs a region: " + id)
		assert(not ids.has(id), "Location ids must be unique: " + id)
		ids[id] = true
		location_by_id[id] = location
		assert(location.has("q") and location.has("r"), "Every location needs source local axial coordinates: " + id)
		var cell := MAP_DATA.world_cell_from_local_hex(Vector2i(int(location["q"]), int(location["r"])))
		assert(cell.x >= -0.5 and cell.x <= 15.5, "Location falls outside strategic map horizontally: " + id)
		assert(cell.y >= -0.5 and cell.y <= 15.5, "Location falls outside strategic map vertically: " + id)

	_checkpoint("all location records passed; checking required destination inventory")
	for required_id in [
		"hollowmere", "millbrook", "silverhart", "emberlode", "reddale",
		"old_mac_farmstead", "hollowmere_guild_den", "abandoned_house",
		"skarn_tooth_camp", "northwatch_fort",
		"ridgehold_fort", "skarnaks_hold", "kragmoor", "silthandriel",
		"vessel_seekers_crypt", "corvin_ashgrave_barrow", "ashveil_lair",
		"lich_chapterhouse", "emberwood_grove", "vampire_grave", "thieves_cove",
		"emberlode_mine", "farm_wolf_den", "unicorn_vale"
	]:
		assert(ids.has(required_id), "Missing required campaign destination: " + required_id)

	assert(int(location_by_id["millbrook"]["q"]) == 1, "Millbrook anchor must use the offset village centre")
	assert(int(location_by_id["ashveil_lair"]["q"]) == 101, "Dragon lair must be placed 100 q east of Millbrook centre")
	assert(int(location_by_id["lich_chapterhouse"]["q"]) == -39, "Chapterhouse must be offset west of Millbrook centre")

	_checkpoint("required destinations passed; validating 22 connections")
	var connections: Array = parsed.get("connections", [])
	assert(connections.size() == 22, "The current first-pass travel graph should contain 22 connections")
	for connection in connections:
		assert(ids.has(String(connection.get("from", ""))), "Connection has unknown origin")
		assert(ids.has(String(connection.get("to", ""))), "Connection has unknown destination")

	var river: Array = parsed.get("geography", {}).get("river_path", [])
	assert(river.size() == 15, "Campaign 2 strategic river should retain its 15 source cells")
	assert(MAP_DATA.strategic_river_path().size() == 15, "Runtime river must be derived from the manifest")
	assert(MAP_DATA.strategic_grid_size() == Vector2i(16, 16))
	assert(MAP_DATA.hollowmere_origin_cell() == Vector2i(6, 6))
	assert(MAP_DATA.hollowmere_local_reference() == Vector2i(8, 24))
	assert(MAP_DATA.world_cell_from_local_hex(Vector2i(8, 24)) == Vector2i(6, 6))
	assert(MAP_DATA.world_cell_from_local_hex(Vector2i(8, -496)) == Vector2i(6, 2))
	assert(MAP_DATA.world_cell_from_local_hex(Vector2i(1, -366)) == Vector2i(6, 3))
	assert(MAP_DATA.world_cell_from_local_hex(Vector2i(-256, 22)) == Vector2i(4, 6))

	_checkpoint("river and coordinate adapter passed; resolving strategic markers")
	var markers: Array = MAP_DATA.strategic_locations()
	assert(markers.size() == 6, "Strategic marker selection must be manifest-authored")
	_checkpoint("marker validation passed; entering MAP_DATA.generate_grid()")
	var grid: Array = MAP_DATA.generate_grid()
	_checkpoint("generate_grid() returned; checking generated 16x16 cells")
	assert(grid.size() == 16 and grid[0].size() == 16, "Strategic grid dimensions must come from the manifest")
	assert(grid[0][0]["terrain"] == "ocean")
	assert(grid[13][2]["terrain"] == "forest" and grid[13][2]["faction"] == "elves")
	assert(grid[0][10]["faction"] == "dwarves", "North-east faction border override must be retained")
	assert(grid[4][12]["faction"] == "orcs", "South edge of the dwarf/orc border must be retained")
	assert(grid[6][6]["poi"].get("id", "") == "hollowmere")

	_checkpoint("all assertions passed")
	print("Campaign 2 geography manifest: %d locations, %d connections, %d river cells — OK" % [locations.size(), connections.size(), river.size()])
	quit(0)
