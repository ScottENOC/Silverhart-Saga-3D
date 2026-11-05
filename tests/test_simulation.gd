extends SceneTree

var _failures: int = 0

func _initialize() -> void:
    _test_character_round_trip()
    _test_movement_validation()
    _test_time_point_rules()
    _test_action_movement_cost()
    _test_terrain_pathfinding()
    _test_elevation_rules()
    _test_world_clock()
    _test_combat_turn_scheduler()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
    print("WorldSimulation tests passed.")
    quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
    if not condition:
        _failures += 1
        push_error(message)

func _test_character_round_trip() -> void:
    var original := CharacterState.new("npc_garrick_holt", "Garrick Holt", Vector2i(2, -1))
    original.health = 73
    original.time_points = 87.5
    original.time_points_per_tick = 1.25
    original.total_time_points_spent = 42.0
    original.quick_recovery_rank = 4
    original.skills["fastMovement"] = 2
    original.equipment["armour"] = "light_armor"
    var restored := CharacterState.from_dict(original.to_dict())
    _check(restored.id == original.id)
    _check(restored.display_name == original.display_name)
    _check(restored.axial == original.axial)
    _check(restored.health == 73)
    _check(is_equal_approx(restored.time_points, 87.5))
    _check(is_equal_approx(restored.time_points_per_tick, 1.25))
    _check(is_equal_approx(restored.total_time_points_spent, 42.0))
    _check(restored.quick_recovery_rank == 4)
    _check(int(restored.skills["fastMovement"]) == 2)
    _check(String(restored.equipment["armour"]) == "light_armor")

func _test_movement_validation() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(2, 0), 0.0, false)
    sim.register_character(CharacterState.new("player", "Player", Vector2i.ZERO))
    _check(sim.try_move_character("player", Vector2i(1, 0)))
    _check(not sim.try_move_character("player", Vector2i(2, 0)))
    _check(not sim.try_move_character("player", Vector2i(3, 0)))
    _check(not sim.try_move_character("missing", Vector2i(0, 1)))

func _test_time_point_rules() -> void:
    _check(not ActionEconomy.can_start_combat_turn(99.99))
    _check(ActionEconomy.can_start_combat_turn(100.0))
    _check(not ActionEconomy.can_start_combat_turn(120.0, false))
    _check(not ActionEconomy.can_start_combat_turn(120.0, true, true))
    _check(not ActionEconomy.can_start_combat_turn(120.0, true, false, true))
    _check(not ActionEconomy.can_start_combat_turn(120.0, true, false, false, true))
    _check(ActionEconomy.turn_end_threshold() == 80)
    _check(ActionEconomy.turn_end_threshold(5) == 75)
    _check(ActionEconomy.turn_end_threshold(99) == 60)
    _check(ActionEconomy.should_end_turn(80.9))
    _check(not ActionEconomy.should_end_turn(81.0))
    _check(ActionEconomy.should_end_turn(75.9, 5))
    _check(not ActionEconomy.should_end_turn(76.0, 5))
    _check(ActionEconomy.should_end_turn(140.0, 0, true))
    _check(is_equal_approx(ActionEconomy.regenerate(149.5), 150.5))
    _check(is_equal_approx(ActionEconomy.regenerate(150.0), 150.0))
    _check(is_equal_approx(ActionEconomy.regenerate(10.0, 0.5, 2.0), 11.0))
    _check(is_equal_approx(ActionEconomy.spend(10.0, 3.5), 6.5))
    _check(not ActionEconomy.can_afford(3.0, 5.0))

func _test_action_movement_cost() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(2, 0), 0.0, false)
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.time_points = 5.0
    sim.register_character(player)
    _check(sim.try_move_character_action("player", Vector2i(1, 0), 5.0))
    _check(player.axial == Vector2i(1, 0))
    _check(is_equal_approx(player.time_points, 0.0))
    _check(is_equal_approx(player.total_time_points_spent, 5.0))
    _check(not sim.try_move_character_action("player", Vector2i(0, 0), 1.0))
    _check(player.axial == Vector2i(1, 0))
    _check(is_equal_approx(player.time_points, 0.0))
    player.time_points = 10.0
    _check(not sim.try_move_character_action("player", Vector2i(2, 0), 5.0))
    _check(is_equal_approx(player.time_points, 10.0))

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
    _check(path.size() == 4, "Pathfinder should route around blocked terrain")
    _check(path[0] == Vector2i.ZERO)
    _check(path[3] == Vector2i(2, 0))
    for i in range(1, path.size()):
        _check(HexGrid.distance(path[i - 1], path[i]) == 1)
    sim.map_data.add_cell(Vector2i(0, -1), 0.0, true, "forest")
    _check(is_equal_approx(sim.movement_cost("player", Vector2i(0, -1)), 7.5))
    player.skills["fastMovement"] = 2
    _check(is_equal_approx(sim.movement_cost("player", Vector2i(0, -1)), 4.5))
    _check(sim.try_move_character_step("player", Vector2i(0, 1)))
    _check(player.axial == Vector2i(0, 1))
    _check(is_equal_approx(player.time_points, 17.0))
    _check(is_equal_approx(player.total_time_points_spent, 3.0))

func _test_elevation_rules() -> void:
    var map_data := HexMapData.new()
    map_data.add_cell(Vector2i(0, 0), 0.0)
    map_data.add_cell(Vector2i(1, 0), 0.5)
    map_data.add_cell(Vector2i(2, 0), 2.5)
    map_data.add_cell(Vector2i(3, 0), 6.5)
    var climber := CharacterState.new("climber", "Climber", Vector2i.ZERO)
    var gentle_cost := MovementRules.step_cost(map_data, Vector2i.ZERO, Vector2i(1, 0), climber)
    _check(gentle_cost > 5.0 and gentle_cost < 6.0, "Gentle uphill should add a modest movement cost")
    var steep_cost := MovementRules.step_cost(map_data, Vector2i(1, 0), Vector2i(2, 0), climber)
    _check(is_inf(steep_cost), "A climbable face should require climbing skill")
    climber.skills["climbing"] = 1
    steep_cost = MovementRules.step_cost(map_data, Vector2i(1, 0), Vector2i(2, 0), climber)
    _check(steep_cost > 10.0, "Climbing skill should make a steep face traversable at a high cost")
    var cliff_cost := MovementRules.step_cost(map_data, Vector2i(2, 0), Vector2i(3, 0), climber)
    _check(is_inf(cliff_cost), "A cliff should require expert climbing")
    climber.skills["climbing"] = 3
    cliff_cost = MovementRules.step_cost(map_data, Vector2i(2, 0), Vector2i(3, 0), climber)
    _check(cliff_cost > steep_cost, "Expert climbing should permit cliffs at a substantial cost")

    # Shared vertex coordinates must resolve to one sample across adjacent cells.
    map_data.set_vertex_height(Vector2i.ZERO, 0, 2.25)
    var shared := map_data.corner_world_position(Vector2i.ZERO, 0)
    var adjacent := map_data.corner_world_position(Vector2i(1, 0), 4)
    _check(is_equal_approx(shared.x, adjacent.x) and is_equal_approx(shared.z, adjacent.z))
    _check(is_equal_approx(shared.y, adjacent.y), "Adjacent hexes must share their edge vertex height")

func _test_world_clock() -> void:
    var clock := WorldClock.new()
    _check(clock.advance_world_seconds(0.39) == 0)
    _check(is_equal_approx(clock.world_seconds, 0.0))
    _check(clock.advance_world_seconds(0.01) == 1)
    _check(is_equal_approx(clock.world_seconds, 0.4))
    _check(clock.tick_index == 1)
    clock.set_world_seconds(11.0 * 3600.0)
    var date := clock.calendar_date()
    var time := clock.time_of_day()
    _check(date.month_name == "Dawnfrost")
    _check(date.day_of_month == 1)
    _check(time.text == "11:00")
    clock.set_world_seconds(31.0 * 86400.0)
    date = clock.calendar_date()
    _check(date.month_name == "Brightsun")
    _check(date.day_of_month == 2)
    clock.set_world_seconds(0.0)
    clock.time_speed_multiplier = 3.0
    _check(clock.advance_real_time(0.01, true) == 1)
    clock.set_world_seconds(0.0)
    _check(clock.advance_real_time(0.01, false) == 0)
    clock.set_world_seconds(0.4)
    clock.paused = true
    _check(clock.advance_world_seconds(4.0) == 0)
    _check(is_equal_approx(clock.world_seconds, 0.4))
    clock.paused = false
    var saved := clock.to_dict()
    var restored := WorldClock.new()
    restored.load_dict(saved)
    _check(restored.tick_index == clock.tick_index)
    _check(is_equal_approx(restored.world_seconds, clock.world_seconds))

func _test_combat_turn_scheduler() -> void:
    var sim := WorldSimulation.new()
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    var guard := CharacterState.new("guard", "Guard", Vector2i(1, 0))
    player.time_points = 99.5
    guard.time_points = 99.0
    sim.register_character(player)
    sim.register_character(guard)
    sim.start_combat()
    _check(sim.advance_world_seconds(0.4) == 1)
    _check(not sim.turn_scheduler.has_active_turn())
    _check(is_equal_approx(player.time_points, 100.5))
    _check(is_equal_approx(guard.time_points, 100.0))
    _check(sim.advance_world_seconds(0.4) == 0)
    _check(sim.turn_scheduler.current_character_id == "player")
    _check(sim.get_current_turn_character() == player)
    _check(is_equal_approx(sim.clock.world_seconds, 0.4))
    _check(is_equal_approx(player.time_points, 100.5))
    _check(is_equal_approx(guard.time_points, 100.0))
    _check(sim.advance_world_seconds(0.4) == 0)
    _check(is_equal_approx(player.time_points, 100.5))
    _check(is_equal_approx(guard.time_points, 100.0))
    _check(not sim.try_end_current_turn())
    player.time_points = 80.0
    _check(sim.try_end_current_turn())
    _check(not sim.turn_scheduler.has_active_turn())
    _check(sim.advance_world_seconds(0.4) == 0)
    _check(sim.turn_scheduler.current_character_id == "guard")
    _check(is_equal_approx(guard.time_points, 100.0))
    var save_data := sim.to_dict()
    var loaded := WorldSimulation.new()
    loaded.load_dict(save_data)
    _check(loaded.is_in_combat)
    _check(loaded.get_character("guard") != null)
    _check(loaded.get_character("player") != null)
    _check(is_equal_approx(loaded.clock.world_seconds, sim.clock.world_seconds))
