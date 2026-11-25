extends Node
class_name WorldPlayerMovementController

## Keep logical path steps just slower than the 0.36s actor tween.
const PATH_STEP_INTERVAL: float = 0.40
const FOLLOW_DISTANCE: int = 2

var simulation: WorldSimulation
var presentation_root: Node3D
var active_character_id: String = "player"
var tile_mesh: Mesh
var path_material: Material
var world_position_for_hex: Callable
var active_path: Array[Vector2i] = []
var path_markers: Array[MeshInstance3D] = []
var path_step_accumulator: float = 0.0
var group_movement_enabled: bool = false
var _follower_cursor: int = 0

func configure(campaign_simulation: WorldSimulation, world_presentation_root: Node3D, marker_mesh: Mesh, marker_material: Material, hex_world_position: Callable, initial_character_id: String = "player") -> void:
	simulation = campaign_simulation
	presentation_root = world_presentation_root
	tile_mesh = marker_mesh
	path_material = marker_material
	world_position_for_hex = hex_world_position
	active_character_id = initial_character_id

func set_active_character_id(character_id: String) -> void:
	clear_path()
	active_character_id = character_id
	_follower_cursor = 0

func set_group_movement_enabled(enabled: bool) -> void:
	group_movement_enabled = enabled and simulation != null and not simulation.is_in_combat
	_follower_cursor = 0
	if not group_movement_enabled:
		return

func is_group_movement_enabled() -> bool:
	return group_movement_enabled and simulation != null

func set_destination(destination: Vector2i) -> void:
	if simulation == null:
		return
	var path := simulation.find_path(active_character_id, destination)
	if path.size() < 2:
		clear_path()
		return
	active_path = path
	path_step_accumulator = PATH_STEP_INTERVAL
	_show_path_markers(active_path)

func clear_path() -> void:
	active_path.clear()
	_clear_path_markers()

func attempt_relative_move(relative_step: int) -> void:
	if simulation == null or simulation.clock.paused:
		return
	var state := simulation.get_character(active_character_id)
	if state == null:
		return
	var direction_index := posmod(state.facing_direction + relative_step, 6)
	simulation.try_move_character_step(state.id, state.axial + HexGrid.DIRECTIONS[direction_index])

func handle_directional_key(keycode: int) -> bool:
	var relative_step := -1
	match keycode:
		KEY_Q: relative_step = 5
		KEY_W: relative_step = 0
		KEY_E: relative_step = 1
		KEY_A: relative_step = 4
		KEY_S: relative_step = 3
		KEY_D: relative_step = 2
		_:
			return false
	clear_path()
	attempt_relative_move(relative_step)
	return true

func process_movement(delta: float) -> void:
	if simulation == null:
		return
	if simulation.is_in_combat:
		return
	path_step_accumulator += delta
	if path_step_accumulator < PATH_STEP_INTERVAL:
		return
	path_step_accumulator = 0.0
	if active_path.size() >= 2:
		_advance_path_step()
	if is_group_movement_enabled():
		_advance_group_followers()

func get_active_path() -> Array[Vector2i]:
	return active_path.duplicate()

func _advance_path_step() -> void:
	if simulation.clock.paused or simulation.has_pending_reaction():
		return
	if active_path.size() < 2:
		clear_path()
		return
	if simulation.is_in_combat:
		return
	var next_hex := active_path[1]
	var active_state := simulation.get_character(active_character_id)
	if active_state == null:
		clear_path()
		return
	if active_state.time_points < simulation.movement_cost(active_character_id, next_hex):
		return
	if not simulation.try_move_character_step(active_character_id, next_hex):
		var destination := active_path[active_path.size() - 1]
		var replacement_path := simulation.find_path(active_character_id, destination)
		if replacement_path.size() < 2:
			clear_path()
			return
		active_path = replacement_path
		_show_path_markers(active_path)
		return
	active_path.pop_front()
	_show_path_markers(active_path)
	if active_path.size() < 2:
		clear_path()

func _advance_group_followers() -> void:
	if simulation.clock.paused or simulation.has_pending_reaction():
		return
	var leader := simulation.get_character(active_character_id)
	if leader == null:
		return
	var party_ids := simulation.get_party_member_ids()
	var followers: Array[String] = []
	for value in party_ids:
		var character_id := String(value)
		if character_id != active_character_id:
			followers.append(character_id)
	if followers.is_empty():
		return
	# Rotate the first follower each tick so a larger party gets fair movement
	# opportunities without trying to move several occupants through one hex.
	_follower_cursor = posmod(_follower_cursor, followers.size())
	for offset in range(followers.size()):
		var index := (_follower_cursor + offset) % followers.size()
		var follower_id := followers[index]
		var follower := simulation.get_character(follower_id)
		if follower == null or not follower.can_act():
			continue
		if HexGrid.distance(follower.axial, leader.axial) <= FOLLOW_DISTANCE:
			continue
		var destination := _best_following_hex(follower_id, follower.axial, leader.axial)
		if destination == follower.axial:
			continue
		var route := simulation.find_path(follower_id, destination)
		if route.size() < 2:
			continue
		var next_hex: Vector2i = route[1]
		if follower.time_points < simulation.movement_cost(follower_id, next_hex):
			continue
		if simulation.try_move_character_step(follower_id, next_hex):
			_follower_cursor = (index + 1) % followers.size()
			return

func _best_following_hex(follower_id: String, follower_hex: Vector2i, leader_hex: Vector2i) -> Vector2i:
	var best_hex := follower_hex
	var best_distance := 2147483647
	for direction in HexGrid.DIRECTIONS:
		var candidate: Vector2i = leader_hex + direction
		if not simulation.map_data.is_walkable(candidate):
			continue
		if simulation.is_hex_occupied(candidate):
			var occupant := String(simulation.occupied_hexes.get(candidate, ""))
			if occupant != follower_id:
				continue
		var distance := HexGrid.distance(follower_hex, candidate)
		if distance < best_distance:
			best_distance = distance
			best_hex = candidate
	return best_hex

func _show_path_markers(path: Array[Vector2i]) -> void:
	_clear_path_markers()
	if presentation_root == null or tile_mesh == null or not world_position_for_hex.is_valid():
		return
	for index in range(1, path.size()):
		var marker := MeshInstance3D.new()
		marker.mesh = tile_mesh
		marker.material_override = path_material
		var world_position: Vector3 = world_position_for_hex.call(path[index])
		marker.position = world_position + Vector3(0.0, 0.10, 0.0)
		marker.scale = Vector3(0.82, 0.25, 0.82)
		presentation_root.add_child(marker)
		path_markers.append(marker)

func _clear_path_markers() -> void:
	for marker in path_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	path_markers.clear()
