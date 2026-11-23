extends RefCounted
class_name WorldBorderFortPresentation
## Source-backed, presentation-only dressing for the two border forts.
## Terrain, doors, garrisons, siege state and combat remain owned elsewhere.

const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

const NORTHWATCH_SIEGE_ENGINE := FEATURES.NORTHWATCH_CENTRE + Vector2i(0, -46)
const NORTHWATCH_CATAPULT := FEATURES.NORTHWATCH_CENTRE + Vector2i(63, 0)
const NORTHWATCH_OIL_BARRELS: Array[Vector2i] = [
	Vector2i(267, -6),
	Vector2i(269, -6)
]
const KEEP_HEARTHS: Array[Vector2i] = [
	FEATURES.NORTHWATCH_CENTRE,
	FEATURES.RIDGEHOLD_CENTRE
]

static var _northwatch_ladder_hexes: Array[Vector2i] = []
static var _northwatch_ladders_ready := false

static func present_chunk(
	parent: Node3D,
	terrain_data: Campaign2WorldTerrainData,
	chunk_min: Vector2i,
	chunk_size: int,
	hex_radius: float
) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_border_fort_presentation_arguments"}
	var count := 0
	if _contains(NORTHWATCH_SIEGE_ENGINE, chunk_min, chunk_size):
		_add_siege_engine(parent, terrain_data, NORTHWATCH_SIEGE_ENGINE, hex_radius)
		count += 1
	if _contains(NORTHWATCH_CATAPULT, chunk_min, chunk_size):
		_add_catapult(parent, terrain_data, NORTHWATCH_CATAPULT, hex_radius)
		count += 1
	for barrel_hex in NORTHWATCH_OIL_BARRELS:
		if _contains(barrel_hex, chunk_min, chunk_size):
			_add_oil_barrel(parent, terrain_data, barrel_hex, hex_radius)
			count += 1
	for hearth_hex in KEEP_HEARTHS:
		if _contains(hearth_hex, chunk_min, chunk_size):
			_add_keep_hearth(parent, terrain_data, hearth_hex, hex_radius)
			count += 1
	_ensure_northwatch_ladders(terrain_data)
	for ladder_hex in _northwatch_ladder_hexes:
		if _contains(ladder_hex, chunk_min, chunk_size):
			_add_ladder(parent, terrain_data, ladder_hex, hex_radius)
			count += 1
	return {"ok": true, "props": count}

static func _ensure_northwatch_ladders(terrain_data: Campaign2WorldTerrainData) -> void:
	if _northwatch_ladders_ready:
		return
	var directions: Array[Vector2i] = FEATURES.STAR_FORT_DIRECTIONS
	for index in range(directions.size()):
		var direction: Vector2i = directions[index]
		var next_direction: Vector2i = directions[(index + 1) % directions.size()]
		var target := FEATURES.NORTHWATCH_CENTRE + Vector2i(
			roundi(float(direction.x + next_direction.x) * 3.5),
			roundi(float(direction.y + next_direction.y) * 3.5)
		)
		var nearest := Vector2i.ZERO
		var nearest_distance := 2147483647
		for q in range(FEATURES.NORTHWATCH_CENTRE.x - 24, FEATURES.NORTHWATCH_CENTRE.x + 25):
			for r in range(FEATURES.NORTHWATCH_CENTRE.y - 24, FEATURES.NORTHWATCH_CENTRE.y + 25):
				var candidate := Vector2i(q, r)
				if terrain_data.terrain_for_hex(candidate) != "climbable_wall":
					continue
				var distance := _axial_distance(candidate, target)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest = candidate
		if nearest_distance < 2147483647 and not _northwatch_ladder_hexes.has(nearest):
			_northwatch_ladder_hexes.append(nearest)
	_northwatch_ladders_ready = true

static func _add_siege_engine(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := _prop_root(parent, terrain_data, "NorthwatchSiegeEngine", hex, radius)
	var timber := _material(Color("#69482c"))
	var dark_wood := _material(Color("#392b20"))
	var iron := _material(Color("#4b5052"), 0.72, 0.55)
	_add_box(root, "RamChassis", Vector3(0.0, 1.15, 0.0), Vector3(5.8, 0.45, 3.0), timber)
	_add_box(root, "CoveredCanopy", Vector3(0.0, 3.05, 0.0), Vector3(5.1, 0.28, 2.7), dark_wood)
	_add_box(root, "CanopyFront", Vector3(0.0, 2.45, -1.2), Vector3(5.0, 1.1, 0.18), timber)
	_add_box(root, "RamBeam", Vector3(0.0, 1.65, -3.1), Vector3(0.42, 0.42, 5.6), dark_wood)
	_add_box(root, "RamHead", Vector3(0.0, 1.65, -5.85), Vector3(0.85, 0.8, 0.9), iron)
	for side in [-1.0, 1.0]:
		_add_wheel(root, "Wheel_%s" % side, Vector3(side * 2.45, 0.78, 0.0), 0.82, timber, iron)

static func _add_catapult(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := _prop_root(parent, terrain_data, "NorthwatchGreenskinCatapult", hex, radius)
	var timber := _material(Color("#604126"))
	var rope := _material(Color("#a58b5c"))
	var iron := _material(Color("#4b5052"), 0.72, 0.55)
	_add_box(root, "CatapultBase", Vector3(0.0, 0.42, 0.0), Vector3(5.0, 0.5, 3.4), timber)
	for side in [-1.0, 1.0]:
		_add_beam(root, "Frame_%s_A" % side, Vector3(side * 1.35, 0.65, -0.8), Vector3(side * 1.35, 3.7, -0.8), 0.32, timber)
		_add_beam(root, "Frame_%s_B" % side, Vector3(side * 1.35, 0.65, 0.8), Vector3(side * 1.35, 3.7, -0.8), 0.32, timber)
	_add_cylinder(root, "Axle", Vector3(0.0, 2.35, 0.0), 0.18, 3.4, iron)
	_add_beam(root, "ThrowingArm", Vector3(0.0, 2.35, 0.0), Vector3(0.0, 5.3, -2.1), 0.28, timber)
	_add_beam(root, "SlingCordA", Vector3(0.0, 5.15, -1.9), Vector3(-0.75, 4.65, -3.1), 0.06, rope)
	_add_beam(root, "SlingCordB", Vector3(0.0, 5.15, -1.9), Vector3(0.75, 4.65, -3.1), 0.06, rope)
	_add_box(root, "SlingPouch", Vector3(0.0, 4.58, -3.1), Vector3(1.0, 0.12, 0.8), rope)
	for side in [-1.0, 1.0]:
		_add_wheel(root, "Wheel_%s" % side, Vector3(side * 2.05, 0.65, 0.0), 0.68, timber, iron)

static func _add_oil_barrel(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := _prop_root(parent, terrain_data, "NorthwatchOilBarrel_%d_%d" % [hex.x, hex.y], hex, radius)
	var wood := _material(Color("#68452c"))
	var iron := _material(Color("#45494a"), 0.7, 0.5)
	_add_cylinder(root, "BarrelBody", Vector3(0.0, 0.68, 0.0), 0.46, 1.3, wood)
	for y in [0.22, 1.1]:
		_add_torus(root, "Hoop_%s" % y, Vector3(0.0, y, 0.0), 0.48, 0.055, iron)

static func _add_ladder(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := _prop_root(parent, terrain_data, "NorthwatchWallLadder_%d_%d" % [hex.x, hex.y], hex, radius)
	var wood := _material(Color("#765333"))
	for side in [-1.0, 1.0]:
		_add_beam(root, "Rail_%s" % side, Vector3(side * 0.62, 0.0, 0.0), Vector3(side * 0.62, 3.15, 0.0), 0.16, wood)
	for rung in range(7):
		var y := 0.25 + float(rung) * 0.43
		_add_box(root, "Rung_%d" % rung, Vector3(0.0, y, 0.0), Vector3(1.2, 0.12, 0.14), wood)

static func _add_keep_hearth(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := _prop_root(parent, terrain_data, "BorderFortHearth_%d_%d" % [hex.x, hex.y], hex, radius)
	var stone := _material(Color("#595b5a"))
	var coal := _material(Color("#28211d"))
	var flame := _material(Color("#f28b38"), 0.35)
	flame.emission_enabled = true
	flame.emission = Color("#ff6a24")
	flame.emission_energy_multiplier = 1.8
	_add_cylinder(root, "HearthStone", Vector3(0.0, 0.18, 0.0), 1.05, 0.36, stone)
	_add_cylinder(root, "CoalBed", Vector3(0.0, 0.4, 0.0), 0.72, 0.08, coal)
	_add_cylinder(root, "FireGlow", Vector3(0.0, 0.72, 0.0), 0.34, 0.62, flame)

static func _prop_root(parent: Node3D, terrain_data: Campaign2WorldTerrainData, node_name: String, hex: Vector2i, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = HexGrid.axial_to_world(hex, radius, terrain_data.elevation_for_hex(hex))
	parent.add_child(root)
	return root

static func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, node_name, mesh, position, material)

static func _add_cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _add_mesh(parent, node_name, mesh, position, material)

static func _add_torus(parent: Node3D, node_name: String, position: Vector3, radius: float, thickness: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 12
	mesh.ring_segments = 8
	return _add_mesh(parent, node_name, mesh, position, material)

static func _add_wheel(parent: Node3D, node_name: String, position: Vector3, radius: float, wood: Material, iron: Material) -> void:
	var wheel := _add_cylinder(parent, node_name, position, radius, 0.24, wood)
	wheel.rotation.z = deg_to_rad(90.0)
	var band := _add_torus(parent, node_name + "_IronBand", position, radius * 0.92, 0.055, iron)
	band.rotation.z = deg_to_rad(90.0)

static func _add_beam(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, thickness: float, material: Material) -> void:
	var direction := finish - start
	var beam := _add_box(parent, node_name, (start + finish) * 0.5, Vector3(thickness, direction.length(), thickness), material)
	beam.quaternion = Quaternion(Vector3.UP, direction.normalized())

static func _add_mesh(parent: Node3D, node_name: String, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

static func _material(colour: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	return material

static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size

static func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2)
