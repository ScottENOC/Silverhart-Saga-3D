extends SceneTree

const FACTION_SIMULATION = preload("res://scripts/simulation/campaign_faction_simulation.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_source_faction_seeds()
	_test_goblin_to_orc_reputation_cascade()
	_test_autonomous_ironbond_influence()
	_test_agenda_progress_survives_save_load()
	_test_world_clock_drives_agendas()
	if _failures > 0:
		push_error("%d campaign faction assertion(s) failed." % _failures)
		quit(1)
		return
	print("Campaign faction state tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_source_faction_seeds() -> void:
	var journal := CampaignJournal.new()
	FACTION_SIMULATION.seed_faction_standings(journal, "human")
	_check(is_equal_approx(journal.faction_standing("silverhart_kingdom"), 5.0))
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), 5.0))
	_check(is_equal_approx(journal.faction_standing("goblin_tribe"), 0.0))
	_check(is_equal_approx(journal.faction_standing("thieves_guild"), 0.0))
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0))

	var goblin := CampaignJournal.new()
	FACTION_SIMULATION.seed_faction_standings(goblin, "goblin")
	_check(is_equal_approx(goblin.faction_standing("goblin_tribe"), 5.0))
	_check(is_equal_approx(goblin.faction_standing("orc_raiders"), 15.0))
	_check(is_equal_approx(goblin.faction_standing("silverhart_kingdom"), -15.0))
	_check(is_equal_approx(goblin.faction_standing("ironbond_company"), -15.0))
	_check(is_equal_approx(goblin.faction_standing("dwarven_kingdom"), -15.0))
	_check(is_equal_approx(goblin.faction_standing("elven_realm"), -15.0))
	_check(is_equal_approx(goblin.faction_standing("necromancer_cult"), 0.0))
	_check(is_equal_approx(goblin.faction_standing("thieves_guild"), 0.0))

	var orc := CampaignJournal.new()
	FACTION_SIMULATION.seed_faction_standings(orc, "orc")
	_check(is_equal_approx(orc.faction_standing("orc_raiders"), 5.0))
	_check(is_equal_approx(orc.faction_standing("goblin_tribe"), 15.0))

	var elf := CampaignJournal.new()
	FACTION_SIMULATION.seed_faction_standings(elf, "elf")
	_check(is_equal_approx(elf.faction_standing("elven_realm"), 5.0))
	_check(is_equal_approx(elf.faction_standing("silverhart_kingdom"), 0.0))

	var dwarf := CampaignJournal.new()
	FACTION_SIMULATION.seed_faction_standings(dwarf, "dwarf")
	_check(is_equal_approx(dwarf.faction_standing("dwarven_kingdom"), 5.0))

	var undead := CampaignJournal.new()
	FACTION_SIMULATION.seed_faction_standings(undead, "undead")
	_check(is_equal_approx(undead.faction_standing("necromancer_cult"), 5.0))

	var restored := CampaignJournal.new()
	restored.seed_faction_reputation("goblin_tribe", 42.0, 17.0)
	FACTION_SIMULATION.seed_faction_standings(restored, "human")
	_check(is_equal_approx(restored.faction_standing("goblin_tribe"), 42.0), "Initial faction seeding must not overwrite saved reputation")
	_check(is_equal_approx(float(restored.faction_knowledge["goblin_tribe"]), 17.0), "Initial faction seeding must not overwrite saved knowledge")


func _test_goblin_to_orc_reputation_cascade() -> void:
	var journal := CampaignJournal.new()
	journal.seed_faction_reputation("goblin_tribe", 0.0, 0.0)
	journal.seed_faction_reputation("orc_raiders", 0.0, 0.0)
	var result := FACTION_SIMULATION.adjust_goblin_reputation(journal, 20.0, 10.0, "helped the Skarn-tooth tribe")
	_check(bool(result.get("ok", false)))
	_check(is_equal_approx(journal.faction_standing("goblin_tribe"), 20.0))
	_check(is_equal_approx(journal.faction_standing("orc_raiders"), 7.0), "The orc horde receives 35% of goblin standing changes")
	_check(is_equal_approx(float(journal.faction_knowledge["orc_raiders"]), 3.5), "Faction knowledge cascades at the same 35% rate")

	journal.adjust_faction_reputation("orc_raiders", -10.0, 0.0, "independent raider action")
	_check(is_equal_approx(journal.faction_standing("goblin_tribe"), 20.0), "The source cascade is one-way, not reciprocal")


func _test_autonomous_ironbond_influence() -> void:
	var journal := CampaignJournal.new()
	journal.seed_faction_reputation("ironbond_company", 20.0, 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", 30.0)
	var agenda := FACTION_SIMULATION.new()
	agenda.reset_world_time(0.0)
	agenda.advance_to(journal, 1800.0)
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.01), "A thriving Ironbond agenda gains 0.02 influence per in-game hour")
	journal.adjust_faction_reputation("ironbond_company", -40.0, 0.0, "the Company lost standing")
	agenda.advance_to(journal, 3600.0)
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0), "A struggling Ironbond agenda loses 0.02 influence per in-game hour")
	journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", 69.99, "clamp test")
	journal.adjust_faction_reputation("ironbond_company", 40.0, 0.0, "the Company recovered")
	agenda.advance_to(journal, 5400.0)
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 100.0), "Autonomous influence remains clamped to 0..100")
	journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", -200.0, "lower clamp test")
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 0.0), "Merchant influence cannot fall below zero")


func _test_agenda_progress_survives_save_load() -> void:
	var journal := CampaignJournal.new()
	journal.seed_faction_reputation("ironbond_company", 20.0, 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", 30.0)
	var source_clock := WorldClock.new()
	var source_agenda := FACTION_SIMULATION.new()
	source_agenda.reset_world_time(source_clock.world_seconds)
	source_clock.time_advanced.connect(func(world_seconds: float) -> void:
		source_agenda.advance_to(journal, world_seconds)
	)
	source_clock.advance_world_seconds(1800.0)
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.01))

	var restored_journal := CampaignJournal.new()
	restored_journal.load_dict(journal.to_dict())
	var restored_clock := WorldClock.new()
	restored_clock.load_dict(source_clock.to_dict())
	var restored_agenda := FACTION_SIMULATION.new()
	restored_agenda.reset_world_time(restored_clock.world_seconds)
	restored_clock.time_advanced.connect(func(world_seconds: float) -> void:
		restored_agenda.advance_to(restored_journal, world_seconds)
	)
	restored_clock.advance_world_seconds(1800.0)
	_check(is_equal_approx(restored_journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.02), "Merchant influence and elapsed world time survive campaign save/load")


func _test_world_clock_drives_agendas() -> void:
	var journal := CampaignJournal.new()
	journal.seed_faction_reputation("ironbond_company", 20.0, 0.0)
	journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", 30.0)
	var agenda := FACTION_SIMULATION.new()
	agenda.reset_world_time(0.0)
	var clock := WorldClock.new()
	clock.time_advanced.connect(func(world_seconds: float) -> void:
		agenda.advance_to(journal, world_seconds)
	)
	clock.advance_world_seconds(3600.0)
	_check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.02), "The authoritative campaign clock advances faction agendas")
