extends SceneTree

var _failures: int = 0

func _initialize() -> void:
    _test_campaign_journal()
    _test_hollowmere_campaign_content()
    _test_companion_campaign_dialogue_and_recruitment()
    _test_farmstead_dire_wolf_encounter()
    _test_hollowmere_encounter()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Campaign content tests passed.")
    quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
    if not condition:
        _failures += 1
        push_error(message)
func _has_companion_recruit_choice(conversation: Dictionary) -> bool:
    for choice_value in conversation.get("choices", []):
        var choice: Dictionary = choice_value
        if String(choice.get("id", "")).begins_with("recruit:"):
            return true
    return false
func _test_campaign_journal() -> void:
    var journal := CampaignJournal.new()
    var intro_definition := {
        "id": "hollowmere_arrival",
        "title": "A Place to Begin",
        "objectives": [
            {"id": "speak_to_garrick", "target": 1, "required": true}
        ]
    }
    var opening_definition := {
        "id": "ironbond_shakedown",
        "title": "The Ironbond Shakedown",
        "prerequisites": ["hollowmere_arrival"],
        "objectives": [
            {"id": "hear_the_demand", "target": 1, "required": true},
            {"id": "gather_witnesses", "target": 2, "required": true},
            {"id": "keep_patron_safe", "target": 1, "required": false}
        ]
    }
    _check(bool(journal.register_quest_definition(intro_definition).get("ok", false)))
    _check(bool(journal.register_quest_definition(opening_definition).get("ok", false)))
    _check(String(journal.register_quest_definition(opening_definition).get("reason", "")) == "duplicate_quest_definition")
    _check(String(journal.start_quest("missing_quest").get("reason", "")) == "unknown_quest")
    _check(String(journal.start_quest("ironbond_shakedown").get("reason", "")) == "prerequisite_incomplete")

    _check(bool(journal.start_quest("hollowmere_arrival").get("ok", false)))
    _check(bool(journal.set_objective_progress("hollowmere_arrival", "speak_to_garrick", 1.0).get("completed", false)))
    _check(bool(journal.complete_quest("hollowmere_arrival").get("ok", false)))
    _check(bool(journal.start_quest("ironbond_shakedown").get("ok", false)))

    _check(bool(journal.set_objective_progress("ironbond_shakedown", "hear_the_demand", 5.0).get("completed", false)), "Objective progress clamps to its target")
    _check(String(journal.complete_quest("ironbond_shakedown").get("reason", "")) == "required_objectives_incomplete", "Required objectives block quest completion")
    _check(bool(journal.set_objective_progress("ironbond_shakedown", "gather_witnesses", 1.0).get("ok", false)))
    _check(not bool(journal.complete_quest("ironbond_shakedown").get("ok", false)))
    _check(bool(journal.set_objective_progress("ironbond_shakedown", "gather_witnesses", 2.0).get("completed", false)))
    _check(bool(journal.record_decision("ironbond_shakedown", "response_to_demand", "stand_with_townsfolk").get("ok", false)))
    _check(String(journal.record_decision("ironbond_shakedown", "response_to_demand", "pay_the_company").get("reason", "")) == "decision_already_recorded")

    _check(int(journal.adjust_faction_standing("ironbond_company", -2, "defied the shakedown").get("current", 0)) == -2)
    _check(int(journal.adjust_faction_standing("hollowmere", 1, "stood with the villagers").get("current", 0)) == 1)
    _check(bool(journal.complete_quest("ironbond_shakedown").get("ok", false)), "Optional objectives do not block completion")
    _check(String(journal.quest_state("ironbond_shakedown").get("status", "")) == "completed")
    _check(journal.faction_standing("ironbond_company") == -2)

    var saved := journal.to_dict()
    var restored := CampaignJournal.new()
    restored.register_quest_definition(intro_definition)
    restored.register_quest_definition(opening_definition)
    restored.load_dict(saved)
    _check(restored.to_dict() == saved, "Quest states, decisions and standings survive serialization")

    var simulation := WorldSimulation.new()
    var forwarded: Array = []
    simulation.action_committed.connect(func(event: SimulationEvent) -> void:
        forwarded.append(event)
    )
    simulation.campaign_journal.register_quest_definition(intro_definition)
    simulation.campaign_journal.start_quest("hollowmere_arrival")
    _check(not forwarded.is_empty(), "Journal events flow through the simulation event stream")
    _check(String(forwarded[0].event_type) == "quest_started")

func _test_hollowmere_campaign_content() -> void:
    var definition := HollowmereCampaignContent.shakedown_quest_definition()
    _check(String(definition.get("id", "")) == HollowmereCampaignContent.QUEST_ID, "Hollowmere shakedown must have a stable quest ID")
    _check(definition.get("objectives", []).size() == 1, "Shakedown should have one required response objective")

    var opening := HollowmereCampaignContent.opening_lines()
    _check(opening.size() == 4, "Opening should preserve narrator, Dray, Garrick and Dray's threat lines")
    _check(String(opening[1].get("speaker_id", "")) == "dray_coltayne")
    _check(String(opening[2].get("speaker_id", "")) == "garrick_holt")

    var choices := HollowmereCampaignContent.shakedown_choices()
    _check(choices.size() == 3, "Original shakedown should retain all three response branches")
    _check(bool(choices[0].get("available", false)), "Stay out branch should be available")
    _check(bool(choices[1].get("available", false)), "Encourage pay branch should be available")
    _check(bool(choices[2].get("available", false)), "Fight branch should be available now that the encounter is implemented")
    _check(int(choices[0].get("ironbond_delta", 0)) == 5)
    _check(int(choices[1].get("ironbond_delta", 0)) == 15)
    _check(int(choices[2].get("ironbond_delta", 0)) == -35)

    var journal := CampaignJournal.new()
    journal.register_quest_definition(definition)
    _check(bool(journal.start_quest(HollowmereCampaignContent.QUEST_ID).get("ok", false)))
    var stay_out := HollowmereCampaignContent.resolve_shakedown(journal, "stay_out")
    _check(bool(stay_out.get("ok", false)), "Stay-out choice should resolve through the campaign journal")
    _check(journal.faction_standing("ironbond_company") == 10.0, "Stay-out should apply the source Ironbond standing change")
    _check(journal.npc_standing("garrick_holt") == -5.0, "Staying out should lower Garrick's standing")
    _check(journal.npc_standing("mira_ashbrook") == 0.0 and journal.npc_standing("oskar_vinn") == 0.0, "Staying out should disappoint the two tavern patrons")
    _check(journal.npc_standing("hollowmere_elder") == 1.0, "The elder should receive the 40 percent authority-cascade ripple")
    _check(is_equal_approx(journal.npc_standing("hollowmere_baron"), 3.4), "The baron should receive the second authority-cascade ripple")
    _check(is_equal_approx(journal.faction_standing("silverhart_kingdom"), 4.36), "The kingdom should receive the faint third authority-cascade ripple")
    _check(journal.merchant_influence_for("ironbond_company", "silverhart_kingdom") == 31.0)
    var restored_journal := CampaignJournal.new()
    restored_journal.register_quest_definition(definition)
    restored_journal.load_dict(journal.to_dict())
    _check(restored_journal.npc_standing("garrick_holt") == -5.0, "Individual NPC standing must survive journal serialization")
    _check(restored_journal.npc_knowledge.get("garrick_holt", -1.0) == 10.0, "NPC knowledge must survive journal serialization")
    _check(restored_journal.merchant_influence_for("ironbond_company", "silverhart_kingdom") == 31.0, "Merchant influence must survive journal serialization")
    _check(String(journal.quest_state(HollowmereCampaignContent.QUEST_ID).get("status", "")) == "completed")
    _check(String(journal.quest_state(HollowmereCampaignContent.QUEST_ID).get("decisions", {}).get("response", "")) == "stay_out")

    var second_journal := CampaignJournal.new()
    second_journal.register_quest_definition(definition)
    second_journal.start_quest(HollowmereCampaignContent.QUEST_ID)
    var encourage := HollowmereCampaignContent.resolve_shakedown(second_journal, "encourage_pay")
    _check(bool(encourage.get("ok", false)))
    _check(second_journal.faction_standing("ironbond_company") == 20.0)
    _check(second_journal.npc_standing("garrick_holt") == 10.0)
    _check(second_journal.npc_standing("mira_ashbrook") == 5.0 and second_journal.npc_standing("oskar_vinn") == 5.0)
    _check(is_equal_approx(second_journal.npc_standing("hollowmere_elder"), 7.0))
    _check(is_equal_approx(second_journal.npc_standing("hollowmere_baron"), 5.8))
    _check(is_equal_approx(second_journal.faction_standing("silverhart_kingdom"), 5.32))
    _check(second_journal.merchant_influence_for("ironbond_company", "silverhart_kingdom") == 32.0)
    _check(String(second_journal.quest_state(HollowmereCampaignContent.QUEST_ID).get("decisions", {}).get("ironbond_arc_side", "")) == "ironbond")
    var fight_journal := CampaignJournal.new()
    fight_journal.register_quest_definition(definition)
    fight_journal.start_quest(HollowmereCampaignContent.QUEST_ID)
    var fight_result := HollowmereCampaignContent.apply_shakedown_choice(fight_journal, "fight")
    _check(bool(fight_result.get("ok", false)), "The fight branch should apply its consequences when combat begins")
    _check(String(fight_journal.quest_state(HollowmereCampaignContent.QUEST_ID).get("status", "")) == "active", "The fight quest should remain active until the encounter is won")
    _check(bool(HollowmereCampaignContent.complete_shakedown(fight_journal).get("ok", false)), "The fight quest should complete after victory")
    _check(fight_journal.faction_standing("ironbond_company") == -30.0)
    _check(fight_journal.npc_standing("garrick_holt") == 30.0 and fight_journal.npc_standing("mira_ashbrook") == 25.0)
    _check(fight_journal.npc_standing("hollowmere_elder") == 15.0)
    _check(fight_journal.npc_standing("hollowmere_baron") == 9.0)
    _check(is_equal_approx(fight_journal.faction_standing("silverhart_kingdom"), 6.6))
    _check(fight_journal.merchant_influence_for("ironbond_company", "silverhart_kingdom") == 28.0)
    var dwarf_journal := CampaignJournal.new()
    HollowmereCampaignContent.initialize_social_standings(dwarf_journal, "dwarf")
    _check(dwarf_journal.faction_standing("ironbond_company") == 0.0, "Dwarven characters should not inherit human faction standing")
    var orc_journal := CampaignJournal.new()
    HollowmereCampaignContent.initialize_social_standings(orc_journal, "orc")
    _check(orc_journal.faction_standing("ironbond_company") == -15.0, "Orc characters should start hostile to the human Ironbond Company")
    var known_journal := CampaignJournal.new()
    known_journal.seed_npc_reputation("known_npc", 0.0, 100.0)
    known_journal.adjust_npc_reputation("known_npc", 10.0, 0.0, "dampening test")
    _check(is_equal_approx(known_journal.npc_standing("known_npc"), 3.0), "Known relationships should dampen reputation swings to 30 percent")
    _check(not bool(HollowmereCampaignContent.resolve_shakedown(second_journal, "fight").get("ok", false)), "A second branch cannot overwrite the recorded response")

    var garrick := HollowmereCampaignContent.npc_greeting("garrick_holt", false)
    _check(String(garrick.get("speaker", "")) == "Garrick Holt")
    var disappointed_garrick := HollowmereCampaignContent.npc_greeting("garrick_holt", true, -5.0, "stay_out")
    _check(String(disappointed_garrick.get("text", "")).contains("stood aside"), "Garrick should react personally to the stay-out branch")
    var grateful_garrick := HollowmereCampaignContent.npc_greeting("garrick_holt", true, 30.0, "fight")
    _check(String(grateful_garrick.get("text", "")).contains("stood up"), "Garrick should react personally to the fight branch")
    _check(garrick.get("choices", []).size() >= 2, "Garrick should offer the Ironbond question and local news")

    var exchanges := HollowmereCampaignContent.ambient_exchanges()
    _check(exchanges.size() >= 40, "Hollowmere should have a broad set of ambient exchanges")
    var has_aftermath := false
    for exchange_value in exchanges:
        var exchange: Dictionary = exchange_value
        if String(exchange.get("id", "")) == "ironbond_aftermath":
            has_aftermath = true
    _check(has_aftermath, "Ambient content should include the Ironbond aftermath conversation")

    var chatter := AmbientChatter.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 9127
    var first := chatter.choose_exchange("mira_ashbrook", "oskar_vinn", "civilian", "civilian", 100.0, 12, 50, false, rng)
    _check(not first.is_empty(), "Nearby NPC pair should receive an eligible daytime exchange")
    _check(String(first.get("id", "")) != "ironbond_aftermath", "Unresolved shakedown chatter must not leak early")
    chatter.record_exchange(first, "mira_ashbrook", "oskar_vinn", 100.0)
    var blocked := chatter.choose_exchange("oskar_vinn", "mira_ashbrook", "civilian", "civilian", 150.0, 12, 50, false, rng)
    _check(blocked.is_empty(), "The same NPC pair should observe the 120-second cooldown")
    var aftermath := {
        "id": "ironbond_aftermath",
        "topic": "ironbond-aftermath",
        "roles": ["any"],
        "requires_shakedown": true
    }
    _check(not chatter._is_eligible(aftermath, "civilian", "civilian", 12, 50, false), "Event chatter must be gated until the shakedown resolves")
    _check(chatter._is_eligible(aftermath, "civilian", "civilian", 12, 50, true), "Event chatter should unlock after the shakedown resolves")
    var fight_only := {"id": "fight_after", "topic": "ironbond", "roles": ["any"], "requires_shakedown": true, "shakedown_choice": "fight"}
    _check(not chatter._is_eligible(fight_only, "civilian", "civilian", 12, 50, false, "fight"))
    _check(not chatter._is_eligible(fight_only, "civilian", "civilian", 12, 50, true, "stay_out"))
    _check(chatter._is_eligible(fight_only, "civilian", "civilian", 12, 50, true, "fight"), "Outcome-specific chatter should unlock only for its matching branch")
    var wick := HollowmereCampaignContent.npc_greeting("wick_hallow", false)
    _check(String(wick.get("speaker", "")) == "Wick Hallow", "Wick should have a real talk tree")
    var night_exchange := {"id": "night", "topic": "time", "roles": ["any"], "hour_start": 21, "hour_end": 5}
    _check(chatter._is_eligible(night_exchange, "civilian", "civilian", 23, 50, false), "Night chatter should wrap across midnight")
    _check(not chatter._is_eligible(night_exchange, "civilian", "civilian", 12, 50, false), "Night chatter should not run at midday")

func _test_companion_campaign_dialogue_and_recruitment() -> void:
    var journal := CampaignJournal.new()
    CompanionCampaignContent.register_quest_definitions(journal)
    _check(journal.quest_definitions.size() >= 8, "All companion recruitment quests should be registered")
    var empty_inventory: Array[Dictionary] = []
    var no_party: Array[String] = []

    var aldric_before := CompanionCampaignContent.conversation("ser_aldric_thorne", journal, empty_inventory, no_party)
    _check(not _has_companion_recruit_choice(aldric_before), "Aldric must not recruit before being freed")
    _check(bool(journal.start_quest("aldric_rescue").get("ok", false)))
    _check(bool(CompanionCampaignContent.complete_objective(journal, "aldric_rescue", "freed").get("ok", false)))
    var aldric_after := CompanionCampaignContent.conversation("ser_aldric_thorne", journal, empty_inventory, no_party)
    _check(_has_companion_recruit_choice(aldric_after), "Aldric should offer to join after rescue")
    _check(CompanionCampaignContent.is_companion_id("companion_ser_aldric_thorne"), "Manifest game IDs must resolve to companion dialogue")
    _check(_has_companion_recruit_choice(CompanionCampaignContent.conversation("companion_ser_aldric_thorne", journal, empty_inventory, no_party)), "Manifest game IDs must resolve to the correct recruitment state")

    _check(bool(journal.start_quest("goblin_threat").get("ok", false)))
    _check(bool(CompanionCampaignContent.complete_with_decision(journal, "goblin_threat", "resolved", "resolution", "goblin_alliance").get("ok", false)))
    var nix_after := CompanionCampaignContent.conversation("nix_sharpear", journal, empty_inventory, no_party)
    _check(_has_companion_recruit_choice(nix_after), "Nix should join only after the peaceful goblin alliance")

    _check(bool(journal.start_quest("orc_stronghold_trust").get("ok", false)))
    _check(bool(CompanionCampaignContent.complete_objective(journal, "orc_stronghold_trust", "troll_slain").get("ok", false)))
    var grukk_without_trust := CompanionCampaignContent.conversation("warlord_grukk_ironhide", journal, empty_inventory, no_party)
    _check(not _has_companion_recruit_choice(grukk_without_trust), "Grukk must require deeper orc faction trust after the troll quest")
    journal.adjust_faction_standing("orc_raiders", 40, "companion recruitment test")
    var grukk_with_trust := CompanionCampaignContent.conversation("warlord_grukk_ironhide", journal, empty_inventory, no_party)
    _check(_has_companion_recruit_choice(grukk_with_trust), "Grukk should offer to join at 40 orc standing")

    _check(bool(journal.start_quest("reyna_dire_wolf_hunt").get("ok", false)))
    _check(not _has_companion_recruit_choice(CompanionCampaignContent.conversation("reyna_fletcher", journal, empty_inventory, no_party)), "Reyna must not recruit before Tessa is rescued and the dire wolf is defeated")
    _check(bool(journal.set_objective_progress("reyna_dire_wolf_hunt", "trail_found", 1.0).get("ok", false)))
    _check(bool(journal.set_objective_progress("reyna_dire_wolf_hunt", "child_rescued", 1.0).get("ok", false)))
    _check(not _has_companion_recruit_choice(CompanionCampaignContent.conversation("reyna_fletcher", journal, empty_inventory, no_party)), "Rescuing Tessa alone must not unlock Reyna")
    _check(bool(CompanionCampaignContent.complete_objective(journal, "reyna_dire_wolf_hunt", "dire_wolf_slain").get("ok", false)))
    _check(_has_companion_recruit_choice(CompanionCampaignContent.conversation("reyna_fletcher", journal, empty_inventory, no_party)), "Reyna should recruit only after the rescue and dire wolf hunt")
    _check(_has_companion_recruit_choice(CompanionCampaignContent.conversation("companion_reyna_fletcher", journal, empty_inventory, no_party)), "Reyna's manifest game ID must resolve to her recruitment dialogue")

    _check(bool(journal.start_quest("mirabel_spider_ruin").get("ok", false)))
    _check(bool(CompanionCampaignContent.complete_objective(journal, "mirabel_spider_ruin", "nest_cleared").get("ok", false)))
    _check(_has_companion_recruit_choice(CompanionCampaignContent.conversation("mirabel_quill", journal, empty_inventory, no_party)), "Mirabel should join after the ruin is cleared")

    _check(bool(journal.start_quest("fenn_herb_gathering").get("ok", false)))
    var two_herbs: Array[Dictionary] = [{"id":"herbs","quantity":2,"instance_id":"herbs_a"}]
    _check(not _has_companion_recruit_choice(CompanionCampaignContent.conversation("fenn_oakheart", journal, two_herbs, no_party)), "Fenn should require all three herb bundles")
    var three_herbs: Array[Dictionary] = [{"id":"herbs","quantity":3,"instance_id":"herbs_a"}]
    _check(_has_companion_recruit_choice(CompanionCampaignContent.conversation("fenn_oakheart", journal, three_herbs, no_party)), "Fenn should offer to join when three herbs are available")

    _check(bool(journal.start_quest("northwatch_siege").get("ok", false)))
    _check(bool(CompanionCampaignContent.complete_objective(journal, "northwatch_siege", "defended").get("ok", false)))
    _check(_has_companion_recruit_choice(CompanionCampaignContent.conversation("brother_alden", journal, empty_inventory, no_party)), "Alden should offer to join after Northwatch is defended")

    _check(bool(journal.start_quest("star_fort_companion").get("ok", false)))
    _check(bool(CompanionCampaignContent.complete_with_decision(journal, "star_fort_companion", "greenskin_resolution", "side", "greenskin").get("ok", false)))
    _check(_has_companion_recruit_choice(CompanionCampaignContent.conversation("snik_fangtooth", journal, empty_inventory, no_party)), "Snik should offer to join only after the greenskin Star Fort outcome")

    var restored := CampaignJournal.new()
    CompanionCampaignContent.register_quest_definitions(restored)
    restored.load_dict(journal.to_dict())
    _check(_has_companion_recruit_choice(CompanionCampaignContent.conversation("nix_sharpear", restored, empty_inventory, no_party)), "Companion quest outcomes should persist through journal save/load")
    _check(_has_companion_recruit_choice(CompanionCampaignContent.conversation("reyna_fletcher", restored, empty_inventory, no_party)), "Reyna's staged rescue outcome should persist through journal save/load")

func _test_farmstead_dire_wolf_encounter() -> void:
    var simulation := WorldSimulation.new()
    var player := CharacterState.new("player", "Adventurer", Vector2i(0, 0))
    player.side = "player"
    var wren := CharacterState.new("companion_wren_talbot", "Wren Talbot", Vector2i(1, 0))
    wren.side = "player"
    var civilian := CharacterState.new("farmstead_civilian_test", "Civilian", Vector2i(2, 0))
    civilian.side = "neutral"
    var unrelated_enemy := CharacterState.new("unrelated_enemy_test", "Unrelated Enemy", Vector2i(3, 0))
    unrelated_enemy.side = "enemy"
    unrelated_enemy.combat_dormant = true
    simulation.register_character(player)
    simulation.register_character(wren)
    simulation.register_character(civilian)
    simulation.register_character(unrelated_enemy)
    var wolf_result := FarmsteadDireWolfEncounter.create_dire_wolf(simulation, Vector2i(5, 5))
    _check(bool(wolf_result.get("ok", false)), "The dire wolf should be registered")
    var party_ids: Array[String] = ["player", "companion_wren_talbot"]
    var start := FarmsteadDireWolfEncounter.start(simulation, party_ids)
    _check(bool(start.get("ok", false)), "The dire wolf encounter should start")
    _check(simulation.is_in_combat, "The dire wolf hunt should use the shared combat scheduler")
    var wolf := simulation.get_character(FarmsteadDireWolfEncounter.DIRE_WOLF_ID)
    _check(wolf.max_health == 150 and wolf.health == 150, "Dire wolf Health ranks should apply exactly once")
    _check(civilian.combat_dormant and unrelated_enemy.combat_dormant, "Non-party actors should be excluded during combat")
    wolf.apply_damage(1000)
    simulation.end_combat()
    FarmsteadDireWolfEncounter.finish(simulation, party_ids, start.get("previous_states", {}))
    _check(not civilian.combat_dormant and civilian.side == "neutral", "Civilian world state should be restored")
    _check(unrelated_enemy.combat_dormant and unrelated_enemy.side == "enemy", "Existing dormant enemy state should be preserved")
    _check(wolf.combat_dormant and wolf.side == "enemy", "Dire wolf should return to its dormant enemy state")
    simulation.free()

func _test_hollowmere_encounter() -> void:
    var simulation := WorldSimulation.new()
    var player := CharacterState.new("player", "Adventurer", Vector2i(0, 0))
    player.side = "player"
    player.time_points = 151.0
    simulation.register_character(player)
    var wren := CharacterState.new("companion_wren_talbot", "Wren Talbot", Vector2i(1, 0))
    simulation.register_character(wren)
    for entry in [["dray_coltayne", Vector2i(0, 1)], ["tomlin_brask", Vector2i(1, 1)], ["hask_greel", Vector2i(2, 1)]]:
        var enemy := CharacterState.new(String(entry[0]), String(entry[0]), entry[1])
        simulation.register_character(enemy)
    var garrick := CharacterState.new("garrick_holt", "Garrick Holt", Vector2i(3, 1))
    simulation.register_character(garrick)
    var mira := CharacterState.new("mira_ashbrook", "Mira Ashbrook", Vector2i(4, 1))
    simulation.register_character(mira)
    var oskar := CharacterState.new("oskar_vinn", "Oskar Vinn", Vector2i(5, 1))
    simulation.register_character(oskar)
    var bystander := CharacterState.new("wick_hallow", "Wick Hallow", Vector2i(6, 1))
    simulation.register_character(bystander)
    var started := HollowmereEncounter.start(simulation)
    _check(bool(started.get("ok", false)), "Hollowmere encounter should start with its authored cast")
    _check(simulation.is_in_combat)
    _check(player.side == "player" and wren.side == "player")
    _check(not player.combat_dormant and not wren.combat_dormant)
    _check(simulation.get_character("dray_coltayne").side == "enemy")
    _check(not simulation.get_character("dray_coltayne").combat_dormant)
    _check(simulation.get_character("dray_coltayne").health == 130)
    _check(is_equal_approx(simulation.get_character("dray_coltayne").time_points, 100.0), "Encounter combatants should begin at 100 TP")
    _check(is_equal_approx(garrick.time_points, 100.0), "Authored allies should begin at 100 TP")
    _check(garrick.side == "player" and mira.side == "player" and oskar.side == "player", "Garrick, Mira and Oskar should join the player side")
    _check(not garrick.combat_dormant and not mira.combat_dormant and not oskar.combat_dormant, "Tavern allies should receive AI combat turns")
    _check(bystander.combat_dormant and bystander.side == "neutral", "Other tavern bystanders must not enter combat initiative")
    simulation.advance_world_seconds(0.1)
    _check(simulation.get_current_turn_character() == player, "Highest-TP player should receive the first test turn")
    var attack := simulation.try_attack_character("player", "hask_greel", {"time_point_cost": 10.0, "weapon_id": "sword"}, 9127)
    _check(bool(attack.get("ok", false)), "The encounter should use the real WorldSimulation attack resolver")
    _check(player.time_points == 141.0, "The main attack should consume the source 10 TP cost")
    simulation.turn_scheduler.current_character_id = "garrick_holt"
    var ally_attack := simulation.try_attack_character("garrick_holt", "hask_greel", {"time_point_cost": 10.0, "weapon_id": "club"}, 9128)
    _check(bool(ally_attack.get("ok", false)), "Garrick should use the same simulation attack resolver as the player")
    _check(garrick.time_points == 90.0, "Garrick starts at 100 TP and spends 10 TP on his attack")
    _check(simulation.try_end_current_turn(true))
    _check(garrick.time_points == 80.0, "AI allies should forfeit unused TP after their single action")
    _check(not HollowmereEncounter.enemies_defeated(simulation))
    _check(not HollowmereEncounter.party_defeated(simulation))
    simulation.get_character("dray_coltayne").apply_damage(1000)
    simulation.get_character("tomlin_brask").apply_damage(1000)
    simulation.get_character("hask_greel").apply_damage(1000)
    _check(HollowmereEncounter.enemies_defeated(simulation), "Downed or dead Ironbond soldiers should end the encounter")
    _check(not HollowmereEncounter.party_defeated(simulation))
    simulation.get_character("player").apply_damage(1000)
    simulation.get_character("companion_wren_talbot").apply_damage(1000)
    _check(not HollowmereEncounter.party_defeated(simulation), "The three tavern allies should be able to keep fighting after the main pair fall")
    garrick.apply_damage(1000)
    mira.apply_damage(1000)
    oskar.apply_damage(1000)
    _check(HollowmereEncounter.party_defeated(simulation), "The encounter should detect all five player-side combatants defeated")
    HollowmereEncounter.finish(simulation)
    _check(garrick.side == "neutral" and garrick.combat_dormant, "Defenders should return to neutral NPC status after combat")
    _check(player.side == "player" and not player.combat_dormant, "The player should remain an active party character")
    simulation.end_combat()
    simulation.free()
