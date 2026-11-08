extends SceneTree

const SIMULATION_SCRIPT = preload("res://scripts/simulation/world_simulation.gd")
const STATE_SCRIPT = preload("res://scripts/simulation/character_state.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var simulation := SIMULATION_SCRIPT.new()
    root.add_child(simulation)
    for hex in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(2, -1)]:
        simulation.map_data.add_cell(hex, 0.0, true, "wood_floor")

    var player := STATE_SCRIPT.new("player", "Player", Vector2i(0, 0))
    player.time_points = 100.0
    player.side = "player"
    var patron := STATE_SCRIPT.new("patron", "Bram Fenwick", Vector2i(1, 0))
    patron.side = "neutral"
    simulation.register_character(player)
    simulation.register_character(patron)

    var route := simulation.find_path("player", Vector2i(2, 0))
    _check(route.size() >= 3 and route.has(Vector2i(1, 0)), "Pathfinding routes through a non-hostile NPC hex")
    _check(simulation.try_move_character_step("player", Vector2i(1, 0)), "Player can move through a non-hostile NPC")
    _check(player.axial == Vector2i(1, 0), "Player enters the NPC's former hex")
    _check(patron.axial != Vector2i(1, 0), "NPC steps aside rather than overlapping the player")
    _check(String(simulation.occupied_hexes.get(player.axial, "")) == "player", "Player occupancy remains registered")

    var blocked := SIMULATION_SCRIPT.new()
    root.add_child(blocked)
    for hex in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
        blocked.map_data.add_cell(hex, 0.0, true, "wood_floor")
    var mover := STATE_SCRIPT.new("mover", "Mover", Vector2i(0, 0))
    mover.time_points = 100.0
    var blocker := STATE_SCRIPT.new("blocker", "Impassable NPC", Vector2i(1, 0))
    blocker.impassable_to_player = true
    blocked.register_character(mover)
    blocked.register_character(blocker)
    _check(not blocked.try_move_character_step("mover", Vector2i(1, 0)), "Explicitly impassable NPC remains a movement blocker")

    simulation.queue_free()
    blocked.queue_free()
    if failures.is_empty():
        print("NPC_PASS_THROUGH_TEST: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: ", message)
    else:
        failures.append(message)
        push_error("FAIL: ", message)
