extends RefCounted
## Chunk-scoped presentation of the short source-authored path to the Abandoned House.
## The source supplies the waypoint, two painted Path cells and west doorway; the worn earth
## surface is a restrained 3D material treatment, not additional world geometry.

const WAYPOINT := Vector2i(8, -176)
const DOORWAY := Vector2i(11, -176)
# Source loop: q = waypoint.q + 1; q < doorHex.q. The endpoints are not Path cells.
const PATH_HEXES: Array[Vector2i] = [
	Vector2i(9, -176),
	Vector2i(10, -176)
]

static func present_chunk(parent: Node3D, terrain_data: Campaign2WorldTerrainData, chunk_min: Vector2i, chunk_size: int, hex_radius: float) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_abandoned_house_approach_arguments"}
	var presented := 0
	for hex in PATH_HEXES:
		if not _contains(hex, chunk_min, chunk_size):
			continue
		_add_path_cell(parent, terrain_data, hex, hex_radius)
		presented += 1
	return {"ok": true, "features": presented, "path_hexes": PATH_HEXES.duplicate()}

static func _add_path_cell(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := parent.get_node_or_null("AbandonedHouseApproach")
	if root == null:
		root = Node3D.new()
		root.name = "AbandonedHouseApproach"
		parent.add_child(root)
	var centre := HexGrid.axial_to_world(hex, radius, terrain_data.elevation_for_hex(hex))
	var earth := _material(Color("#80694b"))
	var worn_earth := _material(Color("#9a805d"))
	for index in range(3):
		var patch := MeshInstance3D.new()
		patch.name = "Path_%d_%d_%02d" % [hex.x, hex.y, index]
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 0.16
		patch.mesh = mesh
		patch.scale = Vector3(radius * (0.88 if index == 1 else 0.62), 0.055, radius * 0.34)
		patch.position = centre + Vector3(-radius * 0.22 + float(index) * radius * 0.22, 0.035, (float(index % 2) - 0.5) * radius * 0.16)
		patch.material_override = worn_earth if index == 1 else earth
		root.add_child(patch)

static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material

static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size
