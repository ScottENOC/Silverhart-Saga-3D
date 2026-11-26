extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const WALL_FACTORY = preload("res://scripts/world/world_wall_feature_factory.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

var failures: int = 0

func _initialize() -> void:
	_test_northwatch_wall_chunk()
	_test_wall_chunk_boundary_continuity()
	_test_wall_heights()
	if failures > 0:
		push_error("%d wall feature test(s) failed." % failures)
		quit(1)
		return
	print("Regional wall feature factory tests passed.")
	quit(0)

func _test_northwatch_wall_chunk() -> void:
	var terrain_data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var centre: Vector2i = FEATURES.NORTHWATCH_CENTRE
	var chunk := terrain_data.chunk_for_hex(centre, 24)
	var chunk_min := chunk * 24
	var parent := Node3D.new()
	root.add_child(parent)
	var materials := {
		"climbable_wall": StandardMaterial3D.new(),
		"keep_wall": StandardMaterial3D.new()
	}
	var result: Dictionary = WALL_FACTORY.present_chunk(parent, terrain_data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M, materials)
	_check(bool(result.get("ok", false)), "Northwatch wall chunk should present successfully")
	_check(int(result.get("wall_hex_count", 0)) > 0, "Northwatch's source wall ring should produce wall cells")
	_check(int(result.get("face_count", 0)) > 0, "Wall cells should produce vertical faces against non-wall neighbours")
	_check(int(result.get("mesh_count", 0)) > 0, "Wall faces should be emitted as renderable meshes")
	parent.free()


func _test_wall_chunk_boundary_continuity() -> void:
	var terrain_data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var centre: Vector2i = FEATURES.NORTHWATCH_CENTRE
	var base_chunk := terrain_data.chunk_for_hex(centre, 24)
	var base_min := base_chunk * 24
	var materials := {
		"climbable_wall": StandardMaterial3D.new(),
		"keep_wall": StandardMaterial3D.new()
	}
	var single_parent := Node3D.new()
	var single_result: Dictionary = WALL_FACTORY.present_chunk(single_parent, terrain_data, base_min, 48, HexGrid.DEFAULT_RADIUS_M, materials)
	_check(bool(single_result.get("ok", false)), "Combined Northwatch wall region should present successfully")
	var split_wall_hexes := 0
	var split_faces := 0
	for q_offset in [0, 24]:
		for r_offset in [0, 24]:
			var chunk_parent := Node3D.new()
			var chunk_min := base_min + Vector2i(q_offset, r_offset)
			var result: Dictionary = WALL_FACTORY.present_chunk(chunk_parent, terrain_data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M, materials)
			_check(bool(result.get("ok", false)), "Each streamed Northwatch wall subchunk should present successfully")
			split_wall_hexes += int(result.get("wall_hex_count", 0))
			split_faces += int(result.get("face_count", 0))
			chunk_parent.free()
	_check(split_wall_hexes == int(single_result.get("wall_hex_count", -1)), "Splitting wall terrain across chunk boundaries must not lose or duplicate wall cells")
	_check(split_faces == int(single_result.get("face_count", -1)), "Chunk edges must not create false wall faces or hide real faces")
	single_parent.free()

func _test_wall_heights() -> void:
	_check(is_equal_approx(WALL_FACTORY.height_for_terrain("climbable_wall"), 2.8), "Climbable ramparts should use the shared rampart height")
	_check(is_equal_approx(WALL_FACTORY.height_for_terrain("keep_wall"), 3.3), "Keep walls should be taller than outer ramparts")
	_check(is_equal_approx(WALL_FACTORY.height_for_terrain("grass"), 0.0), "Ordinary terrain must not be raised as a wall")
	_check(WALL_FACTORY.height_for_terrain("keep_wall") > WALL_FACTORY.height_for_terrain("climbable_wall"), "Keep walls should be visually taller than outer walls")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
