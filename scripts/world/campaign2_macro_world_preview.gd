extends Node3D
## Browsable 3D strategic overview for Campaign 2.
## This is a macro-world presentation layer; local maps remain the playable movement spaces.

const MAP_DATA = preload("res://scripts/world/main_campaign_world_map_data.gd")
const MANIFEST_PATH := "res://data/world/campaign2_geography.json"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const HEX_X_STEP := 1.5
const HEX_Z_STEP := 1.7320508
const TILE_RADIUS := 0.96

var camera: Camera3D
var target := Vector3.ZERO
var yaw := deg_to_rad(25.0)
var pitch := deg_to_rad(48.0)
var camera_distance := 37.0
var rotating := false
var panning := false
var manifest: Dictionary = {}
var location_positions: Dictionary = {}
var label_stacks: Dictionary = {}
var terrain_materials: Dictionary = {}
var faction_materials: Dictionary = {}

func _ready() -> void:
	_load_manifest()
	_create_environment()
	_create_camera()
	_build_world()
	_build_interface()
	_update_camera()

func _load_manifest() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		manifest = parsed
	else:
		push_error("Campaign 2 geography manifest could not be parsed.")

func _create_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#101923")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a8b9c6")
	environment.ambient_light_energy = 0.75
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "MacroWorldCamera"
	camera.fov = 42.0
	camera.near = 0.1
	camera.far = 200.0
	camera.current = true
	add_child(camera)

func _build_world() -> void:
	_build_materials()
	_build_tiles()
	_build_river()
	_build_region_labels()
	_build_locations()
	_build_routes()

func _build_materials() -> void:
	terrain_materials = {
		"ocean": _material(Color("#075a91"), 0.35),
		"grass": _material(Color("#668a50"), 0.92),
		"forest": _material(Color("#285b37"), 0.95),
		"mountain": _material(Color("#858b8b"), 0.96),
		"hills": _material(Color("#a28a70"), 0.95)
	}
	faction_materials = {
		"humans": Color("#e8d7a9"),
		"elves": Color("#66d69a"),
		"dwarves": Color("#e4bd62"),
		"orcs": Color("#df755e"),
		"": Color("#7d9aab")
	}

func _material(colour: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = roughness
	return result

func _build_tiles() -> void:
	var grid: Array = MAP_DATA.generate_grid()
	for column in range(MAP_DATA.WORLD_SIZE):
		for row in range(MAP_DATA.WORLD_SIZE):
			var cell: Dictionary = grid[row][column]
			var terrain := String(cell.get("terrain", "grass"))
			var height := _terrain_height(terrain)
			var centre := _cell_position(column, row)
			var tile := MeshInstance3D.new()
			tile.name = "WorldCell_%02d_%02d" % [column, row]
			var mesh := CylinderMesh.new()
			mesh.top_radius = TILE_RADIUS
			mesh.bottom_radius = TILE_RADIUS
			mesh.height = height
			mesh.radial_segments = 6
			tile.mesh = mesh
			tile.position = Vector3(centre.x, height * 0.5 - 0.12, centre.z)
			tile.material_override = terrain_materials[terrain]
			add_child(tile)

			match terrain:
				"mountain":
					_add_mountain_cluster(centre, height, column * 17 + row)
				"hills":
					_add_hill(centre, height, column * 13 + row)
				"forest":
					_add_forest_cluster(centre, height, column * 19 + row)

	# A quiet ground plane fills the small gaps between hexes and gives the
	# coast and border regions a continuous visual base.
	var ground := MeshInstance3D.new()
	ground.name = "WorldMapGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(34.0, 38.0)
	ground.mesh = plane
	ground.position = Vector3(0.0, -0.32, 0.0)
	ground.material_override = _material(Color("#253b35"))
	add_child(ground)

func _terrain_height(terrain: String) -> float:
	match terrain:
		"ocean": return 0.22
		"forest": return 0.32
		"hills": return 0.48
		"mountain": return 0.82
		_: return 0.28

func _add_mountain_cluster(centre: Vector3, base_height: float, seed: int) -> void:
	for index in range(2):
		var peak := MeshInstance3D.new()
		var cone := ConeMesh.new()
		cone.bottom_radius = 0.42 if index == 0 else 0.29
		cone.top_radius = 0.015
		cone.height = 1.15 if index == 0 else 0.78
		cone.radial_segments = 5
		peak.mesh = cone
		peak.material_override = terrain_materials["mountain"]
		var offset := Vector3(-0.22 if index == 0 else 0.28, 0.48, 0.12 if index == 0 else -0.18)
		peak.position = centre + offset + Vector3(0.0, base_height * 0.5, 0.0)
		peak.rotation.y = float(posmod(seed + index * 3, 6)) * PI / 3.0
		add_child(peak)

func _add_hill(centre: Vector3, base_height: float, seed: int) -> void:
	var hill := MeshInstance3D.new()
	var cone := ConeMesh.new()
	cone.bottom_radius = 0.48
	cone.top_radius = 0.04
	cone.height = 0.72
	cone.radial_segments = 6
	hill.mesh = cone
	hill.material_override = terrain_materials["hills"]
	hill.position = centre + Vector3(0.0, base_height * 0.5 + 0.28, 0.0)
	hill.rotation.y = float(posmod(seed, 6)) * PI / 3.0
	add_child(hill)

func _add_forest_cluster(centre: Vector3, base_height: float, seed: int) -> void:
	for index in range(2):
		var offset := Vector3(-0.25 if index == 0 else 0.25, base_height * 0.5, 0.12 if index == 0 else -0.16)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.045
		trunk_mesh.bottom_radius = 0.07
		trunk_mesh.height = 0.42
		trunk.mesh = trunk_mesh
		trunk.material_override = _material(Color("#65472f"))
		trunk.position = centre + offset + Vector3(0.0, 0.20, 0.0)
		add_child(trunk)

		var crown := MeshInstance3D.new()
		var crown_mesh := ConeMesh.new()
		crown_mesh.bottom_radius = 0.31
		crown_mesh.top_radius = 0.0
		crown_mesh.height = 0.86
		crown_mesh.radial_segments = 6
		crown.mesh = crown_mesh
		crown.material_override = _material(Color("#1e4b31") if posmod(seed + index, 2) == 0 else Color("#2c623c"))
		crown.position = centre + offset + Vector3(0.0, 0.78, 0.0)
		add_child(crown)

func _build_river() -> void:
	var path: Array = manifest.get("geography", {}).get("river_path", [])
	var points: Array[Vector3] = []
	for pair in path:
		if pair is Array and pair.size() == 2:
			points.append(_cell_position(int(pair[0]), int(pair[1])) + Vector3(0.0, 0.32, 0.0))
	for index in range(points.size() - 1):
		_add_segment("GreatRiver_%02d" % index, points[index], points[index + 1], 0.105, _material(Color("#62c5e8"), 0.28))

func _build_routes() -> void:
	var connections: Array = manifest.get("connections", [])
	for index in range(connections.size()):
		var connection: Dictionary = connections[index]
		var from_id := String(connection.get("from", ""))
		var to_id := String(connection.get("to", ""))
		if not location_positions.has(from_id) or not location_positions.has(to_id):
			continue
		var colour := Color("#b89a67")
		var radius := 0.035
		match String(connection.get("kind", "")):
			"border_road":
				colour = Color("#c47b61")
				radius = 0.045
			"long_road":
				colour = Color("#a99a77")
				radius = 0.025
			"trail":
				colour = Color("#7c8b6d")
				radius = 0.018
			"local_path":
				colour = Color("#e0c38b")
				radius = 0.03
		var a: Vector3 = location_positions[from_id] + Vector3(0.0, 0.34, 0.0)
		var b: Vector3 = location_positions[to_id] + Vector3(0.0, 0.34, 0.0)
		_add_segment("Route_%02d_%s_%s" % [index, from_id, to_id], a, b, radius, _material(colour, 0.9))

func _add_segment(node_name: String, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var direction := finish - start
	var length := direction.length()
	if length < 0.01:
		return
	var segment := MeshInstance3D.new()
	segment.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 6
	segment.mesh = mesh
	segment.position = (start + finish) * 0.5
	segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
	segment.material_override = material
	add_child(segment)

func _build_region_labels() -> void:
	_add_region_label("SILVERHART KINGDOM", Vector3(-3.4, 0.55, 0.1), Color("#f0e4c7"))
	_add_region_label("ORC TRIBES", Vector3(7.8, 0.75, 2.3), Color("#f2a08c"))
	_add_region_label("THE DEEPHOLDS", Vector3(8.0, 2.4, -9.2), Color("#f1d17f"))
	_add_region_label("SYLVAN COURT", Vector3(-4.0, 0.65, 10.5), Color("#9be4b8"))
	_add_region_label("WESTERN SEA", Vector3(-10.8, 0.35, -1.5), Color("#b4e2f0"))

func _add_region_label(label_text: String, at: Vector3, colour: Color) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 56
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = colour
	label.outline_size = 9
	label.outline_modulate = Color("#15202a")
	label.position = at
	add_child(label)

func _build_locations() -> void:
	var locations: Array = manifest.get("locations", [])
	for index in range(locations.size()):
		var location: Dictionary = locations[index]
		var id := String(location.get("id", ""))
		var local_q := int(location.get("q", 8))
		var local_r := int(location.get("r", 24))
		var map_position := _local_hex_to_map_position(local_q, local_r)
		location_positions[id] = map_position
		_add_location_marker(location, map_position, index)

func _local_hex_to_map_position(local_q: int, local_r: int) -> Vector3:
	var map_column := 6.0 + float(local_q - 8) / float(MAP_DATA.WORLD_HEX_SIZE)
	var map_row := 6.0 + float(local_r - 24) / float(MAP_DATA.WORLD_HEX_SIZE)
	var nearest_column := roundi(map_column)
	var nearest_row := roundi(map_row)
	var base := _cell_position(nearest_column, nearest_row)
	var column_offset := map_column - float(nearest_column)
	var row_offset := map_row - float(nearest_row)
	return Vector3(
		base.x + column_offset * HEX_X_STEP,
		0.0,
		base.z + (row_offset + column_offset * 0.5) * HEX_Z_STEP
	)

func _cell_position(column: int, row: int) -> Vector3:
	return Vector3(
		(float(column) - 7.5) * HEX_X_STEP,
		0.0,
		(float(row) - 7.5 + float(posmod(column, 2)) * 0.5) * HEX_Z_STEP
	)

func _add_location_marker(location: Dictionary, map_position: Vector3, index: int) -> void:
	var id := String(location.get("id", "poi"))
	var kind := String(location.get("kind", "site"))
	var colour := _location_colour(kind)
	var stack_key := "%d,%d" % [roundi(map_position.x * 2.0), roundi(map_position.z * 2.0)]
	var stack := int(label_stacks.get(stack_key, 0))
	label_stacks[stack_key] = stack + 1

	var marker := MeshInstance3D.new()
	marker.name = "POI_" + id
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.14
	mesh.bottom_radius = 0.14
	mesh.height = 0.58
	mesh.radial_segments = 8
	marker.mesh = mesh
	marker.material_override = _material(colour, 0.45)
	marker.position = map_position + Vector3(0.0, 0.46, 0.0)
	add_child(marker)

	var label := Label3D.new()
	label.name = "Label_" + id
	label.text = String(location.get("name", id))
	label.font_size = 46 if kind in ["capital", "dwarven_capital", "elven_capital"] else 38
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color("#fff1cf") if String(location.get("visibility", "")) != "exploration_site" else Color("#c6d0bb")
	label.outline_size = 8
	label.outline_modulate = Color("#17212a")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = map_position + Vector3(0.0, 1.15 + float(stack) * 0.34, 0.0)
	add_child(label)

func _location_colour(kind: String) -> Color:
	match kind:
		"capital", "dwarven_capital", "elven_capital": return Color("#f0ce79")
		"town", "village", "village_mine", "starting_village": return Color("#e8d7a9")
		"farmstead": return Color("#9bc17c")
		"fort": return Color("#d97861")
		"goblin_camp", "orc_stronghold": return Color("#d68b65")
		"dungeon", "haunted_house", "chapterhouse", "dragon_lair": return Color("#bd91d2")
		"druid_grove": return Color("#78c89a")
		"grave", "cave_network": return Color("#9aabb8")
		"guild": return Color("#c5a9df")
		_: return Color("#e8d7a9")

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var title_panel := PanelContainer.new()
	title_panel.position = Vector2(24.0, 20.0)
	title_panel.custom_minimum_size = Vector2(510.0, 92.0)
	root.add_child(title_panel)
	var title_stack := VBoxContainer.new()
	title_stack.add_theme_constant_override("separation", 4)
	title_panel.add_child(title_stack)
	var title := Label.new()
	title.text = "THE SILVERHART REALMS"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#f0dfbd"))
	title_stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "CAMPAIGN 2  •  3D STRATEGIC WORLD  •  SOURCE-DERIVED PLACEMENT"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#b7c4c9"))
	title_stack.add_child(subtitle)

	var back := Button.new()
	back.text = "BACK TO MENU"
	back.position = Vector2(-178.0, 24.0)
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -178.0
	back.offset_right = -24.0
	back.offset_top = 24.0
	back.offset_bottom = 70.0
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	root.add_child(back)

	var legend := PanelContainer.new()
	legend.anchor_top = 1.0
	legend.anchor_bottom = 1.0
	legend.offset_left = 24.0
	legend.offset_right = 680.0
	legend.offset_top = -82.0
	legend.offset_bottom = -20.0
	root.add_child(legend)
	var legend_row := HBoxContainer.new()
	legend_row.add_theme_constant_override("separation", 14)
	legend.add_child(legend_row)
	_add_legend_item(legend_row, Color("#075a91"), "SEA")
	_add_legend_item(legend_row, Color("#668a50"), "HUMAN LANDS")
	_add_legend_item(legend_row, Color("#df755e"), "ORC LANDS")
	_add_legend_item(legend_row, Color("#e4bd62"), "DEEPHOLDS")
	_add_legend_item(legend_row, Color("#66d69a"), "SYLVAN COURT")

	var help := Label.new()
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = -560.0
	help.offset_right = -24.0
	help.offset_top = -66.0
	help.offset_bottom = -20.0
	help.text = "Left-drag: rotate   •   Right-drag: pan   •   Wheel: zoom   •   R: reset   •   Esc: menu"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_color_override("font_color", Color("#d2d8d9"))
	help.add_theme_font_size_override("font_size", 12)
	root.add_child(help)

func _add_legend_item(parent: HBoxContainer, colour: Color, text_value: String) -> void:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 5)
	parent.add_child(item)
	var swatch := ColorRect.new()
	swatch.color = colour
	swatch.custom_minimum_size = Vector2(12.0, 12.0)
	item.add_child(swatch)
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#e0e5e2"))
	item.add_child(label)

func _update_camera() -> void:
	if camera == null:
		return
	var horizontal := cos(pitch) * camera_distance
	camera.position = target + Vector3(sin(yaw) * horizontal, sin(pitch) * camera_distance, cos(yaw) * horizontal)
	camera.look_at(target, Vector3.UP)

func _reset_camera() -> void:
	target = Vector3.ZERO
	yaw = deg_to_rad(25.0)
	pitch = deg_to_rad(48.0)
	camera_distance = 37.0
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE:
				get_tree().change_scene_to_file(MENU_SCENE)
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_R:
				_reset_camera()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			rotating = button.pressed
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			panning = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(16.0, camera_distance * 0.88)
			_update_camera()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(70.0, camera_distance * 1.12)
			_update_camera()

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if rotating:
			yaw -= motion.relative.x * 0.008
			pitch = clampf(pitch + motion.relative.y * 0.006, deg_to_rad(18.0), deg_to_rad(78.0))
			_update_camera()
		elif panning:
			var right := camera.global_transform.basis.x
			var up := camera.global_transform.basis.y
			target -= right * motion.relative.x * camera_distance * 0.0015
			target += up * motion.relative.y * camera_distance * 0.0015
			_update_camera()
