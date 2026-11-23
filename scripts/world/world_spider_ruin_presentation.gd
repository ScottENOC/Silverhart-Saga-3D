extends RefCounted
## Broken-stone dressing for the small source-authored spider ruin near Reddale.
## The two spider defenders, Mirabel's quest and loot remain campaign-owned.

const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

static func present_chunk(parent: Node3D, terrain_data: Campaign2WorldTerrainData, chunk_min: Vector2i, chunk_size: int, hex_radius: float) -> Dictionary:
	if parent == null or terrain_data == null or chunk_size <= 0 or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_spider_ruin_presentation_arguments"}
	var count := 0
	for q in range(FEATURES.MIRABEL_SPIDER_RUIN_CENTRE.x - FEATURES.MIRABEL_SPIDER_RUIN_RADIUS, FEATURES.MIRABEL_SPIDER_RUIN_CENTRE.x + FEATURES.MIRABEL_SPIDER_RUIN_RADIUS + 1):
		for r in range(FEATURES.MIRABEL_SPIDER_RUIN_CENTRE.y - FEATURES.MIRABEL_SPIDER_RUIN_RADIUS, FEATURES.MIRABEL_SPIDER_RUIN_CENTRE.y + FEATURES.MIRABEL_SPIDER_RUIN_RADIUS + 1):
			var hex := Vector2i(q, r)
			var distance := _axial_distance(hex, FEATURES.MIRABEL_SPIDER_RUIN_CENTRE)
			if distance < 1 or distance > FEATURES.MIRABEL_SPIDER_RUIN_RADIUS:
				continue
			if terrain_data.terrain_for_hex(hex) != "rocky_outcrop" or not _contains(hex, chunk_min, chunk_size):
				continue
			if _rubble_roll(hex) < 0.48:
				continue
			_add_rubble(parent, terrain_data, hex, hex_radius)
			count += 1
	return {"ok": true, "rubble_count": count}

static func _add_rubble(parent: Node3D, terrain_data: Campaign2WorldTerrainData, hex: Vector2i, radius: float) -> void:
	var root := Node3D.new()
	root.name = "MirabelRuinRubble_%d_%d" % [hex.x, hex.y]
	root.position = HexGrid.axial_to_world(hex, radius, terrain_data.elevation_for_hex(hex))
	var seed := _rubble_roll(hex)
	root.rotation.y = deg_to_rad(float(posmod(hex.x * 29 + hex.y * 43, 360)))
	parent.add_child(root)
	var stone := _material(Color("#77736b").lerp(Color("#9a9180"), seed))
	var shadow := _material(Color("#4b4a45"))
	var base := MeshInstance3D.new()
	base.name = "CollapsedMasonry"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.4 + seed * 0.8, 0.32 + seed * 0.16, 0.85 + seed * 0.45)
	base.mesh = base_mesh
	base.position = Vector3(0.0, base_mesh.size.y * 0.5, 0.0)
	base.rotation.y = deg_to_rad(seed * 35.0)
	base.material_override = stone
	root.add_child(base)
	var fragment := MeshInstance3D.new()
	fragment.name = "FallenBlock"
	var fragment_mesh := BoxMesh.new()
	fragment_mesh.size = Vector3(0.55 + seed * 0.35, 0.42 + seed * 0.3, 0.5)
	fragment.mesh = fragment_mesh
	fragment.position = Vector3(0.32, 0.52, -0.28)
	fragment.rotation = Vector3(deg_to_rad(18.0 + seed * 22.0), 0.0, deg_to_rad(12.0 + seed * 20.0))
	fragment.material_override = shadow
	root.add_child(fragment)

static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material

static func _rubble_roll(hex: Vector2i) -> float:
	var value := sin(float(hex.x) * 17.17 + float(hex.y) * 41.73) * 24634.6345
	return value - floor(value)

static func _contains(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size

static func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2)
