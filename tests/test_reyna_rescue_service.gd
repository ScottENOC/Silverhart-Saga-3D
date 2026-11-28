extends SceneTree

const RESCUE = preload("res://scripts/quests/reyna_rescue_service.gd")
const QUEST_REGISTRY = preload("res://scripts/quests/campaign_quest_registry.gd")


func _initialize() -> void:
	_test_inactive_quest_does_not_trigger()
	_test_trail_discovery_is_quest_owned()
	_test_shelter_spawning_requires_trail_and_unrescued_child()
	_test_objective_completion_query()
	_test_direct_interaction_prompts()
	print("Reyna rescue service tests passed.")
	quit(0)


func _simulation_with_quest() -> WorldSimulation:
	var simulation := WorldSimulation.new()
	assert(bool(QUEST_REGISTRY.register_definitions(simulation).get("ok", false)))
	return simulation


func _test_inactive_quest_does_not_trigger() -> void:
	var simulation := _simulation_with_quest()
	var result := RESCUE.proximity_action(simulation, true, true, false)
	assert(String(result.get("action", "")) == "none")
	assert(not RESCUE.objective_complete(simulation, "trail_found"))
	simulation.free()


func _test_trail_discovery_is_quest_owned() -> void:
	var simulation := _simulation_with_quest()
	assert(bool(simulation.campaign_journal.start_quest(RESCUE.QUEST_ID).get("ok", false)))
	var away := RESCUE.proximity_action(simulation, false, false, false)
	assert(String(away.get("action", "")) == "show_trail_clue")
	var nearby := RESCUE.proximity_action(simulation, true, false, false)
	assert(String(nearby.get("action", "")) == "record_trail_found")
	var recorded := RESCUE.record_trail_found(simulation)
	assert(bool(recorded.get("ok", false)))
	assert(RESCUE.objective_complete(simulation, "trail_found"))
	var duplicate := RESCUE.record_trail_found(simulation)
	assert(bool(duplicate.get("ok", false)), "Repeated trail discovery should remain safe.")
	simulation.free()


func _test_shelter_spawning_requires_trail_and_unrescued_child() -> void:
	var simulation := _simulation_with_quest()
	assert(bool(simulation.campaign_journal.start_quest(RESCUE.QUEST_ID).get("ok", false)))
	assert(String(RESCUE.proximity_action(simulation, false, true, false).get("action", "")) == "show_trail_clue")
	assert(bool(RESCUE.record_trail_found(simulation).get("ok", false)))
	assert(String(RESCUE.proximity_action(simulation, false, true, false).get("action", "")) == "spawn_missing_child")
	assert(String(RESCUE.proximity_action(simulation, false, true, true).get("action", "")) == "none")
	simulation.free()


func _test_objective_completion_query() -> void:
	var simulation := _simulation_with_quest()
	assert(bool(simulation.campaign_journal.start_quest(RESCUE.QUEST_ID).get("ok", false)))
	assert(not RESCUE.objective_complete(simulation, "child_rescued"))
	assert(bool(simulation.campaign_journal.set_objective_progress(RESCUE.QUEST_ID, "child_rescued", 1.0).get("ok", false)))
	assert(RESCUE.objective_complete(simulation, "child_rescued"))
	simulation.free()


func _test_direct_interaction_prompts() -> void:
	var simulation := _simulation_with_quest()
	var blocked := RESCUE.interaction_for_character(simulation, "farmstead_dire_wolf")
	assert(String(blocked.get("action", "")) == "block_hunt")
	assert(String(blocked.get("speaker", "")) == "Dire wolf")
	var child_before := RESCUE.interaction_for_character(simulation, RESCUE.CHILD_ID)
	assert(String(child_before.get("action", "")) == "speak")
	assert(String(child_before.get("choices", [])[0].get("id", "")) == "reyna_rescue_child")
	assert(bool(simulation.campaign_journal.start_quest(RESCUE.QUEST_ID).get("ok", false)))
	assert(bool(simulation.campaign_journal.set_objective_progress(RESCUE.QUEST_ID, "child_rescued", 1.0).get("ok", false)))
	var child_after := RESCUE.interaction_for_character(simulation, RESCUE.CHILD_ID)
	assert(String(child_after.get("expression", "")) == "smile")
	var ready_wolf := RESCUE.interaction_for_character(simulation, "farmstead_dire_wolf")
	assert(String(ready_wolf.get("action", "")) == "start_hunt")
	assert(String(RESCUE.interaction_for_character(simulation, "unrelated_npc").get("action", "")) == "none")
	simulation.free()
