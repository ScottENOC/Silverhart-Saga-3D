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
    _test_combat_resolution()
    _test_downed_and_death_lifecycle()
    _test_unified_action_contract()
    _test_reaction_resolution_safety()
    _test_incapacitated_turn_cleanup()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
        return
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
    sim.free()

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
    sim.free()

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
    sim.free()

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
    loaded.free()
    sim.free()

func _test_combat_resolution() -> void:
    var attacker := CharacterState.new("hero", "Hero")
    var target := CharacterState.new("guard", "Guard")
    attacker.side = "player"
    attacker.base_damage = 8
    attacker.to_hit_melee = 20.0
    attacker.time_points = 30.0
    attacker.skills["orc_brute_strength"] = 1
    target.health = 30
    target.max_health = 30
    target.passive_dodge = 10.0
    target.armour_reduction = 3
    target.shield_reduction = 2
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var result := CombatRules.resolve_attack(attacker, target, {
        "time_point_cost": 10.0,
        "weapon_damage": 4,
        "weapon_id": "sword",
        "attacker_terrain_hit_bonus": 5.0
    }, rng)
    _check(bool(result.get("ok", false)))
    _check(float(result.get("hit_chance", 0.0)) == 65.0)
    _check(is_equal_approx(attacker.time_points, 20.0))
    if bool(result.get("hit", false)):
        _check(int(result.get("raw_damage", 0)) == 14)
        _check(int(result.get("reduction", 0)) == 5)
        _check(int(result.get("damage", 0)) == 9)
        _check(target.health == 21)

    var guarded := CharacterState.new("armoured", "Armoured")
    guarded.health = 20
    guarded.max_health = 20
    guarded.base_reduction = 2
    guarded.armour_reduction = 4
    guarded.shield_reduction = 3
    guarded.caught_off_guard = true
    _check(CombatRules.damage_reduction(guarded) == 0)
    guarded.caught_off_guard = false
    guarded.climbing = true
    _check(CombatRules.damage_reduction(guarded) == 6)

    var lethal_rng := RandomNumberGenerator.new()
    lethal_rng.seed = 3
    attacker.to_hit_melee = 100.0
    attacker.time_points = 20.0
    target.health = 1
    target.alive = true
    var lethal := CombatRules.resolve_attack(attacker, target, {
        "time_point_cost": 5.0,
        "weapon_damage": 20
    }, lethal_rng)
    _check(bool(lethal.get("hit", false)))
    _check(bool(lethal.get("target_defeated", false)))
    _check(not target.alive and target.health <= -target.max_health * 0.5)

    var poor := CharacterState.new("poor", "Poor")
    poor.time_points = 1.0
    var before_health := target.health
    var rejected := CombatRules.resolve_attack(poor, target, {"time_point_cost": 5.0}, lethal_rng)
    _check(not bool(rejected.get("ok", false)))
    _check(target.health == before_health)

    var sim := WorldSimulation.new()
    var sim_attacker := CharacterState.new("sim_hero", "Hero", Vector2i.ZERO)
    var sim_target := CharacterState.new("sim_guard", "Guard", Vector2i(1, 0))
    sim_attacker.to_hit_melee = 100.0
    sim_attacker.base_damage = 12
    sim_attacker.time_points = 50.0
    sim.register_character(sim_attacker)
    sim.register_character(sim_target)
    sim.is_in_combat = true
    sim.turn_scheduler.current_character_id = "sim_hero"
    var integrated := sim.try_attack_character("sim_hero", "sim_guard", {
        "time_point_cost": 5.0
    }, 11)
    _check(bool(integrated.get("ok", false)))
    _check(bool(integrated.get("hit", false)))
    _check(sim_target.health == 88)
    _check(is_equal_approx(sim_attacker.time_points, 45.0))
    _check(not bool(sim.try_attack_character("sim_guard", "sim_hero", {}, 11).get("ok", false)))
    sim.free()

func _test_downed_and_death_lifecycle() -> void:
    var target := CharacterState.new("target", "Target")
    target.max_health = 100
    target.health = 20
    _check(target.apply_damage(40) == "downed")
    _check(target.alive and target.unconscious)
    _check(target.health == -20, "Downed HP remains negative rather than clamping to zero")
    _check(target.can_be_targeted(), "Unconscious living characters remain valid targets")
    _check(not target.can_act(), "Unconscious characters cannot act")
    _check(not target.can_start_combat_turn(), "Unconscious characters cannot receive turns")
    _check(target.apply_healing(25) == "revived_from_unconscious")
    _check(target.health == 5 and not target.unconscious and target.alive)
    _check(target.apply_damage(56) == "died")
    _check(not target.alive and not target.unconscious)
    _check(target.health <= -50, "True death occurs at or below -50% maximum HP")
    _check(target.apply_healing(100) == "unchanged", "Healing does not silently resurrect true-dead characters")
    var second := CharacterState.new("second", "Second")
    second.health = 1
    second.apply_damage(51)
    _check(not second.alive and not second.unconscious, "Exact -50% HP boundary is true death")

func _test_unified_action_contract() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    var mover := CharacterState.new("mover", "Mover", Vector2i.ZERO)
    mover.time_points = 20.0
    sim.register_character(mover)
    var move_result := sim.submit_action(SimulationActionRequest.move("mover", Vector2i(1, 0), 5.0))
    _check(bool(move_result.get("ok", false)))
    _check(mover.axial == Vector2i(1, 0))
    _check(is_equal_approx(mover.time_points, 15.0))
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i(0, 1))
    var victim := CharacterState.new("victim", "Victim", Vector2i(1, 1))
    attacker.to_hit_melee = 100.0
    attacker.base_damage = 10
    attacker.time_points = 20.0
    victim.health = 10
    victim.max_health = 100
    sim.register_character(attacker)
    sim.register_character(victim)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "attacker"
    var attack_result := sim.submit_action(SimulationActionRequest.attack("attacker", "victim", {"time_point_cost": 5.0}), 19)
    _check(bool(attack_result.get("ok", false)))
    _check(victim.unconscious and victim.alive, "Attack downs rather than kills in the negative HP band")
    _check(bool(attack_result.get("target_unconscious", false)))
    _check(String(attack_result.get("action_type", "")) == "attack")
    sim.free()

func _test_reaction_resolution_safety() -> void:
    var sim := WorldSimulation.new()
    var reactor := CharacterState.new("reactor", "Reactor", Vector2i.ZERO)
    reactor.time_points = 20.0
    sim.register_character(reactor)
    sim.start_combat()
    var requested_count := [0]
    var resolved_count := [0]
    var last_choice := [""]
    var last_reason := [""]
    sim.reaction_requested.connect(func(_id: String, _options: Array[Dictionary], _request_id: int, _source: String) -> void:
        requested_count[0] += 1
    )
    sim.reaction_resolved.connect(func(_id: String, choice: String, _request_id: int, reason: String) -> void:
        resolved_count[0] += 1
        last_choice[0] = choice
        last_reason[0] = reason
    )

    reactor.alive = false
    var dead_result := sim.request_reaction("reactor", [{"id": "parry", "name": "Parry", "tp_cost": 3.0}])
    _check(bool(dead_result.get("ok", false)) and not bool(dead_result.get("pending", true)))
    _check(resolved_count[0] == 1 and last_choice[0].is_empty())
    _check(last_reason[0] == "reactor_unavailable")
    _check(requested_count[0] == 0 and sim.pending_reaction.is_empty())

    reactor.alive = true
    reactor.unconscious = true
    var unconscious_result := sim.request_reaction("reactor", [{"id": "parry", "tp_cost": 3.0}])
    _check(not bool(unconscious_result.get("pending", true)))
    _check(resolved_count[0] == 2 and last_choice[0].is_empty())
    _check(sim.pending_reaction.is_empty())

    reactor.unconscious = false
    var opened := sim.request_reaction("reactor", [
        {"id": "parry", "name": "Parry", "tp_cost": 3.0},
        {"id": "dodge", "name": "Dodge", "tp_cost": 5.0}
    ], "attack_001")
    _check(bool(opened.get("pending", false)))
    _check(requested_count[0] == 1 and not sim.pending_reaction.is_empty())
    _check(not sim.try_end_current_turn(), "A pending reaction must prevent normal turn completion")
    _check(not sim.resolve_reaction("unknown").get("ok", false), "Invalid choices must not consume the pending request")
    var chosen := sim.resolve_reaction("parry")
    _check(bool(chosen.get("ok", false)) and String(chosen.get("choice_id", "")) == "parry")
    _check(is_equal_approx(reactor.time_points, 17.0))
    _check(resolved_count[0] == 3 and last_choice[0] == "parry" and last_reason[0] == "selected")
    _check(sim.pending_reaction.is_empty())

    reactor.time_points = 20.0
    var death_wait := sim.request_reaction("reactor", [{"id": "parry", "tp_cost": 3.0}], "attack_002")
    _check(bool(death_wait.get("pending", false)))
    reactor.apply_damage(150)
    _check(not reactor.alive)
    _check(sim.pending_reaction.is_empty(), "Death while a reaction is pending must clear the wait immediately")
    _check(resolved_count[0] == 4 and last_choice[0].is_empty() and last_reason[0] == "reactor_incapacitated")

    reactor.alive = true
    reactor.health = 100
    reactor.unconscious = false
    reactor.reaction_blocked = true
    var blocked := sim.request_reaction("reactor", [{"id": "parry", "tp_cost": 3.0}])
    _check(not bool(blocked.get("pending", true)) and String(blocked.get("reason", "")) == "reactor_unavailable")
    _check(sim.pending_reaction.is_empty())
    sim.free()

func _test_incapacitated_turn_cleanup() -> void:
    var sim := WorldSimulation.new()
    var actor := CharacterState.new("actor", "Actor", Vector2i.ZERO)
    actor.time_points = 120.0
    sim.register_character(actor)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "actor"
    actor.apply_damage(150)
    _check(not sim.turn_scheduler.has_active_turn(), "An incapacitated active combatant must relinquish their turn")
    sim.free()
