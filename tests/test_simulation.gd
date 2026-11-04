extends SceneTree

func _initialize() -> void:
    _test_character_round_trip()
    _test_movement_validation()
    _test_time_point_rules()
    _test_action_movement_cost()
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
    assert(not ActionEconomy.can_start_combat_turn(120.0, false))
    assert(not ActionEconomy.can_start_combat_turn(120.0, true, true))
    assert(not ActionEconomy.can_start_combat_turn(120.0, true, false, true))
    assert(not ActionEconomy.can_start_combat_turn(120.0, true, false, false, true))

    assert(ActionEconomy.turn_end_threshold() == 80)
    assert(ActionEconomy.turn_end_threshold(5) == 75)
    assert(ActionEconomy.turn_end_threshold(99) == 60)
    assert(ActionEconomy.should_end_turn(80.9))
    assert(not ActionEconomy.should_end_turn(81.0))
    assert(ActionEconomy.should_end_turn(75.9, 5))
    assert(not ActionEconomy.should_end_turn(76.0, 5))
    assert(ActionEconomy.should_end_turn(140.0, 0, true))

    assert(is_equal_approx(ActionEconomy.regenerate(149.5), 150.0))
    assert(is_equal_approx(ActionEconomy.regenerate(150.0), 150.0))
    assert(is_equal_approx(ActionEconomy.regenerate(10.0, 0.5, 2.0), 11.0))
    assert(is_equal_approx(ActionEconomy.spend(10.0, 3.5), 6.5))
    assert(not ActionEconomy.can_afford(3.0, 5.0))

func _test_action_movement_cost() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(2, 0), 0.0, false)
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.time_points = 5.0
    sim.register_character(player)

    assert(sim.try_move_character_action("player", Vector2i(1, 0), 5.0))
    assert(player.axial == Vector2i(1, 0))
    assert(is_equal_approx(player.time_points, 0.0))
    assert(is_equal_approx(player.total_time_points_spent, 5.0))

    # Insufficient TP and illegal movement must not change state or spend TP.
    assert(not sim.try_move_character_action("player", Vector2i(0, 0), 1.0))
    assert(player.axial == Vector2i(1, 0))
    assert(is_equal_approx(player.time_points, 0.0))
    player.time_points = 10.0
    assert(not sim.try_move_character_action("player", Vector2i(2, 0), 5.0))
    assert(is_equal_approx(player.time_points, 10.0))
