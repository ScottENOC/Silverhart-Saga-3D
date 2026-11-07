extends RefCounted
class_name AccessoryAttachment
## Attaches reusable accessory scenes to named GLB socket nodes.

static func attach(character_root: Node3D, socket_name: String, accessory_scene: PackedScene, accessory_id: String) -> Node3D:
	if character_root == null or accessory_scene == null or accessory_id.is_empty():
		return null
	var socket := character_root.find_child(socket_name, true, false) as Node3D
	if socket == null:
		push_warning("Character is missing accessory socket: " + socket_name)
		return null
	var instance := accessory_scene.instantiate() as Node3D
	if instance == null:
		push_warning("Accessory scene root must be Node3D: " + accessory_id)
		return null
	instance.name = "Accessory_" + accessory_id
	instance.set_meta("accessory_id", accessory_id)
	socket.add_child(instance)
	instance.transform = Transform3D.IDENTITY
	return instance

static func attach_piercing(character_root: Node3D, accessory_id: String) -> MeshInstance3D:
	if character_root == null or accessory_id.is_empty():
		return null
	var socket_name := ""
	var radius := 0.008
	var colour := Color(0.74, 0.78, 0.82, 1.0)
	match accessory_id:
		"nipple_piercing_left":
			socket_name = "SOCKET_Nipple_L"
		"nipple_piercing_right":
			socket_name = "SOCKET_Nipple_R"
		"clitoral_hood_piercing":
			socket_name = "SOCKET_ClitoralHood"
			radius = 0.0055
			colour = Color(0.78, 0.64, 0.38, 1.0)
		_:
			push_warning("Unknown piercing accessory id: " + accessory_id)
			return null
	var socket := character_root.find_child(socket_name, true, false) as Node3D
	if socket == null:
		push_warning("Character is missing piercing socket: " + socket_name)
		return null
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.82
	material.roughness = 0.24
	var instance := MeshInstance3D.new()
	instance.name = "Accessory_" + accessory_id
	instance.material_override = material
	instance.set_meta("accessory_id", accessory_id)
	if accessory_id == "clitoral_hood_piercing":
		instance.mesh = _curved_barbell_mesh(radius * 0.34, radius * 1.65)
	else:
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.78
		torus.outer_radius = radius
		torus.rings = 32
		torus.ring_segments = 10
		instance.mesh = torus
	socket.add_child(instance)
	instance.transform = Transform3D.IDENTITY
	if accessory_id == "clitoral_hood_piercing":
		for x in [-radius * 1.65, radius * 1.65]:
			var bead := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = radius * 0.42
			sphere.height = radius * 0.84
			bead.mesh = sphere
			bead.material_override = material
			bead.position.x = x
			bead.set_meta("accessory_id", accessory_id)
			instance.add_child(bead)
	return instance


static func _curved_barbell_mesh(tube_radius: float, half_span: float) -> ArrayMesh:
	# A shallow curved bar following the surface, with separate end beads.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var steps := 16
	var sides := 8
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x: float = lerpf(-half_span, half_span, t)
		var y := 0.0018 * sin(PI * t)
		var centre := Vector3(x, y, 0.0)
		var tangent := Vector3(1.0, 0.0018 * PI * cos(PI * t) / (2.0 * half_span), 0.0).normalized()
		var side := Vector3(-tangent.y, tangent.x, 0.0).normalized()
		for j in range(sides):
			var a := TAU * float(j) / float(sides)
			var radial := side * cos(a) + Vector3.BACK * sin(a)
			vertices.append(centre + radial * tube_radius)
			normals.append(radial)
	for i in range(steps):
		for j in range(sides):
			var a := i * sides + j
			var b := i * sides + (j + 1) % sides
			var c := (i + 1) * sides + (j + 1) % sides
			var d := (i + 1) * sides + j
			indices.append_array(PackedInt32Array([a, b, c, a, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func remove_by_id(character_root: Node, accessory_id: String) -> bool:
	if character_root == null:
		return false
	for node in character_root.find_children("*", "Node3D", true, false):
		if str(node.get_meta("accessory_id", "")) == accessory_id:
			node.queue_free()
			return true
	return false
