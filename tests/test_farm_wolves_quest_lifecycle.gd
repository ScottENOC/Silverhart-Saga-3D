extends SceneTree

const FARM_QUEST = preload("res://scripts/simulation/farm_wolves_quest.gd")


func _initialize() -> void:
	_test_approach_rules()
	_test_wolf_registration_is_idempotent()
	_test_invalid_spawn_layout_is_rejected()
	print("Farm wolf quest lifecycle tests passed.")
	quit(0)


func _simulation_at(hex: Vector2i) -> WorldSimulation:
	var simulation := WorldSimulation.new()
	assert(bool(simulation.campaign_journal.register_quest_definition(FARM_QUEST.definition()).get("ok", false)))
	var player := CharacterState.new("player", "Player", hex)
	player.side = "player"
	simulation.register_character(player)
	return simulation


func _test_approach_rules() -> void:
	var den := Vector2i(12, -4)
	var simulation := _simulation_at(den + Vector2i(8, 0))
	assert(bool(simulation.campaign_journal.start_quest(FARM_QUEST.QUEST_ID).get("ok", false)))
	var first := FARM_QUEST.evaluate_approach(simulation, den, false, false)
	assert(bool(first.get("ok", false)))
	assert(bool(first.get("should_spawn", false)), "Active quest should trigger at the inclusive approach radius")

	var far_player := simulation.get_character("player")
	far_player.axial = den + Vector2i(9, 0)
	var departed := FARM_QUEST.evaluate_approach(simulation, den, true, false)
	assert(bool(departed.get("ok", false)))
	assert(not bool(departed.get("should_spawn", true)))
	assert(bool(departed.get("retry_armed", false)), "Leaving the den should arm a retry")

	far_player.axial = den
	var returned := FARM_QUEST.evaluate_approach(simulation, den, true, true)
	assert(bool(returned.get("ok", false)))
	assert(bool(returned.get("should_spawn", false)), "Returning should retry while wolves remain")

	assert(bool(simulation.campaign_journal.set_objective_progress(FARM_QUEST.QUEST_ID, FARM_QUEST.OBJECTIVE_ID, 3.0).get("ok", false)))
	var completed := FARM_QUEST.evaluate_approach(simulation, den, true, true)
	assert(not bool(completed.get("should_spawn", true)), "Completed pack should not respawn")
	simulation.free()

	var inactive := _simulation_at(den)
	var not_accepted := FARM_QUEST.evaluate_approach(inactive, den, false, false)
	assert(not bool(not_accepted.get("should_spawn", true)), "Unaccepted quest should not trigger")
	inactive.free()


func _test_wolf_registration_is_idempotent() -> void:
	var simulation := _simulation_at(Vector2i.ZERO)
	var spawn_hexes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]
	var first := FARM_QUEST.ensure_wolves(simulation, spawn_hexes)
	assert(bool(first.get("ok", false)))
	assert(first.get("created_ids", []).size() == FARM_QUEST.WOLF_IDS.size())
	assert(FARM_QUEST.remaining_wolves(simulation, true) == FARM_QUEST.WOLF_IDS.size())

	var first_wolf := simulation.get_character(FARM_QUEST.WOLF_IDS[0])
	first_wolf.health = 0
	first_wolf.alive = false
	var repeated := FARM_QUEST.ensure_wolves(simulation, spawn_hexes)
	assert(bool(repeated.get("ok", false)))
	assert(repeated.get("created_ids", []).is_empty(), "Existing wolves must not be duplicated or reset")
	assert(first_wolf.health == 0, "Re-ensuring wolves must preserve existing combat state")
	assert(FARM_QUEST.remaining_wolves(simulation, true) == FARM_QUEST.WOLF_IDS.size() - 1)
	simulation.free()


func _test_invalid_spawn_layout_is_rejected() -> void:
	var simulation := _simulation_at(Vector2i.ZERO)
	var too_few: Array[Vector2i] = [Vector2i(1, 0)]
	var invalid := FARM_QUEST.ensure_wolves(simulation, too_few)
	assert(not bool(invalid.get("ok", true)))
	assert(String(invalid.get("reason", "")) == "invalid_spawn_count")
	assert(FARM_QUEST.remaining_wolves(simulation, true) == 0)
	simulation.free()
