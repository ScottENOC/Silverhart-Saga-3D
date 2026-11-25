extends RefCounted
## Chunk-scoped physical dressing for Old Mac's source-anchored wolf den.
## The original source defines the den's discovery coordinate, not a built
## structure. This keeps the presentation deliberately natural and does not
## invent an interior, actors, quest triggers or encounter state.

static func present_chunk(parent: Node3D, terrain_data: Campaign2WorldTerrainData, chunk_min: Vector2i, chunk_size: int, hex_radius: float) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_wolf_den_presentation_arguments"}
	var site := terrain_data.encounter_site("farm_wolf_den")
	if site.is_empty() or String(site.get("kind", "")) != "wolf_den":
		return {"ok": false, "reason": "missing_source_wolf_den_anchor"}
	var hex := Vector2i(int(site.get("q", 0)), int(site.get("r", 0)))
	if not _contains(hex, chunk_min, chunk_size):
		return {"ok": true, "features": 0}
	_add_den_entrance(parent, terrain_data, hex, hex_radius)
	return {"ok": true, "features": 1, "anchor": hex}

static func _add_den_entrance(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := Node3D.new()
	root.name = "OldMacWolfDenPresentation"
	root.position = HexGrid.axial_to_world(hex, radius, terrain_data.elevation_for_hex(hex))
	parent.add_child(root)
	var stone := _material(Color("#625e55"))
	var dark_stone := _material(Color("#373a36"))
	var bone := _material(Color("#b6aa8e"))
	_add_rock(root, "EntranceLeft", Vector3(-0.62, 0.46, 0.0), Vector3(0.46, 0.92, 0.42), stone)
	_add_rock(root, "EntranceRight", Vector3(0.62, 0.42, 0.02), Vector3(0.42, 0.84, 0.38), stone)
	_add_rock(root, "Overhang", Vector3(0.0, 0.91, -0.02), Vector3(1.12, 0.32, 0.42), dark_stone)
	var mouth := MeshInstance3D.new()
	mouth.name = "ShadowedDenMouth"
	var mouth_mesh := SphereMesh.new()
	mouth_mesh.radius = 0.42
	mouth_mesh.height = 0.62
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(0.0, 0.28, 0.10)
	mouth.scale = Vector3(1.25, 0.82, 0.38)
	mouth.material_override = dark_stone
	root.add_child(mouth)
	for index in range(3):
		var bone_prop := MeshInstance3D.new()
		bone_prop.name = "ScatteredBone_%02d" % index
		var bone_mesh := CapsuleMesh.new()
		bone_mesh.radius = 0.055
		bone_mesh.height = 0.48 + float(index % 2) * 0.12
		bone_prop.mesh = bone_mesh
		bone_prop.position = Vector3(-0.78 + float(index) * 0.62, 0.08, 0.55 + float(index % 2) * 0.18)
		bone_prop.rotation.z = deg_to_rad(18.0 - float(index) * 13.0)
		bone_prop.rotation.y = deg_to_rad(float(index) * 37.0)
		bone_prop.material_override = bone
		root.add_child(bone_prop)

static func _add_rock(parent: Node3D, node_name: String, offset: Vector3, dimensions: Vector3, material: Material) -> void:
	var rock := MeshInstance3D.new()
	rock.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	rock.mesh = mesh
	rock.position = offset
	rock.scale = dimensions
	rock.material_override = material
	parent.add_child(rock)

static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material

static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size
