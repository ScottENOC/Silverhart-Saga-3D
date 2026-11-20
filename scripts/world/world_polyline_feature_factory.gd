class_name WorldPolylineFeatureFactory
extends RefCounted
## Builds disposable ribbon meshes from authored axial centre-lines.
## Definitions own route identity and geometry; callers supply material bindings.

const ORGANIC_FEATURES = preload("res://scripts/world/organic_world_features.gd")

static func render_features(
	parent: Node3D,
	definitions: Array,
	materials: Dictionary,
	hex_radius: float
) -> Array[Node3D]:
	var created: Array[Node3D] = []
	if parent == null or hex_radius <= 0.0:
		return created
	var seen_ids: Dictionary = {}
	for definition in definitions:
		if not definition is Dictionary:
			continue
		var feature_id := String(definition.get("id", ""))
		var material_key := String(definition.get("material", ""))
		var axial_points: Array = definition.get("points", [])
		var raw_widths: Array = definition.get("widths", [])
		if feature_id.is_empty() or seen_ids.has(feature_id):
			push_warning("Polyline feature requires a unique non-empty id: %s" % feature_id)
			continue
		seen_ids[feature_id] = true
		if not materials.has(material_key) or axial_points.size() < 2 or axial_points.size() != raw_widths.size():
			push_warning("Invalid polyline feature definition: %s" % feature_id)
			continue
		var points: Array[Vector3] = []
		var widths := PackedFloat32Array()
		var valid := true
		for index in range(axial_points.size()):
			if not axial_points[index] is Vector2i:
				valid = false
				break
			var width := float(raw_widths[index])
			if width <= 0.0:
				valid = false
				break
			points.append(HexGrid.axial_to_world(axial_points[index], hex_radius, float(definition.get("elevation", 0.0))))
			widths.append(width)
		if not valid:
			push_warning("Polyline feature contains invalid points or widths: %s" % feature_id)
			continue
		var mesh_node := ORGANIC_FEATURES.make_ribbon(
			feature_id,
			points,
			widths,
			materials[material_key],
			float(definition.get("y_offset", 0.0)),
			int(definition.get("samples_per_segment", 8))
		)
		if mesh_node.mesh == null:
			continue
		parent.add_child(mesh_node)
		created.append(mesh_node)
	return created
