extends Node3D
## Streamed, source-derived regional map for Campaign 2.
## Hollowmere uses its authored exterior; surrounding local-hex terrain is streamed in chunks.

const TERRAIN_DATA_SCRIPT = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const VILLAGE_SCRIPT = preload("res://scripts/world/hollowmere_village.gd")
const MACRO_SCENE := "res://scenes/prototypes/campaign2_macro_world_preview.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const HEX_RADIUS := HexGrid.DEFAULT_RADIUS_M
const CHUNK_SIZE := 24
const LOAD_RADIUS_CHUNKS := 1

var terrain_data: Campaign2WorldTerrainData
var chunk_nodes: Dictionary = {}
var camera: Camera3D
var target := Vector3.ZERO
var yaw := deg_to_rad(24.0)
var pitch := deg_to_rad(56.0)
var camera_distance := 125.0
var rotating := false
var panning := false
var last_stream_centre := Vector2i(999999, 999999)
var materials: Dictionary = {}
var tree_crown_mesh: Mesh
var tree_trunk_mesh: Mesh
var terrain_meshes: Dictionary = {}
var marker_locations: Dictionary = {}

func _ready() -> void:
	terrain_data = TERRAIN_DATA_SCRIPT.new() as Campaign2WorldTerrainData
	_create_environment()
	_create_materials()
	_create_camera()
	_add_authored_hollowmere()
	_build_interface()
	jump_to_location("hollowmere")

func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#111a22")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#aebdc0")
	environment.ambient_light_energy = 0.78
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _create_materials() -> void:
	materials = {
		"grass": _material(Color("#66864c")),
		"forest": _material(Color("#315d3b")),
		"hills": _material(Color("#9b8968")),
		"mountain": _material(Color("#858b8e")),
		"badlands": _material(Color("#a36f55")),
		"water": _material(Color("#3d9fc2"), 0.28),
		"path": _material(Color("#b79b70"))
	}
	var crown := ConeMesh.new()
	crown.bottom_radius = 0.82
	crown.top_radius = 0.02
	crown.height = 2.8
	crown.radial_segments = 6
	tree_crown_mesh = crown
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.17
	trunk.height = 0.9
	trunk.radial_segments = 6
	tree_trunk_mesh = trunk

func _material(colour: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "RegionalMapCamera"
	camera.fov = 48.0
	camera.near = 0.1
	camera.far = 5000.0
	camera.current = true
	add_child(camera)
	_update_camera()

func _add_authored_hollowmere() -> void:
	# Reuse the actual starting-village scene instead of drawing a second,
	# approximate village over it. Its authored map occupies radius 96.
	var village := VILLAGE_SCRIPT.new() as Node3D
	village.name = "AuthoredHollowmereVillage"
	add_child(village)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var heading_panel := PanelContainer.new()
	heading_panel.position = Vector2(20.0, 18.0)
	heading_panel.custom_minimum_size = Vector2(440.0, 78.0)
	root.add_child(heading_panel)
	var heading_stack := VBoxContainer.new()
	heading_stack.add_theme_constant_override("separation", 3)
	heading_panel.add_child(heading_stack)
	var heading := Label.new()
	heading.text = "CAMPAIGN 2 — REGIONAL WORLD"
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", Color("#f0dfbd"))
	heading_stack.add_child(heading)
	var detail := Label.new()
	detail.text = "STREAMED LOCAL HEX TERRAIN  •  24-HEX CHUNKS  •  SOURCE-ANCHORED ROUTES"
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", Color("#b7c4c9"))
	heading_stack.add_child(detail)

	var locations_panel := PanelContainer.new()
	locations_panel.anchor_left = 1.0
	locations_panel.anchor_right = 1.0
	locations_panel.offset_left = -226.0
	locations_panel.offset_right = -18.0
	locations_panel.offset_top = 116.0
	locations_panel.offset_bottom = 490.0
	root.add_child(locations_panel)
	var location_column := VBoxContainer.new()
	location_column.add_theme_constant_override("separation", 7)
	locations_panel.add_child(location_column)
	var location_heading := Label.new()
	location_heading.text = "JUMP TO LOCATION"
	location_heading.add_theme_font_size_override("font_size", 13)
	location_column.add_child(location_heading)
	_add_jump_button(location_column, "Hollowmere", "hollowmere")
	_add_jump_button(location_column, "Millbrook", "millbrook")
	_add_jump_button(location_column, "Silverhart", "silverhart")
	_add_jump_button(location_column, "Emberlode", "emberlode")
	_add_jump_button(location_column, "Reddale", "reddale")
	_add_jump_button(location_column, "Old Mac's Farmstead", "old_mac_farmstead")

	var macro_button := Button.new()
	macro_button.text = "MACRO WORLD"
	macro_button.anchor_left = 1.0
	macro_button.anchor_right = 1.0
	macro_button.offset_left = -226.0
	macro_button.offset_right = -18.0
	macro_button.offset_top = 24.0
	macro_button.offset_bottom = 68.0
	macro_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(MACRO_SCENE))
	root.add_child(macro_button)

	var menu_button := Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.position = Vector2(20.0, 106.0)
	menu_button.custom_minimum_size = Vector2(150.0, 40.0)
	menu_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	root.add_child(menu_button)

	var help := Label.new()
	help.anchor_left = 0.0
	help.anchor_right = 1.0
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 20.0
	help.offset_right = -245.0
	help.offset_top = -52.0
	help.offset_bottom = -16.0
	help.text = "Left-drag: orbit   •   Right-drag: pan   •   Wheel: zoom   •   WASD / arrows: travel   •   Esc: macro map"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color("#d2d8d9"))
	root.add_child(help)

func _add_jump_button(parent: VBoxContainer, label_text: String, location_id: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: jump_to_location(location_id))
	parent.add_child(button)

func jump_to_location(location_id: String) -> void:
	for location in terrain_data.locations:
		if String(location.get("id", "")) != location_id:
			continue
		var hex := Vector2i(int(location.get("q", 8)), int(location.get("r", 24)))
		target = HexGrid.axial_to_world(hex, HEX_RADIUS, terrain_data.elevation_for_hex(hex))
		_update_camera()
		_update_streamed_chunks(true)
		return

func _process(_delta: float) -> void:
	_update_streamed_chunks(false)

func _update_streamed_chunks(force: bool) -> void:
	var centre_hex := HexGrid.world_to_axial(Vector3(target.x, 0.0, target.z), HEX_RADIUS)
	var centre_chunk := terrain_data.chunk_for_hex(centre_hex, CHUNK_SIZE)
	if not force and centre_chunk == last_stream_centre:
		return
	last_stream_centre = centre_chunk
	var wanted: Dictionary = {}
	for dq in range(-LOAD_RADIUS_CHUNKS, LOAD_RADIUS_CHUNKS + 1):
		for dr in range(-LOAD_RADIUS_CHUNKS, LOAD_RADIUS_CHUNKS + 1):
			var chunk := centre_chunk + Vector2i(dq, dr)
			var key := _chunk_key(chunk)
			wanted[key] = true
			if not chunk_nodes.has(key):
				chunk_nodes[key] = _build_chunk(chunk)
	var stale: Array[String] = []
	for key in chunk_nodes:
		if not wanted.has(key):
			stale.append(String(key))
	for key in stale:
		var node: Node = chunk_nodes[key]
		if is_instance_valid(node):
			node.queue_free()
		chunk_nodes.erase(key)

func _build_chunk(chunk: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "TerrainChunk_%d_%d" % [chunk.x, chunk.y]
	add_child(root)
	var tools: Dictionary = {}
	for terrain in materials:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(materials[terrain])
		tools[terrain] = surface
	var tree_transforms: Array[Transform3D] = []
	var trunk_transforms: Array[Transform3D] = []
	var chunk_min := chunk * CHUNK_SIZE
	for q in range(chunk_min.x, chunk_min.x + CHUNK_SIZE):
		for r in range(chunk_min.y, chunk_min.y + CHUNK_SIZE):
			var hex := Vector2i(q, r)
			var terrain := terrain_data.terrain_for_hex(hex)
			if terrain == "authored" or terrain == "void" or not tools.has(terrain):
				continue
			var elevation := terrain_data.elevation_for_hex(hex)
			_add_hex_to_surface(tools[terrain] as SurfaceTool, hex, elevation)
			if terrain_data.has_tree(hex):
				var centre := HexGrid.axial_to_world(hex, HEX_RADIUS, elevation)
				var size_roll := Campaign2WorldTerrainData._stable_roll(hex, 2909)
				var scale := 0.72 + size_roll * 0.5
				var rotation := size_roll * TAU
				var basis := Basis(Vector3.UP, rotation).scaled(Vector3(scale, scale, scale))
				tree_transforms.append(Transform3D(basis, centre + Vector3(0.0, 1.35 * scale, 0.0)))
				trunk_transforms.append(Transform3D(Basis(Vector3.UP, rotation).scaled(Vector3(scale, scale, scale)), centre + Vector3(0.0, 0.45 * scale, 0.0)))
	for terrain in tools:
		var mesh := (tools[terrain] as SurfaceTool).commit()
		if mesh == null:
			continue
		var instance := MeshInstance3D.new()
		instance.name = "Terrain_" + String(terrain)
		instance.mesh = mesh
		instance.material_override = materials[terrain]
		root.add_child(instance)
	_add_multimesh(root, "ForestCrowns", tree_crown_mesh, tree_transforms)
	_add_multimesh(root, "ForestTrunks", tree_trunk_mesh, trunk_transforms)
	_add_chunk_locations(root, chunk)
	return root

func _add_hex_to_surface(surface: SurfaceTool, hex: Vector2i, elevation: float) -> void:
	var centre := HexGrid.axial_to_world(hex, HEX_RADIUS, elevation)
	var corners := HexGrid.corner_offsets(HEX_RADIUS * 1.005)
	for index in range(HexGrid.SIDE_COUNT):
		var next_index := (index + 1) % HexGrid.SIDE_COUNT
		surface.set_normal(Vector3.UP)
		surface.add_vertex(centre)
		surface.add_vertex(centre + Vector3(corners[next_index].x, 0.0, corners[next_index].y))
		surface.add_vertex(centre + Vector3(corners[index].x, 0.0, corners[index].y))

func _add_multimesh(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty() or mesh == null:
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = _material(Color("#315b38") if node_name == "ForestCrowns" else Color("#5b402b"))
	parent.add_child(instance)

func _add_chunk_locations(parent: Node3D, chunk: Vector2i) -> void:
	var chunk_min := chunk * CHUNK_SIZE
	for location in terrain_data.locations:
		var hex := Vector2i(int(location.get("q", 8)), int(location.get("r", 24)))
		if hex.x < chunk_min.x or hex.x >= chunk_min.x + CHUNK_SIZE or hex.y < chunk_min.y or hex.y >= chunk_min.y + CHUNK_SIZE:
			continue
		var marker := MeshInstance3D.new()
		marker.name = "POI_" + String(location.get("id", "site"))
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.28
		mesh.bottom_radius = 0.28
		mesh.height = 1.0
		mesh.radial_segments = 8
		marker.mesh = mesh
		marker.material_override = _material(_location_colour(String(location.get("kind", ""))))
		var position := HexGrid.axial_to_world(hex, HEX_RADIUS, terrain_data.elevation_for_hex(hex))
		marker.position = position + Vector3(0.0, 1.5, 0.0)
		parent.add_child(marker)
		var label := Label3D.new()
		label.text = String(location.get("name", location.get("id", "Site")))
		label.font_size = 34
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color("#fff0d0")
		label.outline_size = 7
		label.outline_modulate = Color("#17212a")
		label.position = position + Vector3(0.0, 3.0, 0.0)
		parent.add_child(label)

func _location_colour(kind: String) -> Color:
	match kind:
		"capital", "dwarven_capital", "elven_capital": return Color("#f0ce79")
		"town", "village", "village_mine", "starting_village": return Color("#e8d7a9")
		"farmstead": return Color("#9bc17c")
		"fort": return Color("#d97861")
		"goblin_camp", "orc_stronghold": return Color("#d68b65")
		"dungeon", "haunted_house", "chapterhouse", "dragon_lair": return Color("#bd91d2")
		_: return Color("#a9c0cb")

func _update_camera() -> void:
	if camera == null:
		return
	var horizontal := cos(pitch) * camera_distance
	camera.position = target + Vector3(sin(yaw) * horizontal, sin(pitch) * camera_distance, cos(yaw) * horizontal)
	camera.look_at(target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE:
				get_tree().change_scene_to_file(MACRO_SCENE)
				get_viewport().set_input_as_handled()
			elif key.keycode in [KEY_W, KEY_UP, KEY_S, KEY_DOWN, KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
				var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
				var right := Vector3(cos(yaw), 0.0, -sin(yaw))
				var movement := Vector3.ZERO
				if key.keycode in [KEY_W, KEY_UP]: movement += forward
				if key.keycode in [KEY_S, KEY_DOWN]: movement -= forward
				if key.keycode in [KEY_A, KEY_LEFT]: movement -= right
				if key.keycode in [KEY_D, KEY_RIGHT]: movement += right
				target += movement.normalized() * maxf(8.0, camera_distance * 0.12)
				_update_camera()
				get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			rotating = button.pressed
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			panning = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(18.0, camera_distance * 0.86)
			_update_camera()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(650.0, camera_distance * 1.16)
			_update_camera()
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if rotating:
			yaw -= motion.relative.x * 0.008
			pitch = clampf(pitch + motion.relative.y * 0.006, deg_to_rad(18.0), deg_to_rad(82.0))
			_update_camera()
		elif panning:
			var right := camera.global_transform.basis.x
			var forward := -camera.global_transform.basis.z
			right.y = 0.0
			forward.y = 0.0
			target -= right.normalized() * motion.relative.x * camera_distance * 0.0017
			target += forward.normalized() * motion.relative.y * camera_distance * 0.0017
			_update_camera()

static func _chunk_key(chunk: Vector2i) -> String:
	return "%d,%d" % [chunk.x, chunk.y]
