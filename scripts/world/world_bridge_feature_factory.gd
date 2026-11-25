class_name WorldBridgeFeatureFactory
extends RefCounted
## Builds a small bridge assembly from authored axial placement and box-part data.
## This factory knows nothing about a particular settlement or river.

static func create_bridge(parent: Node3D, definition: Dictionary, materials: Dictionary, hex_radius: float) -> Node3D:
	if parent == null or hex_radius <= 0.0:
		return null
	var feature_id := String(definition.get("id", ""))
	var centre: Variant = definition.get("centre")
	var parts: Array = definition.get("parts", [])
	if feature_id.is_empty() or not centre is Vector2i or parts.is_empty():
		push_warning("Bridge definition requires an id, axial centre and parts")
		return null
	var validated_parts: Array[Dictionary] = []
	for part in parts:
		if not part is Dictionary:
			return null
		var part_name := String(part.get("name", ""))
		var material_key := String(part.get("material", ""))
		var position: Variant = part.get("position")
		var size: Variant = part.get("size")
		if part_name.is_empty() or not position is Vector3 or not size is Vector3:
			push_warning("Invalid bridge part in %s" % feature_id)
			return null
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0 or not materials.has(material_key):
			push_warning("Invalid bridge dimensions or material in %s/%s" % [feature_id, part_name])
			return null
		validated_parts.append(part)
	var root := Node3D.new()
	root.name = feature_id
	root.position = HexGrid.axial_to_world(centre, hex_radius, float(definition.get("elevation", 0.0)))
	root.rotation.y = deg_to_rad(float(definition.get("rotation_degrees", 0.0)))
	for part in validated_parts:
		var instance := MeshInstance3D.new()
		instance.name = String(part["name"])
		var mesh := BoxMesh.new()
		mesh.size = part["size"]
		instance.mesh = mesh
		instance.position = part["position"]
		instance.material_override = materials[String(part["material"])]
		root.add_child(instance)
	parent.add_child(root)
	return root
