class_name HollowmereVillage
extends Node3D
## Exterior presentation for the first playable location. Buildings and paths are
## intentionally blockout-quality; the underlying layout is the authored map.

const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M
const GROUND_SIZE: float = 220.0

var grass_material: StandardMaterial3D
var path_material: StandardMaterial3D
var water_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var plaster_material: StandardMaterial3D
var timber_material: StandardMaterial3D
var dark_wood_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var glass_material: StandardMaterial3D
var foliage_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	_create_materials()
	_create_ground()
	_create_paths_and_stream()
	_create_buildings()
	_create_bridge()
	_create_signpost()
	_create_forest()

func _material(colour: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = roughness
	result.metallic = metallic
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _create_materials() -> void:
	grass_material = _material(Color(0.27, 0.36, 0.23))
	path_material = _material(Color(0.43, 0.34, 0.23))
	water_material = _material(Color(0.16, 0.31, 0.36), 0.22)
	stone_material = _material(Color(0.38, 0.37, 0.33))
	plaster_material = _material(Color(0.61, 0.53, 0.40))
	timber_material = _material(Color(0.31, 0.18, 0.10))
	dark_wood_material = _material(Color(0.16, 0.09, 0.05))
	roof_material = _material(Color(0.24, 0.25, 0.22))
	glass_material = _material(Color(0.29, 0.45, 0.49, 0.72), 0.18)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foliage_materials = [
		_material(Color(0.19, 0.30, 0.17)),
		_material(Color(0.24, 0.35, 0.19)),
		_material(Color(0.29, 0.38, 0.22))
	]

func _create_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "HollowmereGrassland"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground.mesh = mesh
	ground.position.y = -0.22
	ground.material_override = grass_material
	add_child(ground)

func _create_paths_and_stream() -> void:
	_add_hex_surface("VillageRoadNetwork", HollowmereVillageData.path_cells(), path_material, 0.025)
	_add_hex_surface("VillageStream", HollowmereVillageData.water_cells(), water_material, -0.055)

func _add_hex_surface(node_name: String, cells: Array[Vector2i], material: Material, elevation: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := HexGrid.corner_offsets(HEX_RADIUS * 1.005)
	for hex in cells:
		var centre := HexGrid.axial_to_world(hex, HEX_RADIUS, elevation)
		for i in range(HexGrid.SIDE_COUNT):
			var next_i := (i + 1) % HexGrid.SIDE_COUNT
			surface.set_normal(Vector3.UP)
			surface.add_vertex(centre)
			surface.add_vertex(centre + Vector3(corners[next_i].x, 0.0, corners[next_i].y))
			surface.add_vertex(centre + Vector3(corners[i].x, 0.0, corners[i].y))
	var mesh := surface.commit()
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)

func _create_buildings() -> void:
	# Positions and entrances follow Campaign 2's Hollowmere layout.
	_create_cottage("GeneralStore", Vector2i(0, 18), 8.5, 6.5, 2.9, 1.8, "north")
	_create_cottage("Chapel", Vector2i(-14, 0), 6.8, 7.2, 3.2, 2.0, "east")
	_create_cottage("EldersHouse", Vector2i(0, -12), 6.0, 5.4, 2.65, 1.55, "south")
	_create_cottage("MiraHouse", Vector2i(12, 9), 5.5, 5.0, 2.5, 1.45, "west")
	_create_cottage("OskarHouse", Vector2i(-6, 9), 5.5, 5.0, 2.5, 1.45, "east")
	_add_store_sign()
	_add_chapel_bell_tower()

func _create_cottage(id: String, centre_hex: Vector2i, width: float, depth: float, wall_height: float, roof_rise: float, door_side: String) -> void:
	var root := Node3D.new()
	root.name = id
	root.position = HexGrid.axial_to_world(centre_hex, HEX_RADIUS)
	add_child(root)

	var wall_thickness := 0.24
	var wall_y := 0.22 + wall_height * 0.5
	_add_box(root, "StoneFoundation", Vector3(0.0, 0.10, 0.0), Vector3(width + 0.35, 0.20, depth + 0.35), stone_material)

	if door_side == "north" or door_side == "south":
		_add_box(root, "WestWall", Vector3(-width * 0.5, wall_y, 0.0), Vector3(wall_thickness, wall_height, depth), plaster_material)
		_add_box(root, "EastWall", Vector3(width * 0.5, wall_y, 0.0), Vector3(wall_thickness, wall_height, depth), plaster_material)
		var back_z := depth * 0.5 if door_side == "north" else -depth * 0.5
		_add_box(root, "BackWall", Vector3(0.0, wall_y, back_z), Vector3(width, wall_height, wall_thickness), plaster_material)
		var front_z := -depth * 0.5 if door_side == "north" else depth * 0.5
		_add_door_wall(root, front_z, width, wall_height, wall_thickness, false)
		_add_box(root, "FrontDoor", Vector3(0.0, 1.18, front_z), Vector3(1.02, 2.05, 0.12), dark_wood_material)
	else:
		_add_box(root, "NorthWall", Vector3(0.0, wall_y, -depth * 0.5), Vector3(width, wall_height, wall_thickness), plaster_material)
		_add_box(root, "SouthWall", Vector3(0.0, wall_y, depth * 0.5), Vector3(width, wall_height, wall_thickness), plaster_material)
		var back_x := -width * 0.5 if door_side == "east" else width * 0.5
		_add_box(root, "BackWall", Vector3(back_x, wall_y, 0.0), Vector3(wall_thickness, wall_height, depth), plaster_material)
		var front_x := width * 0.5 if door_side == "east" else -width * 0.5
		_add_door_wall(root, front_x, depth, wall_height, wall_thickness, true)
		_add_box(root, "FrontDoor", Vector3(front_x, 1.18, 0.0), Vector3(0.12, 2.05, 1.02), dark_wood_material)

	# Timber framing and a simple pitched roof give the buildings a coherent village silhouette.
	for x in [-width * 0.5 + 0.12, 0.0, width * 0.5 - 0.12]:
		for z in [-depth * 0.5 + 0.12, depth * 0.5 - 0.12]:
			_add_box(root, "TimberPost", Vector3(x, wall_y, z), Vector3(0.16, wall_height + 0.08, 0.16), timber_material)
	var slope_length := sqrt(pow(depth * 0.5, 2.0) + pow(roof_rise, 2.0))
	var roof_angle := rad_to_deg(atan2(roof_rise, depth * 0.5))
	var north_roof := _add_box(root, "NorthRoofSlope", Vector3(0.0, 0.22 + wall_height + roof_rise * 0.5, -depth * 0.25), Vector3(width + 0.65, 0.20, slope_length), roof_material)
	north_roof.rotation_degrees.x = -roof_angle
	var south_roof := _add_box(root, "SouthRoofSlope", Vector3(0.0, 0.22 + wall_height + roof_rise * 0.5, depth * 0.25), Vector3(width + 0.65, 0.20, slope_length), roof_material)
	south_roof.rotation_degrees.x = roof_angle
	_add_box(root, "RoofRidge", Vector3(0.0, 0.22 + wall_height + roof_rise, 0.0), Vector3(width + 0.75, 0.18, 0.22), dark_wood_material)
	_add_box(root, "SideWindow", Vector3(width * 0.5 + 0.02, 1.75, 0.55), Vector3(0.08, 0.72, 0.82), glass_material)
	_add_box(root, "WindowSill", Vector3(width * 0.5 + 0.10, 1.36, 0.55), Vector3(0.16, 0.12, 1.0), timber_material)
	_add_box(root, "Chimney", Vector3(-width * 0.28, wall_height + 0.75, -depth * 0.22), Vector3(0.55, 1.8, 0.58), stone_material)

func _add_door_wall(parent: Node3D, front: float, length: float, wall_height: float, thickness: float, side_wall: bool) -> void:
	var door_width := 1.15
	var segment := maxf(0.5, (length - door_width) * 0.5)
	var wall_y := 0.22 + wall_height * 0.5
	var lintel_y := 0.22 + wall_height - 0.32
	if side_wall:
		_add_box(parent, "DoorWallA", Vector3(front, wall_y, -(door_width * 0.5 + segment * 0.5)), Vector3(thickness, wall_height, segment), plaster_material)
		_add_box(parent, "DoorWallB", Vector3(front, wall_y, door_width * 0.5 + segment * 0.5), Vector3(thickness, wall_height, segment), plaster_material)
		_add_box(parent, "DoorLintel", Vector3(front, lintel_y, 0.0), Vector3(thickness, 0.64, door_width), plaster_material)
	else:
		_add_box(parent, "DoorWallA", Vector3(-(door_width * 0.5 + segment * 0.5), wall_y, front), Vector3(segment, wall_height, thickness), plaster_material)
		_add_box(parent, "DoorWallB", Vector3(door_width * 0.5 + segment * 0.5, wall_y, front), Vector3(segment, wall_height, thickness), plaster_material)
		_add_box(parent, "DoorLintel", Vector3(0.0, lintel_y, front), Vector3(door_width, 0.64, thickness), plaster_material)

func _add_store_sign() -> void:
	var root := get_node_or_null("GeneralStore") as Node3D
	if root == null:
		return
	_add_box(root, "StoreSignBoard", Vector3(0.0, 2.75, -3.45), Vector3(3.3, 0.55, 0.16), dark_wood_material)
	var sign := Label3D.new()
	sign.name = "StoreSign"
	sign.text = "GENERAL STORE"
	sign.position = Vector3(0.0, 2.62, -3.56)
	sign.font_size = 34
	sign.pixel_size = 0.006
	sign.modulate = Color(0.91, 0.82, 0.63)
	sign.outline_size = 5
	add_child_to(root, sign)

func _add_chapel_bell_tower() -> void:
	var root := get_node_or_null("Chapel") as Node3D
	if root == null:
		return
	_add_box(root, "BellTower", Vector3(0.0, 4.2, -1.4), Vector3(1.45, 2.1, 1.45), stone_material)
	_add_box(root, "BellOpening", Vector3(0.0, 4.35, -0.64), Vector3(0.72, 0.62, 0.08), dark_wood_material)
	_add_box(root, "ChapelCrossStem", Vector3(0.0, 5.75, -1.4), Vector3(0.14, 1.0, 0.14), timber_material)
	_add_box(root, "ChapelCrossBar", Vector3(0.0, 5.85, -1.4), Vector3(0.65, 0.14, 0.14), timber_material)

func _create_bridge() -> void:
	var centre := HexGrid.axial_to_world(HollowmereVillageData.BRIDGE, HEX_RADIUS, 0.0)
	_add_box(self, "StreamBridgeDeck", centre + Vector3(0.0, 0.18, 0.0), Vector3(2.8, 0.24, 4.2), timber_material)
	for side in [-1.0, 1.0]:
		_add_box(self, "BridgeRail", centre + Vector3(side * 1.22, 0.62, 0.0), Vector3(0.16, 0.72, 4.0), dark_wood_material)
		for z in [-1.7, 0.0, 1.7]:
			_add_box(self, "BridgePost", centre + Vector3(side * 1.22, 0.55, z), Vector3(0.2, 0.95, 0.2), timber_material)

func _create_signpost() -> void:
	var centre := HexGrid.axial_to_world(HollowmereVillageData.CROSSROADS, HEX_RADIUS, 0.0)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.10
	post_mesh.bottom_radius = 0.15
	post_mesh.height = 2.6
	post.mesh = post_mesh
	post.position = centre + Vector3(0.0, 1.3, 0.0)
	post.material_override = timber_material
	add_child(post)
	_add_box(self, "SignboardNorth", centre + Vector3(0.0, 2.0, -0.05), Vector3(4.2, 0.78, 0.14), dark_wood_material)
	_add_box(self, "SignboardSouth", centre + Vector3(0.0, 1.05, -0.05), Vector3(4.2, 0.78, 0.14), dark_wood_material)
	var north_south_label := Label3D.new()
	north_south_label.text = "N  MILLBROOK  /  SILVERHART\nS  OLD MAC'S FARMSTEAD"
	north_south_label.position = centre + Vector3(0.0, 2.0, -0.14)
	north_south_label.font_size = 17
	north_south_label.pixel_size = 0.004
	north_south_label.modulate = Color(0.91, 0.82, 0.63)
	north_south_label.outline_size = 4
	add_child(north_south_label)
	var east_west_label := Label3D.new()
	east_west_label.text = "E  REDDALE  /  W  EMBERLODE"
	east_west_label.position = centre + Vector3(0.0, 1.05, -0.14)
	east_west_label.font_size = 17
	east_west_label.pixel_size = 0.004
	east_west_label.modulate = Color(0.91, 0.82, 0.63)
	east_west_label.outline_size = 4
	add_child(east_west_label)

func _create_forest() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.10
	trunk_mesh.bottom_radius = 0.18
	trunk_mesh.height = 1.8
	trunk_mesh.radial_segments = 7
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.95
	canopy_mesh.height = 1.9
	for q in range(-40, 41, 4):
		for r in range(-40, 41, 4):
			var hex := Vector2i(q, r)
			if not HollowmereVillageData.is_forest_candidate(hex):
				continue
			var noise := HollowmereVillageData._stable_noise(q + 17, r - 9)
			if noise < 0.56:
				continue
			var centre := HexGrid.axial_to_world(hex, HEX_RADIUS)
			var jitter := Vector3((noise - 0.5) * 2.0, 0.0, (0.5 - fmod(noise * 3.7, 1.0)) * 2.0)
			var tree := Node3D.new()
			tree.name = "VillageTree"
			tree.position = centre + jitter
			add_child(tree)
			var trunk := MeshInstance3D.new()
			trunk.mesh = trunk_mesh
			trunk.position.y = 0.9
			trunk.material_override = _material(Color(0.25, 0.15, 0.09))
			tree.add_child(trunk)
			var canopy := MeshInstance3D.new()
			canopy.mesh = canopy_mesh
			canopy.position.y = 2.15
			canopy.scale = Vector3(1.0 + noise * 0.25, 1.0 + noise * 0.32, 1.0 + noise * 0.25)
			canopy.material_override = foliage_materials[int(noise * 10.0) % foliage_materials.size()]
			tree.add_child(canopy)

func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func add_child_to(parent: Node3D, child: Node) -> void:
	parent.add_child(child)

