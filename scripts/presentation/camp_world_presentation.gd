class_name CampWorldPresentation
extends Node3D
## Lightweight in-world campsite props. Character simulation remains authoritative;
## this node only presents the chosen ground location and its equipment.

var _camp_root: Node3D
var _world_position_for_hex: Callable


func configure(world_position_for_hex: Callable) -> void:
	_world_position_for_hex = world_position_for_hex


func present_camp(site: Dictionary, sleeping_arrangements: Array[Dictionary], environment: Dictionary = {}) -> void:
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
	var dwelling_profile: Dictionary = site.get("dwelling_profile", {})
	var layout_id := String(dwelling_profile.get("layout_id", site.get("layout_id", "")))
	var is_livable_dwelling := bool(dwelling_profile.get("is_sheltered", false)) and not layout_id.is_empty()
	if is_livable_dwelling and not layout_id.is_empty():
		_create_dwelling_stations(site, dwelling_profile, environment, position)
	else:
		_create_campfire(bool(environment.get("fire_lit", false)))
	_create_tents(sleeping_arrangements)
	_create_bedrolls(sleeping_arrangements)
	_create_nameplate(_dwelling_display_name(String(dwelling_profile.get("dwelling_id", ""))) if is_livable_dwelling else "WILDERNESS CAMP")


func _create_dwelling_stations(site: Dictionary, profile: Dictionary, environment: Dictionary, base_position: Vector3) -> void:
	var layout_id := String(profile.get("layout_id", ""))
	var offsets: Dictionary = CampPartyActivityDirector.LAYOUT_STATION_OFFSETS.get(layout_id, {})
	if offsets.is_empty():
		return
	var station_root := Node3D.new()
	station_root.name = "DwellingStations"
	_camp_root.add_child(station_root)
	var origin_value: Variant = site.get("hex", Vector2i.ZERO)
	var origin_hex: Vector2i = origin_value if origin_value is Vector2i else Vector2i.ZERO
	for role_value in offsets.keys():
		var role := String(role_value)
		var offset: Vector2i = offsets[role_value]
		var station := Node3D.new()
		station.name = "DwellingStation_" + role
		if _world_position_for_hex.is_valid() and site.get("hex", null) is Vector2i:
			station.position = _world_position_for_hex.call(origin_hex + offset) - base_position
		else:
			station.position = Vector3(float(offset.x) * 1.7, 0.0, float(offset.y) * 1.7)
		station_root.add_child(station)
		# These are invisible routine anchors only. Actual furniture is owned and
		# placed by the player; do not furnish a newly acquired dwelling for free.


func _build_dwelling_station_prop(parent: Node3D, role: String, fire_lit: bool) -> void:
	var timber := _material(Color("#60432b"))
	var dark_timber := _material(Color("#39271b"))
	var stone := _material(Color("#77746a"))
	var cloth := _material(Color("#8a7960"))
	var iron := _material(Color("#454b4d"))
	var warm_light := _material(Color("#ffb45f"), 0.4, Color("#ff8a32"))
	match role:
		"hearth":
			_mesh_box(parent, "HearthStoneBase", Vector3(0.0, 0.22, 0.0), Vector3(1.0, 0.44, 0.82), stone)
			_mesh_box(parent, "HearthMantel", Vector3(0.0, 0.72, -0.10), Vector3(1.12, 0.12, 0.92), dark_timber)
			_mesh_box(parent, "HearthOpening", Vector3(0.0, 0.42, 0.36), Vector3(0.48, 0.42, 0.04), iron)
			if fire_lit:
				var ember := MeshInstance3D.new()
				var ember_mesh := SphereMesh.new()
				ember_mesh.radius = 0.22
				ember_mesh.height = 0.36
				ember.mesh = ember_mesh
				ember.position = Vector3(0.0, 0.42, 0.29)
				ember.material_override = warm_light
				parent.add_child(ember)
				var hearth_light := OmniLight3D.new()
				hearth_light.position = Vector3(0.0, 0.9, 0.6)
				hearth_light.light_color = Color("#ffad68")
				hearth_light.light_energy = 0.65
				hearth_light.omni_range = 5.0
				parent.add_child(hearth_light)
		"table":
			_mesh_box(parent, "TableTop", Vector3(0.0, 0.78, 0.0), Vector3(1.05, 0.14, 0.72), dark_timber)
			for x in [-0.42, 0.42]:
				for z in [-0.27, 0.27]:
					_mesh_box(parent, "TableLeg_%s_%s" % [x, z], Vector3(x, 0.38, z), Vector3(0.10, 0.76, 0.10), timber)
		"workshop":
			_mesh_box(parent, "WorkshopBenchTop", Vector3(0.0, 0.72, 0.0), Vector3(1.15, 0.16, 0.48), timber)
			for x in [-0.46, 0.46]:
				_mesh_box(parent, "WorkshopLeg_%s" % x, Vector3(x, 0.34, 0.0), Vector3(0.12, 0.68, 0.52), dark_timber)
			_mesh_box(parent, "ToolRack", Vector3(0.0, 1.05, -0.30), Vector3(0.95, 0.50, 0.08), dark_timber)
			_mesh_cylinder(parent, "HammerHandle", Vector3(-0.22, 1.13, -0.22), 0.035, 0.48, timber)
			_mesh_box(parent, "HammerHead", Vector3(-0.22, 1.32, -0.22), Vector3(0.24, 0.09, 0.12), iron)
		"study":
			_mesh_box(parent, "StudyDeskTop", Vector3(0.0, 0.78, 0.0), Vector3(0.92, 0.13, 0.58), dark_timber)
			for x in [-0.36, 0.36]:
				_mesh_box(parent, "StudyDeskLeg_%s" % x, Vector3(x, 0.38, 0.0), Vector3(0.10, 0.76, 0.52), timber)
			_mesh_box(parent, "BookStack_A", Vector3(-0.20, 0.91, -0.08), Vector3(0.30, 0.10, 0.22), cloth)
			_mesh_box(parent, "BookStack_B", Vector3(-0.16, 1.02, -0.08), Vector3(0.26, 0.09, 0.20), iron)
		"common":
			_mesh_box(parent, "CommonBenchSeat", Vector3(0.0, 0.48, 0.0), Vector3(1.05, 0.16, 0.36), timber)
			_mesh_box(parent, "CommonBenchBack", Vector3(0.0, 0.80, -0.15), Vector3(1.05, 0.48, 0.12), dark_timber)
			for x in [-0.40, 0.40]:
				_mesh_box(parent, "CommonBenchLeg_%s" % x, Vector3(x, 0.23, 0.0), Vector3(0.10, 0.46, 0.34), dark_timber)
		"threshold":
			for x in [-0.48, 0.48]:
				_mesh_box(parent, "DoorPost_%s" % x, Vector3(x, 1.0, 0.0), Vector3(0.16, 2.0, 0.16), dark_timber)
			_mesh_box(parent, "DoorLintel", Vector3(0.0, 1.92, 0.0), Vector3(1.12, 0.18, 0.18), timber)
			_mesh_box(parent, "ThresholdLantern", Vector3(0.0, 1.35, 0.18), Vector3(0.20, 0.28, 0.20), warm_light)
		"yard":
			_mesh_box(parent, "YardLogStack_A", Vector3(-0.10, 0.16, 0.0), Vector3(0.86, 0.22, 0.32), timber)
			_mesh_box(parent, "YardLogStack_B", Vector3(-0.10, 0.38, 0.0), Vector3(0.78, 0.20, 0.30), dark_timber)
			_mesh_cylinder(parent, "YardBarrel", Vector3(0.52, 0.38, 0.18), 0.26, 0.72, timber)
		"bedroom":
			_mesh_box(parent, "BedFrame", Vector3(0.0, 0.24, 0.0), Vector3(0.88, 0.34, 1.55), dark_timber)
			_mesh_box(parent, "BedMattress", Vector3(0.0, 0.48, 0.0), Vector3(0.80, 0.16, 1.42), cloth)
			_mesh_box(parent, "BedPillow", Vector3(0.0, 0.60, -0.54), Vector3(0.58, 0.12, 0.28), stone)


func _dwelling_display_name(dwelling_id: String) -> String:
	match dwelling_id:
		"crossroads_cottage":
			return "CROSSROADS COTTAGE"
		"country_house":
			return "COUNTRY HOUSE"
		"abandoned_house":
			return "ROADSIDE HOUSE"
		"silverhart_manor":
			return "SILVERHART MANOR"
	return "PARTY DWELLING"


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


func _create_campfire(is_lit: bool) -> void:
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
	if is_lit:
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
		for _character_id in arrangement.get("sleeping_bag_character_ids", []):
			var angle := TAU * float(index) / 6.0
			var offset := Vector3(cos(angle) * 2.0, 0.09, sin(angle) * 2.0)
			var roll := _mesh_box(_camp_root, "Bedroll_%02d" % index, offset, Vector3(0.72, 0.14, 1.35), bedroll_material)
			roll.rotation.y = -angle
			index += 1


func _create_nameplate(display_text: String = "CAMP") -> void:
	var label := Label3D.new()
	label.name = "CampNameplate"
	label.text = display_text
	label.position = Vector3(0.0, 2.3, 0.0)
	label.font_size = 28
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#f0dfbd")
	label.outline_size = 5
	label.outline_modulate = Color("#20231d")
	_camp_root.add_child(label)
