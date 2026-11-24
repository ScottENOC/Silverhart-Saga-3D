extends SceneTree

const JOURNAL_SCRIPT = preload("res://scripts/simulation/campaign_journal.gd")
const REDDALE_CONTENT = preload("res://scripts/simulation/reddale_campaign_content.gd")
const CHARACTER_STATE = preload("res://scripts/simulation/character_state.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_offer_threshold()
	_test_resist_ironbond_outcome()
	_test_broker_ironbond_outcome()
	if _failures > 0:
		push_error("%d Reddale campaign assertion(s) failed." % _failures)
		quit(1)
		return
	print("Reddale campaign content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _new_journal(influence: float = 30.0) -> CampaignJournal:
	var journal := JOURNAL_SCRIPT.new()
	journal.seed_faction_reputation("ironbond_company", 10.0, 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", influence)
	journal.seed_faction_reputation("silverhart_kingdom", 0.0, 0.0)
	return journal


func _test_offer_threshold() -> void:
	var below := _new_journal(39.0)
	_check(not REDDALE_CONTENT.can_offer_cut(below), "Reddale's Cut must remain unavailable below 40 influence")
	var denied := REDDALE_CONTENT.start_cut(below)
	_check(not bool(denied.get("ok", false)), "Starting below the influence threshold must fail")
	_check(not below.quests.has("reddale_cut"), "A denied offer must not create quest state")

	var at_threshold := _new_journal(40.0)
	_check(REDDALE_CONTENT.can_offer_cut(at_threshold), "Reddale's Cut must unlock at 40 influence")
	var started := REDDALE_CONTENT.start_cut(at_threshold)
	_check(bool(started.get("ok", false)), "The Reeve should be able to offer the quest at 40 influence")
	_check(not REDDALE_CONTENT.can_offer_cut(at_threshold), "The quest must not be offered a second time")


func _test_resist_ironbond_outcome() -> void:
	var journal := _new_journal(45.0)
	_check(bool(REDDALE_CONTENT.start_cut(journal).get("ok", false)), "Resistance path should start")
	var result := REDDALE_CONTENT.resolve_cut(journal, "resist_ironbond")
	_check(bool(result.get("ok", false)), "Resistance path should resolve")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), -5.0), "Resistance should reduce Ironbond standing by 15")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0), "Resistance should reduce Ironbond influence by 15")
	_check(is_equal_approx(journal.faction_standing("silverhart_kingdom"), 20.0), "Resistance should improve Silverhart Kingdom standing by 20")
	_check(int(result.get("gold_delta", -1)) == 0, "Resistance should not award gold")
	var settlement := journal.settlement_campaign_state("reddale")
	_check(is_equal_approx(float(settlement.get("public_order", 0.0)), 10.0), "Resistance should improve Reddale public order")
	_check(is_equal_approx(float(settlement.get("ironbond_presence", 0.0)), -20.0), "Resistance should reduce Ironbond presence in Reddale")
	_check(bool(settlement.get("flags", {}).get("reeve_backed_resistance", false)), "Reddale should remember the Reeve backed resistance")
	var reeve := journal.npc_campaign_state("reeve_aldous_finch")
	_check(is_equal_approx(float(reeve.get("trust", 0.0)), 15.0), "The Reeve should trust the party more after resistance")
	_check(bool(reeve.get("flags", {}).get("will_openly_oppose_ironbond", false)), "The Reeve should openly oppose Ironbond after resistance")
	_check(String(reeve.get("flags", {}).get("public_status", "")) == "Openly opposes Ironbond", "The Reeve should have a public status after resistance")
	_check(String(settlement.get("flags", {}).get("public_status", "")) == "Public order restored", "Reddale should expose its changed public status after resistance")
	_check(String(journal.quest_state("reddale_cut").get("status", "")) == "completed", "Resistance should complete the quest")
	var repeated := REDDALE_CONTENT.resolve_cut(journal, "resist_ironbond")
	_check(not bool(repeated.get("ok", false)), "The decision must not be repeatable")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0), "Repeated resolution must not change influence")


func _test_broker_ironbond_outcome() -> void:
	var journal := _new_journal(45.0)
	_check(bool(REDDALE_CONTENT.start_cut(journal).get("ok", false)), "Broker path should start")
	var player := CHARACTER_STATE.new("player", "Player")
	var result := REDDALE_CONTENT.resolve_cut(journal, "broker_ironbond_deal", player)
	_check(bool(result.get("ok", false)), "Broker path should resolve")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), 30.0), "Brokered deal should improve Ironbond standing by 20")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 60.0), "Brokered deal should increase Ironbond influence by 15")
	_check(is_equal_approx(journal.faction_standing("silverhart_kingdom"), -10.0), "Brokered deal should reduce Silverhart Kingdom standing by 10")
	_check(int(result.get("gold_delta", 0)) == 50, "Brokered deal should report the 50 gold reward")
	_check(player.gold == 50, "Brokered deal should apply the 50 gold reward to the player")
	var settlement := journal.settlement_campaign_state("reddale")
	_check(is_equal_approx(float(settlement.get("prosperity", 0.0)), 8.0), "Brokered deal should improve Reddale prosperity")
	_check(is_equal_approx(float(settlement.get("ironbond_presence", 0.0)), 20.0), "Brokered deal should increase Ironbond presence in Reddale")
	_check(bool(settlement.get("flags", {}).get("ironbond_deal_brokered", false)), "Reddale should remember the brokered Ironbond deal")
	var reeve := journal.npc_campaign_state("reeve_aldous_finch")
	_check(is_equal_approx(float(reeve.get("trust", 0.0)), 5.0), "The Reeve should record the party brokered the deal")
	_check(not bool(reeve.get("flags", {}).get("will_openly_oppose_ironbond", true)), "The Reeve should not openly oppose Ironbond after brokering")
	_check(String(reeve.get("flags", {}).get("public_status", "")) == "Brokered Ironbond deal", "The Reeve should have a public status after brokering")
	_check(String(settlement.get("flags", {}).get("public_status", "")) == "Ironbond trade deal established", "Reddale should expose its changed public status after brokering")
	var restored := JOURNAL_SCRIPT.new()
	restored.load_dict(journal.to_dict())
	_check(is_equal_approx(restored.faction_standing("ironbond_company"), 30.0), "Faction reputation should survive save/load")
	_check(is_equal_approx(restored.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 60.0), "Faction influence should survive save/load")
	_check(is_equal_approx(restored.faction_standing("silverhart_kingdom"), -10.0), "Silverhart Kingdom reputation should survive save/load")
	_check(is_equal_approx(float(restored.settlement_campaign_state("reddale").get("prosperity", 0.0)), 8.0), "Reddale campaign state should survive save/load")
	_check(is_equal_approx(float(restored.npc_campaign_state("reeve_aldous_finch").get("trust", 0.0)), 5.0), "Reeve campaign state should survive save/load")
