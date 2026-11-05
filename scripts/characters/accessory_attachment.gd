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
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.78
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 10
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.82
	material.roughness = 0.24
	var instance := MeshInstance3D.new()
	instance.name = "Accessory_" + accessory_id
	instance.mesh = torus
	instance.material_override = material
	instance.set_meta("accessory_id", accessory_id)
	socket.add_child(instance)
	instance.transform = Transform3D.IDENTITY
	return instance

static func remove_by_id(character_root: Node, accessory_id: String) -> bool:
	if character_root == null:
		return false
	for node in character_root.find_children("*", "Node3D", true, false):
		if str(node.get_meta("accessory_id", "")) == accessory_id:
			node.queue_free()
			return true
	return false
