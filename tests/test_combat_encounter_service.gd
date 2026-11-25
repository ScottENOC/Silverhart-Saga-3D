extends SceneTree

const ENCOUNTER_SERVICE = preload("res://scripts/simulation/combat_encounter_service.gd")
const DIRE_WOLF_ENCOUNTER = preload("res://scripts/simulation/farmstead_dire_wolf_encounter.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_begin_and_restore_all_participants()
	_test_reject_invalid_rosters_without_mutation()
	_test_dire_wolf_domain_uses_shared_lifecycle()
	if _failures > 0:
		push_error("%d combat encounter service assertion(s) failed." % _failures)
		quit(1)
		return
	print("Combat encounter service tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_begin_and_restore_all_participants() -> void:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	player.side = "player"
	player.combat_dormant = false
	var companion := CharacterState.new("companion", "Companion", Vector2i(1, 0))
	companion.side = "neutral"
	companion.combat_dormant = true
	var wolf := CharacterState.new("wolf", "Wolf", Vector2i(2, 0))
	wolf.side = "enemy"
	wolf.combat_dormant = true
	var bystander := CharacterState.new("bystander", "Bystander", Vector2i(3, 0))
	bystander.side = "neutral"
	bystander.combat_dormant = false
	simulation.register_character(player)
	simulation.register_character(companion)
	simulation.register_character(wolf)
	simulation.register_character(bystander)

	var result: Dictionary = ENCOUNTER_SERVICE.begin(simulation, ["player", "companion"], ["wolf"])
	_check(bool(result.get("ok", false)), "A valid encounter roster should start.")
	_check(simulation.is_in_combat, "Beginning an encounter should start simulation combat.")
	_check(player.side == "player" and not player.combat_dormant, "Party members should be active on the player side.")
	_check(companion.side == "player" and not companion.combat_dormant, "Neutral companions should join the player side.")
	_check(wolf.side == "enemy" and not wolf.combat_dormant, "Enemies should be active on the enemy side.")
	_check(bystander.combat_dormant, "Non-participants should be dormant during the encounter.")

	var finish_result: Dictionary = ENCOUNTER_SERVICE.finish(simulation, result.get("session", {}))
	_check(bool(finish_result.get("ok", false)), "A valid encounter session should finish.")
	_check(not simulation.is_in_combat, "Finishing an encounter should end simulation combat.")
	_check(player.side == "player" and not player.combat_dormant, "The player's original state should be restored.")
	_check(companion.side == "neutral" and companion.combat_dormant, "A companion's original state should be restored.")
	_check(wolf.side == "enemy" and wolf.combat_dormant, "An enemy's original state should be restored.")
	_check(bystander.side == "neutral" and not bystander.combat_dormant, "Unrelated characters should not remain dormant after combat.")
	simulation.free()


func _test_reject_invalid_rosters_without_mutation() -> void:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	simulation.register_character(player)
	var missing_enemy: Dictionary = ENCOUNTER_SERVICE.begin(simulation, ["player"], ["missing"])
	_check(not bool(missing_enemy.get("ok", false)), "An encounter with a missing enemy should be rejected.")
	_check(not simulation.is_in_combat, "A rejected roster must not start combat.")
	_check(not player.combat_dormant, "A rejected roster must not mutate participant state.")
	var duplicate: Dictionary = ENCOUNTER_SERVICE.begin(simulation, ["player"], ["player"])
	_check(not bool(duplicate.get("ok", false)), "A participant cannot be on both sides.")
	_check(not simulation.is_in_combat, "A duplicate roster must not start combat.")
	simulation.free()

func _test_dire_wolf_domain_uses_shared_lifecycle() -> void:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	player.side = "player"
	var bystander := CharacterState.new("bystander", "Bystander", Vector2i(1, 0))
	bystander.combat_dormant = false
	simulation.register_character(player)
	simulation.register_character(bystander)
	var created: Dictionary = DIRE_WOLF_ENCOUNTER.create_dire_wolf(simulation, Vector2i(2, 0))
	_check(bool(created.get("ok", false)), "The dire wolf encounter should create its authored enemy.")
	var started: Dictionary = DIRE_WOLF_ENCOUNTER.start(simulation, ["player"])
	_check(bool(started.get("ok", false)), "The dire wolf encounter should start through the shared lifecycle.")
	_check(simulation.is_in_combat, "The dire wolf encounter should activate WorldSimulation combat.")
	_check(bystander.combat_dormant, "The shared lifecycle should suspend unrelated characters during the hunt.")
	DIRE_WOLF_ENCOUNTER.finish(simulation, ["player"], started.get("previous_states", {}))
	_check(not simulation.is_in_combat, "Finishing the dire wolf encounter should end combat.")
	_check(not bystander.combat_dormant, "The dire wolf encounter should restore unrelated characters afterwards.")
	simulation.free()
