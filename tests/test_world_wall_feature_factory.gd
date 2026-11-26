extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const WALL_FACTORY = preload("res://scripts/world/world_wall_feature_factory.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

var failures: int = 0

func _initialize() -> void:
	_test_northwatch_wall_chunk()
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
	_check(int(result.get("mesh_count", 0)) >= 2, "Wall faces and solid top surfaces should be emitted as renderable meshes")
	_check(int(result.get("top_triangle_count", 0)) == int(result.get("wall_hex_count", 0)) * HexGrid.SIDE_COUNT, "Every wall hex should receive a complete six-triangle top cap")
	var top_mesh_found := false
	for child in parent.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("WallTops_"):
			top_mesh_found = true
			var top_mesh: Mesh = (child as MeshInstance3D).mesh
			_check(top_mesh.get_surface_count() > 0, "Wall top cap mesh should contain a renderable surface")
			if top_mesh.get_surface_count() > 0:
				var arrays: Array = top_mesh.surface_get_arrays(0)
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				_check(not normals.is_empty(), "Wall top cap mesh should provide explicit normals")
				for normal in normals:
					_check(normal.y > 0.99, "Wall top cap normals should face upward")
	_check(top_mesh_found, "Northwatch walls should include a distinct solid top-cap mesh")
	parent.free()

func _test_wall_heights() -> void:
	_check(is_equal_approx(WALL_FACTORY.height_for_terrain("climbable_wall"), 2.8), "Climbable ramparts should use the shared rampart height")
	_check(is_equal_approx(WALL_FACTORY.height_for_terrain("keep_wall"), 3.3), "Keep walls should be taller than outer ramparts")
	_check(is_equal_approx(WALL_FACTORY.height_for_terrain("grass"), 0.0), "Ordinary terrain must not be raised as a wall")
	_check(WALL_FACTORY.height_for_terrain("keep_wall") > WALL_FACTORY.height_for_terrain("climbable_wall"), "Keep walls should be visually taller than outer walls")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
