extends SceneTree

var _failures := 0
var _camp_actor_probes: Dictionary = {}
var _camp_animal_care_events := 0
var _camp_night_events := 0


class CampActivityProbe extends RefCounted:
	var last_activity: String = ""
	var activity_count: int = 0

	func play_camp_activity(activity: String) -> bool:
		last_activity = activity
		activity_count += 1
		return true


func _camp_actor_for_id(character_id: String) -> Object:
	return _camp_actor_probes.get(character_id)


func _on_camp_action_committed(event: SimulationEvent) -> void:
	if event.event_type == "camp_animal_care":
		_camp_animal_care_events += 1

func _on_camp_night_encounter_resolved(result: Dictionary) -> void:
	_camp_night_events += 1


func _initialize() -> void:
	_test_site_validation()
	_test_activity_planning_and_player_override()
	_test_tent_capacity_and_relationship_matching()
	_test_indoor_floor_sleeping_and_security()
	_test_general_camp_occupant_registry()
	_test_world_camp_animal_care_integration()
	_test_scheduled_horse_care_routine()
	_test_night_resolution_and_save_load()
	_test_night_watch_rotation_and_detection()
	_test_world_simulation_integration()
	_test_companions_walk_to_camp_stations()
	_test_dwelling_layout_station_selection()
	_test_evening_routine_progression()
	_test_livable_dwelling_avoids_unneeded_tent_setup()
	_test_world_weather_state_and_camp_integration()
	_test_dwelling_station_presentation()
	_test_ara_camp_animation_mapping()
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
	_check(not activity_names.has("watch"), "Night watch should not pull companions away from evening routines")
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


func _test_indoor_floor_sleeping_and_security() -> void:
	var dwelling := CampSimulation.new()
	dwelling.begin_camp(
		{"walkable": true, "dwelling_profile": {
			"dwelling_id": "country_house", "is_sheltered": true,
			"sleeping_capacity": 1, "indoor_floor_capacity": 4,
			"warmth_bonus": 15.0, "security_bonus": 15.0
		}},
		["a", "b", "c", "d"], {"danger": 0.6, "night_temperature_c": 2.0},
		{"tents": 2, "sleeping_bags": 3}
	)
	var arrangements := dwelling.plan_sleeping_arrangements(2)
	_check(arrangements.size() == 4, "A party that fits inside should not pitch tents or sleep outdoors")
	_check(String(arrangements[0].sleeping_surface) == "bed", "A placed bed should be allocated before floor space")
	_check(String(arrangements[1].sleeping_surface) == "floor", "Additional occupants should sleep on the indoor floor")
	_check(String(arrangements[1].shelter_type) == "dwelling", "Indoor floor sleepers should remain sheltered")
	_check((arrangements[1].sleeping_bag_character_ids as Array).size() == 1, "Available bedrolls should improve indoor floor sleeping")
	for arrangement in arrangements:
		_check(String(arrangement.shelter_type) == "dwelling", "Indoor capacity should take priority over outdoor tents")
	var indoor_result := dwelling.skip_to_morning()
	_check(float(indoor_result.summary.exposure_ratio) == 0.0, "A fully indoor party should have no outdoor exposure")
	_check(float(indoor_result.summary.ambush_chance) < float(indoor_result.summary.base_ambush_chance), "A secure dwelling should reduce ambush risk")
	_check(String(indoor_result.summary.characters.a.sleeping_surface) == "bed", "Night results should report the allocated sleeping surface")
	_check(String(indoor_result.summary.characters.b.sleeping_surface) == "floor", "Night results should distinguish floor sleeping from a bed")

	var outdoor := CampSimulation.new()
	outdoor.begin_camp({"walkable": true}, ["a", "b", "c", "d"], {"danger": 0.6}, {})
	var outdoor_result := outdoor.skip_to_morning()
	_check(float(indoor_result.summary.ambush_chance) < float(outdoor_result.summary.ambush_chance), "Sleeping inside should be safer than sleeping exposed outdoors")

	var uninhabitable := CampSimulation.new()
	uninhabitable.begin_camp(
		{"walkable": true, "dwelling_profile": {
			"is_sheltered": false, "sleeping_capacity": 8, "indoor_floor_capacity": 20
		}},
		["a"], {}, {}
	)
	var unsafe_arrangement := uninhabitable.plan_sleeping_arrangements(0)
	_check(String(unsafe_arrangement[0].shelter_type) == "open_air", "A structurally uninhabitable dwelling must not provide indoor sleeping space")


func _test_general_camp_occupant_registry() -> void:
	var camp := CampSimulation.new()
	camp.begin_camp(
		{"walkable": true, "safe_tethering": true},
		["player", "druid"],
		{"camp_occupants": [
			{"occupant_id": "moss", "kind": "animal", "species": "wolf", "bonded_to": "druid", "can_sleep": true, "can_work": false, "needs": ["food", "water", "shelter", "sleep", "safety", "social"]},
			{"occupant_id": "horse_01", "kind": "animal", "species": "horse", "can_sleep": true, "can_work": false, "needs": ["food", "water", "shelter", "sleep"]},
			{"occupant_id": "refugee_01", "kind": "follower", "species": "humanoid", "can_sleep": true, "can_work": false},
			{"occupant_id": "cook_01", "kind": "resident", "species": "humanoid", "can_sleep": true, "can_work": true},
			{"occupant_id": "traveller_01", "kind": "guest", "species": "humanoid", "staying_overnight": true}
		]},
		{"water": 3, "fodder": 2}
	)
	_check(camp.occupants.size() == 7, "Camp registry should include party members and independent camp occupants")
	_check(camp.party_ids.size() == 2, "Followers, animals, residents and guests must not consume party slots")
	_check(String(camp.occupant_for("moss").kind) == "animal", "Animal companions should retain their distinct occupant kind")
	_check(String(camp.occupant_for("moss").species) == "wolf", "Animal occupants should retain species information")
	_check(String(camp.occupant_for("refugee_01").kind) == "follower", "A protected traveller should be represented as a follower")
	_check(String(camp.occupant_for("cook_01").kind) == "resident", "Household workers should have a resident category")
	_check(bool(camp.occupant_for("traveller_01").can_sleep), "Overnight guests should be eligible for sleeping allocation")
	_check(not bool(camp.occupant_for("traveller_01").can_work), "Guests should not default to camp duties")
	_check(camp.occupants_of_kind("animal").size() == 2, "Occupants should be queryable by category")
	_check(not bool(camp.perform_animal_care("moss", "water", "druid").ok), "Horse-specific care must not be applied to a wolf")
	_check(bool(camp.perform_animal_care("horse_01", "water", "druid").ok), "A capable party member should be able to water a camp horse")
	_check(bool(camp.perform_animal_care("horse_01", "feed", "druid").ok), "A capable party member should be able to feed a camp horse when fodder is supplied")
	var repeat_feed := camp.perform_animal_care("horse_01", "feed", "druid")
	_check(bool(repeat_feed.get("ok", false)) and bool(repeat_feed.get("already_completed", false)), "Repeating a completed feed action should be idempotent")
	_check(int(camp.resources.fodder) == 1, "Repeating care must not consume fodder twice")
	_check(bool(camp.perform_animal_care("horse_01", "groom", "druid").ok), "A camp horse should be groomable")
	_check(bool(camp.perform_animal_care("horse_01", "tether", "druid").ok), "A horse should be tetherable at a safe authored anchor")
	_check(bool(camp.perform_animal_care("horse_01", "rest", "druid").ok), "A horse should be able to settle to rest")
	_check(bool(camp.horse_care_for("horse_01").get("watered", false)) and bool(camp.horse_care_for("horse_01").get("fed", false)), "Horse care flags should record feeding and watering")
	_check(bool(camp.horse_care_for("horse_01").get("groomed", false)) and bool(camp.horse_care_for("horse_01").get("tethered", false)) and bool(camp.horse_care_for("horse_01").get("resting", false)), "Horse care should record grooming, tethering and rest")
	_check(int(camp.resources.water) == 2 and int(camp.resources.fodder) == 1, "Watering and feeding should consume their respective camp supplies")
	_check(not bool(camp.perform_animal_care("horse_01", "feed", "refugee_01").ok), "A follower without work capability must not be accepted as a care handler")
	camp.resources["fodder"] = 0
	_check(bool(camp.register_camp_occupant({"occupant_id": "horse_02", "kind": "animal", "species": "horse"}).ok), "A second horse should be registerable independently")
	_check(not bool(camp.perform_animal_care("horse_02", "feed", "druid").ok), "Feeding another horse without fodder must fail")
	_check(not bool(camp.remove_camp_occupant("player").ok), "Party members cannot be removed through the non-party occupant API")
	_check(bool(camp.remove_camp_occupant("traveller_01").ok), "Non-party occupants should be removable when they leave")
	var departure := CampSimulation.new()
	departure.begin_camp(
		{"walkable": true, "safe_tethering": true},
		["player"],
		{"camp_occupants": [
			{"occupant_id": "horse_departing", "kind": "animal", "species": "horse"},
			{"occupant_id": "stablehand_departing", "kind": "resident", "occupation": "stablehand", "can_work": true},
			{"occupant_id": "backup_handler", "kind": "follower", "can_work": true}
		]},
		{"water": 1, "fodder": 1}
	)
	_check(bool(departure.remove_camp_occupant("stablehand_departing").ok), "A departing care handler should be removable")
	var reassigned_schedule := departure.horse_care_schedule_for("horse_departing")
	_check(String(reassigned_schedule[0].get("handler_id", "")) == "backup_handler", "An active horse-care queue should be reassigned when its handler leaves")
	_check(String(departure.assignments.get("backup_handler", {}).get("activity", "")) == "care_horse_water", "The replacement handler should receive the active care activity")
	_check(bool(departure.remove_camp_occupant("horse_departing").ok), "A departing horse should be removable")
	_check(departure.horse_care_schedule_for("horse_departing").is_empty(), "Removing a horse should prune its queued chores")
	_check(not departure.animal_care.has("horse_departing"), "Removing a horse should prune its care state")
	_check(departure.from_dict(departure.to_dict()), "Removing camp occupants should leave a valid save snapshot")
	_check(not bool(camp.register_camp_occupant({"occupant_id": "bad", "kind": "spaceship"}).ok), "Unknown occupant kinds should be rejected")
	_check(not bool(camp.register_camp_occupant({"occupant_id": "player", "kind": "follower"}).ok), "A party member cannot be reclassified as a non-party follower")

	var saved := camp.to_dict()
	var restored := CampSimulation.new()
	_check(restored.from_dict(saved), "The full camp occupant registry should survive save/load")
	_check(restored.occupant_for("moss") == camp.occupant_for("moss"), "Animal identity and care metadata should persist")
	_check(restored.horse_care_for("horse_01") == camp.horse_care_for("horse_01"), "Horse care state should persist through save/load")
	_check(restored.occupant_for("cook_01") == camp.occupant_for("cook_01"), "Resident metadata should persist")


func _test_world_camp_animal_care_integration() -> void:
	var world := WorldSimulation.new()
	var player := CharacterState.new("player", "Player")
	player.side = "player"
	world.register_character(player)
	var horse := AnimalCatalog.create_state("horse", "camp_horse", "Mallow", Vector2i(1, 0), 4812)
	_check(bool(world.register_animal(horse).get("ok", false)), "A registered world horse should be available to the camp system")
	_camp_animal_care_events = 0
	world.action_committed.connect(_on_camp_action_committed)
	var started := world.begin_camp(
		{"walkable": true, "safe_tethering": true},
		{"camp_occupants": [
			{"occupant_id": "camp_horse", "kind": "animal", "species": "horse", "can_sleep": true, "can_work": false}
		]},
		{"water": 1, "fodder": 1}
	)
	_check(bool(started.get("ok", false)), "World camp setup should accept an explicitly registered horse occupant")
	world.advance_world_seconds(20.0)
	_check(int(world.camp_simulation.resources.water) == 0, "Deterministic world-time advancement should complete scheduled horse watering")
	_check(bool(world.camp_simulation.horse_care_for("camp_horse").get("watered", false)), "Scheduled horse watering should update the authoritative care state")
	_check(_camp_animal_care_events == 1, "Scheduled animal care should be published as a world simulation event")
	var fed := world.care_camp_animal("camp_horse", "feed", "player")
	_check(_camp_animal_care_events == 2, "Manual animal care should use the same world event channel")
	_check(bool(fed.get("ok", false)), "World simulation should expose camp horse feeding")
	var saved := world.to_dict()
	var restored := WorldSimulation.new()
	restored.load_dict(saved)
	restored.action_committed.connect(_on_camp_action_committed)
	_check(bool(restored.camp_simulation.horse_care_for("camp_horse").get("watered", false)), "World save/load should preserve camp horse care state")
	_check(bool(restored.camp_simulation.horse_care_for("camp_horse").get("fed", false)), "World save/load should preserve camp horse feeding")
	_check(bool(restored.care_camp_animal("camp_horse", "groom", "player").get("ok", false)), "Restored world simulations should retain animal care event wiring")
	_check(_camp_animal_care_events == 3, "Animal care after loading should still publish world events")
	world.free()
	restored.free()


func _test_scheduled_horse_care_routine() -> void:
	var camp := CampSimulation.new()
	camp.begin_camp(
		{"walkable": true, "safe_tethering": true},
		["player", "wren"],
		{"camp_occupants": [
			{"occupant_id": "horse_mallow", "kind": "animal", "species": "horse", "can_sleep": true, "can_work": false},
			{"occupant_id": "stablehand_01", "kind": "resident", "species": "humanoid", "occupation": "stablehand", "can_sleep": true, "can_work": true}
		]},
		{"water": 1, "fodder": 1}
	)
	var schedule := camp.horse_care_schedule_for("horse_mallow")
	_check(schedule.size() == 5, "Each camp horse should receive a five-step evening care schedule")
	_check(String(schedule[0].get("action", "")) == "water" and String(schedule[0].get("status", "")) == "in_progress", "Horse watering should be the first scheduled chore")
	_check(String(schedule[0].get("handler_id", "")) == "stablehand_01", "A resident stablehand should be preferred over party members")
	_check(String(camp.assignments.get("stablehand_01", {}).get("activity", "")) == "care_horse_water", "The selected worker should receive the corresponding camp activity")
	_check(camp.party_ids.size() == 2, "A resident stablehand must not occupy a party slot")
	camp.advance_real_time(4.0)
	schedule = camp.horse_care_schedule_for("horse_mallow")
	_check(String(schedule[0].get("status", "")) == "completed", "Watering should complete after its scheduled work duration")
	_check(String(schedule[1].get("status", "")) == "in_progress", "The next chore should begin automatically when watering completes")
	_check(int(camp.resources.water) == 0, "Water should be consumed when the watering task completes")
	camp.advance_real_time(4.0)
	_check(int(camp.resources.fodder) == 0, "Fodder should be consumed when feeding completes")
	var saved := camp.to_dict()
	var restored := CampSimulation.new()
	_check(restored.from_dict(saved), "An in-progress horse care schedule with a non-party handler should survive save/load")
	_check(restored.horse_care_schedule_for("horse_mallow") == camp.horse_care_schedule_for("horse_mallow"), "Task progress and handler assignment should persist")
	restored.advance_real_time(21.0)
	var completed_schedule := restored.horse_care_schedule_for("horse_mallow")
	for task in completed_schedule:
		_check(String(task.get("status", "")) == "completed", "Water, feed, grooming, tethering and rest should all finish in the evening schedule")
	var care := restored.horse_care_for("horse_mallow")
	_check(bool(care.get("watered", false)) and bool(care.get("fed", false)), "Scheduled care should update horse hydration and feeding state")
	_check(bool(care.get("groomed", false)) and bool(care.get("tethered", false)) and bool(care.get("resting", false)), "Scheduled care should finish grooming, tethering and rest")
	_check(String(restored.assignments.get("stablehand_01", {}).get("activity", "")) != "care_horse_tether", "The worker should return to their prior routine after completing horse care")


	var waiting := CampSimulation.new()
	waiting.begin_camp(
		{"walkable": true, "safe_tethering": true},
		["player", "wren"],
		{"player_character_id": "player", "water_nearby": true, "camp_occupants": [
			{"occupant_id": "horse_waiting", "kind": "animal", "species": "horse"},
			{"occupant_id": "stablehand_waiting", "kind": "resident", "occupation": "stablehand", "can_work": true}
		]},
		{"water": 0, "fodder": 1}
	)
	var waiting_schedule := waiting.horse_care_schedule_for("horse_waiting")
	_check(String(waiting_schedule[0].get("status", "")) == "pending", "Horse watering should wait when camp water has not yet been collected")
	waiting.advance_real_time(24.0)
	_check(int(waiting.resources.water) == 2, "The existing fetch-water preparation should replenish camp water")
	waiting.advance_real_time(1.0)
	waiting_schedule = waiting.horse_care_schedule_for("horse_waiting")
	_check(String(waiting_schedule[0].get("status", "")) == "in_progress", "A waiting horse watering task should resume when water becomes available")


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
	_check(int(result.summary.watchers) > 0, "The night watch should be assigned when sleep begins")
	_check(float(result.summary.characters.player.comfort) > 0.0)
	_check(String(restored.phase) == "resolved")
	_check(int(restored.resources.water) == 0, "Drinking water should be consumed once for the whole party, not once per character")
	_check(String(restored.next_day_effects("player").get("fatigue_band", "")) == "rested")
	_check(restored.time_point_regeneration_multiplier("player") > 1.0, "A well-rested character should receive a modest next-day recovery bonus")
	var after_night := restored.condition_for("player")
	restored.begin_camp({"walkable": true}, ["player", "wren"])
	_check(restored.condition_for("player") == after_night, "Fatigue, hunger and thirst must persist between camp sessions")
	_check(not bool(restored.resolve_night().ok), "A resolved camp cannot resolve twice")



func _find_night_seed(ambush_limit: float, detection_limit: float, want_detected: bool) -> int:
	for seed_value in range(1, 10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var attack_roll := rng.randf()
		var detection_rolls: Array[float] = [rng.randf(), rng.randf(), rng.randf()]
		if attack_roll >= ambush_limit:
			continue
		if want_detected and detection_rolls[0] < detection_limit:
			return seed_value
		if not want_detected:
			var all_missed := true
			for detection_roll in detection_rolls:
				if detection_roll < detection_limit:
					all_missed = false
					break
			if all_missed:
				return seed_value
	return 0


func _find_shift_isolation_seed(attack_limit: float, strong_limit: float, weak_limit: float) -> int:
	for seed_value in range(1, 10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var attack_roll := rng.randf()
		var first_shift_roll := rng.randf()
		var second_shift_roll := rng.randf()
		var third_shift_roll := rng.randf()
		if attack_roll < attack_limit and first_shift_roll >= strong_limit and second_shift_roll >= weak_limit and second_shift_roll < strong_limit and third_shift_roll >= strong_limit:
			return seed_value
	return 0


func _test_night_watch_rotation_and_detection() -> void:
	var detected_camp := CampSimulation.new()
	var detected_seed := _find_night_seed(0.38, 0.42, true)
	_check(detected_seed > 0, "A deterministic seed should be available for a detected ambush test")
	detected_camp.begin_camp(
		{"walkable": true, "site_id": "watch_test"},
		["a", "b"],
		{"danger": 1.0, "night_seed": detected_seed, "companion_profiles": {
			"a": {"perception": 3.0}, "b": {"perception": 0.0}
		}},
		{}
	)
	var started := detected_camp.begin_night()
	_check(bool(started.get("ok", false)), "Night should begin before the watch schedule is generated")
	_check(detected_camp.night_watch_schedule.size() == 3, "An eight-hour night should be divided into three watch shifts")
	var first_watchers: Array = detected_camp.night_watch_schedule[0].get("watcher_ids", [])
	var second_watchers: Array = detected_camp.night_watch_schedule[1].get("watcher_ids", [])
	_check(first_watchers.size() == 1 and second_watchers.size() == 1, "A two-person party should assign one watcher per shift")
	_check(first_watchers[0] != second_watchers[0], "Two-person parties should rotate watch rather than leave one person awake all night")
	var saved := detected_camp.to_dict()
	var restored := CampSimulation.new()
	_check(restored.from_dict(saved), "The watch rotation should survive saving during the night")
	_check(restored.night_watch_schedule == detected_camp.night_watch_schedule, "The exact watch roster should be restored")
	var detected_result := restored.resolve_night()
	_check(bool(detected_result.ok), "A saved night should resolve normally")
	var detected_event: Dictionary = detected_result.summary.get("night_encounter", {})
	_check(bool(detected_event.get("attacked", false)), "The deterministic danger roll should produce an attack")
	_check(bool(detected_event.get("detected", false)), "A perceptive watcher should detect the deterministic attack")
	_check(String(detected_event.get("watcher_id", "")) == "a", "The strongest scheduled watcher should be credited with detection")
	var saved_resolved := restored.to_dict()
	var restored_resolved := CampSimulation.new()
	_check(restored_resolved.from_dict(saved_resolved), "Resolved encounter information should survive save/load")
	_check(restored_resolved.night_encounter_result == detected_event, "Loading must not reroll or duplicate a resolved night event")

	var mixed_seed := _find_shift_isolation_seed(0.38, 0.42, 0.27)
	_check(mixed_seed > 0, "A deterministic seed should isolate the weaker watch shift")
	var mixed_camp := CampSimulation.new()
	mixed_camp.begin_camp(
		{"walkable": true, "site_id": "mixed_watch_test"},
		["a", "b"],
		{"danger": 1.0, "night_seed": mixed_seed, "companion_profiles": {
			"a": {"perception": 3.0}, "b": {"perception": 0.0}
		}},
		{}
	)
	mixed_camp.begin_night()
	var mixed_result := mixed_camp.resolve_night()
	var mixed_event: Dictionary = mixed_result.summary.get("night_encounter", {})
	_check(bool(mixed_event.get("attacked", false)), "The mixed-skill deterministic roll should produce an attack")
	_check(not bool(mixed_event.get("detected", true)), "A weaker later shift must not inherit the earlier shift's higher detection chance")
	_check(is_equal_approx(float(mixed_event.get("detection_chance", 0.0)), 0.42), "The encounter should report the strongest individual shift chance")

	var short_night := CampSimulation.new()
	short_night.begin_camp({"walkable": true, "site_id": "short_watch_test"}, ["a", "b"], {"danger": 0.0}, {})
	short_night.begin_night()
	var short_result := short_night.resolve_night(6.0)
	_check(bool(short_result.get("ok", false)), "A shorter sleep duration should still resolve")
	var safe_night_event: Dictionary = short_result.get("summary", {}).get("night_encounter", {})
	_check(not bool(safe_night_event.get("attacked", true)), "A zero-danger site should not produce a night attack")
	_check(short_night.night_encounter_result == safe_night_event, "A peaceful night result should also be retained as the resolved encounter state")
	_check(is_equal_approx(float(short_night.night_watch_schedule[2].get("end_hour", 0.0)), 6.0), "Watch shift boundaries should scale to the actual sleep duration")
	var short_watch_hours := short_night._watch_hours_by_character(6.0)
	var total_short_watch_hours := 0.0
	for watched_hours in short_watch_hours.values():
		total_short_watch_hours += float(watched_hours)
	_check(is_equal_approx(total_short_watch_hours, 6.0), "Total scheduled watch hours should equal the resolved night duration")

	var missed_camp := CampSimulation.new()
	var missed_seed := _find_night_seed(0.38, 0.15, false)
	_check(missed_seed > 0, "A deterministic seed should be available for an undetected ambush test")
	missed_camp.begin_camp(
		{"walkable": true, "site_id": "missed_watch_test"},
		["a", "b"],
		{"danger": 1.0, "night_seed": missed_seed},
		{}
	)
	missed_camp.conditions["a"]["fatigue"] = 100.0
	missed_camp.conditions["b"]["fatigue"] = 100.0
	missed_camp.begin_night()
	var missed_result := missed_camp.resolve_night()
	var missed_event: Dictionary = missed_result.summary.get("night_encounter", {})
	_check(bool(missed_event.get("attacked", false)), "The second deterministic danger roll should produce an attack")
	_check(not bool(missed_event.get("detected", true)), "An exhausted novice watch should be capable of missing an attack")
	_check(not String(missed_event.get("watcher_id", "")).is_empty(), "An undetected attack should still identify the strongest watcher who tried to spot it")
	_check(float(missed_event.get("detection_chance", 1.0)) < 0.2, "Exhaustion should materially reduce detection chance")

	var world := WorldSimulation.new()
	world.player_character_id = "a"
	var watch_leader := CharacterState.new("a", "Watch Leader", Vector2i(0, 0))
	watch_leader.side = "player"
	world.register_character(watch_leader)
	watch_leader.skills["keen_perception"] = 3
	var watch_partner := CharacterState.new("b", "Watch Partner", Vector2i(1, 0))
	watch_partner.side = "player"
	world.register_character(watch_partner)
	_camp_night_events = 0
	world.camp_night_encounter_resolved.connect(_on_camp_night_encounter_resolved)
	var world_camp := world.begin_camp(
		{"walkable": true, "site_id": "world_watch_test"},
		{"danger": 1.0, "night_seed": detected_seed},
		{}
	)
	_check(bool(world_camp.get("ok", false)), "WorldSimulation should begin a camp with registered party members")
	_check(float(world.camp_simulation.companion_profiles["a"].get("perception", 0.0)) == 3.0, "WorldSimulation should pass the authored keen perception skill into camp profiles")
	world.skip_camp_to_morning()
	_check(_camp_night_events == 1, "WorldSimulation should publish a detected night attack for encounter presentation")
	world.free()


func _test_world_simulation_integration() -> void:
	var world := WorldSimulation.new()
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	var companion := CharacterState.new("wren", "Wren", Vector2i(1, 0))
	companion.side = "player"
	companion.tags.append("scholarly")
	companion.health = 50
	companion.hobbled_stacks = 1
	world.register_character(player)
	world.register_character(companion)
	var started := world.begin_camp({"walkable": true}, {"night_temperature_c": 8.0}, {"wood": 1, "rations": 2, "water": 2, "tents": 1})
	_check(bool(started.ok), "World simulation should start camp with the current party")
	_check(String(world.camp_simulation.companion_profiles.wren.personality) == "scholarly", "Authored personality tags should flow into camp routine preferences.")
	_check(bool(world.camp_simulation.companion_profiles.wren.injured), "Current health and hobbling should inform camp routine choices.")
	var social_event := world.record_companion_interaction("wren", "player", "flirt", {"attraction": 2.0}, "camp_flirt:001")
	_check(bool(social_event.get("changed", false)), "Flirting should be recordable during any camp activity")
	_check(float(world.camp_simulation.condition_for("wren").get("social_satisfaction", 0.0)) > 0.0, "Social contact should contribute to later camp comfort without requiring a socialise assignment")
	world.advance_real_time(2.0)
	_check(is_equal_approx(world.clock.world_seconds, 10.0), "Camp evening should use the ordinary 5x exploration clock")
	player.time_points = 0.0
	world.companion_bonds.set_relationship("wren", "player", {"friendship": 30})
	var saved := world.to_dict()
	var restored := WorldSimulation.new()
	restored.load_dict(saved)
	_check(String(restored.camp_simulation.phase) == "evening", "Camp state should be part of the world save")
	_check(float(restored.companion_bonds.snapshot("wren", "player").friendship) == 30.0, "Companion bonds should be part of the world save")
	var morning := restored.skip_camp_to_morning(6.0)
	_check(bool(morning.ok), "The world simulation should resolve the camp night")
	_check(is_equal_approx(restored.clock.world_seconds, 10.0 + 6.0 * WorldClock.SECONDS_PER_HOUR), "Sleeping should skip directly to morning and advance the authoritative clock by the sleep duration")
	_check(restored.get_character("player").time_points >= 149.0, "Instant sleep should bulk-apply overnight time-point recovery without simulating every 0.4-second tick")


func _test_companions_walk_to_camp_stations() -> void:
	var world := WorldSimulation.new()
	for q in range(-6, 7):
		for r in range(-6, 7):
			if HexGrid.distance(Vector2i.ZERO, Vector2i(q, r)) <= 6:
				world.map_data.add_cell(Vector2i(q, r), 0.0, true, "grass")
	var player := CharacterState.new("player", "Player", Vector2i(-4, 0))
	player.side = "player"
	var companion := CharacterState.new("wren", "Wren", Vector2i(4, 0))
	companion.side = "player"
	var second_companion := CharacterState.new("aldric", "Aldric", Vector2i(4, -1))
	second_companion.side = "player"
	world.register_character(player)
	world.register_character(companion)
	world.register_character(second_companion)
	var started := world.begin_camp({"hex": Vector2i.ZERO, "walkable": true}, {})
	_check(bool(started.get("ok", false)), "Camp should start before companions are routed")
	var probe := CampActivityProbe.new()
	var second_probe := CampActivityProbe.new()
	_camp_actor_probes["wren"] = probe
	_camp_actor_probes["aldric"] = second_probe
	var director := CampPartyActivityDirector.new()
	director.configure(world, Callable(self, "_camp_actor_for_id"))
	director.begin_camp(world.camp_simulation.site)
	_check(director.is_running(), "A companion away from camp should receive a visible approach route")
	var initial_distance := HexGrid.distance(companion.axial, Vector2i.ZERO)
	var second_initial_distance := HexGrid.distance(second_companion.axial, Vector2i.ZERO)
	for _step in range(20):
		director.process_activity_movement(0.7)
	_check(HexGrid.distance(companion.axial, Vector2i.ZERO) < initial_distance, "Companion should physically move towards their camp station")
	_check(HexGrid.distance(second_companion.axial, Vector2i.ZERO) < second_initial_distance, "A second companion should move on the same camp movement cadence")
	_check(probe.activity_count > 0, "A companion should start an Ara activity after reaching their station")
	_check(second_probe.activity_count > 0, "A second companion should also start an Ara activity after reaching their station")
	_check(probe.last_activity == "socialise", "The animation should match the companion's assigned camp routine")
	_check(player.axial == Vector2i(-4, 0), "The player should remain under direct movement control")
	var reassigned := world.camp_simulation.assign_activity("wren", "watch")
	_check(bool(reassigned.get("ok", false)), "A companion's camp assignment can change during the evening")
	for _step in range(20):
		director.process_activity_movement(0.7)
	_check(probe.last_activity == "watch", "The director should update the companion's station and Ara routine after reassignment")
	director.stop()
	_check(not director.is_running(), "Packing or sleeping should be able to stop autonomous camp movement")
	director.free()
	_camp_actor_probes.clear()


func _test_world_weather_state_and_camp_integration() -> void:
	var weather := WorldWeatherState.new(12345)
	var sample_time := float((6 * 30 + 15) * WorldClock.SECONDS_PER_DAY + 14 * WorldClock.SECONDS_PER_HOUR)
	var first := weather.conditions_at(sample_time)
	var second := WorldWeatherState.new(12345).conditions_at(sample_time)
	_check(first == second, "Weather should be deterministic for a campaign seed and world time.")
	var summer_time := float((2 * 30 + 15) * WorldClock.SECONDS_PER_DAY + 14 * WorldClock.SECONDS_PER_HOUR)
	var winter_time := float((9 * 30 + 15) * WorldClock.SECONDS_PER_DAY + 14 * WorldClock.SECONDS_PER_HOUR)
	var summer := weather.conditions_at(summer_time)
	var winter := weather.conditions_at(winter_time)
	_check(float(summer.temperature_c) > float(winter.temperature_c), "The existing seasonal calendar should drive warmer summer and colder winter weather.")
	var open_weather := weather.conditions_at(sample_time, "grass")
	var forest_weather := weather.conditions_at(sample_time, "forest")
	_check(float(forest_weather.wind_speed) < float(open_weather.wind_speed), "Forest cover should reduce the wind companions experience at camp.")
	_check(bool(weather.update_to(0.0)), "Weather should initialise its first three-hour period.")
	_check(not weather.update_to(10.0), "Weather should not reroll within the same three-hour period.")
	_check(bool(weather.update_to(WorldWeatherState.WEATHER_PERIOD_SECONDS)), "Weather should advance at a three-hour boundary.")

	var world := WorldSimulation.new()
	world.weather_state = WorldWeatherState.new(24680)
	world.clock.set_world_seconds(WorldWeatherState.WEATHER_PERIOD_SECONDS - 1.0)
	world.weather_state.update_to(world.clock.world_seconds)
	var player := CharacterState.new("player", "Player")
	var companion := CharacterState.new("wren", "Wren", Vector2i(1, 0))
	companion.side = "player"
	world.register_character(player)
	world.register_character(companion)
	var started := world.begin_camp({"walkable": true, "terrain_id": "forest"}, {}, {"wood": 1, "rations": 2, "water": 2})
	_check(bool(started.get("ok", false)), "Camp should start with weather supplied by the world simulation.")
	var expected_start := world.weather_state.conditions_at(world.clock.world_seconds, "forest")
	_check(String(world.camp_simulation.environment.weather_type) == String(expected_start.weather_type), "Camp should receive the current world weather rather than a hard-coded temperature.")
	world.advance_real_time(1.0)
	var expected_after_transition := world.weather_state.conditions_at(world.clock.world_seconds, "forest")
	_check(String(world.camp_simulation.environment.weather_type) == String(expected_after_transition.weather_type), "An active camp should receive weather changes as the world clock crosses a weather period.")
	var saved := world.to_dict()
	var restored := WorldSimulation.new()
	restored.load_dict(saved)
	_check(restored.weather_state.seed == world.weather_state.seed, "The campaign weather seed should persist through save and restore.")
	_check(restored.weather_state.conditions_at(restored.clock.world_seconds) == world.weather_state.conditions_at(world.clock.world_seconds), "Weather should reproduce the same conditions after loading a save.")

	var exposed := CampSimulation.new()
	exposed.begin_camp(
		{"walkable": true},
		["scholar"],
		{"companion_profiles": {"scholar": {"personality": "scholarly"}}},
		{"wood": 1, "rations": 1}
	)
	exposed.advance_real_time(24.0)
	_check(String(exposed.assignments.scholar.activity) == "study_map", "A clear exposed camp should allow a scholarly companion to study.")
	exposed.update_weather({"storm": true, "heavy_rain": true, "wind_speed": 62.0, "rain_intensity": 0.9, "night_temperature_c": 8.0})
	_check(String(exposed.assignments.scholar.activity) == "socialise", "A new storm should move companions away from exposed activities.")
	var sheltered := CampSimulation.new()
	sheltered.begin_camp(
		{"walkable": true, "dwelling_profile": {"dwelling_id": "silverhart_manor", "layout_id": "silverhart_manor_livable", "sleeping_capacity": 8}},
		["scholar"],
		{"storm": true, "heavy_rain": true, "wind_speed": 62.0, "rain_intensity": 0.9, "night_temperature_c": 8.0, "companion_profiles": {"scholar": {"personality": "scholarly"}}},
		{"wood": 1, "rations": 1}
	)
	sheltered.advance_real_time(24.0)
	_check(String(sheltered.assignments.scholar.activity) == "study_map", "A sheltered manor should retain suitable indoor activities during a storm.")


func _test_dwelling_station_presentation() -> void:
	var manor_presenter := CampWorldPresentation.new()
	get_root().add_child(manor_presenter)
	manor_presenter.present_camp(
		{
			"hex": Vector2i.ZERO,
			"position": Vector3.ZERO,
			"dwelling_profile": {
				"dwelling_id": "silverhart_manor",
				"layout_id": "silverhart_manor_livable",
				"sleeping_capacity": 0,
				"is_sheltered": true,
				"placed_furniture": []
			}
		},
		[],
		{"fire_lit": true}
	)
	_check(manor_presenter.has_node("InWorldCampsite/DwellingStations/DwellingStation_hearth"), "An unfurnished manor should retain invisible routine anchors for future indoor activity navigation.")
	_check(not manor_presenter.has_node("InWorldCampsite/DwellingStations/DwellingStation_hearth/HearthStoneBase"), "A newly acquired manor should not receive a free hearth furnishing.")
	_check(not manor_presenter.has_node("InWorldCampsite/DwellingStations/DwellingStation_study/StudyDeskTop"), "A newly acquired manor should not receive a free study desk.")
	_check(not manor_presenter.has_node("InWorldCampsite/DwellingStations/DwellingStation_workshop/WorkshopBenchTop"), "A newly acquired manor should not receive a free workshop bench.")
	_check(not manor_presenter.has_node("InWorldCampsite/FireRingStone_00"), "A livable dwelling should not be dressed as a wilderness fire circle.")
	var manor_nameplate := manor_presenter.get_node_or_null("InWorldCampsite/CampNameplate") as Label3D
	_check(manor_nameplate != null and manor_nameplate.text == "SILVERHART MANOR", "The dwelling should identify itself as the party's home.")
	var wilderness_presenter := CampWorldPresentation.new()
	get_root().add_child(wilderness_presenter)
	wilderness_presenter.present_camp({"hex": Vector2i.ZERO, "position": Vector3(20.0, 0.0, 0.0)}, [], {"fire_lit": true})
	_check(wilderness_presenter.has_node("InWorldCampsite/FireRingStone_00"), "A wilderness camp should retain its exposed fire ring.")
	_check(wilderness_presenter.has_node("InWorldCampsite/CampfireLight"), "A lit wilderness camp should show its campfire light.")
	_check(not wilderness_presenter.has_node("InWorldCampsite/DwellingStations"), "A wilderness camp should not receive permanent dwelling furniture.")


func _test_ara_camp_animation_mapping() -> void:
	var social_hints := AraCharacterActor.camp_activity_animation_hints("socialise")
	var watch_hints := AraCharacterActor.camp_activity_animation_hints("watch")
	var sleep_hints := AraCharacterActor.camp_activity_animation_hints("sleep")
	var study_hints := AraCharacterActor.camp_activity_animation_hints("study_map")
	var horse_water_hints := AraCharacterActor.camp_activity_animation_hints("care_horse_water")
	var horse_groom_hints := AraCharacterActor.camp_activity_animation_hints("care_horse_groom")
	_check(social_hints.has("talk"), "Social camp duty should use Ara's available Talk animation")
	_check(watch_hints.has("idle"), "Night watch should use Ara's available Idle animation")
	_check(sleep_hints.has("sleep"), "Sleep should use Ara's sleep animation")
	_check(study_hints.has("use_press"), "Map study should use Ara's seated idle animation")
	_check(horse_water_hints.has("pick_up"), "Horse watering should use Ara pickup/carry animation")
	_check(horse_groom_hints.has("use_press"), "Horse grooming should use Ara interaction animation")


func _test_dwelling_layout_station_selection() -> void:
	var world := WorldSimulation.new()
	for q in range(-5, 6):
		for r in range(-5, 6):
			var hex := Vector2i(q, r)
			if HexGrid.distance(Vector2i.ZERO, hex) <= 5:
				world.map_data.add_cell(hex, 0.0, true, "grass")
	var player := CharacterState.new("player", "Player", Vector2i(-4, 0))
	player.side = "player"
	var companion := CharacterState.new("wren", "Wren", Vector2i(4, 0))
	companion.side = "player"
	world.register_character(player)
	world.register_character(companion)
	var director := CampPartyActivityDirector.new()
	director.configure(world)
	director.begin_camp({
		"hex": Vector2i.ZERO, "walkable": true,
		"dwelling_profile": {"layout_id": "cottage_one_room"}
	})
	var cottage_study := director._choose_station("study_map", {}, "wren")
	_check(cottage_study == Vector2i(-1, 0), "A one-room cottage should use its shared common area when it has no separate study.")
	director.begin_camp({
		"hex": Vector2i.ZERO, "walkable": true,
		"dwelling_profile": {"layout_id": "country_house_three_room"}
	})
	var country_study := director._choose_station("study_map", {}, "wren")
	_check(country_study == Vector2i(-1, 1), "A larger house should route map study to its dedicated study station.")
	var country_cooking := director._choose_station("cook", {}, "wren")
	_check(country_cooking == Vector2i(1, 0), "Cooking should gather at the hearth rather than the study or common room.")
	director.stop()
	director.free()



func _test_evening_routine_progression() -> void:
	var camp := CampSimulation.new()
	camp.begin_camp(
		{"walkable": true},
		["scholar", "guardian", "injured"],
		{"companion_profiles": {
			"scholar": {"personality": "scholarly", "role": "mage", "fatigue": 10.0},
			"guardian": {"personality": "guardian", "role": "fighter", "fatigue": 85.0},
			"injured": {"personality": "practical", "role": "fighter", "injured": true, "fatigue": 20.0}
		}, "night_temperature_c": 8.0},
		{"wood": 2, "rations": 3, "water": 3, "repair_kits": 1}
	)
	var initial_assignments := camp.assignments.duplicate(true)
	camp.assign_activity("scholar", "train")
	camp.assignments["scholar"]["override_remaining"] = 30.0
	camp.advance_real_time(24.0)
	_check(camp.routine_stage == 1, "The camp should move from setup into the main evening routine after 120 world seconds.")
	_check(String(camp.assignments.scholar.activity) == "train" and bool(camp.assignments.scholar.player_override), "A player-directed activity should survive an autonomous routine transition.")
	camp.advance_real_time(10.0)
	_check(String(camp.assignments.scholar.activity) == "study_map", "When the player override expires, the companion should resume the current routine rather than the stale setup task.")
	_check(float(camp.condition_for("scholar").fatigue) > 44.5, "Strenuous player-directed activity should accumulate fatigue during the evening.")
	_check(String(camp.assignments.guardian.activity) == "socialise", "A fatigued companion should avoid strenuous evening duties.")
	_check(String(camp.assignments.injured.activity) == "repair_gear", "An injured companion with a repair kit should favour gear maintenance over strenuous training.")
	camp.advance_real_time(38.0)
	_check(camp.routine_stage == 2, "The camp should enter its late-evening wind-down after 360 world seconds.")
	_check(String(camp.assignments.guardian.activity) == "socialise", "The late routine should retain quiet activities for exhausted companions.")
	var saved := camp.to_dict()
	var restored := CampSimulation.new()
	_check(restored.from_dict(saved), "Routine stage and companion profiles should restore from a save.")
	_check(restored.routine_stage == 2, "A loaded camp should resume at its saved evening stage.")
	_check(restored.companion_profiles == camp.companion_profiles, "Companion routine preferences should persist.")
	_check(initial_assignments.size() == camp.party_ids.size(), "Every companion should receive an initial setup assignment.")
	var exposed := CampSimulation.new()
	exposed.begin_camp(
		{"walkable": true},
		["scholar"],
		{"storm": true, "companion_profiles": {"scholar": {"personality": "scholarly"}}},
		{"wood": 1, "water": 1}
	)
	exposed.advance_real_time(24.0)
	_check(String(exposed.assignments.scholar.activity) == "socialise", "A wilderness camp in a storm should draw companions away from exposed study routines.")
	var sheltered := CampSimulation.new()
	sheltered.begin_camp(
		{"walkable": true, "dwelling_profile": {"dwelling_id": "manor", "sleeping_capacity": 1}},
		["scholar"],
		{"storm": true, "companion_profiles": {"scholar": {"personality": "scholarly"}}},
		{"wood": 1, "water": 1}
	)
	sheltered.advance_real_time(24.0)
	_check(String(sheltered.assignments.scholar.activity) == "study_map", "A livable dwelling should let a scholarly companion continue an indoor routine during a storm.")



func _test_livable_dwelling_avoids_unneeded_tent_setup() -> void:
	var camp := CampSimulation.new()
	camp.begin_camp(
		{"walkable": true, "dwelling_profile": {"dwelling_id": "silverhart_manor", "layout_id": "silverhart_manor_livable", "sleeping_capacity": 6}},
		["player", "wren", "aldric"],
		{"night_temperature_c": 5.0},
		{"wood": 2, "rations": 3, "water": 3, "tents": 2}
	)
	_check(not camp._has_activity("set_up_tents"), "A livable dwelling with enough indoor beds should not send companions to pitch redundant tents.")
	_check(camp.plan_sleeping_arrangements(2).size() == 3, "The party should be allocated indoor beds before outdoor tents.")
