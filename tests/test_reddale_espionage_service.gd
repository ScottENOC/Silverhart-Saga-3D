extends SceneTree

const SERVICE = preload("res://scripts/simulation/reddale_espionage_service.gd")

var _failures := 0


func _initialize() -> void:
	_test_baron_quest_and_clean_hand_in()
	_test_mirrored_petra_quest_and_double_cross()
	_test_double_cross_decline_and_guard_failure()
	if _failures > 0:
		push_error("%d Reddale espionage assertion(s) failed." % _failures)
		quit(1)
		return
	print("Reddale espionage tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _journal() -> CampaignJournal:
	var journal := CampaignJournal.new()
	journal.seed_faction_reputation("silverhart_kingdom", 30.0, 0.0)
	journal.seed_faction_reputation("ironbond_company", 0.0, 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", 45.0)
	SERVICE.register_definitions(journal)
	return journal


func _test_baron_quest_and_clean_hand_in() -> void:
	var journal := _journal()
	var prompt := SERVICE.interact(journal, "baron_corwin_aldervale", Vector2i(146, 15))
	_check(prompt.get("choices", []).size() == 2, "Baron offers the guildhouse espionage quest at +20 kingdom standing")
	var started := SERVICE.choose(journal, "spy_on_guild", "accept")
	_check(bool(started.get("ok", false)), "Player can accept Eyes on the Guildhouse")
	_check(String(journal.quest_state("spy_on_guild").get("status", "")) == "active", "Quest state is stored in CampaignJournal")
	var wrong_hex := SERVICE.search_evidence(journal, "spy_on_guild", Vector2i(146, 33))
	_check(String(wrong_hex.get("reason", "")) == "not_at_evidence", "Evidence cannot be recovered from the wrong tile")
	var found := SERVICE.search_evidence(journal, "spy_on_guild", Vector2i(147, 33))
	_check(bool(found.get("ok", false)), "Correct guildhouse evidence tile advances objective")
	var player := CharacterState.new("player", "Player")
	var handed_in := SERVICE.choose(journal, "spy_on_guild", "hand_in", player)
	_check(bool(handed_in.get("ok", false)), "Baron accepts recovered evidence")
	_check(String(journal.quest_state("spy_on_guild").get("status", "")) == "completed", "Guildhouse quest completes")
	_check(is_equal_approx(journal.faction_standing("silverhart_kingdom"), 45.0), "Clean hand-in improves kingdom standing")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), -20.0), "Clean hand-in damages Ironbond standing")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 35.0), "Clean hand-in reduces Ironbond merchant influence")
	_check(player.experience == SERVICE.COMPLETION_XP, "Quest awards source-authored 150 XP")


func _test_mirrored_petra_quest_and_double_cross() -> void:
	var journal := _journal()
	var started := SERVICE.choose(journal, "spy_on_baron", "accept")
	_check(bool(started.get("ok", false)), "Petra quest can be accepted")
	var baron_prompt := SERVICE.interact(journal, "baron_corwin_aldervale", Vector2i(146, 15))
	_check(baron_prompt.get("choices", []).size() == 2, "Baron confronts the player about Petra's active mission")
	var pledge := SERVICE.choose(journal, "spy_on_baron", "double_agent")
	_check(bool(pledge.get("ok", false)), "Player can become the Baron's inside agent")
	_check(String(journal.quest_state("spy_on_baron").get("double_agent_for", "")) == "silverhart_kingdom", "Double-agent allegiance persists in quest state")
	SERVICE.search_evidence(journal, "spy_on_baron", Vector2i(147, 13))
	var handed_in := SERVICE.choose(journal, "spy_on_baron", "hand_in")
	_check(bool(handed_in.get("ok", false)), "Petra evidence can be handed in after the double-cross")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), -40.0), "Double-cross forces Ironbond standing to -40")
	_check(journal.faction_standing("silverhart_kingdom") >= 0.0, "Double-cross clears negative kingdom standing")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 35.0), "Secret Baron reward changes merchant influence")


func _test_double_cross_decline_and_guard_failure() -> void:
	var journal := _journal()
	SERVICE.choose(journal, "spy_on_guild", "accept")
	var petra_prompt := SERVICE.interact(journal, "petra_voss", Vector2i(146, 35))
	_check(petra_prompt.get("choices", []).size() == 2, "Petra confronts the player about the Baron's active mission")
	var declined := SERVICE.choose(journal, "spy_on_guild", "decline_double_agent")
	_check(bool(declined.get("ok", false)), "Player can decline Petra's double-agent offer")
	var detected := SERVICE.check_guard_detection(journal, "spy_on_guild", Vector2i(146, 34))
	_check(bool(detected.get("detected", false)), "Entering the guard's adjacent hex triggers mission failure")
	_check(String(journal.quest_state("spy_on_guild").get("status", "")) == "failed", "Caught mission is marked failed")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), -27.9), "Declining the double-agent offer then being caught applies the knowledge-dampened failure penalty")
	_check(is_equal_approx(float(journal.faction_knowledge.get("ironbond_company", 0.0)), 30.0), "Declining and detection each increase faction knowledge")
