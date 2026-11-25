class_name WorldInteriorFeatureFactory
extends RefCounted
## Presents reusable interior features from authored data.
## Supports box furnishings and labels; it does not own interaction or simulation state.

static func present(parent: Node3D, definition: Dictionary, materials: Dictionary) -> Node3D:
	if parent == null:
		return null
	var feature_id := String(definition.get("id", "")).strip_edges()
	var features: Variant = definition.get("features", [])
	if feature_id.is_empty() or not features is Array or features.is_empty():
		return null
	var validated: Array[Dictionary] = []
	for item in features:
		if not item is Dictionary:
			return null
		var kind := String(item.get("kind", "box"))
		var item_name := String(item.get("name", "")).strip_edges()
		if item_name.is_empty():
			return null
		if kind == "box":
			var position: Variant = item.get("position")
			var size: Variant = item.get("size")
			var material_key := String(item.get("material", ""))
			if not position is Vector3 or not size is Vector3:
				return null
			if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
				return null
			if not materials.has(material_key) or materials[material_key] == null:
				return null
		elif kind == "label":
			var position: Variant = item.get("position")
			if not position is Vector3 or String(item.get("text", "")).is_empty():
				return null
		else:
			return null
		validated.append(item)
	var root := Node3D.new()
	root.name = feature_id
	for item in validated:
		if String(item.get("kind", "box")) == "label":
			var label := Label3D.new()
			label.name = String(item["name"])
			label.text = String(item["text"])
			label.position = item["position"]
			label.font_size = int(item.get("font_size", 24))
			label.outline_size = int(item.get("outline_size", 5))
			label.modulate = item.get("colour", Color(0.9, 0.82, 0.62))
			root.add_child(label)
			continue
		var instance := MeshInstance3D.new()
		instance.name = String(item["name"])
		var mesh := BoxMesh.new()
		mesh.size = item["size"]
		instance.mesh = mesh
		instance.position = item["position"]
		instance.rotation_degrees = item.get("rotation_degrees", Vector3.ZERO)
		instance.material_override = materials[String(item["material"])]
		root.add_child(instance)
	parent.add_child(root)
	return root
