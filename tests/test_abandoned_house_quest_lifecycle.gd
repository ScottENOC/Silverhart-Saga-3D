extends SceneTree

const QUEST = preload("res://scripts/simulation/abandoned_house_clearing_quest.gd")


func _initialize() -> void:
	_test_approach_does_not_start_from_far_away()
	_test_approach_starts_quest_and_registers_guardians()
	_test_completed_quest_does_not_restore_guardians()
	_test_encounter_entry_checks_range_before_starting()
	print("Abandoned-house quest lifecycle tests passed.")
	quit(0)


func _simulation_at(hex: Vector2i) -> WorldSimulation:
	var simulation := WorldSimulation.new()
	assert(bool(QUEST.register_definition(simulation.campaign_journal).get("ok", false)))
	var player := CharacterState.new("player", "Player", hex)
	player.side = "player"
	simulation.register_character(player)
	return simulation


func _test_approach_does_not_start_from_far_away() -> void:
	var simulation := _simulation_at(Vector2i(100, 100))
	var result := QUEST.prepare_approach(simulation, "player")
	assert(bool(result.get("ok", false)))
	assert(not bool(result.get("should_present", true)))
	assert(String(simulation.campaign_journal.quest_state(QUEST.QUEST_ID).get("status", "")) == "")
	assert(QUEST.guardian_count_remaining(simulation) == QUEST.GUARDIAN_IDS.size())
	simulation.free()


func _test_approach_starts_quest_and_registers_guardians() -> void:
	var simulation := _simulation_at(QUEST.HOUSE_CENTRE)
	var result := QUEST.prepare_approach(simulation, "player")
	assert(bool(result.get("ok", false)))
	assert(bool(result.get("should_present", false)))
	assert(String(simulation.campaign_journal.quest_state(QUEST.QUEST_ID).get("status", "")) == "active")
	assert(result.get("guardian_ids", []).size() == QUEST.GUARDIAN_IDS.size())
	assert(QUEST.guardian_count_remaining(simulation) == QUEST.GUARDIAN_IDS.size())
	var repeat := QUEST.prepare_approach(simulation, "player")
	assert(bool(repeat.get("ok", false)))
	assert(QUEST.guardian_count_remaining(simulation) == QUEST.GUARDIAN_IDS.size())
	simulation.free()


func _test_completed_quest_does_not_restore_guardians() -> void:
	var simulation := _simulation_at(QUEST.HOUSE_CENTRE)
	assert(bool(simulation.campaign_journal.start_quest(QUEST.QUEST_ID).get("ok", false)))
	assert(bool(simulation.campaign_journal.set_objective_progress(QUEST.QUEST_ID, QUEST.OBJECTIVE_ID, 3.0).get("ok", false)))
	assert(bool(simulation.campaign_journal.complete_quest(QUEST.QUEST_ID).get("ok", false)))
	var result := QUEST.prepare_approach(simulation, "player")
	assert(bool(result.get("ok", false)))
	assert(not bool(result.get("should_present", true)))
	assert(String(result.get("reason", "")) == "quest_completed")
	assert(QUEST.guardian_count_remaining(simulation) == QUEST.GUARDIAN_IDS.size())
	simulation.free()


func _test_encounter_entry_checks_range_before_starting() -> void:
	var simulation := _simulation_at(Vector2i(100, 100))
	var result := QUEST.start_encounter_from_character(simulation, "player", ["player"])
	assert(not bool(result.get("ok", true)))
	assert(String(result.get("reason", "")) == "too_far_from_house")
	assert(String(simulation.campaign_journal.quest_state(QUEST.QUEST_ID).get("status", "")) == "")
	simulation.free()
