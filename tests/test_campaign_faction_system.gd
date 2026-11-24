extends SceneTree

const FACTIONS = preload("res://scripts/simulation/campaign_faction_system.gd")

var _failures := 0


func _initialize() -> void:
	_test_race_based_seeding()
	_test_goblin_reputation_spillover()
	_test_feudal_reputation_cascade()
	_test_ironbond_autonomous_agenda_and_save()
	_test_runtime_autoload_integration()
	if _failures > 0:
		push_error("%d campaign faction assertion(s) failed." % _failures)
		quit(1)
		return
	print("Campaign faction system tests passed.")
	quit(0)


func _test_runtime_autoload_integration() -> void:
	var runtime := root.get_node_or_null("CampaignFactionRuntime")
	_check(runtime != null, "Campaign faction runtime autoload is registered")
	if runtime == null:
		return
	var simulation := WorldSimulation.new()
	simulation.name = "FactionRuntimeRegressionSimulation"
	simulation.player_character_id = "player"
	root.add_child(simulation)
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	player.race = "goblin"
	simulation.register_character(player)
	runtime.call("_track_simulation", simulation)
	runtime.call("_process", 0.0)
	_check(is_equal_approx(simulation.campaign_journal.faction_standing("goblin_tribe"), 5.0), "Runtime seeds faction standings from the live player race")
	_check(is_equal_approx(simulation.campaign_journal.faction_standing("silverhart_kingdom"), -15.0), "Runtime seeds hostile kingdom standing for a greenskin player")
	simulation.campaign_journal.adjust_faction_reputation("ironbond_company", 20.0, 0.0, "Runtime regression")
	simulation.clock.advance_world_seconds(3600.0)
	_check(is_equal_approx(simulation.campaign_journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.02), "Runtime advances autonomous agendas from WorldSimulation clock ticks")
	simulation.queue_free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_race_based_seeding() -> void:
	var human := CampaignJournal.new()
	FACTIONS.initialize_social_standings(human, "human")
	_check(is_equal_approx(human.faction_standing("silverhart_kingdom"), 5.0), "Human player receives the source same-race Silverhart standing")
	_check(is_equal_approx(human.faction_standing("ironbond_company"), 5.0), "Human player receives the source same-race Ironbond standing")
	_check(is_equal_approx(human.faction_standing("goblin_tribe"), 0.0), "Human player starts neutral with the goblin tribe")
	_check(is_equal_approx(human.faction_standing("thieves_guild"), 0.0), "Thieves Guild standing is race-neutral")
	_check(is_equal_approx(human.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0), "Ironbond starts with 30 influence in Silverhart")

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
	var authority_tiers: Array[String] = ["goblin_tribe", "silverhart_kingdom"]
	var results := FACTIONS.cascade_reputation(
		journal,
		authority_tiers,
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
	FACTIONS.initialize_social_standings(journal, "human")
	journal.adjust_faction_reputation("ironbond_company", 20.0, 0.0, "Campaign test")
	var first := FACTIONS.advance_time(journal, 3600.0)
	_check(bool(first.get("ok", false)), "Ironbond agenda advances with campaign time")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.02), "Favourable Ironbond standing slowly increases commercial influence")
	var saved := journal.to_dict()
	var restored := CampaignJournal.new()
	restored.load_dict(saved)
	FACTIONS.advance_time(restored, 3600.0)
	_check(is_equal_approx(restored.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.04), "Autonomous agenda resumes from its saved world-time checkpoint")
	FACTIONS.advance_time(restored, 0.0)
	_check(is_equal_approx(restored.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.04), "Zero elapsed time does not double-apply agenda drift")

	var hostile := CampaignJournal.new()
	FACTIONS.initialize_social_standings(hostile, "human")
	hostile.adjust_faction_reputation("ironbond_company", -30.0, 0.0, "Campaign test")
	FACTIONS.advance_time(hostile, 3600.0)
	_check(is_equal_approx(hostile.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 29.98), "Hostile standing slowly reduces commercial influence")

	var neutral := CampaignJournal.new()
	FACTIONS.initialize_social_standings(neutral, "human")
	FACTIONS.advance_time(neutral, 3600.0)
	_check(is_equal_approx(neutral.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0), "Ironbond agenda is stationary inside the neutral standing band")
