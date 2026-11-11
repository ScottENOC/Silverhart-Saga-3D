class_name FogOfWar
extends Node3D
## Persistent hex visibility for Hollowmere. The vision grid is deliberately
## separate from WorldSimulation.map_data so pathfinding does not inherit the
## much larger outdoor map.

const MAP_RADIUS: int = HollowmereVillageData.MAP_RADIUS
const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M
const ROOM_HALF_WIDTH: float = 8.0
const ROOM_HALF_DEPTH: float = 5.5

var vision_map: HexMapData = HexMapData.new()
var observer: CharacterState
var actor_nodes: Dictionary = {}
var resource_nodes: Dictionary = {}
var village_root: Node3D
var village_geometry_by_hex: Dictionary = {}
var visible_hexes: Dictionary = {}
var explored_hexes: Dictionary = {}
var hex_to_instance: Dictionary = {}
var hexes: Array[Vector2i] = []
var vision_offsets: Array[Vector2i] = []
var fog_multimesh_instance: MultiMeshInstance3D
var fog_multimesh: MultiMesh
var debug_panel: PanelContainer
var debug_label: Label
var debug_visible: bool = true

var update_count: int = 0
var total_update_usec: int = 0
var last_update_usec: int = 0
var initialization_usec: int = 0
var max_update_usec: int = 0
var last_candidate_count: int = 0
var last_los_checks: int = 0
var last_changed_count: int = 0
var last_move_callback_usec: int = 0
var last_pathfind_usec: int = 0
var last_simulation_move_usec: int = 0
var last_path_step_usec: int = 0
var _previous_visible: Dictionary = {}

func initialize(
	player_state: CharacterState,
	actors: Dictionary,
	resources: Dictionary,
	outdoor_village: Node3D
) -> void:
	var initialization_started := Time.get_ticks_usec()
	observer = player_state
	actor_nodes = actors
	resource_nodes = resources
	village_root = outdoor_village
	_build_vision_map()
	_build_fog_mesh()
	_build_vision_offsets()
	_cache_village_geometry()
	_build_debug_panel()
	update_visibility(observer)
	initialization_usec = Time.get_ticks_usec() - initialization_started
	_refresh_debug_label()

func _build_vision_offsets() -> void:
	var exploration_range := VisionRules.exploration_range()
	for q in range(-exploration_range, exploration_range + 1):
		for r in range(-exploration_range, exploration_range + 1):
			var offset := Vector2i(q, r)
			if HexGrid.distance(Vector2i.ZERO, offset) <= exploration_range:
				vision_offsets.append(offset)

func _build_vision_map() -> void:
	vision_map = HexMapData.new()
	for q in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for r in range(-MAP_RADIUS, MAP_RADIUS + 1):
			var hex := Vector2i(q, r)
			if not HollowmereVillageData.is_in_bounds(hex):
				continue
			var world := HexGrid.axial_to_world(hex, HEX_RADIUS)
			var inside_tavern := absf(world.x) < ROOM_HALF_WIDTH - 0.2 and absf(world.z) < ROOM_HALF_DEPTH - 0.2
			var terrain_id := "timber_floor" if inside_tavern else HollowmereVillageData.terrain_id_at(hex)
			var blocked := HollowmereVillageData.is_blocked(hex)
			vision_map.add_cell(hex, 0.0, not blocked, terrain_id)
			var cell: Dictionary = vision_map.cells[hex]
			if terrain_id == "building":
				cell["blocks_vision"] = true
				cell["vision_block_height"] = VisionRules.DEFAULT_OPAQUE_HEIGHT_M
			if _is_tavern_wall_cell(world):
				cell["blocks_vision"] = true
				cell["vision_block_height"] = 3.2

func _is_tavern_wall_cell(world: Vector3) -> bool:
	if absf(absf(world.x) - ROOM_HALF_WIDTH) < 1.1 and absf(world.z) < ROOM_HALF_DEPTH:
		return true
	if absf(world.z + ROOM_HALF_DEPTH) < 1.1:
		return true
	if absf(world.z - ROOM_HALF_DEPTH) < 1.1 and absf(world.x) > 1.1:
		return true
	return false

func _build_fog_mesh() -> void:
	# MultiMesh repeats this one small hex. Building the entire world mesh here
	# would accidentally duplicate the whole map once per cell.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := HexGrid.corner_offsets(HEX_RADIUS)
	for i in range(HexGrid.SIDE_COUNT):
		var next_i := (i + 1) % HexGrid.SIDE_COUNT
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(Vector3(corners[i].x, 0.0, corners[i].y))
		surface.add_vertex(Vector3(corners[next_i].x, 0.0, corners[next_i].y))
	var fog_mesh := surface.commit()

	for q in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for r in range(-MAP_RADIUS, MAP_RADIUS + 1):
			var hex := Vector2i(q, r)
			if vision_map.has_cell(hex):
				hex_to_instance[hex] = hexes.size()
				hexes.append(hex)

	fog_multimesh = MultiMesh.new()
	fog_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	fog_multimesh.use_custom_data = true
	fog_multimesh.mesh = fog_mesh
	fog_multimesh.instance_count = hexes.size()
	for index in range(hexes.size()):
		var hex: Vector2i = hexes[index]
		var centre := HexGrid.axial_to_world(hex, HEX_RADIUS, 0.14)
		fog_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, centre))
		fog_multimesh.set_instance_custom_data(index, Color(0.0, 0.0, 0.0, 1.0))

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
varying float fog_state;
void vertex() {
	fog_state = INSTANCE_CUSTOM.r;
}
void fragment() {
	if (fog_state > 0.75) {
		discard;
	}
	if (fog_state < 0.25) {
		ALBEDO = vec3(0.012, 0.016, 0.022);
	} else {
		ALBEDO = vec3(0.12, 0.14, 0.16);
	}
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = 1
	fog_multimesh_instance = MultiMeshInstance3D.new()
	fog_multimesh_instance.name = "PersistentHexFog"
	fog_multimesh_instance.multimesh = fog_multimesh
	fog_multimesh_instance.material_override = material
	fog_multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fog_multimesh_instance)

func update_visibility(player_state: CharacterState) -> void:
	if player_state == null:
		return
	observer = player_state
	var started := Time.get_ticks_usec()
	var visible_range := VisionRules.vision_range(observer)
	var next_visible: Dictionary = {}
	var cells_to_refresh: Dictionary = {}
	for old_hex_value in _previous_visible.keys():
		var previous_hex: Vector2i = old_hex_value
		cells_to_refresh[previous_hex] = true
	var candidate_count := 0
	var los_count := 0
	var changed_count := 0

	# Previously visible cells become explored/dim before the new view is applied.
	for old_hex_value in _previous_visible.keys():
		var old_hex: Vector2i = old_hex_value
		if _set_fog_state(old_hex, 1):
			changed_count += 1

	for offset in vision_offsets:
		var hex := observer.axial + offset
		if not vision_map.has_cell(hex):
			continue
		candidate_count += 1
		los_count += 1
		if not VisionRules.has_line_of_sight(vision_map, observer.axial, hex):
			continue
		if HexGrid.distance(observer.axial, hex) <= visible_range:
			next_visible[hex] = true
			cells_to_refresh[hex] = true
			explored_hexes[hex] = true
			if _set_fog_state(hex, 2):
				changed_count += 1
		else:
			explored_hexes[hex] = true
			if _set_fog_state(hex, 1):
				changed_count += 1

	visible_hexes = next_visible
	_previous_visible = next_visible.duplicate()
	_apply_actor_visibility()
	_apply_village_visibility(cells_to_refresh)

	last_update_usec = Time.get_ticks_usec() - started
	total_update_usec += last_update_usec
	update_count += 1
	max_update_usec = maxi(max_update_usec, last_update_usec)
	last_candidate_count = candidate_count
	last_los_checks = los_count
	last_changed_count = changed_count
	_refresh_debug_label()

func _set_fog_state(hex: Vector2i, state: int) -> bool:
	if not hex_to_instance.has(hex):
		return false
	var index := int(hex_to_instance[hex])
	var current := int(round(fog_multimesh.get_instance_custom_data(index).r * 2.0))
	if current == state:
		return false
	fog_multimesh.set_instance_custom_data(index, Color(float(state) * 0.5, 0.0, 0.0, 1.0))
	return true

func _apply_actor_visibility() -> void:
	for actor_id in actor_nodes.keys():
		if String(actor_id) == "player":
			continue
		var state := actor_nodes[actor_id] as Node3D
		if state == null or not is_instance_valid(state):
			continue
		var character_state := _character_state_for_actor(String(actor_id))
		if character_state != null:
			state.visible = visible_hexes.has(character_state.axial)
	for key in resource_nodes.keys():
		var resource_node := resource_nodes[key] as Node3D
		if resource_node != null and is_instance_valid(resource_node):
			resource_node.visible = visible_hexes.has(key)

func _character_state_for_actor(character_id: String) -> CharacterState:
	var simulation := get_parent().get("simulation") as WorldSimulation
	if simulation == null:
		return null
	return simulation.get_character(character_id)

func _cache_village_geometry() -> void:
	if village_root == null or not is_instance_valid(village_root):
		return
	_collect_village_geometry(village_root)

func _collect_village_geometry(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D:
			var geometry := child as GeometryInstance3D
			if geometry.name != "HollowmereGrassland":
				var hex := HexGrid.world_to_axial(geometry.global_position, HEX_RADIUS)
				if not village_geometry_by_hex.has(hex):
					village_geometry_by_hex[hex] = []
				village_geometry_by_hex[hex].append(geometry)
				geometry.set_meta("fog_original_visible", geometry.visible)
				geometry.visible = false
		_collect_village_geometry(child)

func _apply_village_visibility(cells_to_refresh: Dictionary) -> void:
	for hex_value in cells_to_refresh.keys():
		var hex: Vector2i = hex_value
		if not village_geometry_by_hex.has(hex):
			continue
		for geometry_value in village_geometry_by_hex[hex]:
			var geometry := geometry_value as GeometryInstance3D
			if is_instance_valid(geometry):
				var original_visible := bool(geometry.get_meta("fog_original_visible", true))
				geometry.visible = original_visible and visible_hexes.has(hex)

func _build_debug_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FogPerformanceOverlay"
	layer.layer = 250
	add_child(layer)
	debug_panel = PanelContainer.new()
	debug_panel.position = Vector2(22.0, 158.0)
	debug_panel.custom_minimum_size = Vector2(430.0, 132.0)
	layer.add_child(debug_panel)
	var toggle_button := Button.new()
	toggle_button.text = "Fog performance  [F3]"
	toggle_button.position = Vector2(22.0, 122.0)
	toggle_button.pressed.connect(toggle_debug)
	layer.add_child(toggle_button)
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 13)
	debug_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96))
	debug_panel.add_child(debug_label)
	_refresh_debug_label()

func _refresh_debug_label() -> void:
	if debug_label == null:
		return
	var average_ms := float(total_update_usec) / float(maxi(1, update_count)) / 1000.0
	debug_label.text = (
		"FOG / PERFORMANCE  [F3]\n"
		+ "Setup: %.1f ms  | update: %.3f ms  | avg %.3f  | max %.3f\n" % [
			float(initialization_usec) / 1000.0,
			float(last_update_usec) / 1000.0,
			average_ms,
			float(max_update_usec) / 1000.0
		]
		+ "LOS checks: %d  | candidates: %d  | changed cells: %d\n" % [
			last_los_checks,
			last_candidate_count,
			last_changed_count
		]
		+ "Pathfind: %.3f ms  | simulation move: %.3f ms\n" % [
			float(last_pathfind_usec) / 1000.0,
			float(last_simulation_move_usec) / 1000.0
		]
		+ "Path step: %.3f ms  | movement callback: %.3f ms" % [
			float(last_path_step_usec) / 1000.0,
			float(last_move_callback_usec) / 1000.0
		]
	)
	debug_panel.visible = debug_visible

func record_timing(category: String, elapsed_usec: int) -> void:
	match category:
		"pathfind":
			last_pathfind_usec = elapsed_usec
		"simulation_move":
			last_simulation_move_usec = elapsed_usec
		"movement_callback":
			last_move_callback_usec = elapsed_usec
		"path_step":
			last_path_step_usec = elapsed_usec
	_refresh_debug_label()

func toggle_debug() -> void:
	debug_visible = not debug_visible
	if debug_panel != null:
		debug_panel.visible = debug_visible

func is_visible(hex: Vector2i) -> bool:
	return visible_hexes.has(hex)

func is_explored(hex: Vector2i) -> bool:
	return explored_hexes.has(hex)
