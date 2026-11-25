extends SceneTree

const JOURNAL_SCRIPT = preload("res://scripts/simulation/campaign_journal.gd")
const CONSEQUENCE_SERVICE = preload("res://scripts/simulation/campaign_faction_decision_service.gd")
const HOLLOWMERE_CONTENT = preload("res://scripts/simulation/hollowmere_campaign_content.gd")
const WORLD_CONSEQUENCE_SERVICE = preload("res://scripts/simulation/campaign_world_consequence_service.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_reputation_and_influence_apply_once()
	_test_invalid_outcome_has_no_side_effects()
	_test_world_consequence_persistence_and_idempotency()
	_test_settlement_and_npc_state_updates()
	_test_hollowmere_source_outcomes()
	if _failures > 0:
		push_error("%d campaign faction decision assertion(s) failed." % _failures)
		quit(1)
		return
	print("Campaign faction decision consequence tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _journal_with_active_quest() -> CampaignJournal:
	var journal := JOURNAL_SCRIPT.new()
	journal.register_quest_definition({
		"id": "faction_decision_test",
		"title": "Faction decision test",
		"objectives": []
	})
	journal.start_quest("faction_decision_test")
	journal.seed_faction_reputation("ironbond_company", 10.0, 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", 30.0)
	return journal


func _test_reputation_and_influence_apply_once() -> void:
	var journal := _journal_with_active_quest()
	var factions: Array[Dictionary] = [{
		"faction_id": "ironbond_company",
		"standing_delta": -15.0,
		"knowledge_delta": 15.0
	}]
	var influence: Array[Dictionary] = [{
		"faction_id": "ironbond_company",
		"kingdom_id": "silverhart_kingdom",
		"amount": -15.0
	}]
	var first := CONSEQUENCE_SERVICE.apply_outcome(
		journal, "faction_decision_test", "response", "resist", factions, influence, "Reddale resists Ironbond"
	)
	_check(bool(first.get("ok", false)), "A valid faction decision should apply")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), -5.0), "Reputation should receive the source-authored delta")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 15.0), "Merchant influence should receive the source-authored delta")

	var repeated := CONSEQUENCE_SERVICE.apply_outcome(
		journal, "faction_decision_test", "response", "resist", factions, influence, "Reddale resists Ironbond"
	)
	_check(not bool(repeated.get("ok", false)), "A repeated decision must be rejected")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), -5.0), "Repeated decisions must not duplicate reputation")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 15.0), "Repeated decisions must not duplicate influence")

	var restored := JOURNAL_SCRIPT.new()
	restored.load_dict(journal.to_dict())
	_check(is_equal_approx(restored.faction_standing("ironbond_company"), -5.0), "Reputation must survive save/load")
	_check(is_equal_approx(restored.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 15.0), "Influence must survive save/load")


func _test_invalid_outcome_has_no_side_effects() -> void:
	var journal := _journal_with_active_quest()
	var invalid_factions: Array[Dictionary] = [{
		"faction_id": "ironbond_company",
		"standing_delta": NAN,
		"knowledge_delta": 5.0
	}]
	var result := CONSEQUENCE_SERVICE.apply_outcome(
		journal, "faction_decision_test", "response", "invalid", invalid_factions, [], "invalid test"
	)
	_check(not bool(result.get("ok", false)), "Non-finite deltas must be rejected")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), 10.0), "Invalid outcomes must not mutate reputation")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0), "Invalid outcomes must not mutate influence")
	_check(not journal.quests["faction_decision_test"]["decisions"].has("response"), "Invalid outcomes must not record a decision")

func _test_hollowmere_source_outcomes() -> void:
	var expected := {
		"stay_out": {"reputation": 10.0, "influence": 31.0},
		"encourage_pay": {"reputation": 20.0, "influence": 32.0},
		"fight": {"reputation": -30.0, "influence": 28.0}
	}
	for choice_id_value in expected.keys():
		var choice_id := String(choice_id_value)
		var journal := JOURNAL_SCRIPT.new()
		journal.register_quest_definition(HOLLOWMERE_CONTENT.shakedown_quest_definition())
		journal.start_quest(HOLLOWMERE_CONTENT.QUEST_ID)
		HOLLOWMERE_CONTENT.initialize_social_standings(journal, "human")
		var result := HOLLOWMERE_CONTENT.apply_shakedown_choice(journal, choice_id)
		_check(bool(result.get("ok", false)), "Hollowmere choice should resolve: " + choice_id)
		_check(is_equal_approx(
			journal.faction_standing("ironbond_company"),
			float(expected[choice_id]["reputation"])
		), "Hollowmere should preserve source-authored Ironbond reputation: " + choice_id)
		_check(is_equal_approx(
			journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"),
			float(expected[choice_id]["influence"])
		), "Hollowmere should preserve source-authored merchant influence: " + choice_id)
		var repeated := HOLLOWMERE_CONTENT.apply_shakedown_choice(journal, choice_id)
		_check(not bool(repeated.get("ok", false)), "Hollowmere choice should remain one-shot: " + choice_id)


func _test_world_consequence_persistence_and_idempotency() -> void:
	var journal := _journal_with_active_quest()
	var decision := journal.record_decision("faction_decision_test", "reeve_response", "resist_ironbond")
	_check(bool(decision.get("ok", false)), "World consequence source decision should be recorded")
	var consequence := {
		"region_id": "reddale",
		"state": "ironbond_pressure_reduced",
		"public_order_delta": 10
	}
	var first := journal.record_world_consequence(
		"reddale_ironbond_pressure", "faction_decision_test", "reeve_response", consequence
	)
	_check(bool(first.get("ok", false)), "A valid world consequence should be recorded")
	_check(not bool(first.get("already_recorded", true)), "First world consequence record should be new")
	var repeated := journal.record_world_consequence(
		"reddale_ironbond_pressure", "faction_decision_test", "reeve_response", consequence
	)
	_check(bool(repeated.get("ok", false)) and bool(repeated.get("already_recorded", false)), "Identical world consequence replay should be idempotent")
	var conflict := journal.record_world_consequence(
		"reddale_ironbond_pressure", "faction_decision_test", "reeve_response", {"state": "different"}
	)
	_check(not bool(conflict.get("ok", false)), "A consequence ID must not be reused for conflicting state")
	_check(journal.world_consequence("reddale_ironbond_pressure").get("value", {}) == consequence, "Recorded world consequence should be queryable")
	var restored := JOURNAL_SCRIPT.new()
	restored.register_quest_definition({"id": "faction_decision_test", "objectives": []})
	restored.load_dict(journal.to_dict())
	_check(restored.world_consequence("reddale_ironbond_pressure").get("value", {}) == consequence, "World consequence must survive save/load")
	var replay_after_load := restored.record_world_consequence(
		"reddale_ironbond_pressure", "faction_decision_test", "reeve_response", consequence
	)
	_check(bool(replay_after_load.get("ok", false)) and bool(replay_after_load.get("already_recorded", false)), "Save/load must preserve consequence idempotency")
	var unlinked := restored.record_world_consequence(
		"unlinked_consequence", "faction_decision_test", "missing_decision", {"state": "invalid"}
	)
	_check(not bool(unlinked.get("ok", false)), "World consequences must reference a recorded decision")


func _test_settlement_and_npc_state_updates() -> void:
	var journal := _journal_with_active_quest()
	var decision := journal.record_decision("faction_decision_test", "reeve_response", "resist_ironbond")
	_check(bool(decision.get("ok", false)), "Settlement/NPC updates require a recorded decision")
	var settlements: Array[Dictionary] = [{
		"settlement_id": "reddale",
		"deltas": {"public_order": 12.0, "ironbond_presence": -20.0},
		"flags": {"reeve_backed_resistance": true}
	}]
	var npcs: Array[Dictionary] = [{
		"npc_id": "reeve_aldous_finch",
		"deltas": {"trust": 15.0, "fear": -10.0},
		"flags": {"will_openly_oppose_ironbond": true}
	}]
	var result := WORLD_CONSEQUENCE_SERVICE.apply_decision_consequences(
		journal, "faction_decision_test", "reeve_response", settlements, npcs
	)
	_check(bool(result.get("ok", false)), "A valid campaign decision should update settlement and NPC state")
	var settlement_state := journal.settlement_campaign_state("reddale")
	_check(is_equal_approx(float(settlement_state.get("public_order", 0.0)), 12.0), "Reddale public order should reflect the decision")
	_check(is_equal_approx(float(settlement_state.get("ironbond_presence", 0.0)), -20.0), "Reddale faction presence should reflect the decision")
	_check(bool(settlement_state.get("flags", {}).get("reeve_backed_resistance", false)), "Settlement flags should reflect the decision")
	var npc_state := journal.npc_campaign_state("reeve_aldous_finch")
	_check(is_equal_approx(float(npc_state.get("trust", 0.0)), 15.0), "Reeve trust should reflect the decision")
	_check(is_equal_approx(float(npc_state.get("fear", 0.0)), -10.0), "Reeve fear should reflect the decision")
	_check(bool(npc_state.get("flags", {}).get("will_openly_oppose_ironbond", false)), "Reeve campaign flags should reflect the decision")

	var repeated := WORLD_CONSEQUENCE_SERVICE.apply_decision_consequences(
		journal, "faction_decision_test", "reeve_response", settlements, npcs
	)
	_check(bool(repeated.get("ok", false)) and bool(repeated.get("already_recorded", false)), "World consequence application should be idempotent")
	_check(is_equal_approx(float(journal.settlement_campaign_state("reddale").get("public_order", 0.0)), 12.0), "Repeated application must not stack settlement deltas")
	_check(is_equal_approx(float(journal.npc_campaign_state("reeve_aldous_finch").get("trust", 0.0)), 15.0), "Repeated application must not stack NPC deltas")

	var invalid_settlements: Array[Dictionary] = [{
		"settlement_id": "reddale",
		"deltas": {"public_order": NAN}
	}]
	var invalid := WORLD_CONSEQUENCE_SERVICE.apply_decision_consequences(
		journal, "faction_decision_test", "reeve_response_invalid", invalid_settlements, []
	)
	_check(not bool(invalid.get("ok", false)), "Non-finite settlement deltas must be rejected before mutation")

	var restored := JOURNAL_SCRIPT.new()
	restored.register_quest_definition({"id": "faction_decision_test", "objectives": []})
	restored.load_dict(journal.to_dict())
	_check(is_equal_approx(float(restored.settlement_campaign_state("reddale").get("public_order", 0.0)), 12.0), "Settlement campaign state must survive save/load")
	_check(is_equal_approx(float(restored.npc_campaign_state("reeve_aldous_finch").get("trust", 0.0)), 15.0), "NPC campaign state must survive save/load")
	var replay_after_load := WORLD_CONSEQUENCE_SERVICE.apply_decision_consequences(
		restored, "faction_decision_test", "reeve_response", settlements, npcs
	)
	_check(bool(replay_after_load.get("ok", false)) and bool(replay_after_load.get("already_recorded", false)), "Save/load must preserve world consequence idempotency")
