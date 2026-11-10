extends SceneTree

const INITIATIVE_MODEL = preload("res://scripts/ui/combat_initiative_model.gd")

var _failures: int = 0

func _initialize() -> void:
    _test_character_round_trip()
    _test_campaign_journal()
    _test_hollowmere_campaign_content()
    _test_hollowmere_encounter()
    _test_race_class_character_creation()
    _test_item_catalog_and_hollowmere_loadouts()
    _test_equipped_item_combat_effects()
    _test_movement_validation()
    _test_time_point_rules()
    _test_action_movement_cost()
    _test_terrain_pathfinding()
    _test_elevation_rules()
    _test_world_clock()
    _test_wilderness_resources_and_chunk_streaming()
    _test_combat_turn_scheduler()
    _test_initiative_timeline_model()
    _test_combat_resolution()
    _test_downed_and_death_lifecycle()
    _test_unified_action_contract()
    _test_attack_waits_for_parry_resolution()
    _test_protector_ally_parry()
    _test_shield_other_reduces_one_attack()
    _test_spear_halt_commits_one_step_then_stops()
    _test_spear_intercept_resolves_before_movement()
    _test_sidestep_uses_a_second_stage_destination()
    _test_reaction_resolution_safety()
    _test_incapacitated_turn_cleanup()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
        return
    print("WorldSimulation tests passed.")
    quit(0)


func _test_wilderness_resources_and_chunk_streaming() -> void:
    var simulation := WorldSimulation.new()
    var player := CharacterState.new("gatherer", "Gatherer", Vector2i(0, 0))
    var pickaxe := ItemCatalog.create_instance("pickaxe", "test_pickaxe")
    _check(player.add_inventory_item(pickaxe), "Gatherer should be able to carry a pickaxe")
    simulation.register_character(player)
    var ore_hex := Vector2i(60, 60)
    simulation.map_data.add_cell(ore_hex, 0.0, true, "rocky_outcrop")
    simulation.wilderness_resources.nodes["60,60"] = {
        "type": "ore_node", "item_id": "ore_gold", "depleted": false, "regrow_at": 0.0
    }
    var mined := simulation.harvest_resource_at("gatherer", ore_hex)
    _check(bool(mined.get("ok", false)), "Pickaxe should unlock ore harvesting")
    _check(int(mined.get("amount", 0)) >= 1, "Mining should produce at least one ore item")
    _check(bool(simulation.wilderness_resources.nodes["60,60"].get("depleted", false)), "Mined ore should deplete")
    var saved := simulation.to_dict()
    var restored := WorldSimulation.new()
    restored.load_dict(saved)
    _check(bool(restored.wilderness_resources.nodes["60,60"].get("depleted", false)), "Resource depletion must survive save/load")
    restored.wilderness_resources.advance_time(72.0 * WorldClock.SECONDS_PER_HOUR)
    _check(not bool(restored.wilderness_resources.nodes["60,60"].get("depleted", true)), "Ore should regenerate after 72 game hours")

    var chunks := HexWorldChunkStreamer.new()
    var map := HexMapData.new()
    chunks.load_around(map, Vector2i(100, 100))
    _check(chunks.active_chunk_count() == 9, "A radius-one load should activate nine chunks")
    _check(map.has_cell(Vector2i(100, 100)), "The active region should contain its centre hex")
    var terrain_a := HexWorldChunkStreamer.terrain_for_hex(Vector2i(100, 100), 1)
    var terrain_b := HexWorldChunkStreamer.terrain_for_hex(Vector2i(100, 100), 1)
    _check(terrain_a == terrain_b, "Chunk terrain must be deterministic for a stable world seed")
    chunks.load_around(map, Vector2i(300, 300))
    _check(chunks.active_chunk_count() == 9, "Moving far away should keep the active chunk budget bounded")
    _check(not map.has_cell(Vector2i(100, 100)), "Old generated chunks should unload when outside the active region")

func _check(condition: bool, message: String = "Assertion failed") -> void:
    if not condition:
        _failures += 1
        push_error(message)


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
    _check(simulation.get_character("dray_coltayne").time_points == simulation.get_character("dray_coltayne").max_time_points)
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
    _check(garrick.time_points == 140.0)
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

func _test_character_round_trip() -> void:
    var original := CharacterState.new("npc_garrick_holt", "Garrick Holt", Vector2i(2, -1))
    original.health = 73
    original.time_points = 87.5
    original.time_points_per_tick = 1.25
    original.total_time_points_spent = 42.0
    original.quick_recovery_rank = 4
    original.skills["fastMovement"] = 2
    original.equipment["armour"] = "light_armor"
    var restored := CharacterState.from_dict(original.to_dict())
    _check(restored.id == original.id)
    _check(restored.display_name == original.display_name)
    _check(restored.axial == original.axial)
    _check(restored.health == 73)
    _check(is_equal_approx(restored.time_points, 87.5))
    _check(is_equal_approx(restored.time_points_per_tick, 1.25))
    _check(is_equal_approx(restored.total_time_points_spent, 42.0))
    _check(restored.quick_recovery_rank == 4)
    _check(int(restored.skills["fastMovement"]) == 2)
    _check(String(restored.equipment["armour"]) == "light_armor")
    original.parries_remaining = 1
    original.sidesteps_remaining = 2
    restored = CharacterState.from_dict(original.to_dict())
    _check(restored.parries_remaining == 1, "Parry allowance must survive character serialization")
    _check(restored.sidesteps_remaining == 2, "Sidestep allowance must survive character serialization")
    var carried_sword := {
        "instance_id": "item_sword_001",
        "id": "sword",
        "name": "Short sword",
        "type": "weapon",
        "equipment_slot": "weapon",
        "quantity": 1,
        "description": "A practical one-handed blade."
    }
    _check(original.add_inventory_item(carried_sword), "Character should accept a valid item instance")
    _check(not original.add_inventory_item(carried_sword), "Duplicate item instance IDs must be rejected")
    _check(original.equip_inventory_item("item_sword_001"), "An item with an equipment slot should be equippable")
    _check(String(original.equipment.get("weapon", "")) == "sword")
    _check(original.inventory.is_empty())
    restored = CharacterState.from_dict(original.to_dict())
    _check(String(restored.equipment.get("weapon", "")) == "sword")
    _check(restored.equipped_item_data.has("weapon"), "Equipped item instance data must persist")
    _check(restored.unequip_equipment_slot("weapon"), "Equipped item should be unequippable")
    _check(restored.inventory.size() == 1, "Unequipped item should return to inventory")
    _check(restored.remove_inventory_item("item_sword_001"), "Inventory item should be removable")
    _check(restored.inventory.is_empty())

func _test_equipped_item_combat_effects() -> void:
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i.ZERO)
    attacker.base_damage = 1
    var sword := {
        "instance_id": "weapon_001",
        "id": "sword",
        "name": "Short sword",
        "type": "weapon",
        "equipment_slot": "weapon",
        "damage": 5,
        "quantity": 1
    }
    _check(attacker.add_inventory_item(sword))
    _check(attacker.equip_inventory_item("weapon_001"))
    _check(CombatRules.raw_damage(attacker) == 6, "Equipped weapon instance damage must affect combat")

    var armour := {
        "instance_id": "armour_001",
        "id": "leather_armour",
        "name": "Leather armour",
        "type": "armour",
        "equipment_slot": "armour",
        "weight_class": "light",
        "reduction": 3,
        "quantity": 1
    }
    var shield := {
        "instance_id": "shield_001",
        "id": "round_shield",
        "name": "Round shield",
        "type": "shield",
        "equipment_slot": "offhand",
        "reduction": 2,
        "quantity": 1
    }
    var defender := CharacterState.new("defender", "Defender", Vector2i(1, 0))
    _check(defender.add_inventory_item(armour))
    _check(defender.add_inventory_item(shield))
    _check(defender.equip_inventory_item("armour_001"))
    _check(defender.equip_inventory_item("shield_001"))
    _check(CombatRules.damage_reduction(defender) == 5, "Equipped armour and shield instance reductions must affect defence")
    _check(is_equal_approx(MovementRules.base_cost_for(defender), 5.0), "Light armour should not apply a heavy-armour movement penalty")
    var restored := CharacterState.from_dict(defender.to_dict())
    _check(restored.equipped_item_data.has("armour") and restored.equipped_item_data.has("offhand"), "Equipped item instances must survive save/load")
    _check(CombatRules.damage_reduction(restored) == 5)
    
func _test_movement_validation() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(2, 0), 0.0, false)
    sim.register_character(CharacterState.new("player", "Player", Vector2i.ZERO))
    _check(sim.try_move_character("player", Vector2i(1, 0)))
    _check(not sim.try_move_character("player", Vector2i(2, 0)))
    _check(not sim.try_move_character("player", Vector2i(3, 0)))
    _check(not sim.try_move_character("missing", Vector2i(0, 1)))
    sim.free()

func _test_time_point_rules() -> void:
    _check(not ActionEconomy.can_start_combat_turn(99.99))
    _check(ActionEconomy.can_start_combat_turn(100.0))
    _check(not ActionEconomy.can_start_combat_turn(120.0, false))
    _check(not ActionEconomy.can_start_combat_turn(120.0, true, true))
    _check(not ActionEconomy.can_start_combat_turn(120.0, true, false, true))
    _check(not ActionEconomy.can_start_combat_turn(120.0, true, false, false, true))
    _check(ActionEconomy.turn_end_threshold() == 80)
    _check(ActionEconomy.turn_end_threshold(5) == 75)
    _check(ActionEconomy.turn_end_threshold(99) == 60)
    _check(ActionEconomy.should_end_turn(80.9))
    _check(not ActionEconomy.should_end_turn(81.0))
    _check(ActionEconomy.should_end_turn(75.9, 5))
    _check(not ActionEconomy.should_end_turn(76.0, 5))
    _check(ActionEconomy.should_end_turn(140.0, 0, true))
    _check(is_equal_approx(ActionEconomy.regenerate(149.5), 150.5))
    _check(is_equal_approx(ActionEconomy.regenerate(150.0), 150.0))
    _check(is_equal_approx(ActionEconomy.regenerate(10.0, 0.5, 2.0), 11.0))
    _check(is_equal_approx(ActionEconomy.spend(10.0, 3.5), 6.5))
    _check(not ActionEconomy.can_afford(3.0, 5.0))

func _test_action_movement_cost() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(2, 0), 0.0, false)
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.time_points = 5.0
    sim.register_character(player)
    _check(sim.try_move_character_action("player", Vector2i(1, 0), 5.0))
    _check(player.axial == Vector2i(1, 0))
    _check(is_equal_approx(player.time_points, 0.0))
    _check(is_equal_approx(player.total_time_points_spent, 5.0))
    _check(not sim.try_move_character_action("player", Vector2i(0, 0), 1.0))
    _check(player.axial == Vector2i(1, 0))
    _check(is_equal_approx(player.time_points, 0.0))
    player.time_points = 10.0
    _check(not sim.try_move_character_action("player", Vector2i(2, 0), 5.0))
    _check(is_equal_approx(player.time_points, 10.0))
    sim.free()

func _test_terrain_pathfinding() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0), 0.0, false)
    sim.map_data.add_cell(Vector2i(2, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    sim.map_data.add_cell(Vector2i(1, 1))
    sim.map_data.add_cell(Vector2i(2, 1))
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.time_points = 20.0
    sim.register_character(player)
    var path := sim.find_path("player", Vector2i(2, 0))
    _check(path.size() == 4, "Pathfinder should route around blocked terrain")
    _check(path[0] == Vector2i.ZERO)
    _check(path[3] == Vector2i(2, 0))
    for i in range(1, path.size()):
        _check(HexGrid.distance(path[i - 1], path[i]) == 1)
    sim.map_data.add_cell(Vector2i(0, -1), 0.0, true, "forest")
    _check(is_equal_approx(sim.movement_cost("player", Vector2i(0, -1)), 7.5))
    player.skills["fastMovement"] = 2
    _check(is_equal_approx(sim.movement_cost("player", Vector2i(0, -1)), 4.5))
    _check(sim.try_move_character_step("player", Vector2i(0, 1)))
    _check(player.axial == Vector2i(0, 1))
    _check(is_equal_approx(player.time_points, 17.0))
    _check(is_equal_approx(player.total_time_points_spent, 3.0))
    sim.free()

func _test_elevation_rules() -> void:
    var map_data := HexMapData.new()
    map_data.add_cell(Vector2i(0, 0), 0.0)
    map_data.add_cell(Vector2i(1, 0), 0.5)
    map_data.add_cell(Vector2i(2, 0), 2.5)
    map_data.add_cell(Vector2i(3, 0), 6.5)
    var climber := CharacterState.new("climber", "Climber", Vector2i.ZERO)
    var gentle_cost := MovementRules.step_cost(map_data, Vector2i.ZERO, Vector2i(1, 0), climber)
    _check(gentle_cost > 5.0 and gentle_cost < 6.0, "Gentle uphill should add a modest movement cost")
    var steep_cost := MovementRules.step_cost(map_data, Vector2i(1, 0), Vector2i(2, 0), climber)
    _check(is_inf(steep_cost), "A climbable face should require climbing skill")
    climber.skills["climbing"] = 1
    steep_cost = MovementRules.step_cost(map_data, Vector2i(1, 0), Vector2i(2, 0), climber)
    _check(steep_cost > 10.0, "Climbing skill should make a steep face traversable at a high cost")
    var cliff_cost := MovementRules.step_cost(map_data, Vector2i(2, 0), Vector2i(3, 0), climber)
    _check(is_inf(cliff_cost), "A cliff should require expert climbing")
    climber.skills["climbing"] = 3
    cliff_cost = MovementRules.step_cost(map_data, Vector2i(2, 0), Vector2i(3, 0), climber)
    _check(cliff_cost > steep_cost, "Expert climbing should permit cliffs at a substantial cost")

    # Shared vertex coordinates must resolve to one sample across adjacent cells.
    map_data.set_vertex_height(Vector2i.ZERO, 0, 2.25)
    var shared := map_data.corner_world_position(Vector2i.ZERO, 0)
    var adjacent := map_data.corner_world_position(Vector2i(1, 0), 4)
    _check(is_equal_approx(shared.x, adjacent.x) and is_equal_approx(shared.z, adjacent.z))
    _check(is_equal_approx(shared.y, adjacent.y), "Adjacent hexes must share their edge vertex height")

func _test_world_clock() -> void:
    var clock := WorldClock.new()
    _check(clock.advance_world_seconds(0.39) == 0)
    _check(is_equal_approx(clock.world_seconds, 0.0))
    _check(clock.advance_world_seconds(0.01) == 1)
    _check(is_equal_approx(clock.world_seconds, 0.4))
    _check(clock.tick_index == 1)
    clock.set_world_seconds(11.0 * 3600.0)
    var date := clock.calendar_date()
    var time := clock.time_of_day()
    _check(date.month_name == "Dawnfrost")
    _check(date.day_of_month == 1)
    _check(time.text == "11:00")
    clock.set_world_seconds(31.0 * 86400.0)
    date = clock.calendar_date()
    _check(date.month_name == "Brightsun")
    _check(date.day_of_month == 2)
    clock.set_world_seconds(0.0)
    clock.time_speed_multiplier = 3.0
    _check(clock.advance_real_time(0.01, true) == 1)
    clock.set_world_seconds(0.0)
    _check(clock.advance_real_time(0.01, false) == 0)
    clock.set_world_seconds(0.4)
    clock.paused = true
    _check(clock.advance_world_seconds(4.0) == 0)
    _check(is_equal_approx(clock.world_seconds, 0.4))
    clock.paused = false
    var saved := clock.to_dict()
    var restored := WorldClock.new()
    restored.load_dict(saved)
    _check(restored.tick_index == clock.tick_index)
    _check(is_equal_approx(restored.world_seconds, clock.world_seconds))

func _test_combat_turn_scheduler() -> void:
    var sim := WorldSimulation.new()
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    var guard := CharacterState.new("guard", "Guard", Vector2i(1, 0))
    player.time_points = 99.5
    guard.time_points = 99.0
    sim.register_character(player)
    sim.register_character(guard)
    sim.start_combat()
    _check(sim.advance_world_seconds(0.4) == 1)
    _check(not sim.turn_scheduler.has_active_turn())
    _check(is_equal_approx(player.time_points, 100.5))
    _check(is_equal_approx(guard.time_points, 100.0))
    _check(sim.advance_world_seconds(0.4) == 0)
    _check(sim.turn_scheduler.current_character_id == "player")
    _check(sim.get_current_turn_character() == player)
    _check(is_equal_approx(sim.clock.world_seconds, 0.4))
    _check(is_equal_approx(player.time_points, 100.5))
    _check(is_equal_approx(guard.time_points, 100.0))
    _check(sim.advance_world_seconds(0.4) == 0)
    _check(is_equal_approx(player.time_points, 100.5))
    _check(is_equal_approx(guard.time_points, 100.0))
    _check(not sim.try_end_current_turn())
    player.time_points = 80.0
    _check(sim.try_end_current_turn())
    _check(not sim.turn_scheduler.has_active_turn())
    _check(sim.advance_world_seconds(0.4) == 0)
    _check(sim.turn_scheduler.current_character_id == "guard")
    _check(is_equal_approx(guard.time_points, 100.0))
    var save_data := sim.to_dict()
    var loaded := WorldSimulation.new()
    loaded.load_dict(save_data)
    _check(loaded.is_in_combat)
    _check(loaded.get_character("guard") != null)
    _check(loaded.get_character("player") != null)
    _check(is_equal_approx(loaded.clock.world_seconds, sim.clock.world_seconds))
    var forced_actor := CharacterState.new("forced_actor", "Forced Actor", Vector2i(3, 0))
    forced_actor.time_points = 140.0
    loaded.register_character(forced_actor)
    loaded.turn_scheduler.current_character_id = "forced_actor"
    _check(loaded.try_end_current_turn(true), "Forced end should relinquish the active turn")
    _check(forced_actor.time_points == 80.0, "Voluntary turn end should forfeit unused TP to avoid immediate reselection")
    loaded.free()
    sim.free()

func _test_initiative_timeline_model() -> void:
    var fresh := CharacterState.new("fresh", "Fresh Adventurer", Vector2i(-5, 0))
    _check(is_equal_approx(fresh.time_points, 100.0), "New characters should begin with 100 TP")

    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.side = "player"
    player.time_points = 80.0
    var enemy := CharacterState.new("enemy_guard", "Guard", Vector2i(1, 0))
    enemy.side = "enemy"
    enemy.time_points = 120.0
    enemy.health = 64
    enemy.max_health = 120
    enemy.current_mana = 17
    enemy.max_mana = 40
    var downed := CharacterState.new("downed_ally", "Downed Ally", Vector2i(0, 1))
    downed.side = "player"
    downed.time_points = 110.0
    downed.unconscious = true
    var dormant := CharacterState.new("tavern_guest", "Tavern Guest", Vector2i(1, 1))
    dormant.side = "player"
    dormant.combat_dormant = true
    dormant.time_points = 150.0
    var rider := CharacterState.new("horse", "Horse", Vector2i(2, 0))
    rider.side = "player"
    rider.is_rider = true
    rider.time_points = 149.0
    var neutral := CharacterState.new("villager", "Villager", Vector2i(2, 1))
    neutral.side = "neutral"
    neutral.time_points = 148.0

    var characters := {
        "player": player,
        "enemy_guard": enemy,
        "downed_ally": downed,
        "tavern_guest": dormant,
        "horse": rider,
        "villager": neutral
    }
    var entries: Array[Dictionary] = INITIATIVE_MODEL.build_entries(characters, "player")
    _check(entries.size() == 3, "Initiative should include active player/enemy combatants but exclude dormant NPCs, riders and neutral bystanders")
    _check(String(entries[0]["id"]) == "enemy_guard", "Timeline should sort highest TP first")
    _check(String(entries[1]["id"]) == "downed_ally", "Living unconscious combatants remain visible in the timeline")
    _check(bool(entries[1]["is_unconscious"]) and not bool(entries[1]["can_start_turn"]), "Downed combatants should be visible but not eligible to act")
    _check(String(entries[2]["id"]) == "player" and bool(entries[2]["is_active"]), "Current actor should be marked independently of its TP rank")
    _check(is_equal_approx(float(entries[0]["time_points_ratio"]), 0.8), "TP bar should use the source 150 TP regeneration gate")
    _check(int(entries[0]["health"]) == enemy.health and int(entries[0]["max_health"]) == enemy.max_health, "Initiative entries should expose current and maximum health")
    _check(int(entries[0]["mana"]) == enemy.current_mana and int(entries[0]["max_mana"]) == enemy.max_mana, "Initiative entries should expose current and maximum mana")
    _check(is_equal_approx(ActionEconomy.DEFAULT_MAX_TP, 120.0), "Source entity baseline maxTimePoints is 120, not 150")
    _check(is_equal_approx(ActionEconomy.regenerate(149.0, 1.0, 1.0), 150.0), "TP regeneration should reach the source 150 gate")
    _check(is_equal_approx(ActionEconomy.regenerate(149.5, 1.0, 1.0), 150.5), "The 150 TP regeneration gate should permit a one-tick overshoot")
    _check(is_equal_approx(ActionEconomy.regenerate(150.0, 1.0, 1.0), 150.0), "TP regeneration should pause once current TP reaches 150")

    var tied_a := CharacterState.new("ally_a", "Ally A")
    var tied_b := CharacterState.new("ally_b", "Ally B")
    tied_a.side = "player"
    tied_b.side = "player"
    tied_a.time_points = 100.0
    tied_b.time_points = 100.0
    var tied := INITIATIVE_MODEL.build_entries({"ally_b": tied_b, "ally_a": tied_a})
    _check(String(tied[0]["id"]) == "ally_a" and String(tied[1]["id"]) == "ally_b", "Equal TP display order should be stable by ID")

func _test_combat_resolution() -> void:
    var attacker := CharacterState.new("hero", "Hero")
    var target := CharacterState.new("guard", "Guard")
    attacker.side = "player"
    attacker.base_damage = 8
    attacker.to_hit_melee = 20.0
    attacker.time_points = 30.0
    attacker.skills["orc_brute_strength"] = 1
    target.health = 30
    target.max_health = 30
    target.passive_dodge = 10.0
    target.armour_reduction = 3
    target.shield_reduction = 2
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var result := CombatRules.resolve_attack(attacker, target, {
        "time_point_cost": 10.0,
        "weapon_damage": 4,
        "weapon_id": "sword",
        "attacker_terrain_hit_bonus": 5.0
    }, rng)
    _check(bool(result.get("ok", false)))
    _check(float(result.get("hit_chance", 0.0)) == 65.0)
    _check(is_equal_approx(attacker.time_points, 20.0))
    if bool(result.get("hit", false)):
        _check(int(result.get("raw_damage", 0)) == 14)
        _check(int(result.get("reduction", 0)) == 5)
        _check(int(result.get("damage", 0)) == 9)
        _check(target.health == 21)

    var guarded := CharacterState.new("armoured", "Armoured")
    guarded.health = 20
    guarded.max_health = 20
    guarded.base_reduction = 2
    guarded.armour_reduction = 4
    guarded.shield_reduction = 3
    guarded.caught_off_guard = true
    _check(CombatRules.damage_reduction(guarded) == 0)
    guarded.caught_off_guard = false
    guarded.climbing = true
    _check(CombatRules.damage_reduction(guarded) == 6)

    var lethal_rng := RandomNumberGenerator.new()
    lethal_rng.seed = 3
    attacker.to_hit_melee = 100.0
    attacker.time_points = 20.0
    target.health = 1
    target.alive = true
    var lethal := CombatRules.resolve_attack(attacker, target, {
        "time_point_cost": 5.0,
        "weapon_damage": 20
    }, lethal_rng)
    _check(bool(lethal.get("hit", false)))
    _check(bool(lethal.get("target_defeated", false)))
    _check(not target.alive and target.health <= -target.max_health * 0.5)

    var poor := CharacterState.new("poor", "Poor")
    poor.time_points = 1.0
    var before_health := target.health
    var rejected := CombatRules.resolve_attack(poor, target, {"time_point_cost": 5.0}, lethal_rng)
    _check(not bool(rejected.get("ok", false)))
    _check(target.health == before_health)

    var sim := WorldSimulation.new()
    var sim_attacker := CharacterState.new("sim_hero", "Hero", Vector2i.ZERO)
    var sim_target := CharacterState.new("sim_guard", "Guard", Vector2i(1, 0))
    sim_attacker.to_hit_melee = 100.0
    sim_attacker.base_damage = 12
    sim_attacker.time_points = 50.0
    sim.register_character(sim_attacker)
    sim.register_character(sim_target)
    sim.is_in_combat = true
    sim.turn_scheduler.current_character_id = "sim_hero"
    var integrated := sim.try_attack_character("sim_hero", "sim_guard", {
        "time_point_cost": 5.0
    }, 11)
    _check(bool(integrated.get("ok", false)))
    _check(bool(integrated.get("hit", false)))
    _check(sim_target.health == 88)
    _check(is_equal_approx(sim_attacker.time_points, 45.0))
    _check(not bool(sim.try_attack_character("sim_guard", "sim_hero", {}, 11).get("ok", false)))
    sim.free()

func _test_downed_and_death_lifecycle() -> void:
    var target := CharacterState.new("target", "Target")
    target.max_health = 100
    target.health = 20
    _check(target.apply_damage(40) == "downed")
    _check(target.alive and target.unconscious)
    _check(target.health == -20, "Downed HP remains negative rather than clamping to zero")
    _check(target.can_be_targeted(), "Unconscious living characters remain valid targets")
    _check(not target.can_act(), "Unconscious characters cannot act")
    _check(not target.can_start_combat_turn(), "Unconscious characters cannot receive turns")
    _check(target.apply_healing(25) == "revived_from_unconscious")
    _check(target.health == 5 and not target.unconscious and target.alive)
    _check(target.apply_damage(56) == "died")
    _check(not target.alive and not target.unconscious)
    _check(target.health <= -50, "True death occurs at or below -50% maximum HP")
    _check(target.apply_healing(100) == "unchanged", "Healing does not silently resurrect true-dead characters")
    var second := CharacterState.new("second", "Second")
    second.health = 1
    second.apply_damage(51)
    _check(not second.alive and not second.unconscious, "Exact -50% HP boundary is true death")

func _test_unified_action_contract() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    var mover := CharacterState.new("mover", "Mover", Vector2i.ZERO)
    mover.time_points = 20.0
    sim.register_character(mover)
    var move_result := sim.submit_action(SimulationActionRequest.move("mover", Vector2i(1, 0), 5.0))
    _check(bool(move_result.get("ok", false)))
    _check(mover.axial == Vector2i(1, 0))
    _check(is_equal_approx(mover.time_points, 15.0))
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i(0, 1))
    var victim := CharacterState.new("victim", "Victim", Vector2i(1, 1))
    attacker.to_hit_melee = 100.0
    attacker.base_damage = 10
    attacker.time_points = 20.0
    victim.health = 10
    victim.max_health = 100
    sim.register_character(attacker)
    sim.register_character(victim)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "attacker"
    var attack_result := sim.submit_action(SimulationActionRequest.attack("attacker", "victim", {"time_point_cost": 5.0}), 19)
    _check(bool(attack_result.get("ok", false)))
    _check(victim.unconscious and victim.alive, "Attack downs rather than kills in the negative HP band")
    _check(bool(attack_result.get("target_unconscious", false)))
    _check(String(attack_result.get("action_type", "")) == "attack")
    sim.free()

func _test_attack_waits_for_parry_resolution() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i.ZERO)
    var defender := CharacterState.new("defender", "Defender", Vector2i(1, 0))
    attacker.to_hit_melee = 100.0
    attacker.base_damage = 20
    attacker.time_points = 30.0
    defender.time_points = 20.0
    defender.health = 100
    defender.max_health = 100
    defender.to_hit_melee = 100.0
    defender.equipment["weapon"] = "sword"
    defender.skills["sword_parry"] = 1
    sim.register_character(attacker)
    sim.register_character(defender)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "attacker"

    var pending := sim.try_attack_character("attacker", "defender", {"time_point_cost": 5.0}, 41)
    _check(bool(pending.get("pending", false)), "A qualified defender should be offered a parry before damage resolves")
    _check(defender.health == 100, "Damage must not land while the reaction is pending")
    _check(is_equal_approx(attacker.time_points, 30.0), "Attacker TP must not be spent before the reaction resolves")
    var resolved := sim.resolve_reaction("parry")
    _check(bool(resolved.get("ok", false)))
    _check(defender.health == 100, "A successful parry cancels the incoming attack")
    _check(defender.parries_remaining == 2, "A parry consumes one per-turn parry use")
    _check(is_equal_approx(defender.time_points, 17.0), "The defender pays the source-defined 3 TP parry cost")
    _check(is_equal_approx(attacker.time_points, 25.0), "A successful parry still consumes the attack action's TP cost")
    sim.free()

func _test_protector_ally_parry() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i.ZERO)
    var target := CharacterState.new("target", "Target", Vector2i(1, 0))
    var protector := CharacterState.new("protector", "Protector", Vector2i(0, 1))
    attacker.to_hit_melee = 100.0
    attacker.base_damage = 20
    attacker.time_points = 30.0
    target.side = "player"
    target.time_points = 10.0
    protector.side = "player"
    protector.time_points = 20.0
    protector.to_hit_melee = 100.0
    protector.equipment["weapon"] = "sword"
    protector.skills["protector"] = 1
    protector.skills["sword_parry"] = 1
    sim.register_character(attacker)
    sim.register_character(target)
    sim.register_character(protector)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "attacker"

    var pending := sim.try_attack_character("attacker", "target", {"time_point_cost": 5.0}, 77)
    _check(bool(pending.get("pending", false)), "An eligible adjacent Protector should be offered a reaction")
    _check(target.health == 100, "Protector choice must be offered before attack damage")
    var chosen := sim.resolve_reaction("protector_parry_protector")
    _check(bool(chosen.get("ok", false)))
    _check(target.health == 100, "A successful Protector parry cancels the attack")
    _check(protector.parries_remaining == 2, "Protector consumes one parry allowance")
    _check(is_equal_approx(protector.time_points, 17.0), "Protector pays their own 3 TP")
    _check(is_equal_approx(target.time_points, 10.0), "Protected target does not pay the ally's TP cost")
    _check(is_equal_approx(attacker.time_points, 25.0), "A successful Protector parry still charges the attack")
    sim.free()

func _test_shield_other_reduces_one_attack() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i.ZERO)
    var target := CharacterState.new("target", "Target", Vector2i(1, 0))
    var protector := CharacterState.new("shield_ally", "Shield Ally", Vector2i(0, 1))
    attacker.to_hit_melee = 100.0
    attacker.base_damage = 20
    attacker.time_points = 30.0
    target.side = "player"
    target.time_points = 10.0
    protector.side = "player"
    protector.time_points = 20.0
    protector.equipment["offhand"] = {"id": "round_shield", "type": "shield", "reduction": 4}
    protector.skills["shield_other"] = 1
    protector.skills["shield_proficiency"] = 1
    sim.register_character(attacker)
    sim.register_character(target)
    sim.register_character(protector)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "attacker"

    var pending := sim.try_attack_character("attacker", "target", {"time_point_cost": 5.0}, 91)
    _check(bool(pending.get("pending", false)), "An adjacent shield ally should be offered Shield Other")
    var chosen := sim.resolve_reaction("shield_other_shield_ally")
    _check(bool(chosen.get("ok", false)))
    _check(target.health == 85, "Shield Other should reduce only this incoming hit by shield plus proficiency")
    _check(target.temp_reduction == 0, "Temporary Shield Other reduction must be removed after the attack")
    _check(is_equal_approx(protector.time_points, 19.0), "Shield Other ally pays 1 TP")
    _check(is_equal_approx(target.time_points, 10.0), "Protected target does not pay ally TP")
    sim.free()

func _test_spear_halt_commits_one_step_then_stops() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    var mover := CharacterState.new("mover", "Mover", Vector2i.ZERO)
    var guard := CharacterState.new("guard", "Spear Guard", Vector2i(0, 1))
    mover.time_points = 100.0
    guard.time_points = 20.0
    guard.equipment["weapon"] = "spear"
    guard.skills["spear_halt"] = 1
    sim.register_character(mover)
    sim.register_character(guard)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "mover"
    var halt_events := [false]
    sim.movement_reaction_resolved.connect(func(_id: String, halted: bool) -> void: halt_events[0] = halted)

    var pending := sim.try_move_character_step("mover", Vector2i(1, 0))
    _check(pending and not sim.pending_reaction.is_empty(), "Spear Halt should pause the movement step")
    _check(mover.axial == Vector2i.ZERO, "Mover must not commit position before the reaction resolves")
    var resolved := sim.resolve_reaction("spear_halt_guard")
    _check(bool(resolved.get("ok", false)))
    _check(mover.axial == Vector2i(1, 0), "Spear Halt commits the triggering step")
    _check(halt_events[0], "Spear Halt signals the path controller to stop remaining steps")
    _check(is_equal_approx(guard.time_points, 19.0), "Spear Halt costs 1 TP")
    sim.free()


func _test_spear_intercept_resolves_before_movement() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    var mover := CharacterState.new("mover", "Mover", Vector2i.ZERO)
    var guard := CharacterState.new("interceptor", "Spear Guard", Vector2i(0, 1))
    mover.time_points = 100.0
    mover.health = 100
    guard.time_points = 20.0
    guard.to_hit_melee = 100.0
    guard.base_damage = 10
    guard.equipment["weapon"] = "spear"
    guard.skills["spear_intercept"] = 1
    sim.register_character(mover)
    sim.register_character(guard)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "mover"

    var pending := sim.try_move_character_step("mover", Vector2i(1, 0))
    _check(pending and not sim.pending_reaction.is_empty(), "Spear Intercept should pause movement")
    var resolved := sim.resolve_reaction("spear_intercept_interceptor")
    _check(bool(resolved.get("ok", false)))
    _check(mover.health == 90, "Spear Intercept attacks the mover before the step commits")
    _check(mover.axial == Vector2i(1, 0), "Movement continues after Spear Intercept")
    _check(is_equal_approx(guard.time_points, 15.0), "Spear Intercept costs 5 TP")
    sim.free()


func _test_sidestep_uses_a_second_stage_destination() -> void:
    var sim := WorldSimulation.new()
    for q in range(-1, 3):
        for r in range(-1, 3):
            sim.map_data.add_cell(Vector2i(q, r))
    var mover := CharacterState.new("mover", "Mover", Vector2i.ZERO)
    var defender := CharacterState.new("sidestepper", "Sidestepper", Vector2i(0, 1))
    mover.time_points = 100.0
    defender.time_points = 20.0
    defender.skills["sidestep"] = 1
    defender.sidesteps_remaining = 3
    sim.register_character(mover)
    sim.register_character(defender)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "mover"

    var pending := sim.try_move_character_step("mover", Vector2i(1, 0))
    _check(pending and not sim.pending_reaction.is_empty(), "Sidestep should be offered as a movement reaction")
    var first_stage := sim.resolve_reaction("sidestep_sidestepper")
    _check(bool(first_stage.get("pending", false)) and String(first_stage.get("stage", "")) == "sidestep_destination", "Choosing Sidestep opens a destination stage without spending TP")
    _check(is_equal_approx(defender.time_points, 20.0), "Sidestep TP is not spent before a destination is chosen")
    var second_stage := sim.resolve_reaction("sidestep_to_1_1")
    _check(bool(second_stage.get("ok", false)))
    _check(defender.axial == Vector2i(1, 1), "Sidestep moves the reactor to the selected adjacent free hex")
    _check(defender.sidesteps_remaining == 2, "Sidestep consumes one allowance")
    _check(is_equal_approx(defender.time_points, 14.0), "Sidestep costs 6 TP")
    _check(mover.axial == Vector2i(1, 0), "Mover continues after Sidestep")
    sim.free()


func _test_reaction_resolution_safety() -> void:
    var sim := WorldSimulation.new()
    var reactor := CharacterState.new("reactor", "Reactor", Vector2i.ZERO)
    reactor.time_points = 20.0
    sim.register_character(reactor)
    sim.start_combat()
    var requested_count := [0]
    var resolved_count := [0]
    var last_choice := [""]
    var last_reason := [""]
    sim.reaction_requested.connect(func(_id: String, _options: Array[Dictionary], _request_id: int, _source: String) -> void:
        requested_count[0] += 1
    )
    sim.reaction_resolved.connect(func(_id: String, choice: String, _request_id: int, reason: String) -> void:
        resolved_count[0] += 1
        last_choice[0] = choice
        last_reason[0] = reason
    )

    reactor.alive = false
    var dead_result := sim.request_reaction("reactor", [{"id": "parry", "name": "Parry", "tp_cost": 3.0}])
    _check(bool(dead_result.get("ok", false)) and not bool(dead_result.get("pending", true)))
    _check(resolved_count[0] == 1 and last_choice[0].is_empty())
    _check(last_reason[0] == "reactor_unavailable")
    _check(requested_count[0] == 0 and sim.pending_reaction.is_empty())

    reactor.alive = true
    reactor.unconscious = true
    var unconscious_result := sim.request_reaction("reactor", [{"id": "parry", "tp_cost": 3.0}])
    _check(not bool(unconscious_result.get("pending", true)))
    _check(resolved_count[0] == 2 and last_choice[0].is_empty())
    _check(sim.pending_reaction.is_empty())

    reactor.unconscious = false
    var opened := sim.request_reaction("reactor", [
        {"id": "parry", "name": "Parry", "tp_cost": 3.0},
        {"id": "dodge", "name": "Dodge", "tp_cost": 5.0}
    ], "attack_001")
    _check(bool(opened.get("pending", false)))
    _check(requested_count[0] == 1 and not sim.pending_reaction.is_empty())
    _check(not sim.try_end_current_turn(), "A pending reaction must prevent normal turn completion")
    _check(not sim.resolve_reaction("unknown").get("ok", false), "Invalid choices must not consume the pending request")
    var chosen := sim.resolve_reaction("parry")
    _check(bool(chosen.get("ok", false)) and String(chosen.get("choice_id", "")) == "parry")
    _check(is_equal_approx(reactor.time_points, 17.0))
    _check(resolved_count[0] == 3 and last_choice[0] == "parry" and last_reason[0] == "selected")
    _check(sim.pending_reaction.is_empty())

    reactor.time_points = 20.0
    var death_wait := sim.request_reaction("reactor", [{"id": "parry", "tp_cost": 3.0}], "attack_002")
    _check(bool(death_wait.get("pending", false)))
    reactor.apply_damage(150)
    _check(not reactor.alive)
    _check(sim.pending_reaction.is_empty(), "Death while a reaction is pending must clear the wait immediately")
    _check(resolved_count[0] == 4 and last_choice[0].is_empty() and last_reason[0] == "reactor_incapacitated")

    reactor.alive = true
    reactor.health = 100
    reactor.unconscious = false
    reactor.reaction_blocked = true
    var blocked := sim.request_reaction("reactor", [{"id": "parry", "tp_cost": 3.0}])
    _check(not bool(blocked.get("pending", true)) and String(blocked.get("reason", "")) == "reactor_unavailable")
    _check(sim.pending_reaction.is_empty())
    sim.free()

func _test_incapacitated_turn_cleanup() -> void:
    var sim := WorldSimulation.new()
    var actor := CharacterState.new("actor", "Actor", Vector2i.ZERO)
    actor.time_points = 120.0
    sim.register_character(actor)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "actor"
    actor.apply_damage(150)
    _check(not sim.turn_scheduler.has_active_turn(), "An incapacitated active combatant must relinquish their turn")
    sim.free()


func _test_item_catalog_and_hollowmere_loadouts() -> void:
    var sword := ItemCatalog.create_instance("sword", "catalog_sword_001")
    _check(not sword.is_empty(), "Original sword definition should load")
    _check(int(sword.get("damage", 0)) == 3, "Sword damage should match Hex-crpg")
    _check(String(sword.get("equipment_slot", "")) == "weapon", "Sword should map to the weapon slot")
    _check(int(sword.get("icon_index", -1)) >= 0, "Sword should have a 2D inventory icon")

    var medium_armour := ItemCatalog.create_instance("medium_armor", "catalog_armour_001")
    _check(int(medium_armour.get("reduction", 0)) == 2, "Medium armour reduction should match Hex-crpg")
    _check(String(medium_armour.get("weight_class", "")) == "medium", "Medium armour should retain its movement class")
    var shield := ItemCatalog.create_instance("wooden_shield", "catalog_shield_001")
    _check(String(shield.get("type", "")) == "shield", "Offhand shield must retain shield type for Shield Other")
    _check(String(shield.get("equipment_slot", "")) == "offhand", "Shield should map to the offhand slot")

    var loadout_file := FileAccess.open("res://data/characters/hollowmere_loadouts.json", FileAccess.READ)
    _check(loadout_file != null, "Hollowmere loadout data should exist")
    if loadout_file == null:
        return
    var parsed: Variant = JSON.parse_string(loadout_file.get_as_text())
    _check(parsed is Dictionary, "Hollowmere loadout data should parse")
    if not parsed is Dictionary:
        return
    var loadouts: Dictionary = parsed.get("characters", {})
    _check(loadouts.get("dray_coltayne", []) == ["sword", "medium_armor", "wooden_shield"], "Dray's loadout should match the original campaign")
    _check(loadouts.get("tomlin_brask", []) == ["spear", "light_armor"], "Tomlin's loadout should match the original campaign")
    _check(loadouts.get("hask_greel", []) == ["axe", "light_armor"], "Hask's loadout should match the original campaign")
    _check(loadouts.get("companion_wren_talbot", []) == ["sword", "reinforced_leather_armor", "wooden_shield"], "Wren should retain the sword shown in the Ara profile")
    _check(not loadouts.has("player"), "Do not invent a player class kit before class selection exists")

    var dray := CharacterState.new("dray_coltayne", "Dray Coltayne", Vector2i.ZERO)
    var dray_items: Array = loadouts.get("dray_coltayne", [])
    for index in range(dray_items.size()):
        var item_id := String(dray_items[index])
        var instance_id := "test_dray_%s_%02d" % [item_id, index]
        var item := ItemCatalog.create_instance(item_id, instance_id)
        _check(dray.add_inventory_item(item), "Dray should accept source item %s" % item_id)
        _check(dray.equip_inventory_item(instance_id), "Dray should equip source item %s" % item_id)
    _check(String(dray.equipment.get("weapon", "")) == "sword", "Dray's sword should be equipped")
    _check(String(dray.equipment.get("armour", "")) == "medium_armor", "Dray's medium armour should be equipped")
    _check(String(dray.equipment.get("offhand", "")) == "wooden_shield", "Dray's shield should be equipped")
    _check(CombatRules.damage_reduction(dray) == 3, "Dray's armour and shield should affect damage reduction")
    _check(dray.inventory.is_empty(), "Starting equipment should be equipped, not duplicated in carried items")




func _test_race_class_character_creation() -> void:
    var profile := {"name":"Aldara","race":"human","character_class":"fighter","game_mode":"campaign","campaign_id":"2","difficulty_mode":"normal","gender_presentation":"Feminine","pronouns":"she/her"}
    var fighter := CharacterCreationRules.create_player_state(profile, "player", Vector2i(-1, 2))
    _check(fighter.display_name == "Aldara")
    _check(fighter.race == "human" and fighter.character_class == "fighter")
    _check(fighter.side == "player")
    _check(fighter.level == 1 and fighter.experience == 0)
    _check(int(fighter.attributes.get("strength", 0)) == 3)
    _check(int(fighter.attributes.get("endurance", 0)) == 3)
    _check(int(fighter.attributes.get("agility", 0)) == 1)
    _check(int(fighter.attributes.get("wildcard", 0)) == 1)
    _check(int(fighter.attributes.get("fighter", 0)) == 1)
    _check(int(fighter.attributes.get("weapons", 0)) == 2)
    _check(int(fighter.class_levels.get("fighter", 0)) == 1)
    _check(fighter.gold == 65)
    _check(String(fighter.equipment.get("weapon", "")) == "sword")
    _check(fighter.inventory.is_empty())
    _check(String(fighter.equipped_item_data.get("weapon", {}).get("id", "")) == "sword")
    var round_trip := CharacterState.from_dict(fighter.to_dict())
    _check(round_trip.race == "human" and round_trip.character_class == "fighter")
    _check(round_trip.attributes == fighter.attributes and round_trip.class_levels == fighter.class_levels)
    _check(round_trip.gold == 65 and round_trip.campaign_id == "2")

    var rogue_profile := profile.duplicate(true)
    rogue_profile["race"] = "dwarf"
    rogue_profile["character_class"] = "rogue"
    var rogue := CharacterCreationRules.create_player_state(rogue_profile, "rogue", Vector2i.ZERO)
    _check(int(rogue.attributes.get("dwarf", 0)) == 1 and int(rogue.attributes.get("rogue", 0)) == 1)
    _check(int(rogue.attributes.get("endurance", 0)) == 4 and int(rogue.attributes.get("agility", 0)) == 3)
    _check(String(rogue.equipment.get("weapon", "")) == "dagger")
    _check(rogue.inventory.size() == 2, "Rogue carries bow and torch")

    var cleric_profile := profile.duplicate(true)
    cleric_profile["character_class"] = "cleric"
    var cleric := CharacterCreationRules.create_player_state(cleric_profile, "cleric", Vector2i.ZERO)
    _check(String(cleric.equipment.get("weapon", "")) == "club")
    _check(String(cleric.equipment.get("offhand", "")) == "wooden_shield")
    _check(CombatRules.damage_reduction(cleric) == 1)


    var expected_races := {
        "human":{"agility":1,"strength":1,"endurance":1,"wildcard":1},
        "dwarf":{"dwarf":1,"endurance":2,"strength":1},
        "elf":{"elf":1,"agility":2,"arcane":1},
        "goblin":{"goblin":1,"agility":2,"weapons":1},
        "orc":{"orc":1,"strength":2,"endurance":1}
    }
    var fighter_bonuses: Dictionary = CharacterCreationRules.class_definition("fighter").get("bonus", {})
    for race_id in expected_races:
        var race_profile := profile.duplicate(true)
        race_profile["race"] = race_id
        var race_state := CharacterCreationRules.create_player_state(race_profile, "race_" + race_id, Vector2i.ZERO)
        for attribute in expected_races[race_id]:
            _check(int(race_state.attributes.get(attribute, 0)) == int(expected_races[race_id][attribute]) + int(fighter_bonuses.get(attribute, 0)), "Race bonus mismatch: %s / %s" % [race_id, attribute])

    var expected_classes := {
        "fighter":{"weapon":"sword","carried":0},
        "rogue":{"weapon":"dagger","carried":2},
        "cleric":{"weapon":"club","carried":0},
        "wizard":{"weapon":"dagger","carried":0},
        "druid":{"weapon":"club","carried":0},
        "monk":{"weapon":"dagger","carried":0}
    }
    for class_id in expected_classes:
        var class_profile := profile.duplicate(true)
        class_profile["character_class"] = class_id
        var class_state := CharacterCreationRules.create_player_state(class_profile, "class_" + class_id, Vector2i.ZERO)
        _check(String(class_state.equipment.get("weapon", "")) == String(expected_classes[class_id]["weapon"]), "Class starting weapon mismatch: %s" % class_id)
        _check(class_state.inventory.size() == int(expected_classes[class_id]["carried"]), "Class carried starting items mismatch: %s" % class_id)
        _check(int(class_state.class_levels.get(class_id, 0)) == 1, "Class level marker missing: %s" % class_id)

    var easy_profile := profile.duplicate(true)
    easy_profile["difficulty_mode"] = "easy"
    var easy := CharacterCreationRules.create_player_state(easy_profile, "easy", Vector2i.ZERO)
    _check(easy.gold == 98)
    _check(easy.max_health == 110 and easy.health == 110)
    _check(int(easy.skills.get("health", 0)) == 1 and int(easy.free_skill_ranks.get("health", 0)) == 1)

    var hard_profile := profile.duplicate(true)
    hard_profile["difficulty_mode"] = "hard"
    var hard := CharacterCreationRules.create_player_state(hard_profile, "hard", Vector2i.ZERO)
    var target := CharacterState.new("hard_target", "Target")
    target.health = 100
    target.max_health = 100
    hard.to_hit_melee = 100.0
    hard.time_points = 10.0
    var rng := RandomNumberGenerator.new()
    rng.seed = 1
    var result := CombatRules.resolve_attack(hard, target, {"time_point_cost":1.0, "bonus_damage":10}, rng)
    _check(int(result.get("damage", 0)) == 13, "Hard mode reduces player damage by 10 percent")
    var enemy := CharacterState.new("enemy", "Enemy")
    enemy.to_hit_melee = 100.0
    enemy.base_damage = 10
    enemy.time_points = 10.0
    var hard_target := CharacterCreationRules.create_player_state(hard_profile, "hard_target_player", Vector2i(1, 0))
    hard_target.health = 100
    hard_target.max_health = 100
    var incoming := CombatRules.resolve_attack(enemy, hard_target, {"time_point_cost":1.0}, rng)
    _check(int(incoming.get("damage", 0)) == 8, "Hard mode increases incoming damage after the fighter starting armour and shield reduce it")


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
