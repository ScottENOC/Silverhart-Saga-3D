extends SceneTree

const SIMULATION = preload("res://scripts/simulation/world_simulation.gd")
const LOCATION_LOADER = preload("res://scripts/world/campaign2_location_loader.gd")

var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var simulation = SIMULATION.new()
    root.add_child(simulation)
    var loaded: Dictionary = LOCATION_LOADER.load_multistory_location(root, "kragmoor", simulation)
    _check(bool(loaded.get("ok", false)), "Shared location loader must instantiate Kragmoor from the registry")
    var runtime = loaded.get("runtime")
    _check(runtime.get_current_floor() == 0, "Kragmoor runtime must begin on the Gate Hall surface")
    _check(runtime.get_floor_tile_count(0) > 0 and runtime.get_floor_tile_count(-5) > 0, "All six source floors must build presentation tiles")
    _check(runtime.is_floor_visible(0) and not runtime.is_floor_visible(-1), "Only the active floor may be visible")

    var down := runtime.try_transition_at_stair(-1, Vector2i(908, -610))
    _check(bool(down.get("ok", false)) and runtime.get_current_floor() == -1, "Gate Hall stair must activate the Great Hall")
    _check(not runtime.is_floor_visible(0) and runtime.is_floor_visible(-1), "Floor presentation must switch with traversal")
    _check(simulation.map_data.is_walkable(Vector2i(908, -627)), "Active floor geometry must be registered as logical walkable cells")
    _check(not simulation.map_data.is_walkable(Vector2i(908, -608)), "Inactive floor-only cells must be removed from logical movement")

    _check(bool(runtime.try_transition_at_stair(0, Vector2i(908, -610)).get("ok", false)), "Great Hall stair must return to the Gate Hall")
    _check(bool(runtime.try_transition_at_stair(-1, Vector2i(908, -610)).get("ok", false)), "Gate Hall stair must permit descent again")
    _check(bool(runtime.try_transition_at_stair(-2, Vector2i(908, -626)).get("ok", false)), "Great Hall must connect to the Vault and Runeforge")
    _check(bool(runtime.try_transition_at_stair(-3, Vector2i(890, -627)).get("ok", false)), "Runeforge must connect to the Deep Mine")
    _check(bool(runtime.try_transition_at_stair(-4, Vector2i(890, -617)).get("ok", false)), "Deep Mine must connect to the Lower Tunnels")
    var sealed := runtime.try_transition_at_stair(-5, Vector2i(890, -605))
    _check(not bool(sealed.get("ok", false)) and String(sealed.get("reason", "")) == "transition_locked", "Sunken Deep must remain sealed until the quest is completed")

    var quest := {
        "id": "deepholds_infestation",
        "title": "What Nests Below",
        "objectives": [{"id": "clear_the_nest", "target": 1.0, "required": true}]
    }
    _check(bool(simulation.campaign_journal.register_quest_definition(quest).get("ok", false)), "Source quest definition must register")
    _check(bool(simulation.campaign_journal.start_quest("deepholds_infestation").get("ok", false)), "Source quest must start")
    _check(bool(simulation.campaign_journal.set_objective_progress("deepholds_infestation", "clear_the_nest", 1.0).get("ok", false)), "Source quest objective must complete")
    _check(bool(simulation.campaign_journal.complete_quest("deepholds_infestation").get("ok", false)), "Source quest must complete")
    _check(bool(runtime.try_transition_at_stair(-5, Vector2i(890, -605)).get("ok", false)), "Quest completion must unlock the Sunken Deep stair")

    var saved_locations: Dictionary = simulation.multistory_location_states_to_dict()
    var restored_simulation = SIMULATION.new()
    restored_simulation.campaign_journal.register_quest_definition(quest)
    restored_simulation.campaign_journal.start_quest("deepholds_infestation")
    restored_simulation.campaign_journal.set_objective_progress("deepholds_infestation", "clear_the_nest", 1.0)
    restored_simulation.campaign_journal.complete_quest("deepholds_infestation")
    _check(restored_simulation.restore_multistory_location_states(saved_locations), "Campaign save adapter must accept multi-story location snapshots")
    root.add_child(restored_simulation)
    var restored_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "kragmoor", restored_simulation, {"multistory_locations": saved_locations})
    _check(bool(restored_load.get("ok", false)), "Shared location loader must restore saved multi-story site state")
    var restored_runtime = restored_load.get("runtime")
    _check(restored_runtime.get_current_floor() == -5, "Save/load must restore the current underground floor")
    _check(restored_runtime.is_floor_visible(-5), "Save/load must restore the visible floor presentation")

    if failures > 0:
        push_error("%d multi-story runtime integration test(s) failed." % failures)
        quit(1)
        return
    print("Kragmoor floor presentation, quest-gated traversal and campaign persistence validated.")
    quit(0)

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
