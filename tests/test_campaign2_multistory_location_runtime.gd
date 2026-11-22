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

    var expected_npcs := {
        "dwarf_king": -1,
        "hall_guard_01": -1,
        "hall_guard_02": -1,
        "deepholds_trader": -2,
        "deepholds_runesmith": -2,
        "deepholds_foreman": -3
    }
    for character_id in expected_npcs:
        var npc_state := simulation.get_character(character_id)
        var npc_actor := runtime.get_actor_by_id(character_id)
        _check(npc_state != null, "Source-authored Kragmoor NPC state must be registered: " + character_id)
        _check(npc_state != null and npc_state.race == "dwarf", "Kragmoor NPC must retain its source dwarf race: " + character_id)
        _check(npc_actor != null and is_instance_valid(npc_actor), "Kragmoor NPC must have an Ara presentation actor: " + character_id)
        _check(npc_actor != null and int(npc_actor.get_meta("campaign2_floor", 999)) == int(expected_npcs[character_id]), "Kragmoor NPC must appear on its source floor: " + character_id)
        _check(npc_actor != null and String(npc_actor.get_meta("faction_id", "")) == "dwarven_kingdom", "Kragmoor NPC must retain its source faction: " + character_id)
    var king_state := simulation.get_character("dwarf_king")
    _check(king_state != null and king_state.class_level_sequence.size() == 2, "King Balrik must retain his two fighter levels")
    _check(king_state != null and String(king_state.equipment.get("weapon", "")) == "axe" and String(king_state.equipment.get("armor", "")) == "heavy_armor", "King Balrik must retain his source axe and heavy armour loadout")
    _check(king_state != null and not simulation.occupied_hexes.has(king_state.axial), "Inactive-floor NPCs must not block active-floor movement")
    var king_save := king_state.to_dict()
    var restored_king := CharacterState.from_dict(king_save)
    _check(not restored_king.occupies_world_hex, "Off-floor occupancy state must survive character save/restore")

    var player_state := CharacterState.new("test_player", "Test Player", Vector2i(908, -609))
    simulation.register_character(player_state)
    var player_actor := Node3D.new()
    root.add_child(player_actor)
    _check(runtime.register_character_actor("test_player", player_actor), "Runtime must accept the externally owned player actor")
    var down: Dictionary = runtime.interact_with_stair("test_player")
    _check(bool(down.get("ok", false)) and runtime.get_current_floor() == -1, "Interacting beside the Gate Hall stair must activate the Great Hall")
    _check(player_state.axial == Vector2i(908, -610), "Stair interaction must move the character onto the authored stair hex")
    _check(is_equal_approx(player_actor.global_position.y, -3.1), "Player presentation must move vertically to the destination floor")
    _check(String(simulation.occupied_hexes.get(king_state.axial, "")) == "dwarf_king", "NPCs on the active floor must reserve their source hexes")
    _check(not runtime.is_floor_visible(0) and runtime.is_floor_visible(-1), "Floor presentation must switch with traversal")
    _check(simulation.map_data.is_walkable(Vector2i(908, -627)), "Active floor geometry must be registered as logical walkable cells")
    _check(not simulation.map_data.is_walkable(Vector2i(908, -608)), "Inactive floor-only cells must be removed from logical movement")

    _check(bool(runtime.try_transition_at_stair(0, Vector2i(908, -610)).get("ok", false)), "Great Hall stair must return to the Gate Hall")
    _check(not simulation.occupied_hexes.has(king_state.axial), "Leaving a floor must release its NPC hex occupancy without deleting its state")
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
