extends SceneTree

const SIMULATION = preload("res://scripts/simulation/world_simulation.gd")
const LOCATION_LOADER = preload("res://scripts/world/campaign2_location_loader.gd")

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Sil'thandriel's great-tree stair must be usable by the same externally
	# controlled player actor as the regional surface movement simulation.
	var tree_simulation = SIMULATION.new()
	root.add_child(tree_simulation)
	var tree_player := CharacterState.new("tree_test_player", "Tree Test Player", Vector2i(-252, 933))
	tree_simulation.register_character(tree_player)
	tree_simulation.map_data.add_cell(Vector2i(-252, 933), 0.0, true, "grass")
	var tree_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "silthandriel", tree_simulation)
	_check(bool(tree_load.get("ok", false)), "Regional player must be able to load Sil'thandriel's source-authored tree interior")
	var tree_runtime = tree_load.get("runtime")
	var tree_actor := Node3D.new()
	root.add_child(tree_actor)
	_check(tree_runtime != null and tree_runtime.register_character_actor("tree_test_player", tree_actor), "Tree interior must register the regional player actor")
	if tree_runtime != null:
		var tree_entry: Dictionary = tree_runtime.interact_with_stair("tree_test_player")
		_check(bool(tree_entry.get("ok", false)) and tree_runtime.get_current_floor() == 1, "Pressing the interaction action at the great-tree stair must enter the Lower Canopy")
		_check(tree_player.axial == Vector2i(-252, 932), "Entering the tree must place the player on the authored entrance stair")
		_check(is_equal_approx(tree_actor.global_position.y, 3.3), "Tree interior must raise the shared player actor to the authored upper floor")
		var tree_exit: Dictionary = tree_runtime.interact_with_stair("tree_test_player")
		_check(bool(tree_exit.get("ok", false)) and tree_runtime.get_current_floor() == 0, "The same stair must return the player from the Lower Canopy to the regional surface")
		_check(is_equal_approx(tree_actor.global_position.y, 0.1), "Returning outside must restore the player actor to surface height")

	# Exterior building doors are ordinary continuous-world movement; there is
	# deliberately no entry/return teleport contract or round-trip helper.

	var simulation = SIMULATION.new()
	root.add_child(simulation)
	var loaded: Dictionary = LOCATION_LOADER.load_multistory_location(root, "kragmoor", simulation)
	_check(bool(loaded.get("ok", false)), "Shared location loader must instantiate Kragmoor from the registry")
	var runtime = loaded.get("runtime")
	_check(runtime != null and not runtime.has_method("enter_from_exterior") and not runtime.has_method("exit_to_exterior"), "Multi-story runtime must not expose exterior door teleport APIs")
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
		_check(palace_runtime.has_floor_object(0, "queen_chambers_bed"), "Queen's private chambers must be presented behind the Grand Hall")
		_check(palace_runtime.has_floor_object(0, "queen_chambers_rear_door"), "Queen's private chambers must retain their internal rear door")
		_check(palace_runtime.has_floor_object(0, "queen_chambers_fireplace"), "Queen's private chambers must present their fireplace")
		_check(palace_runtime.is_floor_visible(0) and not palace_runtime.is_floor_visible(1), "Only the Grand Hall may be visible on entry")
		_check(palace_runtime.has_floor_object(0, "throne"), "The source throne must be presented in the Grand Hall")
		_check(palace_runtime.has_floor_object(0, "grand_hall_front_door"), "The source Grand Hall entrance must be retained")
		_check(palace_runtime.has_floor_actor(0, "queen_seraphine_corrin"), "Queen Seraphine must be presented inside the Grand Hall")
		_check(palace_runtime.has_floor_actor(0, "royal_guard_denna"), "Royal Guard Denna must be presented beside the throne")
		_check(bool(palace_runtime.try_transition_at_stair(1, Vector2i(8, -496)).get("ok", false)), "The Grand Hall stair must reach the gallery")
		_check(palace_runtime.get_current_floor() == 1 and palace_runtime.is_floor_visible(1), "Gallery traversal must switch the active floor")
		var palace_saved_locations: Dictionary = restored_simulation.multistory_location_states_to_dict()
		var palace_restored_simulation = SIMULATION.new()
		_check(palace_restored_simulation.restore_multistory_location_states(palace_saved_locations), "Palace floor state must be accepted by campaign save restoration")
		root.add_child(palace_restored_simulation)
		var palace_restored_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "silverhart_palace", palace_restored_simulation, {"multistory_locations": palace_saved_locations})
		_check(bool(palace_restored_load.get("ok", false)), "Palace floor state must restore through the shared location loader")
		var palace_restored_runtime = palace_restored_load.get("runtime")
		_check(palace_restored_runtime != null and palace_restored_runtime.get_current_floor() == 1, "Save/load must restore the player's current Grand Hall gallery floor")
		if palace_restored_runtime != null:
			_check(palace_restored_runtime.is_floor_visible(1), "Restored gallery floor must be the visible presentation")
		_check(bool(palace_runtime.try_transition_at_stair(0, Vector2i(8, -496)).get("ok", false)), "The gallery stair must return to the Grand Hall")

	var council_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "silverhart_palace_council_chamber", restored_simulation)
	_check(bool(council_load.get("ok", false)), "Shared location loader must instantiate the source-authored council chamber")
	var council_runtime = council_load.get("runtime")
	if council_runtime != null:
		_check(council_runtime.get_floor_tile_count(0) > 0, "Council chamber must build walkable floor geometry")
		_check(council_runtime.has_floor_object(0, "council_table"), "Council chamber must present its source table")
		_check(council_runtime.has_floor_actor(0, "chancellor_merric_vane"), "Chancellor Merric Vane must be presented inside the council chamber")

	var guild_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "silverhart_thieves_guild", restored_simulation)
	_check(bool(guild_load.get("ok", false)), "Shared location loader must instantiate the source-authored Thieves' Guild")
	var guild_runtime = guild_load.get("runtime")
	if guild_runtime != null:
		_check(guild_runtime.get_floor_tile_count(0) > 0, "Thieves' Guild must build its accessible ground-floor geometry")
		_check(guild_runtime.has_floor_actor(0, "tessa_nightshade"), "Tessa Nightshade must be presented inside the Guild")
		_check(guild_runtime.has_floor_actor(0, "corvin_ashe_guildmaster"), "Guildmaster Corvin Ashe must be presented inside the Guild")
		_check(not guild_runtime.has_floor_object(0, "guild_hidden_vault_door"), "Undiscovered vault door must not be presented")
		_check(not guild_runtime.has_floor_object(0, "guild_vault_chest"), "Hidden vault treasure must not be presented before discovery")
		_check(restored_simulation.map_data.is_walkable(Vector2i(18, -426)), "The source dead-end corridor must be walkable up to the concealed wall")
		_check(not restored_simulation.map_data.is_walkable(Vector2i(19, -426)), "The concealed vault door must block movement before discovery")
		var secret_searcher := CharacterState.new("guild_secret_searcher", "Guild Secret Searcher", Vector2i(18, -426))
		restored_simulation.register_character(secret_searcher)
		var reveal_result: Dictionary = guild_runtime.reveal_secret_door("guild_secret_searcher", "guild_hidden_vault_door")
		_check(bool(reveal_result.get("ok", false)), "A character beside the concealed wall must be able to reveal the source secret door")
		_check(guild_runtime.has_floor_object(0, "guild_hidden_vault_door"), "Discovered secret door must be presented")
		_check(guild_runtime.has_floor_object(0, "guild_vault_chest"), "Vault treasure must appear after discovery")
		_check(restored_simulation.map_data.is_walkable(Vector2i(19, -426)) and restored_simulation.map_data.is_walkable(Vector2i(20, -426)), "Discovery must open the passage and reveal the walkable vault interior")
		var guild_save_bundle: Dictionary = restored_simulation.multistory_location_states_to_dict()
		var guild_saved_state: Dictionary = guild_save_bundle.get("silverhart_thieves_guild", {})
		_check(guild_saved_state.get("discovered_secrets", []).has("guild_hidden_vault_door"), "Discovered vault door must be included in campaign location save data")
		var guild_restored_simulation = SIMULATION.new()
		_check(guild_restored_simulation.restore_multistory_location_states(guild_save_bundle), "Campaign save adapter must accept discovered Guild secrets")
		root.add_child(guild_restored_simulation)
		var guild_restored_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "silverhart_thieves_guild", guild_restored_simulation, {"multistory_locations": guild_save_bundle})
		_check(bool(guild_restored_load.get("ok", false)), "Shared location loader must restore the discovered Guild vault")
		var guild_restored_runtime = guild_restored_load.get("runtime")
		_check(guild_restored_runtime != null and guild_restored_runtime.has_floor_object(0, "guild_hidden_vault_door"), "Save/load must keep the secret door revealed")
		_check(guild_restored_runtime != null and guild_restored_runtime.has_floor_object(0, "guild_vault_chest"), "Save/load must keep the vault treasure presented")
		_check(guild_restored_simulation.map_data.is_walkable(Vector2i(20, -426)), "Save/load must restore access to the hidden vault interior")

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

# Emberlode uses the same multi-story runtime for its surface mine, Working Vein and Old Seam.
	var mine_simulation = SIMULATION.new()
	root.add_child(mine_simulation)
	var mine_load: Dictionary = LOCATION_LOADER.load_multistory_location(root, "emberlode_mine", mine_simulation)
	_check(bool(mine_load.get("ok", false)), "Shared location loader must instantiate the source-authored Emberlode Mine")
	var mine_runtime = mine_load.get("runtime")
	if mine_runtime != null:
		_check(mine_runtime.get_floor_tile_count(0) > 0 and mine_runtime.get_floor_tile_count(-1) > 0 and mine_runtime.get_floor_tile_count(-2) > 0, "Emberlode must present its surface entrance and both underground floors")
		_check(mine_runtime.has_floor_object(0, "emberlode_ledger"), "Emberlode surface must present the source ledger")
		_check(mine_runtime.has_floor_object(-1, "working_vein_gold"), "Working Vein must present the gold deposit")
		_check(mine_runtime.has_floor_object(-2, "old_seam_blue_gem"), "Old Seam must present the blue-gem deposit")
		var mine_player := CharacterState.new("emberlode_test_player", "Mine Test Player", Vector2i(-252, 15))
		mine_simulation.register_character(mine_player)
		var mine_descent: Dictionary = mine_runtime.interact_with_stair("emberlode_test_player")
		_check(bool(mine_descent.get("ok", false)) and mine_runtime.get_current_floor() == -1, "Emberlode surface stair must enter the Working Vein")
		_check(mine_player.axial == Vector2i(-252, 15), "Mine descent must preserve the source stair position")
		_check(bool(mine_simulation.relocate_character("emberlode_test_player", Vector2i(-252, 17))), "Mine test character must be able to reach the Old Seam stair")
		var seam_descent: Dictionary = mine_runtime.interact_with_stair("emberlode_test_player")
		_check(bool(seam_descent.get("ok", false)) and mine_runtime.get_current_floor() == -2, "Working Vein stair must enter the Old Seam")
		_check(mine_runtime.is_floor_visible(-2) and not mine_runtime.is_floor_visible(-1), "Only the active Emberlode mine floor may be visible")

	
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
