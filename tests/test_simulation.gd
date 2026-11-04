extends SceneTree

func _initialize() -> void:
    _test_character_round_trip()
    _test_movement_validation()
    _test_time_point_rules()
    _test_action_movement_cost()
    _test_terrain_pathfinding()
    _test_world_clock()
    _test_combat_turn_scheduler()
    print("WorldSimulation tests passed.")
    quit()

func _test_character_round_trip() -> void:
    var original := CharacterState.new("npc_garrick_holt", "Garrick Holt", Vector2i(2, -1))
    original.health = 73
    original.time_points = 87.5
    original.time_points_per_tick = 1.25
    original.total_time_points_spent = 42.0
    original.quick_recovery_rank = 4
    var restored := CharacterState.from_dict(original.to_dict())
    assert(restored.id == original.id)
    assert(restored.display_name == original.display_name)
    assert(restored.axial == original.axial)
    assert(restored.health == 73)
    assert(is_equal_approx(restored.time_points, 87.5))
    assert(is_equal_approx(restored.time_points_per_tick, 1.25))
    assert(is_equal_approx(restored.total_time_points_spent, 42.0))
    assert(restored.quick_recovery_rank == 4)

func _test_movement_validation() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(2, 0), 0.0, false)
    sim.register_character(CharacterState.new("player", "Player", Vector2i.ZERO))
    assert(sim.try_move_character("player", Vector2i(1, 0)))
    assert(not sim.try_move_character("player", Vector2i(2, 0)))
    assert(not sim.try_move_character("player", Vector2i(3, 0)))
    assert(not sim.try_move_character("missing", Vector2i(0, 1)))

func _test_time_point_rules() -> void:
    assert(not ActionEconomy.can_start_combat_turn(99.99))
    assert(ActionEconomy.can_start_combat_turn(100.0))
    assert(ActionEconomy.turn_end_threshold() == 80)
    assert(ActionEconomy.turn_end_threshold(5) == 75)
    assert(ActionEconomy.turn_end_threshold(99) == 60)
    assert(ActionEconomy.should_end_turn(80.9))
    assert(not ActionEconomy.should_end_turn(81.0))
    assert(is_equal_approx(ActionEconomy.regenerate(149.5), 150.5))
    assert(is_equal_approx(ActionEconomy.regenerate(150.0), 150.0))

func _test_action_movement_cost() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.time_points = 5.0
    sim.register_character(player)
    assert(sim.try_move_character_action("player", Vector2i(1, 0), 5.0))
    assert(player.axial == Vector2i(1, 0))
    assert(is_equal_approx(player.time_points, 0.0))

func _test_terrain_pathfinding() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0), 0.0, false)
    sim.map_data.add_cell(Vector2i(2, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    sim.map_data.add_cell(Vector2i(1, 1))
    sim.map_data.add_cell(Vector2i(2, 1))
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.time_points = 20.0
    sim.register_character(player)
    var path := sim.find_path("player", Vector2i(2, 0))
    assert(path.size() == 5)
    assert(path[0] == Vector2i.ZERO)
    assert(path[4] == Vector2i(2, 0))
    for i in range(1, path.size()):
        assert(HexGrid.distance(path[i - 1], path[i]) == 1)
    sim.map_data.add_cell(Vector2i(0, -1), 0.0, true, "forest")
    assert(is_equal_approx(sim.movement_cost("player", Vector2i(0, -1)), 7.5))
    player.skills["fastMovement"] = 2
    assert(is_equal_approx(sim.movement_cost("player", Vector2i(0, -1)), 4.5))
    assert(sim.try_move_character_step("player", Vector2i(0, 1)))
    assert(player.axial == Vector2i(0, 1))
    assert(is_equal_approx(player.time_points, 15.0))

func _test_world_clock() -> void:
    var clock := WorldClock.new()
    assert(clock.advance_world_seconds(0.39) == 0)
    assert(clock.advance_world_seconds(0.01) == 1)
    clock.set_world_seconds(11.0 * 3600.0)
    assert(clock.calendar_date().month_name == "Dawnfrost")
    assert(clock.time_of_day().text == "11:00")
    clock.set_world_seconds(31.0 * 86400.0)
    assert(clock.calendar_date().month_name == "Brightsun")

func _test_combat_turn_scheduler() -> void:
    var sim := WorldSimulation.new()
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    var guard := CharacterState.new("guard", "Guard", Vector2i(1, 0))
    player.time_points = 99.5
    guard.time_points = 99.0
    sim.register_character(player)
    sim.register_character(guard)
    sim.start_combat()
    assert(sim.advance_world_seconds(0.4) == 1)
    assert(sim.advance_world_seconds(0.4) == 0)
    assert(sim.get_current_turn_character() == player)
