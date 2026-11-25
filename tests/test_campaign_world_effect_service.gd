extends SceneTree

const JOURNAL_SCRIPT = preload("res://scripts/simulation/campaign_journal.gd")
const WORLD_EFFECT_SERVICE = preload("res://scripts/simulation/campaign_world_effect_service.gd")
const SIMULATION_SCRIPT = preload("res://scripts/simulation/world_simulation.gd")
const CHARACTER_SCRIPT = preload("res://scripts/simulation/character_state.gd")

const QUEST_ID := "goblin_effect_test"
const ALDRIC_ID := "ser_aldric_thorne"

var _failures: int = 0


func _initialize() -> void:
	_test_effects_apply_and_persist_once()
	_test_invalid_effects_have_no_side_effects()
	_test_recruited_aldric_can_depart_on_betrayal()
	if _failures > 0:
		push_error("%d campaign world effect assertion(s) failed." % _failures)
		quit(1)
		return
	print("Campaign world effect tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _journal_with_decision() -> CampaignJournal:
	var journal := JOURNAL_SCRIPT.new()
	journal.register_quest_definition({"id": QUEST_ID, "title": "Effect test", "objectives": []})
	journal.start_quest(QUEST_ID)
	journal.record_decision(QUEST_ID, "resolution", "goblin_diplomacy")
	return journal


func _simulation_with_player_and_aldric() -> WorldSimulation:
	var simulation := SIMULATION_SCRIPT.new()
	var player := CHARACTER_SCRIPT.new("player", "Player")
	player.side = "player"
	player.gold = 20
	simulation.register_character(player)
	var aldric := CHARACTER_SCRIPT.new(ALDRIC_ID, "Ser Aldric Thorne")
	aldric.side = "enemy"
	aldric.axial = Vector2i(1, 0)
	simulation.register_character(aldric)
	return simulation


func _test_effects_apply_and_persist_once() -> void:
	var journal := _journal_with_decision()
	var simulation := _simulation_with_player_and_aldric()
	var effects := {
		"region_security": {"hollowmere": -4},
		"region_prosperity": {"emberlode": -25},
		"experience": 40,
		"player_gold": 60,
		"aldric_attitude": -8,
		"rescue_aldric": true,
		"emberlode_raided": true,
		"set_world_flag": {"goblin_scout_note_read": true}
	}
	var first := WORLD_EFFECT_SERVICE.apply_effects(journal, simulation, QUEST_ID, "resolution", effects)
	_check(bool(first.get("ok", false)), "Source campaign effects should apply")
	_check(not bool(first.get("already_applied", true)))
	_check(is_equal_approx(float(journal.region_campaign_state("hollowmere").get("security", 0.0)), -4.0))
	_check(is_equal_approx(float(journal.region_campaign_state("emberlode").get("prosperity", 0.0)), -25.0))
	_check(bool(journal.world_campaign_flag("goblin_scout_note_read", false)))
	_check(bool(journal.world_campaign_flag("emberlode_raided", false)))
	_check(bool(journal.world_campaign_flag("aldric_rescued", false)))
	_check(journal.npc_standing(ALDRIC_ID) == 52.0)
	_check(simulation.get_character("player").experience == 40)
	_check(simulation.get_character("player").gold == 80)
	_check(simulation.get_character(ALDRIC_ID).side == "neutral")

	var repeated := WORLD_EFFECT_SERVICE.apply_effects(journal, simulation, QUEST_ID, "resolution", effects)
	_check(bool(repeated.get("ok", false)) and bool(repeated.get("already_applied", false)))
	_check(is_equal_approx(float(journal.region_campaign_state("hollowmere").get("security", 0.0)), -4.0))
	_check(simulation.get_character("player").experience == 40)
	_check(simulation.get_character("player").gold == 80)

	var restored := JOURNAL_SCRIPT.new()
	restored.register_quest_definition({"id": QUEST_ID, "title": "Effect test", "objectives": []})
	restored.load_dict(journal.to_dict())
	_check(is_equal_approx(float(restored.region_campaign_state("hollowmere").get("security", 0.0)), -4.0))
	_check(is_equal_approx(float(restored.region_campaign_state("emberlode").get("prosperity", 0.0)), -25.0))
	_check(bool(restored.world_campaign_flag("aldric_rescued", false)))
	_check(restored.world_consequences.has("%s::resolution::world_effects" % QUEST_ID))
	var replay_after_load := WORLD_EFFECT_SERVICE.apply_effects(restored, simulation, QUEST_ID, "resolution", effects)
	_check(bool(replay_after_load.get("ok", false)) and bool(replay_after_load.get("already_applied", false)))
	_check(simulation.get_character("player").gold == 80, "Save/load must not allow rewards to be farmed")


func _test_invalid_effects_have_no_side_effects() -> void:
	var journal := _journal_with_decision()
	var simulation := _simulation_with_player_and_aldric()
	var invalid := WORLD_EFFECT_SERVICE.apply_effects(journal, simulation, QUEST_ID, "resolution", {
		"region_security": {"hollowmere": NAN},
		"experience": 100
	})
	_check(not bool(invalid.get("ok", true)), "Non-finite region effects must be rejected")
	_check(journal.region_campaign_state("hollowmere").is_empty())
	_check(not journal.world_consequences.has("%s::resolution::world_effects" % QUEST_ID))
	_check(simulation.get_character("player").experience == 0)

	var insufficient := WORLD_EFFECT_SERVICE.apply_effects(journal, simulation, QUEST_ID, "resolution", {
		"player_gold": -100
	})
	_check(not bool(insufficient.get("ok", true)))
	_check(simulation.get_character("player").gold == 20)
	_check(not journal.world_consequences.has("%s::resolution::world_effects" % QUEST_ID))


func _test_recruited_aldric_can_depart_on_betrayal() -> void:
	var journal := _journal_with_decision()
	journal.seed_npc_reputation(ALDRIC_ID, 60.0)
	var simulation := _simulation_with_player_and_aldric()
	simulation.party_member_ids.append(ALDRIC_ID)
	simulation.get_character(ALDRIC_ID).side = "player"
	var result := WORLD_EFFECT_SERVICE.apply_effects(journal, simulation, QUEST_ID, "resolution", {
		"aldric_leaves_if_recruited": true,
		"aldric_attitude": 0
	})
	_check(bool(result.get("ok", false)))
	_check(not simulation.is_party_member(ALDRIC_ID), "Betrayal removes Aldric from the active party")
	_check(simulation.get_character(ALDRIC_ID) == null, "Aldric's departed companion actor is removed from the simulation")
	_check(journal.npc_standing(ALDRIC_ID) == 0.0, "Betrayal resets Aldric's attitude to zero")
	_check(bool(journal.world_campaign_flag("aldric_leaves_if_recruited", false)))
