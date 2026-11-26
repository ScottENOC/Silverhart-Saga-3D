extends SceneTree

const TOLL_CONTENT = preload("res://scripts/simulation/toll_taker_quest_content.gd")
const TOLL_ENCOUNTER = preload("res://scripts/simulation/toll_taker_quest_encounter.gd")

var _failures := 0


func _initialize() -> void:
	_test_authored_world_placement()
	_test_ogre_actor_state_and_save_record()
	_test_encounter_victory_and_retreat()
	if _failures > 0:
		push_error("%d Toll-Taker world integration assertion(s) failed." % _failures)
		quit(1)
		return
	print("Toll-Taker world integration tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_authored_world_placement() -> void:
	_check(
		TOLL_ENCOUNTER.OGRE_HEX == Vector2i(26, -168),
		"The ogre must retain the source builder's +12 q, +8 r offset from the abandoned house"
	)


func _test_ogre_actor_state_and_save_record() -> void:
	var simulation := WorldSimulation.new()
	var created := TOLL_ENCOUNTER.ensure_ogre(simulation)
	_check(bool(created.get("ok", false)) and bool(created.get("created", false)))
	var ogre := simulation.get_character(TOLL_ENCOUNTER.OGRE_ID)
	_check(ogre != null)
	_check(ogre.axial == TOLL_ENCOUNTER.OGRE_HEX)
	_check(ogre.race == "ogre" and ogre.tags.has("toll_taker_ogre"))
	_check(ogre.alive and ogre.combat_dormant and ogre.side == "enemy")
	var repeated := TOLL_ENCOUNTER.ensure_ogre(simulation)
	_check(bool(repeated.get("ok", false)) and not bool(repeated.get("created", true)))
	var records := TOLL_ENCOUNTER.dynamic_character_records(simulation)
	_check(records.has(TOLL_ENCOUNTER.OGRE_ID))
	var restored := CharacterState.from_dict(records[TOLL_ENCOUNTER.OGRE_ID])
	_check(restored != null and restored.id == TOLL_ENCOUNTER.OGRE_ID)
	_check(restored.axial == TOLL_ENCOUNTER.OGRE_HEX and restored.health == ogre.health)


func _test_encounter_victory_and_retreat() -> void:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	simulation.register_character(player)
	var journal := simulation.campaign_journal
	TOLL_CONTENT.register_definition(journal)
	TOLL_CONTENT.accept(journal)
	TOLL_ENCOUNTER.ensure_ogre(simulation)
	var started := TOLL_ENCOUNTER.start_encounter(simulation, ["player"])
	_check(bool(started.get("ok", false)))
	_check(simulation.is_in_combat)
	var ogre := simulation.get_character(TOLL_ENCOUNTER.OGRE_ID)
	ogre.health = 0
	ogre.alive = false
	var victory := TOLL_ENCOUNTER.resolve_combat(simulation, journal, ["player"], started.session)
	_check(bool(victory.get("ok", false)) and bool(victory.get("resolved", false)))
	_check(String(victory.get("outcome", "")) == "victory")
	_check(not simulation.is_in_combat)
	var objective: Dictionary = journal.quest_state(TOLL_CONTENT.QUEST_ID).get("objectives", {}).get(TOLL_CONTENT.OBJECTIVE_ID, {})
	_check(bool(objective.get("completed", false)), "Ogre defeat must complete the Petra quest objective")
	_check(not TOLL_ENCOUNTER.is_alive(simulation))

	var second_simulation := WorldSimulation.new()
	var second_player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	second_simulation.register_character(second_player)
	TOLL_ENCOUNTER.ensure_ogre(second_simulation)
	var second_start := TOLL_ENCOUNTER.start_encounter(second_simulation, ["player"])
	_check(bool(second_start.get("ok", false)))
	second_player.health = 0
	second_player.alive = false
	var retreat := TOLL_ENCOUNTER.resolve_combat(second_simulation, second_simulation.campaign_journal, ["player"], second_start.session)
	_check(bool(retreat.get("resolved", false)) and String(retreat.get("outcome", "")) == "defeat")
	_check(TOLL_ENCOUNTER.is_alive(second_simulation), "The ogre must survive a party retreat")
