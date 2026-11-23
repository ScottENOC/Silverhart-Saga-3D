extends SceneTree

const HOLLOWMERE_CONTENT = preload("res://scripts/simulation/hollowmere_campaign_content.gd")

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
    var human := CampaignJournal.new()
    HOLLOWMERE_CONTENT.initialize_social_standings(human, "human")
    _check(is_equal_approx(human.faction_standing("silverhart_kingdom"), 5.0))
    _check(is_equal_approx(human.faction_standing("ironbond_company"), 5.0))
    _check(is_equal_approx(human.faction_standing("goblin_tribe"), 0.0))
    _check(is_equal_approx(human.faction_standing("thieves_guild"), 0.0))
    _check(is_equal_approx(human.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0))

    var goblin := CampaignJournal.new()
    HOLLOWMERE_CONTENT.initialize_social_standings(goblin, "goblin")
    _check(is_equal_approx(goblin.faction_standing("goblin_tribe"), 5.0))
    _check(is_equal_approx(goblin.faction_standing("orc_raiders"), 15.0))
    _check(is_equal_approx(goblin.faction_standing("silverhart_kingdom"), -15.0))
    _check(is_equal_approx(goblin.faction_standing("ironbond_company"), -15.0))
    _check(is_equal_approx(goblin.faction_standing("dwarven_kingdom"), -15.0))
    _check(is_equal_approx(goblin.faction_standing("elven_realm"), -15.0))
    _check(is_equal_approx(goblin.faction_standing("necromancer_cult"), 0.0))
    _check(is_equal_approx(goblin.faction_standing("thieves_guild"), 0.0))

    var orc := CampaignJournal.new()
    HOLLOWMERE_CONTENT.initialize_social_standings(orc, "orc")
    _check(is_equal_approx(orc.faction_standing("orc_raiders"), 5.0))
    _check(is_equal_approx(orc.faction_standing("goblin_tribe"), 15.0))

    var elf := CampaignJournal.new()
    HOLLOWMERE_CONTENT.initialize_social_standings(elf, "elf")
    _check(is_equal_approx(elf.faction_standing("elven_realm"), 5.0))
    _check(is_equal_approx(elf.faction_standing("silverhart_kingdom"), 0.0))

    var dwarf := CampaignJournal.new()
    HOLLOWMERE_CONTENT.initialize_social_standings(dwarf, "dwarf")
    _check(is_equal_approx(dwarf.faction_standing("dwarven_kingdom"), 5.0))


func _test_goblin_to_orc_reputation_cascade() -> void:
    var journal := CampaignJournal.new()
    journal.seed_faction_reputation("goblin_tribe", 0.0, 0.0)
    journal.seed_faction_reputation("orc_raiders", 0.0, 0.0)
    var result := journal.adjust_faction_reputation("goblin_tribe", 20.0, 10.0, "helped the Skarn-tooth tribe")
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
    journal.advance_faction_agendas(3599.6)
    _check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0))
    journal.advance_faction_agendas(0.4)
    _check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.02), "A thriving Ironbond agenda adds 0.02 influence per hour")

    journal.adjust_faction_reputation("ironbond_company", -40.0, 0.0, "the Company lost standing")
    journal.advance_faction_agendas(3600.0)
    _check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.0), "A struggling Ironbond agenda loses 0.02 influence per hour")

    journal.adjust_merchant_influence("ironbond_company", "silverhart_kingdom", 69.99, "clamp test")
    journal.adjust_faction_reputation("ironbond_company", 40.0, 0.0, "the Company recovered")
    journal.advance_faction_agendas(3600.0)
    _check(is_equal_approx(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 100.0), "Autonomous influence remains clamped to 0..100")


func _test_agenda_progress_survives_save_load() -> void:
    var source := CampaignJournal.new()
    source.seed_faction_reputation("ironbond_company", 20.0, 0.0)
    source.seed_merchant_influence("ironbond_company", "silverhart_kingdom", 30.0)
    source.advance_faction_agendas(1800.0)

    var restored := CampaignJournal.new()
    restored.load_dict(source.to_dict())
    restored.advance_faction_agendas(1800.0)
    _check(is_equal_approx(restored.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.02), "Partial agenda time survives campaign save/load")
    _check(is_equal_approx(restored.faction_agenda_elapsed_seconds, 0.0))


func _test_world_clock_drives_agendas() -> void:
    var simulation := WorldSimulation.new()
    simulation.campaign_journal.seed_faction_reputation("ironbond_company", 20.0, 0.0)
    simulation.campaign_journal.seed_merchant_influence("ironbond_company", "silverhart_kingdom", 30.0)
    simulation.clock.advance_world_seconds(3600.0)
    _check(is_equal_approx(simulation.campaign_journal.merchant_influence_for("ironbond_company", "silverhart_kingdom"), 30.02), "The authoritative campaign clock advances faction agendas")
    simulation.free()
