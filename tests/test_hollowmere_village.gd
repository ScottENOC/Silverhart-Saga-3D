extends SceneTree

const MAIN_CAMPAIGN_MAP = preload("res://scripts/world/main_campaign_world_map_data.gd")

func _initialize() -> void:
    _test_village_bounds_and_terrain()
    _test_road_network_connectivity()
    _test_building_thresholds()
    _test_hollowmere_character_manifest()
    print("Hollowmere village tests passed.")
    quit()

func _test_village_bounds_and_terrain() -> void:
    assert(HollowmereVillageData.is_in_bounds(Vector2i(12, 26)), "Rowan's crossroads area must be inside the playable map")
    assert(not HollowmereVillageData.is_in_bounds(Vector2i(40, 40)), "The outer map boundary must reject distant cells")
    assert(HollowmereVillageData.is_water(Vector2i(0, HollowmereVillageData.STREAM_R)), "The stream should be water")
    assert(HollowmereVillageData.is_blocked(Vector2i(0, HollowmereVillageData.STREAM_R)), "The stream must block movement")
    assert(not HollowmereVillageData.is_water(HollowmereVillageData.BRIDGE), "The bridge must replace the water tile")
    assert(not HollowmereVillageData.is_blocked(HollowmereVillageData.BRIDGE), "The bridge must be traversable")
    assert(HollowmereVillageData.terrain_id_at(Vector2i(0, 15)) == "path", "The general-store threshold should be a path")

func _test_road_network_connectivity() -> void:
    var path_cells := HollowmereVillageData.path_cells()
    var path_set: Dictionary = {}
    for cell in path_cells:
        path_set[cell] = true
    assert(path_set.has(HollowmereVillageData.CROSSROADS), "The signposted crossroads must be on the road network")
    assert(path_set.has(HollowmereVillageData.BRIDGE), "The north road must include the bridge")
    for road_end in [Vector2i(8, -40), Vector2i(8, 32), Vector2i(-40, 24), Vector2i(16, 24)]:
        assert(path_set.has(road_end), "Each of the four crossroads roads must reach its map edge")

    var start := Vector2i(0, 6)
    var visited: Dictionary = {start: true}
    var queue: Array[Vector2i] = [start]
    var cursor := 0
    while cursor < queue.size():
        var current := queue[cursor]
        cursor += 1
        for neighbour in HexGrid.neighbors(current):
            if path_set.has(neighbour) and not visited.has(neighbour):
                visited[neighbour] = true
                queue.append(neighbour)

    for destination in [
        HollowmereVillageData.CROSSROADS,
        HollowmereVillageData.BRIDGE,
        Vector2i(8, -40),
        Vector2i(8, 32),
        Vector2i(-40, 24),
        Vector2i(16, 24),
        Vector2i(0, 15),
        Vector2i(-11, 0),
        Vector2i(0, -10),
        Vector2i(10, 9),
        Vector2i(-4, 9)
    ]:
        assert(visited.has(destination), "Village road does not connect to %s" % destination)

func _test_building_thresholds() -> void:
    assert(HollowmereVillageData.is_blocked(Vector2i(0, 18)), "General-store footprint should block movement")
    assert(HollowmereVillageData.is_blocked(Vector2i(-14, 0)), "Chapel footprint should block movement")
    assert(HollowmereVillageData.is_blocked(Vector2i(0, -12)), "Elder-house footprint should block movement")
    for door in [Vector2i(0, 15), Vector2i(-11, 0), Vector2i(0, -10), Vector2i(10, 9), Vector2i(-4, 9)]:
        assert(not HollowmereVillageData.is_blocked(door), "Building entrance should remain traversable: %s" % door)

func _test_hollowmere_character_manifest() -> void:
    var file := FileAccess.open("res://data/characters/hollowmere_npcs.json", FileAccess.READ)
    assert(file != null, "Hollowmere Ara profile manifest must exist")
    var manifest: Variant = JSON.parse_string(file.get_as_text())
    assert(manifest is Dictionary, "Hollowmere character manifest must be valid JSON")
    var characters: Array = manifest.get("characters", [])
    assert(characters.size() == 13, "Expected 13 authored village character profiles")
    var ids: Dictionary = {}
    for profile in characters:
        assert(profile.has("id") and profile.has("game_id") and profile.has("params"))
        assert(not ids.has(profile["id"]), "Character profile IDs must be unique")
        ids[profile["id"]] = true
        var params: Dictionary = profile["params"]
        for slider in ["gender", "age", "muscle", "weight", "height", "proportions"]:
            assert(params.has(slider), "%s is missing Ara slider %s" % [profile["id"], slider])
            assert(float(params[slider]) >= 0.0 and float(params[slider]) <= 1.0)
        var coordinates: Array = profile["hex"]
        var spawn := Vector2i(int(coordinates[0]), int(coordinates[1]))
        assert(HollowmereVillageData.is_in_bounds(spawn), "%s spawn is outside Hollowmere" % profile["id"])
        assert(not HollowmereVillageData.is_blocked(spawn), "%s spawn is not traversable" % profile["id"])

func _test_main_campaign_world_map() -> void:
    var grid := MAIN_CAMPAIGN_MAP.generate_grid()
    assert(grid.size() == 16, "The original Campaign 2 strategic map must have 16 rows")
    for row in grid:
        assert(row.size() == 16, "Every strategic map row must have 16 cells")

    assert(grid[0][0]["terrain"] == "ocean", "The western edge should be ocean")
    assert(grid[6][6]["faction"] == "humans", "Hollowmere should be in human lands")
    assert(grid[15][5]["faction"] == "elves", "The southern forest belt should be elven territory")
    assert(grid[1][14]["faction"] == "dwarves", "The north-east mountain block should be dwarven")
    assert(grid[10][12]["faction"] == "orcs", "The eastern territory should be orc-held")

    assert(grid[6][6]["poi"]["name"] == "Hollowmere", "Hollowmere must be the starting-village marker")
    assert(grid[3][6]["poi"]["name"] == "Millbrook", "Millbrook should lie north of Hollowmere")
    assert(grid[2][6]["poi"]["name"] == "Silverhart", "Silverhart should lie beyond Millbrook")
    assert(grid[6][7]["poi"]["name"] == "Reddale", "Reddale should lie east of Hollowmere")
    assert(grid[6][4]["poi"]["name"] == "Emberlode", "Emberlode should lie west of Hollowmere")
    assert(grid[7][6]["poi"]["name"] == "Old Mac's Farmstead", "The farmstead should lie south of Hollowmere")

    assert(MAIN_CAMPAIGN_MAP.RIVER_PATH.size() == 15, "The source river path should contain 15 strategic cells")
    assert(MAIN_CAMPAIGN_MAP.RIVER_PATH[0] == Vector2i(1, 5))
    assert(MAIN_CAMPAIGN_MAP.RIVER_PATH[14] == Vector2i(15, 4))
    assert(MAIN_CAMPAIGN_MAP.world_cell_from_local_hex(Vector2i(8, 24)) == Vector2i(6, 6), "The local crossroads must map to Hollowmere's world cell")
