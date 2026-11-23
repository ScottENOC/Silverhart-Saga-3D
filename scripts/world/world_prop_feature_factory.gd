extends RefCounted
## Reusable renderer for small authored landmark, wayfinding and quest-dressing assemblies.
## Definitions describe primitive presentation parts; this factory owns no settlement logic.

static func render_features(parent: Node3D, definitions: Array, materials: Dictionary, hex_radius: float) -> bool:
	if parent == null or hex_radius <= 0.0:
		return false
	var ids: Dictionary = {}
	var validated: Array[Dictionary] = []
	for definition in definitions:
		if not _validate_definition(parent, definition, materials, ids):
			push_warning("Invalid authored prop definition")
			return false
		validated.append(definition)
	for definition in validated:
		_render_assembly(parent, definition, materials, hex_radius)
	return true

static func _validate_definition(parent: Node3D, definition: Variant, materials: Dictionary, ids: Dictionary) -> bool:
	if not definition is Dictionary:
		return false
	var feature_id := String(definition.get("id", ""))
	var parts: Variant = definition.get("parts", [])
	if feature_id.is_empty() or ids.has(feature_id) or not parts is Array or parts.is_empty():
		return false
	ids[feature_id] = true
	var parent_node := String(definition.get("parent_node", ""))
	if not parent_node.is_empty():
		var target := parent.get_node_or_null(parent_node)
		if not target is Node3D:
			return false
	elif not (definition.get("anchor") is Vector2i):
		return false
	var names: Dictionary = {}
	for part in parts:
		if not part is Dictionary:
			return false
		var part_name := String(part.get("name", ""))
		var part_type := String(part.get("type", ""))
		if part_name.is_empty() or names.has(part_name):
			return false
		names[part_name] = true
		if part_type not in ["box", "cylinder", "label3d", "omni_light"]:
			return false
		var material_key := String(part.get("material", ""))
		if part_type not in ["label3d", "omni_light"]:
			if not materials.has(material_key) or not (materials[material_key] is Material) or materials[material_key] == null:
				return false
		var position: Variant = part.get("position", Vector3.ZERO)
		if not position is Vector3:
			return false
		if part.has("axial") and not part["axial"] is Vector2i:
			return false
		if part_type == "box":
			var size: Variant = part.get("size")
			if not size is Vector3 or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
				return false
		elif part_type == "cylinder":
			if float(part.get("top_radius", 0.0)) <= 0.0 or float(part.get("bottom_radius", 0.0)) <= 0.0 or float(part.get("height", 0.0)) <= 0.0:
				return false
		elif part_type == "label3d" and String(part.get("text", "")).is_empty():
			return false
		elif part_type == "omni_light" and float(part.get("range", 0.0)) <= 0.0:
			return false
	return true

static func _render_assembly(parent: Node3D, definition: Dictionary, materials: Dictionary, hex_radius: float) -> void:
	var target: Node3D = parent
	var parent_node := String(definition.get("parent_node", ""))
	if not parent_node.is_empty():
		target = parent.get_node(parent_node) as Node3D
	var root := Node3D.new()
	root.name = String(definition["id"])
	if definition.has("anchor"):
		root.position = HexGrid.axial_to_world(definition["anchor"], hex_radius, float(definition.get("elevation", 0.0)))
	else:
		root.position = definition.get("local_offset", Vector3.ZERO)
	root.rotation.y = deg_to_rad(float(definition.get("rotation_degrees", 0.0)))
	target.add_child(root)
	for part in definition["parts"]:
		var instance := _make_part(part, materials, hex_radius, definition)
		root.add_child(instance)

static func _make_part(part: Dictionary, materials: Dictionary, hex_radius: float, definition: Dictionary) -> Node3D:
	var part_type := String(part["type"])
	var instance: Node3D
	if part_type == "box":
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part["size"]
		box.mesh = mesh
		instance = box
	elif part_type == "cylinder":
		var cylinder := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = float(part["top_radius"])
		mesh.bottom_radius = float(part["bottom_radius"])
		mesh.height = float(part["height"])
		mesh.radial_segments = int(part.get("radial_segments", 12))
		cylinder.mesh = mesh
		instance = cylinder
	elif part_type == "label3d":
		var label := Label3D.new()
		label.text = String(part["text"])
		label.font_size = int(part.get("font_size", 24))
		label.pixel_size = float(part.get("pixel_size", 0.01))
		label.modulate = part.get("modulate", Color.WHITE)
		label.outline_size = int(part.get("outline_size", 0))
		instance = label
	else:
		var light := OmniLight3D.new()
		light.light_color = part.get("color", Color("#ff8738"))
		light.light_energy = float(part.get("energy", 1.0))
		light.omni_range = float(part.get("range", 8.0))
		light.shadow_enabled = bool(part.get("shadow_enabled", false))
		instance = light
	instance.name = String(part["name"])
	instance.position = part.get("position", Vector3.ZERO)
	if part.has("axial"):
		var anchor: Vector2i = definition["anchor"]
		var point: Vector3 = HexGrid.axial_to_world(part["axial"], hex_radius, float(definition.get("elevation", 0.0)))
		var origin: Vector3 = HexGrid.axial_to_world(anchor, hex_radius, float(definition.get("elevation", 0.0)))
		instance.position.x += point.x - origin.x
		instance.position.z += point.z - origin.z
	instance.rotation.y = deg_to_rad(float(part.get("rotation_degrees", 0.0)))
	if part_type != "label3d":
		(instance as MeshInstance3D).material_override = materials[String(part["material"])]
	return instance
