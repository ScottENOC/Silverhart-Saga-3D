extends RefCounted
## Reusable renderer for authored agricultural fields, crop rows and post-and-rail fences.
## Definitions contain presentation geometry only; this factory does not alter farm simulation.

const ORGANIC_FEATURES = preload("res://scripts/world/organic_world_features.gd")

static func render_features(parent: Node3D, fields: Array, crop_rows: Array, fences: Array, materials: Dictionary, hex_radius: float) -> Dictionary:
	if parent == null or hex_radius <= 0.0:
		return {"ok": false, "fields": 0, "crop_rows": 0, "fences": 0}
	var ids: Dictionary = {}
	for definition in fields:
		if not _valid_polygon_definition(definition, materials, ids):
			push_warning("Invalid agricultural field definition")
			return {"ok": false, "fields": 0, "crop_rows": 0, "fences": 0}
	for definition in crop_rows:
		if not _valid_crop_row_definition(definition, materials, ids):
			push_warning("Invalid agricultural crop-row definition")
			return {"ok": false, "fields": 0, "crop_rows": 0, "fences": 0}
	for definition in fences:
		if not _valid_fence_definition(definition, materials, ids):
			push_warning("Invalid agricultural fence definition")
			return {"ok": false, "fields": 0, "crop_rows": 0, "fences": 0}

	for definition in fields:
		_render_field(parent, definition, materials[String(definition["material"])], hex_radius)
	for definition in crop_rows:
		_render_crop_row(parent, definition, materials[String(definition["material"])], hex_radius)
	for definition in fences:
		_render_fence(parent, definition, materials[String(definition["material"])], hex_radius)
	return {"ok": true, "fields": fields.size(), "crop_rows": crop_rows.size(), "fences": fences.size()}

static func _valid_id(definition: Variant, ids: Dictionary) -> bool:
	if not definition is Dictionary:
		return false
	var feature_id := String(definition.get("id", ""))
	if feature_id.is_empty() or ids.has(feature_id):
		return false
	ids[feature_id] = true
	return true

static func _valid_material(definition: Dictionary, materials: Dictionary) -> bool:
	var key := String(definition.get("material", ""))
	return materials.has(key) and materials[key] is Material and materials[key] != null

static func _valid_axial_points(points: Variant, minimum: int) -> bool:
	if not points is Array or points.size() < minimum:
		return false
	for point in points:
		if not point is Vector2i:
			return false
	return true

static func _valid_polygon_definition(definition: Variant, materials: Dictionary, ids: Dictionary) -> bool:
	if not _valid_id(definition, ids) or not _valid_material(definition, materials):
		return false
	return _valid_axial_points(definition.get("corners"), 3)

static func _valid_crop_row_definition(definition: Variant, materials: Dictionary, ids: Dictionary) -> bool:
	if not _valid_id(definition, ids) or not _valid_material(definition, materials):
		return false
	var points: Variant = definition.get("points")
	if not _valid_axial_points(points, 2):
		return false
	var widths: Variant = definition.get("widths")
	var expected_widths: int = points.size() + (1 if definition.has("midpoint_offset") and points.size() == 2 else 0)
	if not widths is Array or widths.size() != expected_widths:
		return false
	for width in widths:
		if float(width) <= 0.0:
			return false
	return true

static func _valid_fence_definition(definition: Variant, materials: Dictionary, ids: Dictionary) -> bool:
	if not _valid_id(definition, ids) or not _valid_material(definition, materials):
		return false
	if not _valid_axial_points(definition.get("points"), 2):
		return false
	return float(definition.get("post_spacing", 2.5)) > 0.0 and float(definition.get("post_height", 1.25)) > 0.0

static func _render_field(parent: Node3D, definition: Dictionary, material: Material, hex_radius: float) -> void:
	var points: Array[Vector3] = []
	var centre := Vector3.ZERO
	for hex in definition["corners"]:
		var point := HexGrid.axial_to_world(hex, hex_radius, float(definition.get("elevation", -0.16)))
		points.append(point)
		centre += point
	centre /= float(points.size())
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size()):
		surface.set_normal(Vector3.UP)
		surface.add_vertex(centre)
		surface.add_vertex(points[index])
		surface.add_vertex(points[(index + 1) % points.size()])
	var instance := MeshInstance3D.new()
	instance.name = String(definition["id"])
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

static func _render_crop_row(parent: Node3D, definition: Dictionary, material: Material, hex_radius: float) -> void:
	var points: Array[Vector3] = []
	for hex in definition["points"]:
		points.append(HexGrid.axial_to_world(hex, hex_radius, float(definition.get("elevation", -0.10))))
	if definition.has("midpoint_offset") and points.size() == 2:
		var midpoint: Vector3 = (points[0] + points[1]) * 0.5 + definition["midpoint_offset"]
		points.insert(1, midpoint)
	var widths := PackedFloat32Array()
	for width in definition["widths"]:
		widths.append(float(width))
	var ribbon := ORGANIC_FEATURES.make_ribbon(
		String(definition["id"]), points, widths, material, 0.0,
		int(definition.get("samples_per_segment", 4))
	)
	parent.add_child(ribbon)

static func _render_fence(parent: Node3D, definition: Dictionary, material: Material, hex_radius: float) -> void:
	var root := Node3D.new()
	root.name = String(definition["id"])
	parent.add_child(root)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = float(definition.get("post_top_radius", 0.07))
	post_mesh.bottom_radius = float(definition.get("post_bottom_radius", 0.11))
	post_mesh.height = float(definition.get("post_height", 1.25))
	post_mesh.radial_segments = int(definition.get("post_radial_segments", 6))
	var points: Array = definition["points"]
	for index in range(points.size() - 1):
		var a := HexGrid.axial_to_world(points[index], hex_radius, 0.0)
		var b := HexGrid.axial_to_world(points[index + 1], hex_radius, 0.0)
		var distance := a.distance_to(b)
		var segments := maxi(1, ceili(distance / float(definition.get("post_spacing", 2.5))))
		for step in range(segments + 1):
			var t := float(step) / float(segments)
			var post := MeshInstance3D.new()
			post.name = "Post_%02d_%02d" % [index, step]
			post.mesh = post_mesh
			post.position = a.lerp(b, t) + Vector3.UP * (post_mesh.height * 0.5 - 0.005)
			post.material_override = material
			root.add_child(post)
		var midpoint := (a + b) * 0.5
		var direction := b - a
		var rail := _make_rail("Rail_Lower_%02d" % index, midpoint + Vector3.UP * float(definition.get("lower_rail_height", 0.42)), distance, material)
		rail.rotation.y = atan2(direction.x, direction.z)
		root.add_child(rail)
		var upper := _make_rail("Rail_Upper_%02d" % index, midpoint + Vector3.UP * float(definition.get("upper_rail_height", 0.82)), distance, material)
		upper.rotation.y = atan2(direction.x, direction.z)
		root.add_child(upper)

static func _make_rail(node_name: String, position: Vector3, length: float, material: Material) -> MeshInstance3D:
	var rail := MeshInstance3D.new()
	rail.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, length)
	rail.mesh = mesh
	rail.position = position
	rail.material_override = material
	return rail
