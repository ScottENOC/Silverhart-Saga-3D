extends RefCounted
## Source-authored hoofprint trail around the Wild Unicorn's patrol vale.
## The unicorn actor, patrol AI, discovery checks and dialogue remain campaign-owned.

const TRACKS := [
	{"hex": Vector2i(-274, 24), "direction": Vector2i(-3, 8)},
	{"hex": Vector2i(-275, 27), "direction": Vector2i(-3, 8)},
	{"hex": Vector2i(-276, 29), "direction": Vector2i(-3, 8)},
	{"hex": Vector2i(-277, 32), "direction": Vector2i(-9, 4)},
	{"hex": Vector2i(-280, 33), "direction": Vector2i(-9, 4)},
	{"hex": Vector2i(-283, 35), "direction": Vector2i(-9, 4)},
	{"hex": Vector2i(-286, 36), "direction": Vector2i(-8, -4)},
	{"hex": Vector2i(-289, 35), "direction": Vector2i(-8, -4)},
	{"hex": Vector2i(-291, 33), "direction": Vector2i(-8, -4)},
	{"hex": Vector2i(-294, 32), "direction": Vector2i(-4, -8)},
	{"hex": Vector2i(-295, 29), "direction": Vector2i(-4, -8)},
	{"hex": Vector2i(-297, 27), "direction": Vector2i(-4, -8)},
	{"hex": Vector2i(-298, 24), "direction": Vector2i(3, -8)},
	{"hex": Vector2i(-297, 21), "direction": Vector2i(3, -8)},
	{"hex": Vector2i(-296, 19), "direction": Vector2i(3, -8)},
	{"hex": Vector2i(-295, 16), "direction": Vector2i(9, -4)},
	{"hex": Vector2i(-292, 15), "direction": Vector2i(9, -4)},
	{"hex": Vector2i(-289, 13), "direction": Vector2i(9, -4)},
	{"hex": Vector2i(-286, 12), "direction": Vector2i(8, 4)},
	{"hex": Vector2i(-283, 13), "direction": Vector2i(8, 4)},
	{"hex": Vector2i(-281, 15), "direction": Vector2i(8, 4)},
	{"hex": Vector2i(-278, 16), "direction": Vector2i(4, 8)},
	{"hex": Vector2i(-277, 19), "direction": Vector2i(4, 8)},
	{"hex": Vector2i(-275, 21), "direction": Vector2i(4, 8)}
]

static func present_chunk(parent: Node3D, terrain_data: Campaign2WorldTerrainData, chunk_min: Vector2i, chunk_size: int, hex_radius: float) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_unicorn_track_presentation_arguments"}
	var count := 0
	for track in TRACKS:
		var hex: Vector2i = track["hex"]
		if not _contains(hex, chunk_min, chunk_size):
			continue
		_add_track(parent, terrain_data, hex, track["direction"], hex_radius)
		count += 1
	return {"ok": true, "features": count}


static func _add_track(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, direction: Vector2i, radius: float) -> void:
	var root := Node3D.new()
	root.name = "UnicornHoofprints_%d_%d" % [hex.x, hex.y]
	root.position = HexGrid.axial_to_world(hex, radius, terrain_data.elevation_for_hex(hex))
	parent.add_child(root)
	var next_hex := hex + direction
	var origin := HexGrid.axial_to_world(hex, radius, terrain_data.elevation_for_hex(hex))
	var next_position := HexGrid.axial_to_world(next_hex, radius, terrain_data.elevation_for_hex(next_hex))
	var heading := Vector2(next_position.x - origin.x, next_position.z - origin.z).normalized()
	var lateral := Vector2(-heading.y, heading.x)
	var hoof_material := StandardMaterial3D.new()
	hoof_material.albedo_color = Color("#594a38")
	hoof_material.roughness = 1.0
	for side in [-1.0, 1.0]:
		var print_mesh := MeshInstance3D.new()
		print_mesh.name = "Hoofprint_%s" % ("L" if side < 0.0 else "R")
		var mesh := SphereMesh.new()
		mesh.radius = 0.13
		mesh.height = 0.07
		print_mesh.mesh = mesh
		print_mesh.scale = Vector3(0.8, 0.5, 1.25)
		print_mesh.position = Vector3(lateral.x * side * 0.16, 0.025, lateral.y * side * 0.16)
		print_mesh.rotation.y = atan2(heading.x, heading.y)
		print_mesh.material_override = hoof_material
		root.add_child(print_mesh)


static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size
