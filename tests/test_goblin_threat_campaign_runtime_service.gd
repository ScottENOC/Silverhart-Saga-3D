extends SceneTree

const RUNTIME_SERVICE = preload("res://scripts/simulation/goblin_threat_campaign_runtime_service.gd")
const SIMULATION_SCRIPT = preload("res://scripts/simulation/world_simulation.gd")
const CHARACTER_SCRIPT = preload("res://scripts/simulation/character_state.gd")
const RELATIONSHIP_SCRIPT = preload("res://scripts/simulation/persistent_character_relationship_state.gd")

const ALDRIC_ID := "ser_aldric_thorne"
var _failures: int = 0


func _initialize() -> void:
	_test_chief_gift_is_paid_once()
	_test_favour_effects_reach_campaign_state()
	_test_alliance_rescues_aldric_and_completes_his_quest()
	_test_scout_note_is_a_one_time_world_effect()
	if _failures > 0:
		push_error("%d Skarn-tooth runtime assertion(s) failed." % _failures)
		quit(1)
		return
	print("Skarn-tooth runtime tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _simulation() -> WorldSimulation:
	var simulation := SIMULATION_SCRIPT.new()
	var player := CHARACTER_SCRIPT.new("player", "Player")
	player.side = "player"
	player.gold = 100
	simulation.register_character(player)
	var aldric := CHARACTER_SCRIPT.new(ALDRIC_ID, "Ser Aldric Thorne")
	aldric.side = "enemy"
	aldric.axial = Vector2i(1, 0)
	simulation.register_character(aldric)
	return simulation


func _test_chief_gift_is_paid_once() -> void:
	var simulation := _simulation()
	var relationships := RELATIONSHIP_SCRIPT.new()
	var first := RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
	_check(bool(first.get("ok", false)))
	_check(simulation.get_character("player").gold == 40, "The chief's gift must deduct 60 actual player gold")
	var repeated := RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
	_check(not bool(repeated.get("ok", true)))
	_check(simulation.get_character("player").gold == 40, "A repeated gift must not spend gold twice")


func _test_favour_effects_reach_campaign_state() -> void:
	var simulation := _simulation()
	var first := RUNTIME_SERVICE.resolve_favour(simulation, "raid_mine")
	_check(bool(first.get("ok", false)))
	_check(bool(first.get("world_effects", {}).get("ok", false)))
	_check(simulation.get_character("player").gold == 160, "The Emberlode raid should award its 60-gold strongbox")
	_check(simulation.get_character("player").experience == 50)
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("emberlode").get("security", 0.0)), -20.0))
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("emberlode").get("prosperity", 0.0)), -25.0))
	_check(bool(simulation.campaign_journal.world_campaign_flag("emberlode_raided", false)))
	var repeated := RUNTIME_SERVICE.resolve_favour(simulation, "raid_mine")
	_check(bool(repeated.get("ok", false)) and not bool(repeated.get("applied", true)))
	_check(simulation.get_character("player").gold == 160, "The mine raid reward cannot be farmed")


func _test_alliance_rescues_aldric_and_completes_his_quest() -> void:
	var simulation := _simulation()
	var relationships := RELATIONSHIP_SCRIPT.new()
	var gift := RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
	_check(bool(gift.get("ok", false)))
	var alliance := RUNTIME_SERVICE.resolve_threat(simulation, "goblin_alliance", relationships)
	_check(bool(alliance.get("ok", false)))
	_check(bool(alliance.get("world_effects", {}).get("ok", false)))
	_check(String(simulation.campaign_journal.quest_state("goblin_threat").get("status", "")) == "completed")
	_check(String(simulation.campaign_journal.quest_state("aldric_rescue").get("status", "")) == "completed")
	_check(bool(simulation.campaign_journal.world_campaign_flag("aldric_rescued", false)))
	_check(simulation.get_character(ALDRIC_ID).side == "neutral")
	_check(simulation.get_character("player").experience == 100)
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("hollowmere").get("security", 0.0)), -10.0))


func _test_scout_note_is_a_one_time_world_effect() -> void:
	var simulation := _simulation()
	var first := RUNTIME_SERVICE.read_scout_note(simulation)
	_check(bool(first.get("ok", false)))
	_check(bool(simulation.campaign_journal.world_campaign_flag("goblin_scout_note_read", false)))
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("hollowmere").get("security", 0.0)), -3.0))
	var repeated := RUNTIME_SERVICE.read_scout_note(simulation)
	_check(bool(repeated.get("ok", false)) and bool(repeated.get("already_read", false)))
	_check(is_equal_approx(float(simulation.campaign_journal.region_campaign_state("hollowmere").get("security", 0.0)), -3.0))
