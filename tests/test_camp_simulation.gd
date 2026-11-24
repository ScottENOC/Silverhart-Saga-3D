extends SceneTree

var _failures := 0


func _initialize() -> void:
	_test_site_validation()
	_test_activity_planning_and_player_override()
	_test_tent_capacity_and_relationship_matching()
	_test_night_resolution_and_save_load()
	_test_world_simulation_integration()
	if _failures > 0:
		push_error("%d camp simulation assertion(s) failed." % _failures)
		quit(1)
		return
	print("Camp simulation tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_site_validation() -> void:
	var camp := CampSimulation.new()
	_check(not camp.begin_camp({"walkable": false}, ["player"]).ok)
	_check(not camp.begin_camp({"walkable": true, "occupied": true}, ["player"]).ok)
	_check(not camp.begin_camp({"walkable": true}, []).ok)
	var started := camp.begin_camp({"walkable": true, "position": Vector3(1, 0, 2)}, ["player", "wren"])
	_check(bool(started.ok))
	_check(String(camp.phase) == "evening")


func _test_activity_planning_and_player_override() -> void:
	var camp := CampSimulation.new()
	camp.begin_camp(
		{"walkable": true},
		["player", "wren", "aldric", "fenn", "reyna"],
		{"trees_nearby": true, "water_nearby": true, "danger": 0.3},
		{"wood": 0, "rations": 4, "water": 0, "tents": 1, "repair_kits": 1}
	)
	var activity_names: Array[String] = []
	for character_id in camp.assignments:
		activity_names.append(String(camp.assignments[character_id].activity))
	_check(activity_names.has("gather_wood"))
	_check(activity_names.has("fetch_water"))
	_check(activity_names.has("set_up_tents"))
	_check(activity_names.has("watch"))
	_check(camp.watch_slots_for_party(8) > camp.watch_slots_for_party(3), "Larger parties should support more simultaneous watch positions")
	_check(camp.watch_slots_for_party(1) == 0, "A lone camper cannot maintain a separate watch while sleeping")
	camp.assign_activity("player", "train")
	camp.advance_real_time(9.0)
	_check(String(camp.assignments.player.activity) == "train")
	camp.advance_real_time(1.0)
	_check(String(camp.assignments.player.activity) != "train", "Player-directed activity should return to autonomous duties after ten idle seconds")
	_check(is_equal_approx(camp.elapsed_world_seconds, 50.0), "Camp evening should advance at normal exploration time, not an accelerated camp rate")


func _test_tent_capacity_and_relationship_matching() -> void:
	var camp := CampSimulation.new()
	camp.begin_camp({"walkable": true}, ["a", "b", "c", "d", "e", "f"], {}, {"tents": 2})
	var bonds := CompanionBondState.new()
	bonds.set_relationship("a", "b", {"friendship": 90, "trust": 90})
	bonds.set_relationship("b", "a", {"friendship": 90, "trust": 90})
	bonds.set_relationship("a", "c", {"friendship": 80, "trust": 80})
	bonds.set_relationship("c", "a", {"friendship": 80, "trust": 80})
	bonds.set_relationship("a", "d", {"friendship": 10, "trust": 10})
	bonds.set_relationship("d", "a", {"friendship": 10, "trust": 10})
	var groups := camp.plan_sleeping_arrangements(2, bonds)
	_check(groups.size() == 2)
	_check((groups[0].character_ids as Array).size() == 3)
	_check((groups[1].character_ids as Array).size() == 3)
	_check(float(bonds.compatibility_score("a", "b")) > float(bonds.compatibility_score("a", "d")))
	var crowded := camp.plan_sleeping_arrangements(1, bonds)
	_check((crowded[0].character_ids as Array).size() == 5)
	_check(int(crowded[0].comfort_penalty) == 20)
	var spacious := CampSimulation.new()
	spacious.begin_camp({"walkable": true}, ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"], {}, {"tents": 4})
	var comfortable_groups := spacious.plan_sleeping_arrangements(4, bonds)
	_check(comfortable_groups.size() == 4)
	for group in comfortable_groups:
		_check((group.character_ids as Array).size() <= 3, "Available tents should be used to avoid unnecessary crowding")


func _test_night_resolution_and_save_load() -> void:
	var camp := CampSimulation.new()
	camp.begin_camp(
		{"walkable": true},
		["player", "wren", "aldric"],
		{"night_temperature_c": 2.0, "danger": 0.6, "fire_lit": true},
		{"wood": 2, "rations": 3, "water": 3, "tents": 1, "sleeping_bags": 3}
	)
	camp.plan_sleeping_arrangements(1)
	var saved := camp.to_dict()
	var restored := CampSimulation.new()
	_check(restored.from_dict(saved), "Camp state should restore from a save snapshot")
	_check(restored.to_dict() == saved, "Camp assignments and conditions should survive save/load")
	var result := restored.skip_to_morning()
	_check(bool(result.ok))
	_check(float(result.summary.ambush_chance) >= 0.0 and float(result.summary.ambush_chance) <= 0.45)
	_check(float(result.summary.characters.player.comfort) > 0.0)
	_check(String(restored.phase) == "resolved")
	_check(int(restored.resources.water) == 0, "Drinking water should be consumed once for the whole party, not once per character")
	_check(String(restored.next_day_effects("player").get("fatigue_band", "")) == "rested")
	_check(restored.time_point_regeneration_multiplier("player") > 1.0, "A well-rested character should receive a modest next-day recovery bonus")
	var after_night := restored.condition_for("player")
	restored.begin_camp({"walkable": true}, ["player", "wren"])
	_check(restored.condition_for("player") == after_night, "Fatigue, hunger and thirst must persist between camp sessions")
	_check(not bool(restored.resolve_night().ok), "A resolved camp cannot resolve twice")



func _test_world_simulation_integration() -> void:
	var world := WorldSimulation.new()
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	var companion := CharacterState.new("wren", "Wren", Vector2i(1, 0))
	companion.side = "player"
	world.register_character(player)
	world.register_character(companion)
	var started := world.begin_camp({"walkable": true}, {"night_temperature_c": 8.0}, {"wood": 1, "rations": 2, "water": 2, "tents": 1})
	_check(bool(started.ok), "World simulation should start camp with the current party")
	var social_event := world.record_companion_interaction("wren", "player", "flirt", {"attraction": 2.0}, "camp_flirt:001")
	_check(bool(social_event.get("changed", false)), "Flirting should be recordable during any camp activity")
	_check(float(world.camp_simulation.condition_for("wren").get("social_satisfaction", 0.0)) > 0.0, "Social contact should contribute to later camp comfort without requiring a socialise assignment")
	world.advance_real_time(2.0)
	_check(is_equal_approx(world.clock.world_seconds, 10.0), "Camp evening should use the ordinary 5x exploration clock")
	world.companion_bonds.set_relationship("wren", "player", {"friendship": 30})
	var saved := world.to_dict()
	var restored := WorldSimulation.new()
	restored.load_dict(saved)
	_check(String(restored.camp_simulation.phase) == "evening", "Camp state should be part of the world save")
	_check(float(restored.companion_bonds.snapshot("wren", "player").friendship) == 30.0, "Companion bonds should be part of the world save")
	var morning := restored.skip_camp_to_morning(6.0)
	_check(bool(morning.ok), "The world simulation should resolve the camp night")
	_check(is_equal_approx(restored.clock.world_seconds, 10.0 + 6.0 * WorldClock.SECONDS_PER_HOUR), "Sleeping should skip directly to morning and advance the authoritative clock by the sleep duration")
