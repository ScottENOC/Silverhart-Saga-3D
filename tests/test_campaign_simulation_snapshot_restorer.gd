extends SceneTree

const RESTORER := preload("res://scripts/campaign/campaign_simulation_snapshot_restorer.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var simulation := WorldSimulation.new()
	for q in range(-2, 3):
		for r in range(-2, 3):
			simulation.map_data.add_cell(Vector2i(q, r), 0.0, true, "grass")
	var player := CharacterState.new("player", "Original Hero", Vector2i.ZERO)
	player.side = "player"
	simulation.register_character(player)

	var saved_player := player.to_dict()
	saved_player["display_name"] = "Restored Hero"
	saved_player["health"] = 37
	var dynamic_npc := CharacterState.new("dynamic_test_npc", "Saved Traveller", Vector2i(1, 0))
	dynamic_npc.side = "neutral"
	var clock := simulation.clock.to_dict()
	clock["world_seconds"] = 98765.0
	clock["tick_index"] = 123
	var journal := simulation.campaign_journal.to_dict()
	journal["faction_standings"] = {"restorer_test_faction": -17.0}
	var relationship_state := PersistentCharacterRelationshipState.new()
	relationship_state.adjust_relationship("rowan_fletcher", {"friendship": 12, "familiarity": 3}, "restorer test")

	var snapshot := {
		"character_diffs": {"player": {"__full_record": saved_player}},
		"dynamic_campaign_characters": {"dynamic_test_npc": dynamic_npc.to_dict()},
		"party_member_ids": ["player", "dynamic_test_npc"],
		"clock": clock,
		"campaign_journal": journal,
		"persistent_character_relationships": relationship_state.to_dict(),
		"wilderness_resources": simulation.wilderness_resources.to_dict(),
		"buildings": simulation.building_registry.to_dict()
	}
	var result: Dictionary = RESTORER.restore(simulation, snapshot)
	_check(bool(result.get("ok", false)), "Valid campaign simulation snapshots should restore.")
	var restored_player := simulation.get_character("player")
	_check(restored_player != null and restored_player.display_name == "Restored Hero", "Full character records should restore the saved identity.")
	_check(restored_player != null and restored_player.health == 37, "Full character records should restore character state.")
	_check(simulation.get_character("dynamic_test_npc") != null, "Dynamic campaign characters should be recreated in simulation state.")
	_check(simulation.get_party_member_ids() == ["player", "dynamic_test_npc"], "The canonical party roster should restore after dynamic characters.")
	_check(is_equal_approx(simulation.clock.world_seconds, 98765.0) and simulation.clock.tick_index == 123, "The campaign clock should restore.")
	_check(is_equal_approx(float(simulation.campaign_journal.faction_standings.get("restorer_test_faction", 0.0)), -17.0), "Campaign journal state should restore.")
	var restored_relationships := PERSISTENT_RELATIONSHIP_STORE.state_for(simulation)
	_check(int(restored_relationships.snapshot("rowan_fletcher").get("friendship", 0)) == 12, "Persistent NPC relationships should restore.")
	simulation.free()

	if failures > 0:
		push_error("%d campaign snapshot restorer assertion(s) failed." % failures)
		quit(1)
	else:
		print("Campaign simulation snapshot restorer tests passed.")
		quit(0)


const PERSISTENT_RELATIONSHIP_STORE := preload("res://scripts/simulation/persistent_character_relationship_store.gd")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)
