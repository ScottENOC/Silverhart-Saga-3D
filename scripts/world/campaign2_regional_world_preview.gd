extends Node3D
## Streamed, source-derived regional map for Campaign 2.
## Hollowmere uses its authored exterior; surrounding local-hex terrain is streamed in chunks.

const TERRAIN_DATA_SCRIPT = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const LOCAL_TERRAIN_RULES = preload("res://data/world/terrain/campaign2_local_terrain.gd")
const WORLD_VEGETATION_SCRIPT = preload("res://scripts/world/world_vegetation_generator.gd")
const HEARTLAND_BIOMES = preload("res://data/world/regions/silverhart_heartland/biomes.gd")
const REGIONAL_HYDROLOGY = preload("res://data/world/regions/silverhart_heartland/hydrology.gd")
const SETTLEMENT_BUILDER_SCRIPT = preload("res://scripts/world/campaign2_settlement_builder.gd")
const WALL_FEATURE_FACTORY = preload("res://scripts/world/world_wall_feature_factory.gd")
const LOCATION_LOADER_SCRIPT = preload("res://scripts/world/campaign2_location_loader.gd")
const MACRO_SCENE := "res://scenes/prototypes/campaign2_macro_world_preview.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const HEX_RADIUS := HexGrid.DEFAULT_RADIUS_M
const CHUNK_SIZE := 24
const LOAD_RADIUS_CHUNKS := 1

var terrain_data: Campaign2WorldTerrainData
var settlement_builder: Campaign2SettlementBuilder
var ecology_simulation: WorldSimulation
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
var terrain_meshes: Dictionary = {}
var marker_locations: Dictionary = {}
var movement_controller: WorldPlayerMovementController
var player_actor: Node3D
var active_location_runtime: Campaign2MultiStoryLocationRuntime
var mouse_travel_pressed := false

func _ready() -> void:
	terrain_data = TERRAIN_DATA_SCRIPT.new() as Campaign2WorldTerrainData
	ecology_simulation = WorldSimulation.new()
	ecology_simulation.name = "RegionalEcologySimulation"
	add_child(ecology_simulation)
	settlement_builder = SETTLEMENT_BUILDER_SCRIPT.new(terrain_data.settlement_layouts, null, ecology_simulation) as Campaign2SettlementBuilder
	_create_environment()
	_create_materials()
	_create_camera()
	_create_player()
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
		"sand": _material(Color("#cbb77f")),
		"swamp": _material(Color("#56664a")),
		"rocky_outcrop": _material(Color("#77756e")),
		"dirt": _material(Color("#8b7453")),
		"wood_floor": _material(Color("#947a59")),
		"stone_floor": _material(Color("#77766f")),
		"cave_floor": _material(Color("#554a3c")),
		"climbable_wall": _material(Color("#4e5154")),
		"keep_wall": _material(Color("#34383b")),
		"water": _material(Color("#3d9fc2"), 0.28),
		"path": _material(Color("#b79b70"))
	}

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
	var location_scroll := ScrollContainer.new()
	location_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	location_scroll.custom_minimum_size = Vector2(0.0, 300.0)
	location_column.add_child(location_scroll)
	var location_list := VBoxContainer.new()
	location_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_scroll.add_child(location_list)
	for location in terrain_data.locations:
		_add_jump_button(location_list, String(location.get("name", location.get("id", "Location"))), String(location.get("id", "")))

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
	help.text = "Click: travel   •   QWE / ASD: move   •   F: use nearby stair / enter or exit   •   Middle-drag: orbit   •   Right-drag: pan   •   Wheel: zoom   •   Esc: macro map"
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

func _process(delta: float) -> void:
	if movement_controller != null:
		movement_controller.process_movement(delta)
	_update_streamed_chunks(false)

## Chunk membership is keyed to the camera focus, not the map's gameplay regions.
## Crossing a chunk boundary loads the new 3x3 neighbourhood and retires stale chunks.
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
	var chunk_min := chunk * CHUNK_SIZE
	_populate_chunk_gameplay_cells(chunk)
	for q in range(chunk_min.x, chunk_min.x + CHUNK_SIZE):
		for r in range(chunk_min.y, chunk_min.y + CHUNK_SIZE):
			var hex := Vector2i(q, r)
			var terrain := terrain_data.terrain_for_hex(hex)
			if terrain == "authored" or terrain == "void" or not tools.has(terrain):
				continue
			var elevation := terrain_data.elevation_for_hex(hex)
			var wall_height := WALL_FEATURE_FACTORY.height_for_terrain(terrain)
			_add_hex_to_surface(tools[terrain] as SurfaceTool, hex, elevation + wall_height)

	for terrain in tools:
		var mesh := (tools[terrain] as SurfaceTool).commit()
		if mesh == null:
			continue
		var instance := MeshInstance3D.new()
		instance.name = "Terrain_" + String(terrain)
		instance.mesh = mesh
		instance.material_override = materials[terrain]
		root.add_child(instance)
	var vegetation_placements := _wilderness_vegetation_placements_for_chunk(chunk_min, CHUNK_SIZE)
	var vegetation_spawned := WORLD_VEGETATION_SCRIPT.generate_authored_placements(root, vegetation_placements)
	if vegetation_spawned != vegetation_placements.size():
		push_warning("Regional wilderness vegetation spawned %d of %d GLB models." % [vegetation_spawned, vegetation_placements.size()])
	var wall_result: Dictionary = WALL_FEATURE_FACTORY.present_chunk(root, terrain_data, chunk_min, CHUNK_SIZE, HEX_RADIUS, materials)
	if not bool(wall_result.get("ok", false)):
		push_warning("Regional wall presentation failed: %s" % wall_result)
	_add_chunk_locations(root, chunk)
	settlement_builder.add_settlements_in_chunk(root, chunk_min, CHUNK_SIZE, "chunked")
	return root


func _create_player() -> void:
	var start_hex := Vector2i(8, 24)
	var player := CharacterState.new("player", "Player", start_hex)
	player.side = "player"
	player.time_points = 100.0
	ecology_simulation.player_character_id = player.id
	ecology_simulation.register_character(player)
	ecology_simulation.character_moved.connect(_on_world_character_moved)

	var actor_root := Node3D.new()
	actor_root.name = "RegionalPlayerActor"
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.62
	capsule.height = 2.2
	body.mesh = capsule
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#d7bd8b")
	body_material.roughness = 0.78
	body.material_override = body_material
	body.position.y = 1.1
	actor_root.add_child(body)
	var marker := MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.12
	marker_mesh.bottom_radius = 0.12
	marker_mesh.height = 0.08
	marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("#e8c76d")
	marker.material_override = marker_material
	marker.position.y = 0.08
	actor_root.add_child(marker)
	add_child(actor_root)
	player_actor = actor_root
	_update_player_presentation(start_hex)

	movement_controller = WorldPlayerMovementController.new()
	movement_controller.name = "RegionalPlayerMovementController"
	add_child(movement_controller)
	var path_mesh := CylinderMesh.new()
	path_mesh.top_radius = 0.24
	path_mesh.bottom_radius = 0.24
	path_mesh.height = 0.06
	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color("#f2d27a")
	path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_material.albedo_color.a = 0.78
	movement_controller.configure(ecology_simulation, self, path_mesh, path_material, Callable(self, "_world_position_for_hex"), player.id)
	_load_multistory_location("silthandriel")

## The great-tree entrance is the first live connection between the regional
## player simulation and the shared multi-story location runtime. Other authored
## locations can be registered here as their entrances are brought online.
func _load_multistory_location(location_id: String) -> void:
	var load_result: Dictionary = LOCATION_LOADER_SCRIPT.load_multistory_location(self, location_id, ecology_simulation)
	if not bool(load_result.get("ok", false)):
		push_warning("Could not load regional location %s: %s" % [location_id, load_result])
		return
	active_location_runtime = load_result.get("runtime") as Campaign2MultiStoryLocationRuntime
	if active_location_runtime == null:
		return
	var anchor_data: Dictionary = active_location_runtime.definition.get("anchor", {})
	var anchor := Vector2i(int(anchor_data.get("q", 0)), int(anchor_data.get("r", 0)))
	active_location_runtime.global_position = HexGrid.axial_to_world(anchor, HEX_RADIUS, terrain_data.elevation_for_hex(anchor))
	active_location_runtime.floor_changed.connect(_on_regional_location_floor_changed)
	active_location_runtime.register_character_actor(ecology_simulation.player_character_id, player_actor)
	var player_state := ecology_simulation.get_character(ecology_simulation.player_character_id)
	if player_state != null:
		_update_player_presentation(player_state.axial)

func _interact_with_regional_location() -> bool:
	if active_location_runtime == null:
		return false
	var result: Dictionary = active_location_runtime.interact_with_stair(ecology_simulation.player_character_id)
	if not bool(result.get("ok", false)):
		return false
	var player_state := ecology_simulation.get_character(ecology_simulation.player_character_id)
	if player_state != null:
		target = _world_position_for_hex(player_state.axial)
		_update_player_presentation(player_state.axial)
		_update_camera()
	return true

func _on_regional_location_floor_changed(_location_id: String, _previous_floor: int, _current_floor: int, _stair_position: Vector2i) -> void:
	var player_state := ecology_simulation.get_character(ecology_simulation.player_character_id)
	if player_state == null:
		return
	_update_player_presentation(player_state.axial)
	target = _world_position_for_hex(player_state.axial)
	_update_camera()


## Returns stable GLB placements for wilderness forest cells in one streamed chunk.
## Density remains governed by the source terrain rules; this only replaces the
## old shared cylinder/sphere tree silhouettes with the committed vegetation catalogue.
func _wilderness_vegetation_placements_for_chunk(chunk_min: Vector2i, chunk_size: int) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	for q in range(chunk_min.x, chunk_min.x + chunk_size):
		for r in range(chunk_min.y, chunk_min.y + chunk_size):
			var hex := Vector2i(q, r)
			if not terrain_data.has_tree(hex) or not terrain_data.settlement_definition_registry.resolve(hex).is_empty():
				continue
			var centre := HexGrid.axial_to_world(hex, HEX_RADIUS, terrain_data.elevation_for_hex(hex))
			var size_roll := LOCAL_TERRAIN_RULES.stable_roll(hex, 2909)
			var near_stream := HEARTLAND_BIOMES.is_near_stream(
				hex,
				6.0,
				REGIONAL_HYDROLOGY.stream_centre_r(hex.x)
			)
			var family := HEARTLAND_BIOMES.select_tree_family(hex, near_stream)
			var seed_value := int(LOCAL_TERRAIN_RULES.stable_roll(hex, 3047) * 2147483646.0)
			placements.append({
				"name": "WildernessTree_%d_%d" % [hex.x, hex.y],
				"position": centre,
				"family": family,
				"seed": seed_value,
				"scale": 0.72 + size_roll * 0.5,
				"rotation_y": LOCAL_TERRAIN_RULES.stable_roll(hex, 2909) * TAU
			})
	return placements

func _populate_chunk_gameplay_cells(chunk: Vector2i) -> void:
	var chunk_min := chunk * CHUNK_SIZE
	for q in range(chunk_min.x, chunk_min.x + CHUNK_SIZE):
		for r in range(chunk_min.y, chunk_min.y + CHUNK_SIZE):
			var hex := Vector2i(q, r)
			if ecology_simulation.map_data.has_cell(hex):
				continue
			var terrain := terrain_data.terrain_for_hex(hex)
			if terrain == "void":
				continue
			var walkable := terrain_data.is_walkable_for_hex(hex)
			var movement_multiplier := terrain_data.movement_multiplier_for_hex(hex)
			ecology_simulation.map_data.add_cell(hex, terrain_data.elevation_for_hex(hex), walkable, terrain, movement_multiplier)

func _on_world_character_moved(character_id: String, _from_hex: Vector2i, to_hex: Vector2i) -> void:
	if character_id == ecology_simulation.player_character_id:
		_update_player_presentation(to_hex)
		target = _world_position_for_hex(to_hex)
		_update_camera()
		_update_streamed_chunks(false)
		return
	# NPC simulation state outlives its chunk actor. If the actor is currently
	# streamed, follow the authoritative axial position; otherwise the builder
	# will restore it at that position when its destination chunk loads.
	for actor_value in get_tree().get_nodes_in_group("campaign2_npc_actors"):
		var actor := actor_value as Node3D
		if actor == null or String(actor.get_meta("campaign2_npc_id", "")) != character_id:
			continue
		actor.position = _world_position_for_hex(to_hex)
		break

func _update_player_presentation(hex: Vector2i) -> void:
	if player_actor == null:
		return
	player_actor.position = _world_position_for_hex(hex)

func _world_position_for_hex(hex: Vector2i) -> Vector3:
	var base_position := HexGrid.axial_to_world(hex, HEX_RADIUS, terrain_data.elevation_for_hex(hex))
	if active_location_runtime != null and active_location_runtime.get_current_floor() > 0:
		base_position.y = active_location_runtime.global_position.y + float(active_location_runtime.get_current_floor()) * 3.2 + 0.1
	return base_position

func _request_travel_to_screen_position(screen_position: Vector2) -> void:
	if camera == null or movement_controller == null:
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var player_state := ecology_simulation.get_character(ecology_simulation.player_character_id)
	if player_state == null:
		return
	var ground_height := _world_position_for_hex(player_state.axial).y
	var hit: Variant = Plane(Vector3.UP, ground_height).intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return
	var destination := HexGrid.world_to_axial(hit, HEX_RADIUS)
	if ecology_simulation.map_data.has_cell(destination) and ecology_simulation.map_data.is_walkable(destination):
		movement_controller.set_destination(destination)

func _add_hex_to_surface(surface: SurfaceTool, hex: Vector2i, elevation: float) -> void:
	var centre_elevation := terrain_data.WATER_SURFACE_ELEVATION if terrain_data.terrain_for_hex(hex) == "water" else elevation
	var centre := HexGrid.axial_to_world(hex, HEX_RADIUS, centre_elevation)
	var corners := HexGrid.corner_offsets(HEX_RADIUS)
	for index in range(HexGrid.SIDE_COUNT):
		var next_index := (index + 1) % HexGrid.SIDE_COUNT
		var next_vertex := Vector3(corners[next_index].x, terrain_data.shared_vertex_elevation(hex, next_index), corners[next_index].y)
		var current_vertex := Vector3(corners[index].x, terrain_data.shared_vertex_elevation(hex, index), corners[index].y)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(centre)
		surface.add_vertex(HexGrid.axial_to_world(hex, HEX_RADIUS) + next_vertex)
		surface.add_vertex(HexGrid.axial_to_world(hex, HEX_RADIUS) + current_vertex)

func _add_chunk_locations(parent: Node3D, chunk: Vector2i) -> void:
	var chunk_min := chunk * CHUNK_SIZE
	for location in terrain_data.locations:
		if not terrain_data.is_location_marker_visible(location):
			continue
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
			elif key.keycode == KEY_F and _interact_with_regional_location():
				get_viewport().set_input_as_handled()
			else:
				var movement_key := key.keycode
				match key.keycode:
					KEY_UP: movement_key = KEY_W
					KEY_RIGHT: movement_key = KEY_E
					KEY_DOWN: movement_key = KEY_S
					KEY_LEFT: movement_key = KEY_A
				if movement_controller != null and movement_controller.handle_directional_key(movement_key):
					get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				mouse_travel_pressed = true
			elif mouse_travel_pressed:
				mouse_travel_pressed = false
				_request_travel_to_screen_position(button.position)
				get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_MIDDLE:
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
