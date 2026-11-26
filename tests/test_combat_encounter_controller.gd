extends SceneTree

const COMBAT_ENCOUNTER_CONTROLLER = preload("res://scripts/presentation/combat_encounter_controller.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_encounter_roster_lifecycle()
	if _failures > 0:
		push_error("%d shared encounter controller assertion(s) failed." % _failures)
		quit(1)
		return
	print("Shared encounter controller tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_encounter_roster_lifecycle() -> void:
	var controller := COMBAT_ENCOUNTER_CONTROLLER.new() as CombatEncounterController
	var first_enemies: Array[String] = ["wolf_a"]
	var first_party: Array[String] = ["player", "companion"]
	var controlled: Array[String] = ["player", "companion"]
	controller.begin_encounter(first_enemies, first_party, controlled)
	_check(controller.active, "Controller should become active for a configured encounter.")
	_check(controller.enemy_ids == first_enemies, "Controller should retain the encounter enemy roster.")
	_check(controller.party_ids == first_party, "Controller should retain the encounter party roster.")
	_check(controller.player_controlled_ids == controlled, "Controller should retain the player-control roster.")
	controller.end_encounter()
	_check(not controller.active, "Controller should deactivate when an encounter ends.")
	_check(controller.enemy_ids.is_empty() and controller.party_ids.is_empty(), "Ending an encounter should clear both participant rosters.")
	_check(controller.player_controlled_ids.is_empty(), "Ending an encounter should clear player-control policy.")
	var second_enemies: Array[String] = ["bandit"]
	var second_party: Array[String] = ["player"]
	var second_controlled: Array[String] = ["player"]
	controller.begin_encounter(second_enemies, second_party, second_controlled)
	_check(controller.enemy_ids == second_enemies and controller.party_ids == second_party, "A new encounter should not inherit the previous encounter roster.")
	controller.end_encounter()
