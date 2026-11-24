class_name CampWorldPresentation
extends Node3D
## Lightweight in-world campsite props. Character simulation remains authoritative;
## this node only presents the chosen ground location and its equipment.

var _camp_root: Node3D
var _world_position_for_hex: Callable


func configure(world_position_for_hex: Callable) -> void:
	_world_position_for_hex = world_position_for_hex


func present_camp(site: Dictionary, sleeping_arrangements: Array[Dictionary]) -> void:
	clear_camp()
	var position := Vector3.ZERO
	var position_value: Variant = site.get("position", Vector3.ZERO)
	if position_value is Vector3:
		position = position_value
	elif _world_position_for_hex.is_valid():
		var hex_value: Variant = site.get("hex", Vector2i.ZERO)
		if hex_value is Vector2i:
			position = _world_position_for_hex.call(hex_value)
	_camp_root = Node3D.new()
	_camp_root.name = "InWorldCampsite"
	_camp_root.position = position
	add_child(_camp_root)
	_create_campfire()
	_create_tents(sleeping_arrangements)
	_create_bedrolls(sleeping_arrangements)
	_create_nameplate()


func clear_camp() -> void:
	if is_instance_valid(_camp_root):
		_camp_root.queue_free()
	_camp_root = null


func _material(colour: Color, roughness: float = 0.9, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.4
	return material


func _mesh_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _mesh_cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _create_campfire() -> void:
	var stone := _material(Color("#68645b"))
	var wood := _material(Color("#49301d"))
	var flame := _material(Color("#ff8a32"), 0.35, Color("#ff5b19"))
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = 0.19
		stone_mesh.height = 0.20
		var rock := MeshInstance3D.new()
		rock.name = "FireRingStone_%02d" % index
		rock.mesh = stone_mesh
		rock.position = Vector3(cos(angle) * 0.72, 0.10, sin(angle) * 0.72)
		rock.material_override = stone
		_camp_root.add_child(rock)
	_mesh_cylinder(_camp_root, "Firewood_A", Vector3(0.0, 0.13, 0.0), 0.095, 1.0, wood, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_mesh_cylinder(_camp_root, "Firewood_B", Vector3(0.0, 0.19, 0.0), 0.095, 0.9, wood, Vector3(0.0, deg_to_rad(90.0), deg_to_rad(90.0)))
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.30
	flame_mesh.height = 0.75
	var fire := MeshInstance3D.new()
	fire.name = "CampfireFlame"
	fire.mesh = flame_mesh
	fire.position = Vector3(0.0, 0.48, 0.0)
	fire.material_override = flame
	_camp_root.add_child(fire)
	var light := OmniLight3D.new()
	light.name = "CampfireLight"
	light.position = Vector3(0.0, 1.1, 0.0)
	light.light_color = Color("#ff9b50")
	light.light_energy = 1.1
	light.omni_range = 9.0
	_camp_root.add_child(light)


func _create_tents(arrangements: Array[Dictionary]) -> void:
	var tent_material := _material(Color("#a99a78"))
	var seam_material := _material(Color("#67583f"))
	var tent_index := 0
	for arrangement in arrangements:
		if int(arrangement.get("tent_index", -1)) < 0:
			continue
		var offset := Vector3(-3.0 + float(tent_index % 2) * 6.0, 0.0, -3.2 - float(tent_index / 2) * 4.2)
		var tent := Node3D.new()
		tent.name = "Tent_%02d" % tent_index
		tent.position = offset
		_camp_root.add_child(tent)
		_mesh_box(tent, "Canvas_Left", Vector3(-0.48, 0.72, 0.0), Vector3(1.35, 0.09, 2.0), tent_material, Vector3(0.0, 0.0, deg_to_rad(-47.0)))
		_mesh_box(tent, "Canvas_Right", Vector3(0.48, 0.72, 0.0), Vector3(1.35, 0.09, 2.0), tent_material, Vector3(0.0, 0.0, deg_to_rad(47.0)))
		_mesh_cylinder(tent, "RidgePole", Vector3(0.0, 1.35, 0.0), 0.055, 2.2, seam_material, Vector3(deg_to_rad(90.0), 0.0, 0.0))
		tent_index += 1


func _create_bedrolls(arrangements: Array[Dictionary]) -> void:
	var bedroll_material := _material(Color("#697b83"))
	var index := 0
	for arrangement in arrangements:
		for _character_id in arrangement.get("character_ids", []):
			var angle := TAU * float(index) / 6.0
			var offset := Vector3(cos(angle) * 2.0, 0.09, sin(angle) * 2.0)
			var roll := _mesh_box(_camp_root, "Bedroll_%02d" % index, offset, Vector3(0.72, 0.14, 1.35), bedroll_material)
			roll.rotation.y = -angle
			index += 1


func _create_nameplate() -> void:
	var label := Label3D.new()
	label.name = "CampNameplate"
	label.text = "CAMP"
	label.position = Vector3(0.0, 2.3, 0.0)
	label.font_size = 28
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#f0dfbd")
	label.outline_size = 5
	label.outline_modulate = Color("#20231d")
	_camp_root.add_child(label)
