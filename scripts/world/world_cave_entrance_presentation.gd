extends RefCounted
## Chunk-scoped 3D cave-mouth dressing for source-authored Campaign 2 cave entrances.
## The source defines the surface room and west doorway; the rock framing is a
## restrained 3D presentation adaptation. Interior geometry, occupants and
## quest/encounter state remain owned by the multi-story and campaign systems.

const ENTRANCES: Array[Dictionary] = [
	# buildThievesCoveCaves: entrance room centre (-274,40), west door (-277,40).
	{"id": "thieves_cove", "node": "ThievesCoveEntrance", "hex": Vector2i(-277, 40)},
	# buildNecromancerCrypt: entrance room centre (32,-154), west door (29,-154).
	{"id": "vessel_seekers_crypt", "node": "VesselSeekersCryptEntrance", "hex": Vector2i(29, -154)},
	# buildLichBarrow: antechamber centre (63,-160), west door (60,-160).
	{"id": "corvin_ashgrave_barrow", "node": "CorvinAshgraveBarrowEntrance", "hex": Vector2i(60, -160)}
]

static func present_chunk(parent: Node3D, terrain_data: Campaign2WorldTerrainData, chunk_min: Vector2i, chunk_size: int, hex_radius: float) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_cave_entrance_presentation_arguments"}
	var count := 0
	var presented: Array[String] = []
	for entrance in ENTRANCES:
		var hex: Vector2i = entrance["hex"]
		if not _contains(hex, chunk_min, chunk_size):
			continue
		_add_entrance(parent, terrain_data, entrance, hex, hex_radius)
		presented.append(String(entrance["id"]))
		count += 1
	return {"ok": true, "features": count, "entrances": presented}

static func _add_entrance(parent: Node3D, terrain_data: Campaign2WorldTerrainData, definition: Dictionary, hex: Vector2i, radius: float) -> void:
	var root := Node3D.new()
	root.name = String(definition["node"])
	root.position = HexGrid.axial_to_world(hex, radius, terrain_data.elevation_for_hex(hex))
	# All three source doorways face west. Orient the cave mouth toward the
	# exterior neighbour rather than leaving it facing an arbitrary world axis.
	var outside := HexGrid.axial_to_world(hex + Vector2i(-1, 0), radius)
	var centre := HexGrid.axial_to_world(hex, radius)
	var outward := outside - centre
	root.rotation.y = atan2(outward.x, outward.z)
	parent.add_child(root)
	var stone := _material(Color("#625f57"))
	var dark_stone := _material(Color("#343633"))
	_add_rock(root, "LeftJamb", Vector3(-0.66, 0.54, 0.0), Vector3(0.48, 1.08, 0.48), stone, -9.0)
	_add_rock(root, "RightJamb", Vector3(0.66, 0.49, 0.02), Vector3(0.43, 0.98, 0.44), stone, 7.0)
	_add_rock(root, "Lintel", Vector3(0.0, 1.08, -0.01), Vector3(1.34, 0.38, 0.50), dark_stone, -3.0)
	var mouth := MeshInstance3D.new()
	mouth.name = "DarkCaveMouth"
	var mouth_mesh := SphereMesh.new()
	mouth_mesh.radius = 0.46
	mouth_mesh.height = 0.78
	mouth.mesh = mouth_mesh
	mouth.scale = Vector3(1.25, 1.0, 0.32)
	mouth.position = Vector3(0.0, 0.40, 0.13)
	mouth.material_override = dark_stone
	root.add_child(mouth)
	for index in range(2):
		_add_rock(
			root,
			"LooseStone_%02d" % index,
			Vector3(-0.86 + float(index) * 1.72, 0.13, 0.52),
			Vector3(0.30 + float(index) * 0.06, 0.25, 0.32),
			stone,
			float(index) * 21.0
		)

static func _add_rock(parent: Node3D, node_name: String, offset: Vector3, dimensions: Vector3, material: Material, yaw_degrees: float) -> void:
	var rock := MeshInstance3D.new()
	rock.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	rock.mesh = mesh
	rock.position = offset
	rock.scale = dimensions
	rock.rotation.y = deg_to_rad(yaw_degrees)
	rock.material_override = material
	parent.add_child(rock)

static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material

static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size
