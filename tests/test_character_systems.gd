extends SceneTree

var _failures: int = 0

func _initialize() -> void:
    _test_character_round_trip()
    _test_skill_catalogue_and_progression()
    _test_npc_skill_spending_and_companion_boundary()
    _test_race_class_character_creation()
    _test_canonical_weapon_skill_runtime()
    _test_core_character_skill_runtime()
    _test_additional_skill_effects()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Character and progression tests passed.")
    quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
    if not condition:
        _failures += 1
        push_error(message)
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

func _test_skill_catalogue_and_progression() -> void:
    var definitions := SkillCatalog.definitions()
    _check(definitions.size() == 257, "The source skill catalogue should contain all 186 unique entries")
    _check(int(SkillCatalog.get_skill("health").get("max_ranks", -1)) == 0, "A zero rank cap means unlimited ranks")

    var character := CharacterState.new("skill_test", "Skill Test")
    character.attributes = {"endurance": 3, "strength": 0, "wildcard": 1, "nature": 1, "druid": 1, "elf": 1}
    SkillProgression.initialise(character)
    _check(bool(SkillProgression.purchase(character, "health").get("ok", false)))
    _check(bool(SkillProgression.purchase(character, "health").get("ok", false)))
    _check(bool(SkillProgression.purchase(character, "health").get("ok", false)))
    _check(int(character.skills.get("health", 0)) == 3, "Unlimited-rank skills can be purchased repeatedly while points remain")
    _check(bool(SkillProgression.purchase(character, "health").get("ok", false)), "Wildcard points may also fund a standard tree")
    _check(int(character.skills.get("health", 0)) == 4)
    _check(String(SkillProgression.purchase(character, "health").get("reason", "")) == "insufficient_skill_points")

    var prerequisite_character := CharacterState.new("prereq_test", "Prerequisite Test")
    prerequisite_character.attributes = {"strength": 2}
    SkillProgression.initialise(prerequisite_character)
    _check(String(SkillProgression.can_purchase(prerequisite_character, "medium_armor_training").get("reason", "")) == "prerequisite_missing")
    _check(bool(SkillProgression.purchase(prerequisite_character, "light_armor_training").get("ok", false)))
    _check(bool(SkillProgression.purchase(prerequisite_character, "medium_armor_training").get("ok", false)))
    _check(String(SkillProgression.can_purchase(prerequisite_character, "heavy_armor_training").get("reason", "")) == "insufficient_skill_points")

    var wildcard_character := CharacterState.new("wildcard_test", "Wildcard Test")
    wildcard_character.attributes = {"wildcard": 1}
    SkillProgression.initialise(wildcard_character)
    var wildcard_purchase := SkillProgression.purchase(wildcard_character, "shove")
    _check(bool(wildcard_purchase.get("ok", false)) and String(wildcard_purchase.get("funding_pool", "")) == "wildcard", "Wildcard points may fund standard trees")
    _check(String(SkillProgression.can_purchase(wildcard_character, "regeneration").get("reason", "")) != "ok", "Creature-only skills must not be purchasable from the player skill system")

    var misc_character := CharacterState.new("misc_test", "Misc Test")
    misc_character.attributes = {"endurance": 1, "agility": 1}
    SkillProgression.initialise(misc_character)
    var misc_check := SkillProgression.can_purchase(misc_character, "cooking")
    _check(String(misc_check.get("reason", "")) == "funding_pool_choice_required", "Misc skills ask which attribute pool should pay when several are available")
    var misc_purchase := SkillProgression.purchase(misc_character, "cooking", "agility")
    _check(bool(misc_purchase.get("ok", false)) and int(misc_character.attributes.get("agility", 0)) == 0, "Misc skill purchases deduct from the selected pool")

    var nature_character := CharacterState.new("nature_test", "Nature Test")
    nature_character.attributes = {"nature": 1}
    SkillProgression.initialise(nature_character)
    _check(String(SkillProgression.can_purchase(nature_character, "nature_butchery").get("reason", "")) == "dynamic_prerequisite_missing")
    nature_character.skills["druid_knowledge_nature"] = 1
    _check(bool(SkillProgression.purchase(nature_character, "nature_butchery").get("ok", false)), "Nature skills require either source Knowledge: Nature rank")

    var incompatible_character := CharacterState.new("anti_test", "Anti Test")
    incompatible_character.attributes = {"elf": 1}
    incompatible_character.skills["druid_foliage_expertise"] = 1
    SkillProgression.initialise(incompatible_character)
    _check(String(SkillProgression.can_purchase(incompatible_character, "elf_foliage_expertise").get("reason", "")) == "incompatible_skill_learned", "Anti-prerequisites prevent incompatible choices")

    var quest_character := CharacterState.new("quest_test", "Quest Test")
    quest_character.attributes = {"druid": 1}
    SkillProgression.initialise(quest_character)
    _check(String(SkillProgression.can_purchase(quest_character, "learn_unicorn_summon").get("reason", "")) == "quest_granted_only", "Quest-only skills cannot be purchased")

    var level_character := CharacterCreationRules.create_player_state({
        "name": "Level Test", "race": "human", "character_class": "fighter",
        "game_mode": "campaign", "campaign_id": "2", "difficulty_mode": "normal"
    }, "level_test", Vector2i.ZERO)
    var before_level_attributes := level_character.attributes.duplicate(true)
    var rogue_bonus: Dictionary = CharacterCreationRules.class_definition("rogue").get("bonus", {})
    var level_grant := SkillProgression.grant_level(level_character, "rogue", "level_2")
    _check(bool(level_grant.get("ok", false)) and level_character.level == 2, "A new class level should be granted")
    for pool in rogue_bonus:
        var expected := int(before_level_attributes.get(pool, 0)) + int(rogue_bonus.get(pool, 0))
        _check(int(level_character.attributes.get(pool, 0)) == expected, "Each level grants the selected class pools without repeating race bonuses")
    _check(int(level_character.class_levels.get("rogue", 0)) == 1, "Class-level history should retain multiclass progression")
    _check(String(SkillProgression.grant_level(level_character, "rogue", "level_2").get("reason", "")) == "grant_already_applied", "A level-up cannot award the same points twice")
    _check(int(level_character.skills.size()) == 0, "A level grant must leave new skill points unspent for the player")

    var grant := SkillProgression.grant_points(quest_character, "druid", 2, "level_2_druid")
    _check(bool(grant.get("ok", false)))
    _check(String(SkillProgression.grant_points(quest_character, "druid", 2, "level_2_druid").get("reason", "")) == "grant_already_applied", "A level grant identifier can only be applied once")
    var report := SkillProgression.accounting_report(quest_character)
    _check(bool(report.get("pools", {}).get("druid", {}).get("balanced", false)), "Earned, spent and remaining points must reconcile by pool")
    var restored := CharacterState.from_dict(quest_character.to_dict())
    _check(restored.skill_budget_by_pool == quest_character.skill_budget_by_pool)
    _check(restored.skill_spent_by_pool == quest_character.skill_spent_by_pool)
    _check(restored.skill_point_grants == quest_character.skill_point_grants)
    _check(restored.skill_progression_initialized, "Skill point accounting survives save/load")

func _test_npc_skill_spending_and_companion_boundary() -> void:
    var population_a := CharacterState.new("goblin_a", "Goblin A")
    var population_b := CharacterState.new("goblin_b", "Goblin B")
    var build_a := NPCSkillSpending.build_population(population_a, "goblin", 3, "hollowmere:spawn:12,8")
    var build_b := NPCSkillSpending.build_population(population_b, "goblin", 3, "hollowmere:spawn:12,8")
    _check(bool(build_a.get("ok", false)) and bool(build_b.get("ok", false)), "Generated humanoid NPCs should build successfully")
    _check(population_a.class_level_sequence == population_b.class_level_sequence, "Population class packages must be deterministic for the same seed")
    _check(population_a.skills == population_b.skills, "Population skill allocation must be deterministic for the same seed")
    _check(population_a.attributes == population_b.attributes, "Population point balances must be deterministic for the same seed")
    var population_report := SkillProgression.accounting_report(population_a)
    for pool in population_report.get("pools", {}):
        var row: Dictionary = population_report.pools[pool]
        _check(bool(row.get("balanced", false)), "Generated NPC point budgets must reconcile by pool")


    var troll := CharacterState.new("troll_npc", "Troll NPC")
    var troll_build := NPCSkillSpending.build_population(troll, "troll", 1, "troll:population")
    _check(bool(troll_build.get("ok", false)), "Non-player humanoid races should use the shared NPC progression rules")
    _check(int(troll.skills.get("regeneration", 0)) == 1 and int(troll.free_skill_ranks.get("regeneration", 0)) == 1, "Racial innate abilities are tracked separately from paid ranks")
    var troll_level := NPCSkillSpending.grant_npc_level(troll, "fighter", "troll:level2")
    _check(bool(troll_level.get("ok", false)), "Non-player humanoid races can progress through class levels")

    var authored := CharacterState.new("authored_guard", "Authored Guard")
    authored.equipment["weapon"] = "sword"
    var authored_build := NPCSkillSpending.build_authored(
        authored, "human", ["fighter", "fighter"],
        {"sword_hit": 1, "sword_dmg": 1}, "named:authored_guard"
    )
    _check(bool(authored_build.get("ok", false)), "Authored NPCs should use the shared legal skill spender")
    _check(int(authored.skills.get("sword_hit", 0)) >= 1 and int(authored.skills.get("sword_dmg", 0)) >= 1, "Authored weapon preferences should be purchased with their prerequisites")
    _check(authored.class_level_sequence == ["fighter", "fighter"], "Authored ordered class histories must be retained")

    var companion := CharacterState.new("companion_test", "Companion Test")
    companion.race = "human"
    companion.character_class = "fighter"
    companion.level = 1
    companion.class_levels = {"fighter": 1}
    companion.class_level_sequence = ["fighter"]
    companion.attributes = {"endurance": 2, "strength": 1, "agility": 1, "weapons": 1}
    companion.equipment["weapon"] = "sword"
    SkillProgression.initialise(companion)
    _check(bool(SkillProgression.purchase(companion, "health").get("ok", false)), "Pre-recruitment authored skill spending should be retained")
    companion.npc_preferred_skills = {"sword_hit": 1}
    var paid_health_before_recruitment := int(companion.skill_spent_by_id.get("health", 0))
    var recruited := NPCSkillSpending.recruit_companion(companion, {}, "companion:first_join")
    _check(bool(recruited.get("ok", false)), "First recruitment should initialise a companion's remaining build")
    _check(companion.companion_recruitment_initialized and companion.progression_mode == "companion")
    _check(int(companion.skills.get("health", 0)) >= 1, "Recruitment must preserve skills already earned or authored")
    _check(int(companion.skill_spent_by_id.get("health", 0)) >= paid_health_before_recruitment, "Recruitment must preserve and extend, not reset, the prior paid-point ledger")
    var ranks_at_recruitment := companion.skills.duplicate(true)
    var remaining_at_recruitment := SkillProgression.available_points(companion)
    var rejoin := NPCSkillSpending.recruit_companion(companion, {}, "companion:rejoin")
    _check(String(rejoin.get("reason", "")) == "already_recruited_once", "Leaving and rejoining must not run recruitment allocation again")
    _check(companion.skills == ranks_at_recruitment and SkillProgression.available_points(companion) == remaining_at_recruitment, "Rejoining must not rebuild skills or duplicate spending")

    var attributes_before_level := companion.attributes.duplicate(true)
    var ranks_before_level := companion.skills.duplicate(true)
    var level_up := SkillProgression.grant_level(companion, "rogue", "companion_level_2")
    _check(bool(level_up.get("ok", false)), "A recruited companion should receive normal class-level point grants")
    _check(companion.skills == ranks_before_level, "Post-recruitment level-ups must not auto-spend companion points")
    _check(int(companion.attributes.get("agility", 0)) == int(attributes_before_level.get("agility", 0)) + 3, "Level-up should grant the class bonus without re-awarding race bonuses")
    _check(int(companion.attributes.get("endurance", 0)) == int(attributes_before_level.get("endurance", 0)) + 2)
    _check(SkillProgression.available_points(companion) == remaining_at_recruitment + 7, "New companion points remain available for player allocation")
    var restored := CharacterState.from_dict(companion.to_dict())
    _check(restored.companion_recruitment_initialized and restored.progression_mode == "companion", "Recruitment state survives save/load")
    _check(restored.class_level_sequence == companion.class_level_sequence, "Ordered multiclass history survives save/load")


    var simulation := WorldSimulation.new()
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.side = "player"
    simulation.register_character(player)
    var party_candidate := CharacterState.new("party_candidate", "Party Candidate", Vector2i(1, 0))
    party_candidate.race = "human"
    party_candidate.class_level_sequence = ["fighter"]
    party_candidate.class_levels = {"fighter": 1}
    party_candidate.attributes = {"endurance": 1, "strength": 1, "agility": 1, "weapons": 1}
    SkillProgression.initialise(party_candidate)
    simulation.register_character(party_candidate)
    var join_result := simulation.recruit_companion("party_candidate", {}, "party_candidate:first_join")
    _check(bool(join_result.get("ok", false)) and simulation.is_party_member("party_candidate"), "WorldSimulation should recruit and track a companion")
    _check(bool(simulation.dismiss_companion("party_candidate").get("ok", false)), "A companion can leave the active party without being deleted")
    var rejoin_result := simulation.recruit_companion("party_candidate", {}, "party_candidate:rejoin")
    _check(bool(rejoin_result.get("ok", false)) and String(rejoin_result.get("reason", "")) == "rejoined_existing_companion", "WorldSimulation should rejoin an existing companion without rebuilding")
    var party_ranks_before_level := party_candidate.skills.duplicate(true)
    var party_points_before_level := SkillProgression.available_points(party_candidate)
    var party_level := simulation.grant_character_level("party_candidate", "rogue", "party_candidate:level2")
    _check(bool(party_level.get("ok", false)), "WorldSimulation should grant a companion's class level")
    _check(party_candidate.skills == party_ranks_before_level, "WorldSimulation must not auto-spend post-recruitment companion points")
    _check(SkillProgression.available_points(party_candidate) == party_points_before_level + 7, "Companion level-up pools remain available for player allocation")

    var ordinary_npc := CharacterState.new("ordinary_npc", "Ordinary NPC", Vector2i(2, 0))
    var ordinary_build := NPCSkillSpending.build_population(ordinary_npc, "goblin", 1, "ordinary_npc:population")
    _check(bool(ordinary_build.get("ok", false)))
    simulation.register_character(ordinary_npc)
    var npc_spent_before := 0
    for value in ordinary_npc.skill_spent_by_pool.values():
        npc_spent_before += int(value)
    var npc_level := simulation.grant_character_level("ordinary_npc", "fighter", "ordinary_npc:level2")
    var npc_spent_after := 0
    for value in ordinary_npc.skill_spent_by_pool.values():
        npc_spent_after += int(value)
    _check(bool(npc_level.get("ok", false)) and String(npc_level.get("reason", "")) == "npc_level_granted_and_allocated", "Non-party NPC level-ups should automatically allocate their new points")
    _check(npc_spent_after > npc_spent_before, "Non-party NPCs should spend new level points automatically")
    var npc_report := SkillProgression.accounting_report(ordinary_npc)
    for pool in npc_report.get("pools", {}):
        _check(bool(npc_report.pools[pool].get("balanced", false)), "NPC level-up budgets must remain reconciled")

    var world_saved := simulation.to_dict()
    var world_restored := WorldSimulation.new()
    world_restored.load_dict(world_saved)
    _check(world_restored.is_party_member("party_candidate"), "Party membership survives world save/load")
    _check(world_restored.get_character("party_candidate").companion_recruitment_initialized, "Companion recruitment history survives world save/load")

    var civilian := CharacterState.new("civilian_test", "Civilian Test")
    var civilian_result := NPCSkillSpending.build_civilian(civilian)
    _check(bool(civilian_result.get("ok", false)) and SkillProgression.available_points(civilian) == 0, "Civilians use an explicit zero-class, zero-point progression mode")

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
    _check(CharacterCreationRules.race_ids().size() == 5, "Character creator matches the five races in the original 2D game")

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

func _test_canonical_weapon_skill_runtime() -> void:
    var attacker := CharacterState.new("weapon_skill_attacker", "Weapon Skill Attacker")
    attacker.base_damage = 1
    attacker.time_points = 20.0
    attacker.skills["sword_hit"] = 1
    attacker.skills["sword_dmg"] = 1
    var sword := ItemCatalog.create_instance("starforged_blade", "skill_sword")
    _check(attacker.add_inventory_item(sword) and attacker.equip_inventory_item("skill_sword"))
    var target := CharacterState.new("weapon_skill_target", "Target")
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var result := CombatRules.resolve_attack(attacker, target, {"time_point_cost": 1.0}, rng)
    _check(is_equal_approx(float(result.get("hit_chance", 0.0)), 55.0), "Sword variants derive canonical sword_hit rank")
    _check(int(result.get("raw_damage", 0)) == 6, "Sword variants derive sword_dmg in the normal resolver")

    var axe_attacker := CharacterState.new("axe_skill_attacker", "Axe Skill Attacker")
    axe_attacker.time_points = 20.0
    axe_attacker.base_damage = 1
    axe_attacker.skills["axe_hit"] = 1
    axe_attacker.skills["axe_dmg"] = 3
    var axe := ItemCatalog.create_instance("axe", "skill_axe")
    _check(axe_attacker.add_inventory_item(axe) and axe_attacker.equip_inventory_item("skill_axe"))
    var axe_target := CharacterState.new("axe_skill_target", "Axe Target")
    rng.seed = 12
    var axe_result := CombatRules.resolve_attack(axe_attacker, axe_target, {"time_point_cost": 1.0}, rng)
    _check(is_equal_approx(float(axe_result.get("hit_chance", 0.0)), 55.0), "Axe proficiency adds five percentage points")
    _check(int(axe_result.get("raw_damage", 0)) == 10, "Axe damage mastery adds two damage per rank")

    var unarmed := CharacterState.new("unarmed_skill_attacker", "Unarmed Attacker")
    unarmed.base_damage = 1
    unarmed.time_points = 20.0
    unarmed.skills["unarmed_hit"] = 1
    unarmed.skills["unarmed_dmg"] = 1
    var unarmed_target := CharacterState.new("unarmed_skill_target", "Unarmed Target")
    # Use a deterministic seed that rolls a hit at the 55% test chance; a miss
    # correctly reports zero raw damage and would not exercise unarmed mastery.
    rng.seed = 11
    var unarmed_result := CombatRules.resolve_attack(unarmed, unarmed_target, {"time_point_cost": 1.0}, rng)
    _check(is_equal_approx(float(unarmed_result.get("hit_chance", 0.0)), 55.0), "Unarmed proficiency applies when no weapon is equipped")
    _check(int(unarmed_result.get("raw_damage", 0)) == 3, "Unarmed mastery adds two damage")

    var caught := CharacterState.new("caught_target", "Caught Target")
    caught.caught_off_guard = true
    var opportunist := CharacterState.new("opportunist", "Opportunist")
    opportunist.skills["goblin_opportunist"] = 1
    _check(CombatRules.raw_damage(opportunist, CombatRules.options_with_skill_ranks(opportunist, caught, {})) == 4, "Goblin Opportunist derives target caught-off-guard state")

    var shielded := CharacterState.new("shielded", "Shielded")
    shielded.skills["shield_proficiency"] = 1
    var shield := ItemCatalog.create_instance("wooden_shield", "skill_shield")
    _check(shielded.add_inventory_item(shield) and shielded.equip_inventory_item("skill_shield"))
    _check(CombatRules.damage_reduction(shielded) == 2, "Shield Proficiency adds one passive point with a shield equipped")

func _test_core_character_skill_runtime() -> void:
    var character := CharacterState.new("core_skill_character", "Core Skill Character")
    character.health = 60
    character.max_health = 100
    character.attributes = {"endurance": 3, "agility": 2, "rogue": 2}
    SkillProgression.initialise(character)
    _check(bool(SkillProgression.purchase(character, "health").get("ok", false)))
    _check(character.max_health == 110 and character.health == 70, "Health adds ten current and maximum HP per rank")
    _check(bool(SkillProgression.purchase(character, "health_regen").get("ok", false)))
    _check(is_equal_approx(character.health_regeneration_per_time_point(), 0.2), "Constitution adds 0.1 HP regeneration per TP")
    _check(bool(SkillProgression.purchase(character, "timePointRate").get("ok", false)))
    _check(is_equal_approx(character.time_points_per_tick, 1.05), "Time Point Rate adds 0.05 TP per tick per rank")
    _check(bool(SkillProgression.purchase(character, "quickRecovery").get("ok", false)))
    _check(character.quick_recovery_rank == 1, "Quick Recovery feeds the existing turn-end threshold")
    _check(bool(SkillProgression.purchase(character, "initiativeBonus").get("ok", false)))

    var simulation := WorldSimulation.new()
    character.time_points = 100.0
    simulation.register_character(character)
    simulation.start_combat()
    _check(is_equal_approx(character.time_points, 105.0), "Initiative Bonus grants five TP per rank at combat start")
    simulation.end_combat()
    character.health = 50
    character.time_points = 0.0
    simulation.advance_world_seconds(2.0)
    _check(character.health == 51, "Constitution accumulates fractional healing against TP gained")
    var restored := CharacterState.from_dict(character.to_dict())
    _check(restored.max_health == character.max_health and restored.health == character.health, "Derived HP and regeneration state survives save/load")
    _check(restored.quick_recovery_rank == 1 and is_equal_approx(restored.time_points_per_tick, 1.05), "Action-economy skill ranks survive save/load")
    simulation.free()

func _test_additional_skill_effects() -> void:
    var foliage_map := HexMapData.new()
    foliage_map.add_cell(Vector2i.ZERO, 0.0, true, "foliage")
    var untrained := CharacterState.new("untrained", "Untrained")
    _check(is_equal_approx(MovementRules.terrain_multiplier(foliage_map, Vector2i.ZERO, untrained), 1.5), "Foliage should retain its normal movement penalty without a relevant skill")

    var elf := CharacterState.new("woodland_elf", "Woodland Elf")
    elf.skills["elf_foliage_expertise"] = 1
    _check(is_equal_approx(MovementRules.terrain_multiplier(foliage_map, Vector2i.ZERO, elf), 1.0), "Woodland Stride should remove the foliage movement penalty")
    var druid := CharacterState.new("woodland_druid", "Woodland Druid")
    druid.skills["druid_foliage_expertise"] = 1
    _check(is_equal_approx(MovementRules.terrain_multiplier(foliage_map, Vector2i.ZERO, druid), 1.0), "Foliage Mastery should remove the foliage movement penalty")

    var fast := CharacterState.new("fast_mover", "Fast Mover")
    fast.skills["fastMovement"] = 1
    fast.equipment["armour"] = "light_armor"
    _check(is_equal_approx(MovementRules.base_cost_for(fast), 4.0), "Fast Movement should reduce movement cost by its rank in light armour")
    var swift := CharacterState.new("swift_mover", "Swift Mover")
    swift.skills["swift_step"] = 1
    _check(is_equal_approx(MovementRules.base_cost_for(swift), 4.0), "Swift Step should reduce unarmoured, unshielded movement cost by one")
    swift.equipment["offhand"] = "shield"
    _check(is_equal_approx(MovementRules.base_cost_for(swift), 5.0), "Swift Step should not apply while carrying a shield")

    var attacker := CharacterState.new("skill_attacker", "Skill Attacker")
    attacker.base_damage = 10
    attacker.max_health = 100
    attacker.health = 50
    attacker.skills["dwarf_axe_mastery"] = 1
    attacker.skills["orc_ferocity"] = 1
    attacker.skills["goblin_opportunist"] = 1
    var combined_damage := CombatRules.raw_damage(attacker, {
        "weapon_id": "axe",
        "target_caught_off_guard": true
    })
    _check(combined_damage == 19, "Axe Mastery, Orc Ferocity and Goblin Opportunist should contribute their documented damage bonuses")
    attacker.health = 51
    var above_ferocity_threshold := CombatRules.raw_damage(attacker, {
        "weapon_id": "axe",
        "target_caught_off_guard": false
    })
    _check(above_ferocity_threshold == 12, "Orc Ferocity should stop applying above half health")

    var spectral_target := CharacterState.new("spectral_target", "Spectral Target")
    spectral_target.skills["spectral_form"] = 1
    _check(CombatRules.damage_reduction(spectral_target) == 2, "Spectral Form should add two points of damage reduction")

    for weapon_id in ["sword", "dagger"]:
        var sim := WorldSimulation.new()
        sim.map_data.add_cell(Vector2i.ZERO)
        sim.map_data.add_cell(Vector2i(1, 0))
        var striker := CharacterState.new("striker_%s" % weapon_id, "Striker", Vector2i.ZERO)
        var parrier := CharacterState.new("parrier_%s" % weapon_id, "Parrier", Vector2i(1, 0))
        striker.to_hit_melee = 100.0
        striker.time_points = 30.0
        parrier.to_hit_melee = 100.0
        parrier.time_points = 20.0
        parrier.equipment["weapon"] = weapon_id
        parrier.skills[weapon_id + "_parry"] = 1
        parrier.skills[weapon_id + "_parry_cost"] = 1
        parrier.skills[weapon_id + "_parry_chance"] = 1
        var action_events: Array[Dictionary] = []
        sim.combat_action_resolved.connect(func(event: Dictionary) -> void:
            action_events.append(event)
        )
        sim.register_character(striker)
        sim.register_character(parrier)
        sim.start_combat()
        sim.turn_scheduler.current_character_id = striker.id
        var pending := sim.try_attack_character(striker.id, parrier.id, {"time_point_cost": 5.0}, 123)
        _check(bool(pending.get("pending", false)), "%s Parry should be offered when its weapon skill is present" % weapon_id.capitalize())
        var resolved := sim.resolve_reaction("parry")
        _check(bool(resolved.get("ok", false)), "%s Parry should resolve" % weapon_id.capitalize())
        _check(is_equal_approx(parrier.time_points, 18.0), "%s Parry Efficiency should reduce the reaction cost from 3 TP to 2 TP" % weapon_id.capitalize())
        _check(not action_events.is_empty(), "%s Parry should emit a resolved combat event" % weapon_id.capitalize())
        if not action_events.is_empty():
            _check(int(action_events[0].get("parry_chance", 0)) == 155, "%s Parry Mastery should add five percentage points per rank" % weapon_id.capitalize())
        sim.free()

    var sidestep_sim := WorldSimulation.new()
    for q in range(-1, 3):
        for r in range(-1, 3):
            sidestep_sim.map_data.add_cell(Vector2i(q, r))
    var mover := CharacterState.new("mastery_mover", "Mover", Vector2i.ZERO)
    var sidestepper := CharacterState.new("mastery_sidestepper", "Sidestepper", Vector2i(0, 1))
    mover.time_points = 100.0
    sidestepper.time_points = 20.0
    sidestepper.skills["sidestep"] = 1
    sidestepper.skills["sidestep_mastery"] = 1
    sidestep_sim.register_character(mover)
    sidestep_sim.register_character(sidestepper)
    sidestep_sim.start_combat()
    sidestep_sim.turn_scheduler.current_character_id = mover.id
    var movement_pending := sidestep_sim.try_move_character_step(mover.id, Vector2i(1, 0))
    _check(movement_pending and not sidestep_sim.pending_reaction.is_empty(), "Sidestep Mastery should retain the Sidestep reaction")
    var destination_stage := sidestep_sim.resolve_reaction("sidestep_mastery_sidestepper")
    _check(bool(destination_stage.get("pending", false)), "Sidestep Mastery should open the destination-selection stage")
    var destination_result := sidestep_sim.resolve_reaction("sidestep_to_1_1")
    _check(bool(destination_result.get("ok", false)), "A mastered Sidestep should resolve")
    _check(is_equal_approx(sidestepper.time_points, 15.0), "Sidestep Mastery should reduce Sidestep cost from 6 TP to 5 TP")
    sidestep_sim.free()
