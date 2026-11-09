extends SceneTree

func _initialize() -> void:
    _test_campaign2_road_manifest()
    print("Campaign 2 road manifest tests passed.")
    quit()

func _test_campaign2_road_manifest() -> void:
    var file := FileAccess.open("res://data/world/campaign2_road_paths.json", FileAccess.READ)
    assert(file != null, "Campaign 2 road-path manifest must exist")
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    assert(parsed is Dictionary, "Campaign 2 road-path manifest must be valid JSON")
    var manifest: Dictionary = parsed
    assert(manifest.get("schema_version") == 1)
    assert(manifest.get("coordinate_system") == "axial_qr")
    assert(manifest.get("crossroads") == {"q": 8, "r": 24})

    var roads: Dictionary = manifest.get("roads", {})
    for route_name in ["north", "south", "east", "east_border", "west"]:
        assert(roads.has(route_name), "Missing authored route: %s" % route_name)
        var route: Dictionary = roads[route_name]
        var cells: Array = route.get("cells", [])
        assert(cells.size() > int(route.get("length", 0)), "%s should include lateral wiggle cells" % route_name)
        var previous := Vector2i(8, 24)
        for raw_cell in cells:
            var cell := Vector2i(int(raw_cell["q"]), int(raw_cell["r"]))
            assert(HexGrid.distance(previous, cell) == 1, "%s contains a non-adjacent road step: %s -> %s" % [route_name, previous, cell])
            previous = cell
        var end: Dictionary = route.get("end", {})
        assert(previous == Vector2i(int(end.get("q", 999999)), int(end.get("r", 999999))), "%s endpoint must match its final cell" % route_name)

    var aliases: Dictionary = manifest.get("waypoint_aliases", {})
    _assert_hex(aliases, "abandoned_house", Vector2i(8, -176))
    _assert_hex(aliases, "millbrook", Vector2i(7, -366))
    _assert_hex(aliases, "silverhart", Vector2i(8, -496))
    _assert_hex(aliases, "old_mac_farmstead_road_end", Vector2i(6, 194))
    _assert_hex(aliases, "old_mac_farmhouse_center", Vector2i(0, 194))
    _assert_hex(aliases, "reddale", Vector2i(138, 24))
    _assert_hex(aliases, "skarn_tooth_camp", Vector2i(203, 23))
    _assert_hex(aliases, "northwatch_turn", Vector2i(268, 22))
    _assert_hex(aliases, "ridgehold_and_orc_stronghold", Vector2i(398, 23))
    _assert_hex(aliases, "emberlode_center", Vector2i(-256, 22))

func _assert_hex(source: Dictionary, key: String, expected: Vector2i) -> void:
    assert(source.has(key), "Missing source waypoint alias: %s" % key)
    var raw: Dictionary = source[key]
    var actual := Vector2i(int(raw["q"]), int(raw["r"]))
    assert(actual == expected, "%s should be %s, got %s" % [key, expected, actual])
