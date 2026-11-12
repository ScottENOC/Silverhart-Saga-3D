extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_test_campaign2_road_manifest()
	if failures > 0:
		push_error("%d Campaign 2 road manifest test(s) failed." % failures)
		quit(1)
		return
	print("Campaign 2 road manifest tests passed.")
	quit(0)

func _test_campaign2_road_manifest() -> void:
	var file := FileAccess.open("res://data/world/campaign2_road_paths.json", FileAccess.READ)
	_check(file != null, "Campaign 2 road-path manifest must exist")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary, "Campaign 2 road-path manifest must be valid JSON")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	_check(manifest.get("schema_version") == 1, "Unexpected road manifest schema version")
	_check(manifest.get("coordinate_system") == "axial_qr", "Road coordinates must be axial q/r")
	_assert_hex(manifest, "crossroads", Vector2i(8, 24))

	var roads: Dictionary = manifest.get("roads", {})
	for route_name in ["north", "south", "east", "east_border", "west"]:
		_check(roads.has(route_name), "Missing authored route: %s" % route_name)
		if not roads.has(route_name):
			continue
		var route: Dictionary = roads[route_name]
		var cells: Array = route.get("cells", [])
		_check(cells.size() > int(route.get("length", 0)), "%s should include lateral wiggle cells" % route_name)
		var previous := Vector2i(8, 24)
		for raw_cell in cells:
			if not raw_cell is Dictionary:
				_check(false, "%s contains a malformed road cell" % route_name)
				continue
			var cell := Vector2i(int(raw_cell.get("q", 999999)), int(raw_cell.get("r", 999999)))
			_check(HexGrid.distance(previous, cell) == 1, "%s contains a non-adjacent road step: %s -> %s" % [route_name, previous, cell])
			previous = cell
		var end: Dictionary = route.get("end", {})
		_check(previous == Vector2i(int(end.get("q", 999999)), int(end.get("r", 999999))), "%s endpoint must match its final cell" % route_name)

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
	_check(source.has(key), "Missing source waypoint: %s" % key)
	if not source.has(key):
		return
	var raw: Variant = source[key]
	_check(raw is Dictionary, "Waypoint %s must be an object" % key)
	if not raw is Dictionary:
		return
	var actual := Vector2i(int(raw.get("q", 999999)), int(raw.get("r", 999999)))
	_check(actual == expected, "%s should be %s, got %s" % [key, expected, actual])

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
