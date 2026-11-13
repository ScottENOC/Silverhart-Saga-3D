extends SceneTree

var _failures: int = 0

func _initialize() -> void:
    _test_movement_validation()
    _test_time_point_rules()
    _test_action_movement_cost()
    _test_terrain_pathfinding()
    _test_elevation_rules()
    _test_world_clock()
    _test_wilderness_resources_and_chunk_streaming()
    _test_vision_rules()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
        return
    print("World, movement and vision tests passed.")
    quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
    if not condition:
        _failures += 1
        push_error(message)
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

func _test_wilderness_resources_and_chunk_streaming() -> void:
    var simulation := WorldSimulation.new()
    var player := CharacterState.new("gatherer", "Gatherer", Vector2i(0, 0))
    var pickaxe := ItemCatalog.create_instance("pickaxe", "test_pickaxe")
    _check(player.add_inventory_item(pickaxe), "Gatherer should be able to carry a pickaxe")
    simulation.register_character(player)
    var ore_hex := Vector2i(60, 60)
    simulation.map_data.add_cell(ore_hex, 0.0, true, "rocky_outcrop")
    simulation.wilderness_resources.nodes["60,60"] = {
        "type": "ore_node", "item_id": "ore_gold", "depleted": false, "regrow_at": 0.0
    }
    var mined := simulation.harvest_resource_at("gatherer", ore_hex)
    _check(bool(mined.get("ok", false)), "Pickaxe should unlock ore harvesting")
    _check(int(mined.get("amount", 0)) >= 1, "Mining should produce at least one ore item")
    _check(bool(simulation.wilderness_resources.nodes["60,60"].get("depleted", false)), "Mined ore should deplete")
    var saved := simulation.to_dict()
    var restored := WorldSimulation.new()
    restored.load_dict(saved)
    _check(bool(restored.wilderness_resources.nodes["60,60"].get("depleted", false)), "Resource depletion must survive save/load")
    restored.wilderness_resources.advance_time(72.0 * WorldClock.SECONDS_PER_HOUR)
    _check(not bool(restored.wilderness_resources.nodes["60,60"].get("depleted", true)), "Ore should regenerate after 72 game hours")

    var chunks := HexWorldChunkStreamer.new()
    var map := HexMapData.new()
    chunks.load_around(map, Vector2i(100, 100))
    _check(chunks.active_chunk_count() == 9, "A radius-one load should activate nine chunks")
    _check(map.has_cell(Vector2i(100, 100)), "The active region should contain its centre hex")
    var terrain_a := HexWorldChunkStreamer.terrain_for_hex(Vector2i(100, 100), 1)
    var terrain_b := HexWorldChunkStreamer.terrain_for_hex(Vector2i(100, 100), 1)
    _check(terrain_a == terrain_b, "Chunk terrain must be deterministic for a stable world seed")
    chunks.load_around(map, Vector2i(300, 300))
    _check(chunks.active_chunk_count() == 9, "Moving far away should keep the active chunk budget bounded")
    _check(not map.has_cell(Vector2i(100, 100)), "Old generated chunks should unload when outside the active region")

func _test_vision_rules() -> void:
    var observer := CharacterState.new("vision_observer", "Observer", Vector2i(0, 0))
    _check(VisionRules.vision_range(observer) == 25, "Base live vision should be 25 hexes")
    _check(VisionRules.exploration_range() == 30, "Exploration range should remain separate at 30 hexes")

    observer.skills = {
        "elf_vision": 2,
        "deep_sense": 1,
        "keen_perception": 2,
        "stealth_agility": 1,
        "stealth_rogue": 1
    }
    _check(VisionRules.vision_range(observer) == 33, "Elf vision should add four hexes per rank")
    _check(VisionRules.vision_range(observer, true) == 37, "Deep Sense should add four hexes indoors")
    _check(VisionRules.vision_range(observer, false, true) == 6, "Low light should reduce non-darkvision range to the 0.2 factor")
    _check(VisionRules.stealth_detection_bonus(observer) == 20, "Keen Perception should add ten detection points per rank")
    _check(VisionRules.stealth_check_bonus(observer) == 10, "Inconspicuous and Shadow Weaver should each add five stealth points per rank")

    observer.skills["elf_darkvision"] = 1
    _check(VisionRules.vision_range(observer, false, true) == 33, "Elf Darkvision should remove the low-light penalty")
    observer.skills.clear()
    observer.skills["goblin_keen_senses"] = 1
    observer.skills["goblin_low_light_eyes"] = 1
    _check(VisionRules.vision_range(observer, false, true) == 28, "Goblin Keen Senses should add three hexes and Low-light Eyes should remove the penalty")

    var map := HexMapData.new()
    for q in range(0, 5):
        map.add_cell(Vector2i(q, 0), 0.0, true, "grass")
    var target := CharacterState.new("vision_target", "Target", Vector2i(4, 0))
    observer.axial = Vector2i(0, 0)
    observer.skills.clear()
    _check(VisionRules.has_line_of_sight(map, observer.axial, target.axial), "Clear intervening hexes should permit line of sight")
    _check(VisionRules.can_see(map, observer, target), "A target within base range and clear LOS should be visible")

    map.cells[Vector2i(2, 0)]["blocks_vision"] = true
    _check(not VisionRules.has_line_of_sight(map, observer.axial, target.axial), "An explicit opaque cell should block line of sight")
    map.cells[Vector2i(2, 0)]["blocks_vision"] = false
    map.cells[Vector2i(2, 0)]["terrain_id"] = "palisade_wall"
    _check(not VisionRules.has_line_of_sight(map, observer.axial, target.axial), "Palisade walls should block line of sight")
    map.cells[Vector2i(2, 0)]["terrain_id"] = "grass"
    map.cells[Vector2i(2, 0)]["elevation"] = 3.0
    _check(not VisionRules.has_line_of_sight(map, observer.axial, target.axial), "A ridge above the sight line should block line of sight")
    map.cells[Vector2i(2, 0)]["elevation"] = 0.0
    _check(VisionRules.has_line_of_sight(map, observer.axial, target.axial), "Sight should recover when the ridge is removed")

    observer.skills["elf_vision"] = 2
    target.axial = Vector2i(30, 0)
    for q in range(5, 35):
        map.add_cell(Vector2i(q, 0), 0.0, true, "grass")
    _check(VisionRules.can_see(map, observer, target), "Elf vision should extend the visibility boundary to 33 hexes")
    target.axial = Vector2i(34, 0)
    map.add_cell(Vector2i(34, 0), 0.0, true, "grass")
    _check(not VisionRules.can_see(map, observer, target), "Targets beyond modified vision range should not be visible")

    # LOS must be reciprocal and work along all six axial directions, not only
    # the single horizontal ray used by the basic blocker test.
    var directions: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
        Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)
    ]
    var directional_map := HexMapData.new()
    for direction in directions:
        for step in range(0, 5):
            directional_map.add_cell(direction * step, 0.0, true, "grass")
        _check(VisionRules.has_line_of_sight(directional_map, Vector2i.ZERO, direction * 4), "LOS should work in each of the six hex directions")
        _check(VisionRules.has_line_of_sight(directional_map, direction * 4, Vector2i.ZERO), "LOS should be reciprocal in each of the six hex directions")
        directional_map.cells[direction * 2]["terrain_id"] = "palisade_wall"
        _check(not VisionRules.has_line_of_sight(directional_map, Vector2i.ZERO, direction * 4), "A palisade should block LOS in every hex direction")
        directional_map.cells[direction * 2]["terrain_id"] = "grass"

    var dead_observer := CharacterState.new("dead_observer", "Dead Observer", Vector2i.ZERO)
    dead_observer.alive = false
    _check(not VisionRules.can_see(directional_map, dead_observer, target), "A dead observer cannot see targets")
