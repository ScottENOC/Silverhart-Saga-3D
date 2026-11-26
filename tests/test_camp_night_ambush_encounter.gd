extends SceneTree

const ENCOUNTER = preload("res://scripts/simulation/camp_night_ambush_encounter.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_detected_ambush_starts_without_surprise_penalty()
	_test_undetected_ambush_applies_explicit_initiative_penalty()
	_test_victory_cleans_up_wolves_and_ends_combat()
	_test_party_defeat_resolves_and_cleans_up_wolves()
	_test_ending_interrupted_sleep_advances_to_dawn_and_releases_guest()
	if _failures > 0:
		push_error("%d camp night ambush assertion(s) failed." % _failures)
		quit(1)
		return
	print("Camp night ambush encounter tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _new_simulation() -> WorldSimulation:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	player.side = "player"
	player.time_points = 100.0
	var companion := CharacterState.new("companion", "Companion", Vector2i(1, 0))
	companion.side = "player"
	companion.time_points = 100.0
	simulation.register_character(player)
	simulation.register_character(companion)
	simulation.camp_simulation.night_index = 1
	return simulation


func _start(simulation: WorldSimulation, detected: bool) -> Dictionary:
	var party_ids: Array[String] = ["player", "companion"]
	var spawn_hexes: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0)]
	return ENCOUNTER.start(simulation, party_ids, spawn_hexes, detected)


func _test_detected_ambush_starts_without_surprise_penalty() -> void:
	var simulation := _new_simulation()
	var started := _start(simulation, true)
	_check(bool(started.get("ok", false)), "A detected night ambush should start.")
	_check(simulation.is_in_combat, "A detected ambush should enter the shared combat runtime.")
	_check(simulation.get_character("player").time_points == 100.0, "A detected ambush should not penalise player initiative.")
	_check(simulation.get_character("companion").time_points == 100.0, "A detected ambush should not penalise companion initiative.")
	_check(started.get("enemy_ids", []).size() == 2, "A night ambush should register two authored wolf combatants.")
	_check(simulation.get_character(String(started.enemy_ids[0])).race == "animal", "Night wolves should use the canonical animal character profile.")
	simulation.free()


func _test_undetected_ambush_applies_explicit_initiative_penalty() -> void:
	var simulation := _new_simulation()
	var started := _start(simulation, false)
	_check(bool(started.get("ok", false)), "An undetected night ambush should start.")
	_check(is_equal_approx(simulation.get_character("player").time_points, 80.0), "An undetected ambush should apply the explicit 20 TP surprise penalty.")
	_check(is_equal_approx(simulation.get_character("companion").time_points, 80.0), "The surprise penalty should apply consistently to the party.")
	_check(float(started.get("surprise_time_point_penalty", 0.0)) == 20.0, "The encounter result should report its explicit surprise modifier.")
	simulation.free()


func _test_victory_cleans_up_wolves_and_ends_combat() -> void:
	var simulation := _new_simulation()
	var started := _start(simulation, true)
	_check(bool(started.get("ok", false)), "The victory test encounter should start.")
	for enemy_id_value in started.get("enemy_ids", []):
		var enemy := simulation.get_character(String(enemy_id_value))
		enemy.alive = false
		enemy.health = 0
	var party_ids: Array[String] = ["player", "companion"]
	var result: Dictionary = ENCOUNTER.resolve_combat(simulation, simulation.campaign_journal, party_ids, started)
	_check(bool(result.get("resolved", false)) and String(result.get("outcome", "")) == "victory", "Defeating all night wolves should resolve as victory.")
	_check(not simulation.is_in_combat, "Night ambush victory should end shared combat.")
	_check(simulation.get_character(String(started.enemy_ids[0])) == null, "Resolved night wolves should be removed from authoritative simulation state.")
	_check(result.get("remove_actor_ids", []).size() == 2, "The presenter should receive cleanup requests for both wolf actors.")
	simulation.free()


func _test_ending_interrupted_sleep_advances_to_dawn_and_releases_guest() -> void:
	var simulation := _new_simulation()
	simulation.clock.set_world_seconds(25.0 * WorldClock.SECONDS_PER_HOUR)
	simulation.camp_simulation.begin_camp({"walkable": true}, ["player", "companion"], {}, {})
	var guest := {
		"occupant_id": "rowan_fletcher", "kind": "guest", "species": "humanoid",
		"participates_in_party": false, "can_sleep": true, "can_work": false,
		"staying_overnight": true, "leaves_at_dawn": true
	}
	_check(bool(simulation.camp_simulation.register_camp_occupant(guest).get("ok", false)), "The overnight guest should register before an interrupted night.")
	simulation.camp_simulation.phase = "interrupted"
	simulation.camp_simulation.night_planned_hours = 8.0
	simulation.camp_simulation.night_elapsed_hours = 3.0
	var finished := simulation.finish_interrupted_camp_night()
	_check(bool(finished.get("ok", false)), "Ending an interrupted night should succeed outside combat.")
	_check(is_equal_approx(simulation.clock.world_seconds, 30.0 * WorldClock.SECONDS_PER_HOUR), "Ending interrupted sleep should advance the remaining night hours to dawn without granting sleep recovery.")
	_check(not simulation.camp_simulation.occupants.has("rowan_fletcher"), "A guest marked to leave at dawn should depart when the interrupted night is ended.")
	_check(String(simulation.camp_simulation.phase) == "resolved", "The camp should be ready to pack after the night ends.")
	simulation.free()


func _test_party_defeat_resolves_and_cleans_up_wolves() -> void:
	var simulation := _new_simulation()
	var started := _start(simulation, true)
	_check(bool(started.get("ok", false)), "The defeat test encounter should start.")
	for party_id in ["player", "companion"]:
		var member := simulation.get_character(party_id)
		member.alive = false
		member.health = 0
	var party_ids: Array[String] = ["player", "companion"]
	var result: Dictionary = ENCOUNTER.resolve_combat(simulation, simulation.campaign_journal, party_ids, started)
	_check(bool(result.get("resolved", false)) and String(result.get("outcome", "")) == "defeat", "Losing the whole party should resolve the ambush as a defeat.")
	_check(not simulation.is_in_combat, "Night ambush defeat should end shared combat cleanly.")
	_check(result.get("remove_actor_ids", []).size() == 2, "Retreating wolves should be removed after defeating the party.")
	simulation.free()
