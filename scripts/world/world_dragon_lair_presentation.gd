extends RefCounted
## Chunk-scoped visual dressing for the source-authored Ashveil dragon lair.
## The source terrain defines a radius-six rocky outcrop and radius-two cave den.
## Dragon identity, behaviour, hoard, combat and quest state remain campaign-owned.

const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

static func present_chunk(parent: Node3D, terrain_data: Campaign2WorldTerrainData, chunk_min: Vector2i, chunk_size: int, hex_radius: float) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_dragon_lair_presentation_arguments"}
	var site := terrain_data.encounter_site("ashveil_lair")
	if site.is_empty() or String(site.get("kind", "")) != "dragon_lair":
		return {"ok": false, "reason": "missing_source_ashveil_lair_anchor"}
	var centre := Vector2i(int(site.get("q", 0)), int(site.get("r", 0)))
	var placements: Array[Vector2i] = []
	for q in range(centre.x - FEATURES.DRAGON_LAIR_OUTER_RADIUS, centre.x + FEATURES.DRAGON_LAIR_OUTER_RADIUS + 1):
		for r in range(centre.y - FEATURES.DRAGON_LAIR_OUTER_RADIUS, centre.y + FEATURES.DRAGON_LAIR_OUTER_RADIUS + 1):
			var hex := Vector2i(q, r)
			var distance := _axial_distance(hex, centre)
			if distance < FEATURES.DRAGON_LAIR_DEN_RADIUS + 1 or distance > FEATURES.DRAGON_LAIR_OUTER_RADIUS:
				continue
			if terrain_data.terrain_for_hex(hex) != "rocky_outcrop" or not _contains(hex, chunk_min, chunk_size):
				continue
			if _rock_roll(hex) < 0.42:
				continue
			placements.append(hex)
	for hex in placements:
		_add_outcrop_rock(parent, terrain_data, hex, hex_radius)
	return {"ok": true, "rock_count": placements.size(), "anchor": centre}

static func _add_outcrop_rock(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := Node3D.new()
	root.name = "AshveilOutcropRock_%d_%d" % [hex.x, hex.y]
	root.position = HexGrid.axial_to_world(hex, radius, terrain_data.elevation_for_hex(hex))
	root.rotation.y = deg_to_rad(float(posmod(hex.x * 37 + hex.y * 19, 360)))
	parent.add_child(root)
	var seed := _rock_roll(hex)
	var height := 1.2 + seed * 2.0
	var width := 0.75 + fposmod(seed * 7.3, 0.7)
	var stone := _stone_material(Color("#68645e").lerp(Color("#8a8172"), seed))
	var dark := _stone_material(Color("#454440"))
	var shard := MeshInstance3D.new()
	shard.name = "JaggedOutcrop"
	var shard_mesh := CylinderMesh.new()
	shard_mesh.top_radius = width * 0.22
	shard_mesh.bottom_radius = width
	shard_mesh.height = height
	shard_mesh.radial_segments = 5
	shard.mesh = shard_mesh
	shard.position = Vector3(0.0, height * 0.5, 0.0)
	shard.rotation = Vector3(deg_to_rad(4.0 + seed * 12.0), 0.0, deg_to_rad(-8.0 + seed * 16.0))
	shard.material_override = stone
	root.add_child(shard)
	var shoulder := MeshInstance3D.new()
	shoulder.name = "BrokenRockShoulder"
	var shoulder_mesh := SphereMesh.new()
	shoulder_mesh.radius = width * 0.72
	shoulder_mesh.height = width * 1.25
	shoulder.mesh = shoulder_mesh
	shoulder.position = Vector3(width * 0.42, height * 0.34, width * 0.16)
	shoulder.scale = Vector3(1.0, 0.72, 0.82)
	shoulder.material_override = dark
	root.add_child(shoulder)

static func _stone_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	material.metallic = 0.0
	return material

static func _rock_roll(hex: Vector2i) -> float:
	var value := sin(float(hex.x) * 12.9898 + float(hex.y) * 78.233) * 43758.5453
	return value - floor(value)

static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size

static func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2)
