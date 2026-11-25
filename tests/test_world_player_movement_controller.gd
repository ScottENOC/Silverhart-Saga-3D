extends SceneTree

const CONTROLLER_SCRIPT = preload("res://scripts/world/world_player_movement_controller.gd")

var _failures: int = 0

func _initialize() -> void:
	_test_shared_path_movement()
	_test_group_following_toggle()
	if _failures > 0:
		push_error("%d test assertion(s) failed." % _failures)
		quit(1)
		return
	print("Shared world player movement controller tests passed.")
	quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _hex_world_position(hex: Vector2i) -> Vector3:
	return Vector3(float(hex.x), 0.0, float(hex.y))

func _test_group_following_toggle() -> void:
	var simulation := WorldSimulation.new()
	for q in range(-1, 8):
		simulation.map_data.add_cell(Vector2i(q, 0))
	var leader := CharacterState.new("leader", "Leader", Vector2i(2, 0))
	leader.time_points = 100.0
	var follower := CharacterState.new("follower", "Follower", Vector2i.ZERO)
	follower.time_points = 100.0
	simulation.register_character(leader)
	simulation.register_character(follower)
	simulation.restore_party_members(["leader", "follower"])
	var presentation_root := Node3D.new()
	root.add_child(presentation_root)
	var controller: Variant = CONTROLLER_SCRIPT.new()
	presentation_root.add_child(controller)
	controller.configure(simulation, presentation_root, BoxMesh.new(), StandardMaterial3D.new(), Callable(self, "_hex_world_position"), "leader")
	controller.set_group_movement_enabled(true)
	controller.set_destination(Vector2i(5, 0))
	controller.process_movement(0.40)
	_check(leader.axial == Vector2i(3, 0), "Group movement should preserve normal leader path movement")
	_check(follower.axial != Vector2i.ZERO, "Enabled group movement should advance a distant party follower")
	controller.set_group_movement_enabled(false)
	var follower_position := follower.axial
	controller.process_movement(0.40)
	_check(follower.axial == follower_position, "Disabled group movement should leave followers under individual control")
	controller.set_group_movement_enabled(true)
	simulation.is_in_combat = true
	var combat_follower_position := follower.axial
	controller.process_movement(0.80)
	_check(follower.axial == combat_follower_position, "Group followers must not move during turn-based combat")
	simulation.is_in_combat = false
	_check(controller.is_group_movement_enabled(), "The exploration group-movement preference should survive combat")
	presentation_root.free()
	simulation.free()


func _test_shared_path_movement() -> void:
	var simulation := WorldSimulation.new()
	for q in range(3):
		simulation.map_data.add_cell(Vector2i(q, 0))
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	player.time_points = 30.0
	simulation.register_character(player)
	var presentation_root := Node3D.new()
	root.add_child(presentation_root)
	var controller: Variant = CONTROLLER_SCRIPT.new()
	presentation_root.add_child(controller)
	controller.configure(simulation, presentation_root, BoxMesh.new(), StandardMaterial3D.new(), Callable(self, "_hex_world_position"))
	controller.set_destination(Vector2i(2, 0))
	var route: Array[Vector2i] = controller.get_active_path()
	_check(route.size() == 3, "Shared controller should request a complete path from WorldSimulation")
	_check(route[0] == Vector2i.ZERO and route[2] == Vector2i(2, 0), "Shared route should preserve origin and destination")
	controller.process_movement(0.40)
	_check(player.axial == Vector2i(1, 0), "Shared controller should execute the first legal movement step")
	controller.process_movement(0.40)
	_check(player.axial == Vector2i(2, 0), "Shared controller should execute the second legal movement step")
	_check(controller.get_active_path().is_empty(), "Completed routes should clear their queued path")
	var before_paused_move := player.axial
	simulation.clock.paused = true
	_check(controller.handle_directional_key(KEY_W), "W should be handled by the shared directional input mapping")
	_check(player.axial == before_paused_move, "Directional movement must respect the world pause")
	_check(not controller.handle_directional_key(KEY_F), "Non-movement keys must be left to the location or UI controller")
	controller.clear_path()
	presentation_root.free()
	simulation.free()
