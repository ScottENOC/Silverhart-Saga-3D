extends SceneTree

const JOURNAL_SCRIPT = preload("res://scripts/simulation/campaign_journal.gd")
const CONSEQUENCE_SERVICE = preload("res://scripts/simulation/campaign_faction_decision_service.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_reputation_and_influence_apply_once()
	_test_invalid_outcome_has_no_side_effects()
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
