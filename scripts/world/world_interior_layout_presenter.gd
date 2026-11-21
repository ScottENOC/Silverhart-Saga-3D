class_name WorldInteriorLayoutPresenter
extends RefCounted
## Builds a complete authored interior layout from reusable feature definitions.
## This layer owns static presentation only; doors, floors and interaction state
## remain controlled by the active location/campaign.

const FEATURE_FACTORY = preload("res://scripts/world/world_interior_feature_factory.gd")

static func present(
	parent: Node3D,
	definition: Dictionary,
	materials: Dictionary,
	map_data: Variant,
	hex_radius: float
) -> Dictionary:
	if parent == null or definition.is_empty() or map_data == null or hex_radius <= 0.0:
		return {"ok": false, "reason": "invalid_parent_layout_map_or_scale"}
	var ground_definition: Variant = definition.get("ground", {})
	var floor_definition: Variant = definition.get("hex_floor", {})
	var door_definition: Variant = definition.get("door", {})
	var upper_tiles_definition: Variant = definition.get("upper_floor_tiles", {})
	var building_shell_definition: Dictionary = definition.get("building_shell", {})
	var upper_exterior_definition: Dictionary = definition.get("upper_exterior", {})
	var upper_floor_definition: Dictionary = definition.get("upper_floor", {})
	var upper_rooms_definition: Dictionary = definition.get("upper_rooms", {})
	var taproom_definition: Dictionary = definition.get("taproom", {})
	var roof_definition: Dictionary = definition.get("roof", {})
	if not ground_definition is Dictionary or not floor_definition is Dictionary:
		return {"ok": false, "reason": "invalid_ground_or_hex_floor_definition"}
	if not door_definition is Dictionary or not upper_tiles_definition is Dictionary:
		return {"ok": false, "reason": "invalid_door_or_upper_floor_definition"}
	if not materials.has("dark_wood") or not materials.has("timber"):
		return {"ok": false, "reason": "missing_bed_materials"}
	for material_key in [
		String(ground_definition.get("material", "")),
		String(floor_definition.get("walkable_material", "")),
		String(floor_definition.get("interior_material", "")),
		String(floor_definition.get("blocked_material", "")),
		String(upper_tiles_definition.get("material", "")),
		String(door_definition.get("leaf_material", ""))
	]:
		if not materials.has(material_key) or materials[material_key] == null:
			return {"ok": false, "reason": "missing_material_%s" % material_key}

	var ground := MeshInstance3D.new()
	ground.name = String(ground_definition.get("name", "InteriorGround"))
	var ground_mesh := PlaneMesh.new()
	var ground_size: Vector2 = ground_definition.get("size", Vector2.ZERO)
	ground_mesh.size = ground_size
	if ground_mesh.size.x <= 0.0 or ground_mesh.size.y <= 0.0:
		return {"ok": false, "reason": "invalid_ground_size"}
	ground.mesh = ground_mesh
	ground.position.y = float(ground_definition.get("y", 0.0))
	ground.material_override = materials[String(ground_definition["material"])]
	parent.add_child(ground)

	var tile_thickness := float(floor_definition.get("tile_thickness", 0.12))
	var tile_mesh := _create_hex_tile_mesh(hex_radius, tile_thickness)
	if tile_mesh == null:
		return {"ok": false, "reason": "could_not_create_hex_mesh"}
	var lower_tiles := 0
	for q in range(int(floor_definition.get("q_min", -7)), int(floor_definition.get("q_max", 7)) + 1):
		for r in range(int(floor_definition.get("r_min", -7)), int(floor_definition.get("r_max", 7)) + 1):
			var hex := Vector2i(q, r)
			if not map_data.has_cell(hex):
				continue
			var centre := HexGrid.axial_to_world(hex, hex_radius)
			var inside_room := absf(centre.x) < float(floor_definition.get("room_half_width", 8.0)) - 0.2 				and absf(centre.z) < float(floor_definition.get("room_half_depth", 5.5)) - 0.2
			var tile := MeshInstance3D.new()
			tile.name = "InteriorHex_%d_%d" % [q, r]
			tile.mesh = tile_mesh
			tile.position = HexGrid.axial_to_world(
				hex,
				hex_radius,
				float(floor_definition.get("inside_y", 0.06)) if inside_room else float(floor_definition.get("outside_y", -0.07))
			)
			var material_key := String(floor_definition.get("interior_material", "floor")) if inside_room else String(floor_definition.get("walkable_material", "grass"))
			if not map_data.is_walkable(hex):
				material_key = String(floor_definition.get("blocked_material", "blocked"))
			tile.material_override = materials[material_key]
			parent.add_child(tile)
			lower_tiles += 1

	var shell := FEATURE_FACTORY.present(parent, building_shell_definition, materials)
	if shell == null:
		return {"ok": false, "reason": "building_shell_presentation_failed"}
	var door_pivot := Node3D.new()
	door_pivot.name = String(door_definition.get("pivot_name", "DoorHinge"))
	door_pivot.position = door_definition.get("pivot_position", Vector3.ZERO)
	shell.add_child(door_pivot)
	var door_leaf := _add_box(
		door_pivot,
		String(door_definition.get("leaf_name", "DoorLeaf")),
		door_definition.get("leaf_position", Vector3.ZERO),
		door_definition.get("leaf_size", Vector3.ONE),
		materials[String(door_definition.get("leaf_material", "dark_wood"))]
	)

	var upper_exterior := FEATURE_FACTORY.present(parent, upper_exterior_definition, materials)
	var upper_floor := FEATURE_FACTORY.present(parent, upper_floor_definition, materials)
	if upper_exterior == null or upper_floor == null:
		return {"ok": false, "reason": "upper_storey_presentation_failed"}
	var upper_tiles := Node3D.new()
	upper_tiles.name = "UpperHexFloor"
	upper_floor.add_child(upper_tiles)
	var upper_floor_y := float(upper_tiles_definition.get("floor_y", 3.38))
	for q in range(int(upper_tiles_definition.get("q_min", -4)), int(upper_tiles_definition.get("q_max", 4)) + 1):
		var row_shift := -floori(float(q) / 2.0)
		for row in range(int(upper_tiles_definition.get("row_min", -2)), int(upper_tiles_definition.get("row_max", 2)) + 1):
			var local_hex := Vector2i(q, row + row_shift)
			var local_world := HexGrid.axial_to_world(local_hex, hex_radius)
			var tile := MeshInstance3D.new()
			tile.name = "UpperHex_%d_%d" % [q, row]
			tile.mesh = tile_mesh
			tile.position = Vector3(local_world.x, upper_floor_y, local_world.z)
			tile.material_override = materials[String(upper_tiles_definition.get("material", "floor"))]
			upper_tiles.add_child(tile)

	var upper_interior := Node3D.new()
	upper_interior.name = "UpperBedrooms"
	upper_floor.add_child(upper_interior)
	var upper_rooms := FEATURE_FACTORY.present(upper_interior, upper_rooms_definition, materials)
	if upper_rooms == null:
		return {"ok": false, "reason": "upper_room_presentation_failed"}
	for bed_definition in definition.get("beds", []):
		if not bed_definition is Dictionary or not bed_definition.get("hex") is Vector2i or not bed_definition.get("blanket") is Color:
			return {"ok": false, "reason": "invalid_bed_definition"}
		_present_bed(upper_interior, bed_definition, materials, hex_radius, upper_floor_y)

	var taproom := FEATURE_FACTORY.present(parent, taproom_definition, materials)
	if taproom == null:
		return {"ok": false, "reason": "taproom_presentation_failed"}
	var roof := FEATURE_FACTORY.present(parent, roof_definition, materials)
	if roof == null:
		return {"ok": false, "reason": "roof_presentation_failed"}
	roof.visible = false

	return {
		"ok": true,
		"ground": ground,
		"tile_mesh": tile_mesh,
		"lower_tile_count": lower_tiles,
		"building": shell,
		"door_pivot": door_pivot,
		"door_leaf": door_leaf,
		"upper_exterior": upper_exterior,
		"upper_floor": upper_floor,
		"upper_tiles": upper_tiles,
		"upper_interior": upper_interior,
		"roof": roof,
		"taproom": taproom
	}

static func _create_hex_tile_mesh(hex_radius: float, tile_thickness: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := HexGrid.corner_offsets(hex_radius)
	var half_height := tile_thickness * 0.5
	for i in range(HexGrid.SIDE_COUNT):
		var next_i := (i + 1) % HexGrid.SIDE_COUNT
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(0.0, half_height, 0.0))
		surface.add_vertex(Vector3(corners[next_i].x, half_height, corners[next_i].y))
		surface.add_vertex(Vector3(corners[i].x, half_height, corners[i].y))
	for i in range(HexGrid.SIDE_COUNT):
		var next_i := (i + 1) % HexGrid.SIDE_COUNT
		var a := Vector3(corners[i].x, half_height, corners[i].y)
		var b := Vector3(corners[next_i].x, half_height, corners[next_i].y)
		var c := Vector3(corners[next_i].x, -half_height, corners[next_i].y)
		var d := Vector3(corners[i].x, -half_height, corners[i].y)
		var angle := deg_to_rad(60.0 * (float(i) + 0.5))
		var normal := Vector3(cos(angle), 0.0, sin(angle))
		surface.set_normal(normal)
		surface.add_vertex(a)
		surface.add_vertex(b)
		surface.add_vertex(c)
		surface.set_normal(normal)
		surface.add_vertex(a)
		surface.add_vertex(c)
		surface.add_vertex(d)
	return surface.commit()

static func _present_bed(parent: Node3D, definition: Dictionary, materials: Dictionary, hex_radius: float, floor_y: float) -> void:
	var bed := Node3D.new()
	bed.name = String(definition.get("name", "Bed"))
	bed.position = HexGrid.axial_to_world(definition["hex"], hex_radius, floor_y + 0.17)
	parent.add_child(bed)
	var blanket_material := StandardMaterial3D.new()
	blanket_material.albedo_color = definition["blanket"]
	blanket_material.roughness = 0.88
	blanket_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_box(bed, "BedFrame", Vector3.ZERO, Vector3(1.25, 0.38, 2.15), materials["dark_wood"])
	_add_box(bed, "Mattress", Vector3(0.0, 0.22, 0.0), Vector3(1.15, 0.18, 2.0), _material(Color(0.78, 0.72, 0.58)))
	_add_box(bed, "Blanket", Vector3(0.0, 0.34, 0.28), Vector3(1.12, 0.12, 1.35), blanket_material)
	_add_box(bed, "Pillow", Vector3(0.0, 0.36, -0.78), Vector3(0.82, 0.12, 0.38), _material(Color(0.82, 0.79, 0.68)))
	_add_box(bed, "Headboard", Vector3(0.0, 0.55, -1.0), Vector3(1.3, 0.95, 0.12), materials["timber"])

static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.88
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

static func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance
