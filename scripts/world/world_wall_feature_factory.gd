extends RefCounted
class_name WorldWallFeatureFactory
## Builds raised wall tops and vertical wall faces from the regional terrain's
## authored wall cells. Chunk boundaries are safe because neighbour terrain
## is queried from the canonical terrain provider, not the local chunk mesh.

const CLIMBABLE_WALL_HEIGHT: float = 2.8
const KEEP_WALL_HEIGHT: float = 3.3

static func height_for_terrain(terrain_id: String) -> float:
	match terrain_id:
		"climbable_wall":
			return CLIMBABLE_WALL_HEIGHT
		"keep_wall":
			return KEEP_WALL_HEIGHT
		_:
			return 0.0

static func present_chunk(parent: Node3D, terrain_data: Campaign2WorldTerrainData, chunk_min: Vector2i, chunk_size: int, hex_radius: float, materials: Dictionary) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_wall_chunk_arguments"}
	var surfaces: Dictionary = {}
	var top_surfaces: Dictionary = {}
	for terrain_id in ["climbable_wall", "keep_wall"]:
		var material: Material = materials.get(terrain_id) as Material
		if material == null:
			return {"ok": false, "reason": "missing_wall_material", "terrain": terrain_id}
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		surfaces[terrain_id] = surface
		var top_surface := SurfaceTool.new()
		top_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		top_surface.set_material(material)
		top_surfaces[terrain_id] = top_surface
	var wall_hex_count := 0
	var face_count := 0
	var top_triangle_count := 0
	var corners := HexGrid.corner_offsets(hex_radius * 1.005)
	for q in range(chunk_min.x, chunk_min.x + chunk_size):
		for r in range(chunk_min.y, chunk_min.y + chunk_size):
			var hex := Vector2i(q, r)
			var terrain_id := terrain_data.terrain_for_hex(hex)
			var wall_height := height_for_terrain(terrain_id)
			if wall_height <= 0.0:
				continue
			wall_hex_count += 1
			var base := HexGrid.axial_to_world(hex, hex_radius, terrain_data.elevation_for_hex(hex))
			var top_centre := base + Vector3.UP * wall_height
			var top_surface := top_surfaces[terrain_id] as SurfaceTool
			for side in range(HexGrid.SIDE_COUNT):
				var next_side := (side + 1) % HexGrid.SIDE_COUNT
				var top_a := base + Vector3(corners[side].x, terrain_data.shared_vertex_elevation(hex, side) - terrain_data.elevation_for_hex(hex), corners[side].y) + Vector3.UP * wall_height
				var top_b := base + Vector3(corners[next_side].x, terrain_data.shared_vertex_elevation(hex, next_side) - terrain_data.elevation_for_hex(hex), corners[next_side].y) + Vector3.UP * wall_height
				top_surface.set_normal(Vector3.UP)
				top_surface.add_vertex(top_centre)
				top_surface.add_vertex(top_a)
				top_surface.add_vertex(top_b)
				top_triangle_count += 1
				var neighbour := hex + HexGrid.DIRECTIONS[side]
				if height_for_terrain(terrain_data.terrain_for_hex(neighbour)) > 0.0:
					continue
				_append_wall_face(surfaces[terrain_id] as SurfaceTool, base, corners[side], corners[(side + 1) % HexGrid.SIDE_COUNT], wall_height)
				face_count += 1
	var mesh_count := 0
	for terrain_id in surfaces:
		var face_mesh := (surfaces[terrain_id] as SurfaceTool).commit()
		if face_mesh != null and face_mesh.get_surface_count() > 0:
			var face_instance := MeshInstance3D.new()
			face_instance.name = "WallFaces_" + String(terrain_id)
			face_instance.mesh = face_mesh
			face_instance.material_override = materials[terrain_id]
			parent.add_child(face_instance)
			mesh_count += 1
		var top_mesh := (top_surfaces[terrain_id] as SurfaceTool).commit()
		if top_mesh != null and top_mesh.get_surface_count() > 0:
			var top_instance := MeshInstance3D.new()
			top_instance.name = "WallTops_" + String(terrain_id)
			top_instance.mesh = top_mesh
			top_instance.material_override = materials[terrain_id]
			parent.add_child(top_instance)
			mesh_count += 1
	return {"ok": true, "wall_hex_count": wall_hex_count, "face_count": face_count, "top_triangle_count": top_triangle_count, "mesh_count": mesh_count}

static func _append_wall_face(surface: SurfaceTool, base: Vector3, corner_a: Vector2, corner_b: Vector2, height: float) -> void:
	var a := base + Vector3(corner_a.x, 0.0, corner_a.y)
	var b := base + Vector3(corner_b.x, 0.0, corner_b.y)
	var top_a := a + Vector3.UP * height
	var top_b := b + Vector3.UP * height
	var normal := Vector3.UP.cross(b - a).normalized()
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.add_vertex(top_a)
	surface.add_vertex(top_b)
	surface.add_vertex(a)
	surface.add_vertex(top_b)
	surface.add_vertex(b)
