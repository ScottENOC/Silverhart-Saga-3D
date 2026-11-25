extends RefCounted
## Presentation-only dressing for the source-authored Druid Grove spring and herb patches.
## Elder Nessa, Fenn, herb gathering, the wolf trial and unicorn quest remain campaign-owned.

const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

static func present_chunk(parent: Node3D, terrain_data: Campaign2WorldTerrainData, chunk_min: Vector2i, chunk_size: int, hex_radius: float) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_druid_grove_presentation_arguments"}
	var grove := _location_by_id(terrain_data, "emberwood_grove")
	if grove.is_empty() or String(grove.get("kind", "")) != "druid_grove":
		return {"ok": false, "reason": "missing_source_emberwood_grove_anchor"}
	var grove_centre := Vector2i(int(grove.get("q", 0)), int(grove.get("r", 0)))
	var anchor_offset := grove_centre - FEATURES.DRUID_GROVE_CENTRE
	var spring_hex := FEATURES.DRUID_GROVE_SPRING + anchor_offset
	var count := 0
	if _contains(spring_hex, chunk_min, chunk_size):
		_add_spring(parent, terrain_data, spring_hex, hex_radius)
		count += 1
	for source_hex in FEATURES.HERB_PATCH_HEXES:
		var hex: Vector2i = source_hex + anchor_offset
		if _contains(hex, chunk_min, chunk_size):
			_add_herb_patch(parent, terrain_data, hex, hex_radius)
			count += 1
	return {"ok": true, "features": count, "grove_centre": grove_centre}


static func _location_by_id(terrain_data: Campaign2WorldTerrainData, location_id: String) -> Dictionary:
	for location in terrain_data.locations:
		if location is Dictionary and String(location.get("id", "")) == location_id:
			return location.duplicate(true)
	return {}

static func _add_spring(parent: Node3D, terrain_data: Campaign2WorldTerrainData, spring: Vector2i, radius: float) -> void:
	var root := Node3D.new()
	root.name = "DruidGroveSpringPresentation"
	root.position = HexGrid.axial_to_world(spring, radius, terrain_data.elevation_for_hex(spring))
	parent.add_child(root)
	var stone := _material(Color("#77766a"))
	for index in range(HexGrid.SIDE_COUNT):
		var neighbour: Vector2i = spring + HexGrid.DIRECTIONS[index]
		var point: Vector3 = HexGrid.axial_to_world(neighbour, radius, terrain_data.elevation_for_hex(neighbour))
		var origin: Vector3 = HexGrid.axial_to_world(spring, radius, terrain_data.elevation_for_hex(spring))
		var rock := MeshInstance3D.new()
		rock.name = "SpringStone_%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.34
		mesh.bottom_radius = 0.43
		mesh.height = 0.32
		mesh.radial_segments = 7
		rock.mesh = mesh
		rock.position = Vector3(point.x - origin.x, 0.16, point.z - origin.z)
		rock.rotation.y = deg_to_rad(float(index * 53))
		rock.material_override = stone
		root.add_child(rock)

static func _add_herb_patch(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := Node3D.new()
	root.name = "DruidGroveHerbPatch_%d_%d" % [hex.x, hex.y]
	root.position = HexGrid.axial_to_world(hex, radius, terrain_data.elevation_for_hex(hex))
	parent.add_child(root)
	var stem_material := _material(Color("#456b3e"))
	var leaf_material := _material(Color("#6d9850"))
	var flower_material := _material(Color("#d9c27b"))
	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var offset := Vector3(cos(angle) * 0.38, 0.0, sin(angle) * 0.38)
		var stem := MeshInstance3D.new()
		stem.name = "HerbStem_%02d" % index
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.035
		stem_mesh.bottom_radius = 0.055
		stem_mesh.height = 0.52 + float(index % 3) * 0.12
		stem.mesh = stem_mesh
		stem.position = offset + Vector3(0.0, stem_mesh.height * 0.5, 0.0)
		stem.rotation.z = deg_to_rad(-8.0 + float(index) * 4.0)
		stem.material_override = stem_material
		root.add_child(stem)
		var leaf := MeshInstance3D.new()
		leaf.name = "HerbLeaf_%02d" % index
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.2
		leaf_mesh.height = 0.12
		leaf.mesh = leaf_mesh
		leaf.position = offset + Vector3(0.16, 0.24 + float(index % 3) * 0.06, 0.0)
		leaf.scale = Vector3(1.0, 0.7, 0.55)
		leaf.rotation.y = angle
		leaf.material_override = leaf_material
		root.add_child(leaf)
		if index % 2 == 0:
			var flower := MeshInstance3D.new()
			flower.name = "HerbFlower_%02d" % index
			var flower_mesh := SphereMesh.new()
			flower_mesh.radius = 0.09
			flower_mesh.height = 0.1
			flower.mesh = flower_mesh
			flower.position = offset + Vector3(0.0, stem_mesh.height + 0.04, 0.0)
			flower.material_override = flower_material
			root.add_child(flower)

static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.95
	return material

static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size
