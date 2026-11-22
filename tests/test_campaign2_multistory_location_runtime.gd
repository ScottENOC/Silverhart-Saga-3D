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

    var player_state := CharacterState.new("test_player", "Test Player", Vector2i(908, -609))
    simulation.register_character(player_state)
    var player_actor := Node3D.new()
    root.add_child(player_actor)
    _check(runtime.register_character_actor("test_player", player_actor), "Runtime must accept the externally owned player actor")
    var down: Dictionary = runtime.interact_with_stair("test_player")
    _check(bool(down.get("ok", false)) and runtime.get_current_floor() == -1, "Interacting beside the Gate Hall stair must activate the Great Hall")
    _check(player_state.axial == Vector2i(908, -610), "Stair interaction must move the character onto the authored stair hex")
    _check(is_equal_approx(player_actor.global_position.y, -3.1), "Player presentation must move vertically to the destination floor")
    _check(not runtime.is_floor_visible(0) and runtime.is_floor_visible(-1), "Floor presentation must switch with traversal")
    _check(simulation.map_data.is_walkable(Vector2i(908, -627)), "Active floor geometry must be registered as logical walkable cells")
    _check(not simulation.map_data.is_walkable(Vector2i(908, -608)), "Inactive floor-only cells must be removed from logical movement")

    _check(bool(runtime.try_transition_at_stair(0, Vector2i(908, -610)).get("ok", false)), "Great Hall stair must return to the Gate Hall")
    _check(bool(runtime.try_transition_at_stair(-1, Vector2i(908, -610)).get("ok", false)), "Gate Hall stair must permit descent again")
    _check(bool(runtime.try_transition_at_stair(-2, Vector2i(908, -626)).get("ok", false)), "Great Hall must connect to the Vault and Runeforge")
    _check(bool(runtime.try_transition_at_stair(-3, Vector2i(890, -627)).get("ok", false)), "Runeforge must connect to the Deep Mine")
    _check(bool(runtime.try_transition_at_stair(-4, Vector2i(890, -617)).get("ok", false)), "Deep Mine must connect to the Lower Tunnels")
    var sealed: Dictionary = runtime.try_transition_at_stair(-5, Vector2i(890, -605))
    _check(not bool(sealed.get("ok", false)) and String(sealed.get("reason", "")) == "transition_locked", "Sunken Deep must remain sealed until the quest is completed")
    _check(not runtime.has_floor_object(-4, "transition_-4_-5"), "The sealed passage must not be presented before quest completion")

    var quest := {
        "id": "deepholds_infestation",
        "title": "What Nests Below",
        "objectives": [{"id": "clear_the_nest", "target": 1.0, "required": true}]
    }
    _check(bool(simulation.campaign_journal.register_quest_definition(quest).get("ok", false)), "Source quest definition must register")
    _check(bool(simulation.campaign_journal.start_quest("deepholds_infestation").get("ok", false)), "Source quest must start")
    _check(bool(simulation.campaign_journal.set_objective_progress("deepholds_infestation", "clear_the_nest", 1.0).get("ok", false)), "Source quest objective must complete")
    _check(bool(simulation.campaign_journal.complete_quest("deepholds_infestation").get("ok", false)), "Source quest must complete")
    _check(runtime.has_floor_object(-4, "transition_-4_-5"), "Quest completion must add the missing stair to the Lower Tunnels presentation")
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

    # Silverhart's source-authored Grand Hall has a gallery on the floor above.
    # Keep its separate floor stack in the same generic runtime used by Kragmoor.
    var palace_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "silverhart_palace", restored_simulation)
    _check(bool(palace_load.get("ok", false)), "Shared location loader must instantiate Silverhart Palace from the source floor registry")
    var palace_runtime = palace_load.get("runtime")
    _check(palace_runtime != null and palace_runtime.get_current_floor() == 0, "Silverhart Palace must begin on the Grand Hall floor")
    if palace_runtime != null:
        _check(palace_runtime.get_floor_tile_count(0) > 0 and palace_runtime.get_floor_tile_count(1) > 0, "Grand Hall and gallery must both build walkable floor geometry")
        _check(palace_runtime.is_floor_visible(0) and not palace_runtime.is_floor_visible(1), "Only the Grand Hall may be visible on entry")
        _check(palace_runtime.has_floor_object(0, "throne"), "The source throne must be presented in the Grand Hall")
        _check(palace_runtime.has_floor_object(0, "grand_hall_front_door"), "The source Grand Hall entrance must be retained")
        _check(palace_runtime.has_floor_actor(0, "queen_seraphine_corrin"), "Queen Seraphine must be presented inside the Grand Hall")
        _check(palace_runtime.has_floor_actor(0, "royal_guard_denna"), "Royal Guard Denna must be presented beside the throne")
        _check(bool(palace_runtime.try_transition_at_stair(1, Vector2i(8, -496)).get("ok", false)), "The Grand Hall stair must reach the gallery")
        _check(palace_runtime.get_current_floor() == 1 and palace_runtime.is_floor_visible(1), "Gallery traversal must switch the active floor")
        _check(bool(palace_runtime.try_transition_at_stair(0, Vector2i(8, -496)).get("ok", false)), "The gallery stair must return to the Grand Hall")

    var barracks_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "silverhart_palace_barracks", restored_simulation)
    _check(bool(barracks_load.get("ok", false)), "Shared location loader must instantiate the palace barracks")
    var barracks_runtime = barracks_load.get("runtime")
    if barracks_runtime != null:
        _check(barracks_runtime.get_floor_tile_count(0) > 0 and barracks_runtime.get_floor_tile_count(1) > 0, "Barracks mess hall and loft must both build floor geometry")
        _check(barracks_runtime.has_floor_object(1, "barracks_bed_4"), "Barracks loft must present the fourth source bed")
        _check(barracks_runtime.has_floor_actor(0, "royal_guard_petra"), "Royal Guard Petra must be presented in the barracks")
        _check(bool(barracks_runtime.try_transition_at_stair(1, Vector2i(23, -494)).get("ok", false)), "Barracks stair must reach the loft")
        _check(bool(barracks_runtime.try_transition_at_stair(0, Vector2i(23, -494)).get("ok", false)), "Barracks loft stair must return to the mess hall")

    var wizard_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "silverhart_palace_wizard_tower", restored_simulation)
    _check(bool(wizard_load.get("ok", false)), "Shared location loader must instantiate the palace wizard tower")
    var wizard_runtime = wizard_load.get("runtime")
    if wizard_runtime != null:
        _check(wizard_runtime.get_floor_tile_count(0) > 0 and wizard_runtime.get_floor_tile_count(1) > 0 and wizard_runtime.get_floor_tile_count(2) > 0, "Wizard tower, study and observatory must all build floor geometry")
        _check(wizard_runtime.has_floor_object(0, "wizard_corruption_ledger"), "Wizard tower must present the source corruption ledger")
        _check(wizard_runtime.has_floor_actor(0, "court_wizard_thessaly"), "Court Wizard Thessaly must be presented in the tower")
        _check(bool(wizard_runtime.try_transition_at_stair(1, Vector2i(-6, -481)).get("ok", false)), "Wizard tower stair must reach the study")
        _check(bool(wizard_runtime.try_transition_at_stair(2, Vector2i(-7, -482)).get("ok", false)), "Study stair must reach the observatory")
        _check(bool(wizard_runtime.try_transition_at_stair(1, Vector2i(-7, -482)).get("ok", false)), "Observatory stair must return to the study")
        _check(bool(wizard_runtime.try_transition_at_stair(0, Vector2i(-6, -481)).get("ok", false)), "Study stair must return to the tower")

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
