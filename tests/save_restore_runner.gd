extends Node

const MULTISTORY_REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
const LOCATION_LOADER = preload("res://scripts/world/campaign2_location_loader.gd")

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var profile := {
        "name": "Restore Test Hero",
        "race": "human",
        "character_class": "fighter",
        "difficulty_mode": "normal",
        "game_mode": "campaign",
        "campaign_id": "2",
        "body_variant": "female",
        "gender_presentation": "Feminine",
        "pronouns": "she/her"
    }
    var baseline := WorldSimulation.new()
    var player_state := CharacterCreationRules.create_player_state(profile, "player", Vector2i.ZERO)
    player_state.gold = 1234
    player_state.health = 42
    var saved_character_diffs := {"player": {"__full_record": player_state.to_dict()}}
    for index in range(3):
        var wolf_id := "farm_wolf_%02d" % (index + 1)
        var wolf_state := CharacterState.new(wolf_id, "Wolf", Vector2i(18 + index, -7))
        wolf_state.side = "enemy"
        wolf_state.max_health = 75
        wolf_state.health = 75
        saved_character_diffs[wolf_id] = {"__full_record": wolf_state.to_dict()}

    var clock_data := baseline.clock.to_dict()
    clock_data["world_seconds"] = 98765.0
    clock_data["tick_index"] = 123
    clock_data["paused"] = true

    var journal_data := baseline.campaign_journal.to_dict()
    journal_data["faction_standings"] = {"restore_test_faction": -7.0}

    var guild_registry = MULTISTORY_REGISTRY.new()
    var guild_definition: Dictionary = guild_registry.get_definition("silverhart_thieves_guild")
    var guild_state = baseline.register_multistory_location_state(guild_definition)
    _check(guild_state != null, "Baseline simulation should register the source-authored Thieves' Guild location")
    if guild_state != null:
        _check(bool(guild_state.discover_secret("guild_hidden_vault_door").get("ok", false)), "Baseline simulation should record the discovered hidden vault door")
    var multistory_locations: Dictionary = baseline.multistory_location_states_to_dict()

    var resource_data := baseline.wilderness_resources.to_dict()
    resource_data["nodes"] = {
        "10,10": {
            "type": "berry_bush",
            "available": false,
            "regrow_at": 123456.0
        }
    }

    var snapshot := {
        "schema_version": 1,
        "location": "Save/Restore Integration Test",
        "player_profile": profile,
        "character_diffs": saved_character_diffs,
        "appearance_diffs": {
            "companion_wren_talbot": {"hairColor": "#123456"}
        },
        "party_member_ids": ["player"],
        "simulation_party_member_ids": ["player"],
        "active_character_id": "player",
        "active_party_index": 0,
        "clock": clock_data,
        "campaign_journal": journal_data,
        "wilderness_resources": resource_data,
        "multistory_locations": multistory_locations,
        "world_flags": {
            "ambient_security": 3,
            "shakedown_started": true,
            "shakedown_resolved": true,
            "farm_wolves_spawned": true,
            "farm_wolves_retry_armed": false,
            "wilderness_steps_since_spawn": 4
        },
        "camera": {
            "zoom_distance": 22.0,
            "rotation": Vector3(0.2, 0.4, 0.0)
        },
        "playtime_seconds": 600.0
    }
    baseline.free()

    print("[SaveRestoreIntegration] Seeding pending snapshot and launching main scene.")
    SaveManager.set_pending_load(snapshot)
    var change_error := get_tree().change_scene_to_file("res://scenes/main.tscn")
    _check(change_error == OK, "The integration harness should enter the real campaign scene")

    var tavern: Node = null
    for _frame in range(120):
        await get_tree().process_frame
        var scene_root := get_tree().current_scene
        if scene_root != null:
            tavern = scene_root.get("tavern") as Node
        if scene_root != null and scene_root.get("simulation") != null and tavern != null:
            print("[SaveRestoreIntegration] HollowTankard is ready; checking restored state.")
            break

    _check(tavern != null, "The real campaign scene should construct HollowTankard from a pending save")
    var scene_root := get_tree().current_scene
    var campaign_simulation: WorldSimulation
    if scene_root != null:
        campaign_simulation = scene_root.get("simulation") as WorldSimulation
    _check(campaign_simulation != null, "WorldRoot should own a live campaign simulation")
    if tavern != null:
        var simulation := tavern.get("simulation") as WorldSimulation
        _check(simulation != null, "HollowTankard should receive the shared campaign simulation")
        _check(simulation == campaign_simulation, "HollowTankard should use WorldRoot's shared campaign simulation")
        _check(simulation.get_parent() == scene_root, "WorldSimulation should be owned by WorldRoot, not HollowTankard")
        if simulation != null:
            var restored_player := simulation.get_character("player")
            _check(restored_player != null, "The player should exist after restoring the campaign")
            if restored_player != null:
                _check(restored_player.display_name == "Restore Test Hero", "The saved player identity should be restored")
                _check(restored_player.gold == 1234, "The saved player character diff should be restored")
                _check(restored_player.health == 42, "The saved player health should be restored")
            _check(is_equal_approx(simulation.clock.world_seconds, 98765.0), "The saved world clock should be restored")
            _check(simulation.clock.tick_index == 123 and simulation.clock.paused, "Clock tick and pause state should be restored")
            _check(is_equal_approx(float(simulation.campaign_journal.faction_standings.get("restore_test_faction", 0.0)), -7.0), "Campaign journal standings should be restored")
            _check(simulation.wilderness_resources.nodes.has("10,10"), "Wilderness resource depletion data should be restored")
            var restored_locations: Dictionary = simulation.multistory_location_states_to_dict()
            var restored_guild_state: Dictionary = restored_locations.get("silverhart_thieves_guild", {})
            _check(restored_guild_state.get("discovered_secrets", []).has("guild_hidden_vault_door"), "WorldRoot and HollowTankard must restore the discovered hidden vault from the real campaign snapshot")
            var guild_load: Dictionary = LOCATION_LOADER.load_multistory_location(scene_root, "silverhart_thieves_guild", simulation)
            _check(bool(guild_load.get("ok", false)), "A restored campaign must be able to load Silverhart's Guild interior")
            var guild_runtime = guild_load.get("runtime")
            _check(guild_runtime != null and guild_runtime.has_floor_object(0, "guild_hidden_vault_door"), "The restored Guild must present its already-discovered secret door")
            _check(guild_runtime != null and guild_runtime.has_floor_object(0, "guild_vault_chest"), "The restored Guild must present its hidden vault treasure")
            _check(simulation.map_data.is_walkable(Vector2i(20, -426)), "The restored campaign must retain walkable access into the hidden vault")
            _check(simulation.party_member_ids.size() == 1 and simulation.party_member_ids[0] == "player", "Simulation party membership should be restored")
            _check(simulation.campaign_journal.quest_definitions.has("hollowmere_ironbond_shakedown"), "WorldRoot should register the opening campaign quest")
            _check(simulation.campaign_journal.quest_definitions.has("farm_wolves"), "WorldRoot should register the farm quest")
            _check(simulation.campaign_journal.quest_definitions.has("reyna_dire_wolf_hunt"), "WorldRoot should register companion campaign quests")

        # Party membership is owned exclusively by WorldSimulation. The integration
        # assertion above verifies the restored canonical roster; HollowTankard
        # should not maintain a second presentation-side copy.
        _check(not ("party_member_ids" in tavern), "HollowTankard should not expose a duplicate party roster")
        _check(String(tavern.get("active_character_id")) == "player", "The active character should be restored")
        _check(bool(tavern.get("shakedown_started")) and bool(tavern.get("shakedown_resolved")), "Opening-confrontation flags should be restored without replay")
        var camera = tavern.get("camera_rig")
        _check(camera != null and is_equal_approx(float(camera.zoom_distance), 22.0), "Camera zoom should be restored")
        var actors: Dictionary = tavern.get("actor_by_id")
        for wolf_id in ["farm_wolf_01", "farm_wolf_02", "farm_wolf_03"]:
            var wolf_actor := actors.get(wolf_id) as Node3D
            _check(wolf_actor != null, "Saved active farm wolf %s should have a visible actor after load" % wolf_id)
            if wolf_actor != null:
                _check(bool(wolf_actor.get_meta("farm_quest_wolf", false)), "Restored farm wolves should retain their encounter actor identity")
        var wren := actors.get("companion_wren_talbot") as Node3D
        _check(wren != null, "The base Wren actor should be rebuilt before applying appearance diffs")
        if wren != null:
            var appearance: Dictionary = wren.get_meta("appearance_profile", {})
            _check(String(appearance.get("hairColor", "")) == "#123456", "The saved NPC appearance diff should be restored")

    if failures > 0:
        push_error("%d campaign save/restore integration assertion(s) failed." % failures)
        get_tree().quit(1)
    else:
        print("Campaign save/restore scene integration tests passed.")
        get_tree().quit(0)

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error("FAIL: " + message)
