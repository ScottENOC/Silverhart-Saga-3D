extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const PRESENTATION = preload("res://scripts/world/world_abandoned_house_approach_presentation.gd")

var failures := 0

func _initialize() -> void:
	_test_source_path()
	_test_chunk_scoping()
	if failures > 0:
		push_error("%d abandoned-house approach presentation test(s) failed." % failures)
		quit(1)
		return
	print("Abandoned-house approach presentation tests passed.")
	quit(0)

func _test_source_path() -> void:
	_check(PRESENTATION.WAYPOINT == Vector2i(8, -176), "Approach must start at the source north-road waypoint")
	_check(PRESENTATION.DOORWAY == Vector2i(11, -176), "Approach must terminate at the source west doorway")
	var expected: Array[Vector2i] = [Vector2i(8, -176), Vector2i(9, -176), Vector2i(10, -176), Vector2i(11, -176)]
	_check(PRESENTATION.PATH_HEXES == expected, "Approach must retain the source-authored short path cells")
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, Vector2i(0, -192), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Owning chunk should compose the abandoned-house approach")
	_check(int(result.get("features", 0)) == expected.size(), "All source path cells should be presented exactly once")
	var path_root := parent.get_node_or_null("AbandonedHouseApproach")
	_check(path_root != null, "Path should have a stable presentation root")
	if path_root != null:
		_check(path_root.get_child_count() == expected.size() * 3, "Each source path cell should receive three restrained worn-earth patches")
	parent.free()

func _test_chunk_scoping() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, Vector2i(24, -192), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Unrelated chunks should remain valid")
	_check(int(result.get("features", -1)) == 0 and parent.get_child_count() == 0, "Approach dressing must remain in its owning chunk")
	parent.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
