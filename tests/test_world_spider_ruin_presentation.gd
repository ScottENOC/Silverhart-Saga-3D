extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const PRESENTATION = preload("res://scripts/world/world_spider_ruin_presentation.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

var failures := 0

func _initialize() -> void:
	_test_spider_ruin_rubble()
	_test_chunk_scoping()
	if failures > 0:
		push_error("%d spider ruin presentation test(s) failed." % failures)
		quit(1)
		return
	print("Spider ruin presentation tests passed.")
	quit(0)

func _test_spider_ruin_rubble() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var centre: Vector2i = FEATURES.MIRABEL_SPIDER_RUIN_CENTRE
	var chunk_min := Vector2i(floori(float(centre.x) / 24.0) * 24, floori(float(centre.y) / 24.0) * 24)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Spider ruin presentation should succeed")
	_check(int(result.get("rubble_count", 0)) >= 3, "The small radius-three ruin should receive visible collapsed masonry")
	_check(parent.get_child_count() == int(result.get("rubble_count", 0)), "Each rubble cluster should have one stable root")
	for child in parent.get_children():
		var parts := String(child.name).split("_")
		_check(parts.size() >= 3 and parts[0] == "MirabelRuinRubble", "Rubble should use stable Mirabel ruin IDs")
		if parts.size() >= 3:
			var hex := Vector2i(int(parts[1]), int(parts[2]))
			var distance := _axial_distance(hex, centre)
			_check(distance > 0 and distance <= FEATURES.MIRABEL_SPIDER_RUIN_RADIUS, "Rubble should remain on the source ruin perimeter")
			_check(data.terrain_for_hex(hex) == "rocky_outcrop", "Rubble should only sit on the authored rocky outcrop")
	_check(parent.get_node_or_null("MirabelQuill") == null, "Map dressing must not create Mirabel or her quest actors")
	_check(parent.get_node_or_null("Spider") == null, "Map dressing must not create the two spider defenders")
	parent.free()

func _test_chunk_scoping() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var centre: Vector2i = FEATURES.MIRABEL_SPIDER_RUIN_CENTRE
	var chunk_min := Vector2i(floori(float(centre.x) / 24.0) * 24 + 24, floori(float(centre.y) / 24.0) * 24)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Unrelated chunks should still validate")
	_check(int(result.get("rubble_count", -1)) == 0 and parent.get_child_count() == 0, "Spider ruin rubble should not leak into neighbouring chunks")
	parent.free()

func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
