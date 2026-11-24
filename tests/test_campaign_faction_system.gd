extends SceneTree

const FACTIONS = preload("res://scripts/simulation/campaign_faction_system.gd")

var _failures := 0


func _initialize() -> void:
	_test_race_based_seeding()
	_test_goblin_reputation_spillover()
	_test_feudal_reputation_cascade()
	_test_ironbond_autonomous_agenda_and_save()
	if _failures > 0:
		push_error("%d campaign faction assertion(s) failed." % _failures)
		quit(1)
		return
	print("Campaign faction system tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_race_based_seeding() -> void:
	var human := CampaignJournal.new()
	FACTIONS.initialize_social_standings(human, "human", 39600.0)
	_check(is_equal_approx(human.faction_standing("silverhart_kingdom"), 5.0), "Human player receives the source same-race Silverhart standing")
	_check(is_equal_approx(human.faction_standing("ironbond_company"), 5.0), "Human player receives the source same-race Ironbond standing")
	_check(is_equal_approx(human.faction_standing("goblin_tribe"), 0.0), "Human player starts neutral with the goblin tribe")
	_check(is_equal_approx(human.faction_standing("thieves_guild"), 0.0), "Thieves Guild standing is race-neutral")
	_check(is_equal_approx(human.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0), "Ironbond starts with 30 influence in Silverhart")
	_check(is_equal_approx(human.faction_agenda_last_world_seconds, 39600.0), "Faction agenda clock is anchored to campaign start")

	var goblin := CampaignJournal.new()
	FACTIONS.initialize_social_standings(goblin, "goblin")
	_check(is_equal_approx(goblin.faction_standing("goblin_tribe"), 5.0), "Goblin player receives same-race tribe standing")
	_check(is_equal_approx(goblin.faction_standing("orc_raiders"), 15.0), "Goblin player is kin-adjacent to orc raiders")
	_check(is_equal_approx(goblin.faction_standing("silverhart_kingdom"), -15.0), "Goblin player starts distrusted by human kingdom")
	_check(is_equal_approx(goblin.faction_standing("elven_realm"), -15.0), "Goblin player starts distrusted by elven realm")
	_check(is_equal_approx(goblin.faction_standing("dwarven_kingdom"), -15.0), "Goblin player starts distrusted by dwarven kingdom")
	_check(is_equal_approx(goblin.faction_standing("necromancer_cult"), 0.0), "Unrelated undead faction remains neutral")


func _test_goblin_reputation_spillover() -> void:
	var journal := CampaignJournal.new()
	FACTIONS.initialize_social_standings(journal, "human")
	var result := FACTIONS.adjust_reputation(journal, "goblin_tribe", 20.0, 10.0, "Skarn-tooth diplomacy")
	_check(bool(result.get("ok", false)), "Goblin reputation adjustment succeeds")
	_check(is_equal_approx(journal.faction_standing("goblin_tribe"), 20.0), "Primary goblin reputation receives the full first-impression change")
	_check(is_equal_approx(journal.faction_standing("orc_raiders"), 7.0), "Goblin standing change reports to the orc horde at 35 percent")
	_check(is_equal_approx(float(journal.faction_knowledge.get("orc_raiders", -1.0)), 3.5), "Knowledge spillover is damped to 35 percent")
	FACTIONS.adjust_reputation(journal, "orc_raiders", -10.0, 0.0, "Separate border encounter")
	_check(is_equal_approx(journal.faction_standing("goblin_tribe"), 20.0), "Orc reputation does not spill back into the goblin tribe")

	var known := CampaignJournal.new()
	known.seed_faction_reputation("goblin_tribe", 0.0, 100.0)
	known.seed_faction_reputation("orc_raiders", 0.0, 0.0)
	FACTIONS.adjust_reputation(known, "goblin_tribe", 10.0, 0.0, "Known faction")
	_check(is_equal_approx(known.faction_standing("goblin_tribe"), 3.0), "Faction familiarity dampens the primary standing swing to the 30 percent floor")
	_check(is_equal_approx(known.faction_standing("orc_raiders"), 3.5), "Horde spillover uses the source delta and the receiving faction's own dampening")


func _test_feudal_reputation_cascade() -> void:
	var journal := CampaignJournal.new()
	FACTIONS.initialize_social_standings(journal, "human")
	var results := FACTIONS.cascade_reputation(
		journal,
		["goblin_tribe", "silverhart_kingdom"],
		20.0,
		10.0,
		"Village diplomacy"
	)
	_check(results.size() == 2, "Reputation cascade processes each authority tier")
	_check(is_equal_approx(journal.faction_standing("goblin_tribe"), 20.0), "Nearest faction receives the full cascade delta")
	_check(is_equal_approx(journal.faction_standing("silverhart_kingdom"), 13.0), "Kingdom receives the 40 percent authority-tier ripple")
	_check(is_equal_approx(journal.faction_standing("orc_raiders"), 7.0), "Goblin faction ripple still reaches its orc patrons")


func _test_ironbond_autonomous_agenda_and_save() -> void:
	var journal := CampaignJournal.new()
	FACTIONS.initialize_social_standings(journal, "human", 1000.0)
	journal.adjust_faction_reputation("ironbond_company", 20.0, 0.0, "Campaign test")
	var first := FACTIONS.advance_to_time(journal, 4600.0)
	_check(bool(first.get("ok", false)), "Ironbond agenda advances with campaign time")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.02), "Favourable Ironbond standing slowly increases commercial influence")
	var saved := journal.to_dict()
	var restored := CampaignJournal.new()
	restored.load_dict(saved)
	FACTIONS.advance_to_time(restored, 8200.0)
	_check(is_equal_approx(restored.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.04), "Autonomous agenda resumes from its saved world-time checkpoint")
	FACTIONS.advance_to_time(restored, 8200.0)
	_check(is_equal_approx(restored.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.04), "Repeated time checkpoint does not double-apply agenda drift")

	var hostile := CampaignJournal.new()
	FACTIONS.initialize_social_standings(hostile, "human", 0.0)
	hostile.adjust_faction_reputation("ironbond_company", -30.0, 0.0, "Campaign test")
	FACTIONS.advance_to_time(hostile, 3600.0)
	_check(is_equal_approx(hostile.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 29.98), "Hostile standing slowly reduces commercial influence")

	var neutral := CampaignJournal.new()
	FACTIONS.initialize_social_standings(neutral, "human", 0.0)
	FACTIONS.advance_to_time(neutral, 3600.0)
	_check(is_equal_approx(neutral.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0), "Ironbond agenda is stationary inside the neutral standing band")
