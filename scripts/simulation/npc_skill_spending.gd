class_name NPCSkillSpending
extends RefCounted
## Source-derived NPC build policy. Uses the same SkillProgression purchase path
## as the player; only the choice of who spends points differs.

const NON_PLAYER_RACE_BONUSES := {
    "ogre": {"strength": 4, "endurance": 4, "weapons": 1},
    "troll": {"strength": 3, "endurance": 4},
    "minotaur": {"strength": 3, "endurance": 2, "weapons": 1},
    "harpy": {"agility": 3, "endurance": 1},
    "revenant": {"strength": 2, "endurance": 3},
    "skeleton": {"strength": 1, "endurance": 2, "weapons": 1},
    "zombie": {"strength": 2, "endurance": 4}
}
const RACIAL_TREES := {"dwarf": "dwarf", "elf": "elf", "goblin": "goblin", "orc": "orc"}
const RACE_PACKAGES := {
    "human": [["fighter", 18.0], ["rogue", 16.0], ["cleric", 12.0], ["wizard", 12.0], ["druid", 10.0], ["monk", 8.0], ["fighter/rogue", 8.0], ["fighter/cleric", 6.0], ["rogue/wizard", 5.0], ["fighter/wizard", 3.0], ["rogue/druid", 2.0]],
    "dwarf": [["fighter", 45.0], ["fighter/cleric", 25.0], ["cleric", 15.0], ["fighter/monk", 10.0], ["rogue", 5.0]],
    "elf": [["wizard", 30.0], ["rogue/wizard", 25.0], ["rogue", 20.0], ["fighter/wizard", 10.0], ["druid", 10.0], ["fighter", 5.0]],
    "goblin": [["rogue", 25.0], ["rogue/fighter", 25.0], ["rogue/wizard", 25.0], ["wizard", 12.5], ["fighter/cleric", 12.5]],
    "orc": [["fighter", 55.0], ["fighter/rogue", 20.0], ["fighter/cleric", 15.0], ["fighter/druid", 5.0], ["cleric", 5.0]],
    "ogre": [["fighter", 65.0], ["fighter/rogue", 10.0], ["fighter/cleric", 10.0], ["fighter/druid", 10.0], ["monk", 5.0]],
    "troll": [["fighter", 60.0], ["fighter/druid", 20.0], ["fighter/cleric", 10.0], ["rogue", 10.0]],
    "minotaur": [["fighter", 70.0], ["fighter/rogue", 15.0], ["fighter/cleric", 10.0], ["monk", 5.0]],
    "harpy": [["rogue", 35.0], ["rogue/wizard", 30.0], ["wizard", 20.0], ["rogue/druid", 10.0], ["fighter/rogue", 5.0]],
    "revenant": [["fighter", 55.0], ["fighter/cleric", 30.0], ["cleric", 10.0], ["fighter/rogue", 5.0]],
    "skeleton": [["fighter", 60.0], ["fighter/rogue", 20.0], ["fighter/cleric", 10.0], ["rogue", 10.0]],
    "zombie": [["fighter", 80.0], ["fighter/cleric", 20.0]]
}
const INNATE_RACE_SKILLS := {
    "troll": {"regeneration": 1},
    "minotaur": {"gore_charge": 1},
    "harpy": {"siren_song": 1},
    "revenant": {"revenant_revive": 1}
}
const TREE_PRIORITIES := {
    "strength": ["meleeDamage", "shove", "iron_grip"],
    "endurance": ["health", "health_regen"],
    "agility": ["riding", "fastMovement", "keen_perception", "stealth_agility", "sure_footed", "timePointRate", "sidestep", "sidestep_mastery"],
    "fighter": ["battle_reflexes", "protector"],
    "rogue": ["stealth_rogue", "quickRecovery", "initiativeBonus", "speedy_stealth", "subtle_spell", "dagger_quick_draw", "assassinate"],
    "wizard": ["firebolt_hit", "arcane_eff_range", "arcane_eff_magnitude", "arcane_eff_speed"],
    "cleric": ["divine_judgment", "holy_ground", "cleric_trigger_damage", "cleric_trigger_mana", "cleric_trigger_vision", "cleric_trigger_dmg_red", "cleric_trigger_heal_red", "extended_sentence", "armistice"],
    "druid": ["druid_foliage_expertise", "druid_knowledge_nature"],
    "monk": ["swift_step", "trip_reaction", "agile_climber", "disarm"],
    "arcane": ["learn_firebolt", "arcane_mana", "arcane_regen", "learn_counterspell", "arcane_expand", "arcane_targets"],
    "divine": ["learn_heal", "divine_mana", "divine_regen", "learn_smite_evil", "learn_divine_protection", "learn_divine_silence", "learn_sanctuary", "knowledge_religion"],
    "nature": ["learn_summon_animal", "nature_mana", "nature_regen", "learn_entangle", "learn_calm_animal", "learn_wild_fury"],
    "goblin": ["goblin_quick_reflexes", "goblin_opportunist", "goblin_low_light_eyes", "goblin_pack_hunter", "goblin_keen_senses"],
    "orc": ["orc_brute_strength", "orc_thick_hide", "orc_ferocity", "orc_momentum", "orc_relentless"],
    "elf": ["elf_vision", "elf_darkvision", "elf_bow_range", "keen_hearing", "whisper_step", "elf_foliage_expertise", "elf_knowledge_nature", "elven_grace", "ageless_patience"]
}
const SOFT_CAPS := {
    "health": 4, "health_regen": 2, "meleeDamage": 3, "timePointRate": 3,
    "quickRecovery": 4, "initiativeBonus": 3, "arcane_mana": 3,
    "divine_mana": 3, "nature_mana": 3, "arcane_regen": 2,
    "divine_regen": 2, "nature_regen": 2
}
const EXCLUDED_SKILLS := ["learn_unicorn_summon", "runesmithing", "leatherworking"]

static func _rng(seed_text: String) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(seed_text)
    if rng.seed == 0:
        rng.seed = 1
    return rng

static func _racial_tree(race: String) -> String:
    return String(RACIAL_TREES.get(race, ""))

static func _race_bonus(race: String) -> Dictionary:
    var definition := CharacterCreationRules.race_definition(race)
    if not definition.is_empty():
        return definition.get("bonus", {}).duplicate(true)
    return NON_PLAYER_RACE_BONUSES.get(race, {}).duplicate(true)

static func _ordered_sequence(character: CharacterState, options: Dictionary) -> Array[String]:
    var sequence: Array[String] = []
    var supplied: Variant = options.get("class_levels", [])
    if supplied is Array:
        for class_id in supplied:
            sequence.append(String(class_id))
    if sequence.is_empty() and not character.class_level_sequence.is_empty():
        sequence = character.class_level_sequence.duplicate()
    if sequence.is_empty():
        var keys: Array = character.class_levels.keys()
        keys.sort()
        for class_id in keys:
            for _i in range(maxi(0, int(character.class_levels[class_id]))):
                sequence.append(String(class_id))
    return sequence

static func _build_attributes(race: String, class_sequence: Array[String]) -> Dictionary:
    var attributes: Dictionary = {}
    for pool in ["strength", "endurance", "agility", "weapons", "divine", "nature", "arcane", "wildcard", "fighter", "rogue", "cleric", "wizard", "druid", "monk", "Way of the open palm", "dwarf", "elf", "goblin", "orc"]:
        attributes[pool] = 0
    var race_bonus := _race_bonus(race)
    for pool in race_bonus:
        attributes[pool] = int(attributes.get(pool, 0)) + int(race_bonus[pool])
    for class_id in class_sequence:
        var class_bonus := CharacterCreationRules.class_definition(class_id).get("bonus", {})
        for pool in class_bonus:
            attributes[pool] = int(attributes.get(pool, 0)) + int(class_bonus[pool])
    if _racial_tree(race).is_empty():
        if int(attributes.get("wildcard", 0)) > 0:
            attributes["wildcard"] = int(attributes["wildcard"]) - 1
        var primary := class_sequence[0] if not class_sequence.is_empty() else "fighter"
        attributes[primary] = int(attributes.get(primary, 0)) + 1
    return attributes

static func _counts(sequence: Array[String]) -> Dictionary:
    var result := {}
    for class_id in sequence:
        result[class_id] = int(result.get(class_id, 0)) + 1
    return result

static func _pick_package(race: String, rng: RandomNumberGenerator) -> Array[String]:
    var rows: Array = RACE_PACKAGES.get(race, RACE_PACKAGES["human"])
    var total := 0.0
    for row in rows:
        total += float(row[1])
    var roll := rng.randf() * maxf(total, 1.0)
    for row in rows:
        roll -= float(row[1])
        if roll <= 0.0:
            var classes: Array[String] = []
            for class_id in String(row[0]).split("/"):
                classes.append(class_id)
            return classes
    var fallback: Array[String] = []
    for class_id in String(rows.back()[0]).split("/"):
        fallback.append(class_id)
    return fallback

static func _expand_package(package_classes: Array[String], level: int) -> Array[String]:
    var sequence: Array[String] = []
    if package_classes.is_empty():
        package_classes = ["fighter"]
    for index in range(maxi(1, level)):
        sequence.append(package_classes[index % package_classes.size()])
    return sequence

static func build_population(character: CharacterState, race: String, level: int, seed: String, options: Dictionary = {}) -> Dictionary:
    if character == null or race.is_empty() or seed.is_empty():
        return {"ok": false, "reason": "invalid_population_build"}
    var rng := _rng(seed + ":package")
    var package_classes := _pick_package(race, rng)
    var sequence := _expand_package(package_classes, level)
    var merged := options.duplicate(true)
    merged["class_levels"] = sequence
    merged["race"] = race
    merged["seed"] = seed
    merged["mode"] = "population"
    merged["authored"] = false
    return build_npc(character, merged)

static func build_authored(character: CharacterState, race: String, class_sequence: Array[String], preferred_skills: Dictionary, seed: String, options: Dictionary = {}) -> Dictionary:
    if class_sequence.is_empty():
        return {"ok": false, "reason": "authored_npc_requires_class_levels"}
    var merged := options.duplicate(true)
    merged["class_levels"] = class_sequence
    merged["race"] = race
    merged["preferred_skills"] = preferred_skills
    merged["seed"] = seed
    merged["mode"] = "authored"
    merged["authored"] = true
    return build_npc(character, merged)

static func build_npc(character: CharacterState, options: Dictionary) -> Dictionary:
    if character == null:
        return {"ok": false, "reason": "missing_character"}
    if character.skill_progression_initialized and not bool(options.get("force_rebuild", false)):
        return {"ok": false, "reason": "progression_already_initialised"}
    var race := String(options.get("race", character.race))
    var sequence := _ordered_sequence(character, options)
    if sequence.is_empty():
        if String(options.get("mode", "")) == "civilian":
            return build_civilian(character, race)
        return {"ok": false, "reason": "missing_class_levels"}
    for class_id in sequence:
        if CharacterCreationRules.class_definition(class_id).is_empty():
            return {"ok": false, "reason": "unknown_class", "class_id": class_id}
    character.race = race
    character.character_class = sequence[0]
    character.class_level_sequence = sequence.duplicate()
    character.class_levels = _counts(sequence)
    character.level = sequence.size()
    character.attributes = _build_attributes(race, sequence)
    character.skill_progression_initialized = false
    character.skill_budget_by_pool.clear()
    character.skill_spent_by_pool.clear()
    character.skill_spent_by_id.clear()
    character.skill_point_grants.clear()
    character.companion_recruitment_initialized = false
    character.skills = {}
    character.free_skill_ranks = {}
    character.npc_progression_warnings.clear()
    character.npc_equipment_legality_warnings.clear()
    character.npc_innate_skills.clear()
    character.npc_preferred_skills = options.get("preferred_skills", {}).duplicate(true)
    character.npc_progression_seed = String(options.get("seed", character.id))
    character.npc_authored_progression = bool(options.get("authored", false))
    character.progression_mode = String(options.get("mode", "population"))
    SkillProgression.initialise(character)
    character.npc_skill_point_budget = SkillProgression.available_points(character)
    var combined_innate: Dictionary = INNATE_RACE_SKILLS.get(race, {}).duplicate(true)
    for skill_id in options.get("innate_skills", {}):
        combined_innate[skill_id] = maxi(int(combined_innate.get(skill_id, 0)), int(options.innate_skills[skill_id]))
    _apply_innate_skills(character, combined_innate)
    var archetype: Array = options.get("archetype_skills", [])
    var result := _spend_all(character, character.npc_preferred_skills, archetype, character.npc_progression_seed)
    _check_equipment_legality(character)
    character.npc_unspent_skill_points = SkillProgression.available_points(character)
    return {"ok": true, "reason": "npc_built", "level": character.level, "budget": character.npc_skill_point_budget, "remaining": character.npc_unspent_skill_points, "spending": result, "warnings": character.npc_progression_warnings.duplicate(true)}

static func build_civilian(character: CharacterState, race: String = "human") -> Dictionary:
    if character == null:
        return {"ok": false, "reason": "missing_character"}
    character.race = race
    character.character_class = ""
    character.class_level_sequence.clear()
    character.class_levels.clear()
    character.level = 1
    character.attributes = _build_empty_attributes()
    character.skill_progression_initialized = false
    character.skill_budget_by_pool.clear()
    character.skill_spent_by_pool.clear()
    character.skill_spent_by_id.clear()
    character.skill_point_grants.clear()
    character.companion_recruitment_initialized = false
    character.skills.clear()
    character.free_skill_ranks.clear()
    character.npc_skill_point_budget = 0
    character.npc_unspent_skill_points = 0
    character.npc_preferred_skills.clear()
    character.npc_progression_warnings.clear()
    character.progression_mode = "civilian"
    character.npc_authored_progression = false
    SkillProgression.initialise(character)
    return {"ok": true, "reason": "civilian_built", "budget": 0}

static func recruit_companion(character: CharacterState, preferred_skills: Dictionary = {}, seed: String = "") -> Dictionary:
    if character == null:
        return {"ok": false, "reason": "missing_character"}
    if character.companion_recruitment_initialized:
        character.progression_mode = "companion"
        return {"ok": false, "reason": "already_recruited_once", "remaining": SkillProgression.available_points(character)}
    SkillProgression.initialise(character)
    var snapshot: Dictionary = {}
    for pool in character.attributes:
        snapshot[String(pool)] = int(character.attributes[pool])
    character.companion_recruitment_budget_by_pool = snapshot.duplicate(true)
    var merged_preferences := character.npc_preferred_skills.duplicate(true)
    for skill_id in preferred_skills:
        merged_preferences[skill_id] = maxi(int(merged_preferences.get(skill_id, 0)), int(preferred_skills[skill_id]))
    var chosen_seed := seed if not seed.is_empty() else character.id + ":first-recruitment"
    var spending := _spend_all(character, merged_preferences, [], chosen_seed)
    character.companion_recruitment_initialized = true
    character.progression_mode = "companion"
    character.npc_unspent_skill_points = SkillProgression.available_points(character)
    return {"ok": true, "reason": "companion_recruited", "spent_at_recruitment": spending.get("spent", 0), "remaining": character.npc_unspent_skill_points, "budget_snapshot": snapshot}

static func _build_empty_attributes() -> Dictionary:
    var result := {}
    for pool in ["strength", "endurance", "agility", "weapons", "divine", "nature", "arcane", "wildcard", "fighter", "rogue", "cleric", "wizard", "druid", "monk", "Way of the open palm", "dwarf", "elf", "goblin", "orc"]:
        result[pool] = 0
    return result

static func _apply_innate_skills(character: CharacterState, innate: Dictionary) -> void:
    for skill_id in innate:
        var rank := maxi(0, int(innate[skill_id]))
        if rank <= 0:
            continue
        character.npc_innate_skills[skill_id] = maxi(int(character.npc_innate_skills.get(skill_id, 0)), rank)
        character.free_skill_ranks[skill_id] = int(character.free_skill_ranks.get(skill_id, 0)) + rank
        character.skills[skill_id] = int(character.skills.get(skill_id, 0)) + rank

static func _total_points(attributes: Dictionary) -> int:
    var total := 0
    for value in attributes.values():
        total += maxi(0, int(value))
    return total

static func _weapon_id(character: CharacterState) -> String:
    return String(character.equipment.get("weapon", ""))

static func _has_shield(character: CharacterState) -> bool:
    var offhand := String(character.equipment.get("offhand", ""))
    return String(ItemCatalog.get_definition(offhand).get("type", "")) == "shield"

static func _armor_training_for_item(item_id: String) -> Array[String]:
    var item := ItemCatalog.get_definition(item_id)
    if item.is_empty() or String(item.get("type", "")) != "armor" or String(item.get("subType", "")) == "barding":
        return []
    var reduction := int(item.get("reduction", 0))
    if reduction >= 3:
        return ["light_armor_training", "medium_armor_training", "heavy_armor_training"]
    if reduction >= 2:
        return ["light_armor_training", "medium_armor_training"]
    if reduction >= 1:
        return ["light_armor_training"]
    return []

static func _contextually_suitable(character: CharacterState, skill_id: String, skill: Dictionary) -> bool:
    if EXCLUDED_SKILLS.has(skill_id) or String(skill.get("tree", "")) == "monster_skills":
        return false
    var tree := String(skill.get("tree", ""))
    if RACIAL_TREES.values().has(tree) and tree != _racial_tree(character.race):
        return false
    if skill_id in ["light_armor_training", "medium_armor_training", "heavy_armor_training"]:
        return _armor_training_for_item(String(character.equipment.get("armor", ""))).has(skill_id)
    if skill_id in ["shield_proficiency", "shield_bash", "shield_other"]:
        return _has_shield(character)
    if skill_id in ["riding", "riding_druid", "riding_paladin"]:
        return character.is_rider or character.tags.has("requires_riding_skill")
    for prefix in ["sword_", "axe_", "bow_", "spear_", "dagger_", "club_"]:
        if skill_id.begins_with(prefix):
            var equipped_weapon := _weapon_id(character)
            if not equipped_weapon.is_empty() and equipped_weapon != prefix.trim_suffix("_"):
                return false
    return true

static func _soft_cap(skill_id: String) -> int:
    return int(SOFT_CAPS.get(skill_id, 0))

static func _dynamic_dependencies(skill_id: String) -> Array:
    match skill_id:
        "protector":
            return [["sword_parry", 1], ["dagger_parry", 1]]
        "nature_bounty", "nature_butchery", "nature_ranger":
            return [["druid_knowledge_nature", 1], ["elf_knowledge_nature", 1]]
        "elven_grace":
            return [["elf_foliage_expertise", 1], ["elf_darkvision", 1]]
        "axe_cleave":
            return [["axe_dmg", 2]]
        "headsmans_blow":
            return [["axe_dmg", 3]]
        _:
            return []

static func _rank_legal(character: CharacterState, skill_id: String, ignore_soft_cap: bool) -> bool:
    if not ignore_soft_cap:
        var cap := _soft_cap(skill_id)
        if cap > 0 and int(character.skills.get(skill_id, 0)) >= cap:
            return false
    return _contextually_suitable(character, skill_id, SkillCatalog.get_skill(skill_id))

static func _spend_one(character: CharacterState, skill_id: String, ignore_soft_cap: bool = false) -> bool:
    if not _rank_legal(character, skill_id, ignore_soft_cap):
        return false
    var check := SkillProgression.can_purchase(character, skill_id)
    if String(check.get("reason", "")) == "funding_pool_choice_required":
        var pools: Array = check.get("available_pools", [])
        if pools.is_empty():
            return false
        check = SkillProgression.can_purchase(character, skill_id, {"funding_pool": String(pools[0])})
    if not bool(check.get("ok", false)):
        return false
    return bool(SkillProgression.purchase(character, skill_id, String(check.get("funding_pool", "")).strip_edges()).get("ok", false))

static func _spend_with_prerequisites(character: CharacterState, skill_id: String, ignore_soft_cap: bool, visited: Dictionary = {}) -> bool:
    if visited.has(skill_id):
        return false
    visited[skill_id] = true
    var skill := SkillCatalog.get_skill(skill_id)
    if skill.is_empty() or EXCLUDED_SKILLS.has(skill_id):
        return false
    var prerequisite_value: Variant = skill.get("prerequisite", null)
    var prerequisite := "" if prerequisite_value == null else String(prerequisite_value)
    if not prerequisite.is_empty() and int(character.skills.get(prerequisite, 0)) <= 0:
        _spend_with_prerequisites(character, prerequisite, ignore_soft_cap, visited)
    for dependency in _dynamic_dependencies(skill_id):
        var dependency_id := String(dependency[0])
        var target_rank := int(dependency[1])
        var alternatives := dependency_id.split("|")
        if alternatives.size() > 1:
            var satisfied := false
            for alternative in alternatives:
                if int(character.skills.get(alternative, 0)) >= target_rank:
                    satisfied = true
            if not satisfied:
                for alternative in alternatives:
                    if _spend_with_prerequisites(character, alternative, true, visited):
                        satisfied = true
                        break
            if not satisfied:
                return false
        else:
            while int(character.skills.get(dependency_id, 0)) < target_rank:
                if not _spend_with_prerequisites(character, dependency_id, true, visited):
                    return false
                visited.erase(dependency_id)
    return _spend_one(character, skill_id, ignore_soft_cap)

static func _priority_list(character: CharacterState, preferred: Dictionary, archetype: Array) -> Array[String]:
    var priorities: Array[String] = []
    var add := func(skill_id: String) -> void:
        if not priorities.has(skill_id) and not SkillCatalog.get_skill(skill_id).is_empty():
            priorities.append(skill_id)
    var preferred_ids: Array = preferred.keys()
    preferred_ids.sort_custom(func(a, b):
        var rank_a := int(preferred[a])
        var rank_b := int(preferred[b])
        return rank_a > rank_b if rank_a != rank_b else String(a) < String(b)
    )
    for skill_id in preferred_ids:
        add.call(String(skill_id))
    for skill_id in archetype:
        add.call(String(skill_id))
    var weapon := _weapon_id(character)
    if not weapon.is_empty():
        for suffix in ["hit", "dmg", "parry", "riposte"]:
            add.call(weapon + "_" + suffix)
    if _has_shield(character):
        for skill_id in ["shield_proficiency", "shield_bash", "shield_other"]:
            add.call(skill_id)
    for class_id in character.class_level_sequence:
        for skill_id in TREE_PRIORITIES.get(class_id, []):
            add.call(String(skill_id))
        var school := {"wizard": "arcane", "cleric": "divine", "druid": "nature"}.get(class_id, "")
        for skill_id in TREE_PRIORITIES.get(school, []):
            add.call(String(skill_id))
    for skill_id in TREE_PRIORITIES.get(_racial_tree(character.race), []):
        add.call(String(skill_id))
    for tree in ["strength", "endurance", "agility", "weapons"]:
        for skill_id in TREE_PRIORITIES.get(tree, []):
            add.call(String(skill_id))
    return priorities

static func _spend_all(character: CharacterState, preferred: Dictionary, archetype: Array, seed: String) -> Dictionary:
    var spent_before := 0
    for value in character.skill_spent_by_pool.values():
        spent_before += int(value)
    var required: Array[String] = []
    required.append_array(_armor_training_for_item(String(character.equipment.get("armor", ""))))
    if character.is_rider or character.tags.has("requires_riding_skill"):
        required.append("riding")
    for class_id in character.class_level_sequence:
        match class_id:
            "wizard": required.append("learn_firebolt")
            "cleric": required.append("learn_heal")
            "druid": required.append("learn_summon_animal")
            "monk": required.append("unarmed_hit")
    for skill_id in required:
        _spend_with_prerequisites(character, skill_id, true)
    for skill_id in preferred:
        var target := maxi(0, int(preferred[skill_id]))
        var guard := 0
        while int(character.skills.get(skill_id, 0)) < target and guard < 20:
            guard += 1
            if not _spend_with_prerequisites(character, String(skill_id), true):
                break
    var priorities := _priority_list(character, preferred, archetype)
    var progress := true
    var passes := 0
    while progress and SkillProgression.available_points(character) > 0 and passes < 60:
        progress = false
        passes += 1
        for skill_id in priorities:
            if _spend_with_prerequisites(character, skill_id, false):
                progress = true
            if SkillProgression.available_points(character) <= 0:
                break
    var rng := _rng(seed + ":fallback")
    var safety := 0
    while SkillProgression.available_points(character) > 0 and safety < 300:
        safety += 1
        var candidates: Array[String] = []
        for skill_id in SkillCatalog.all_skill_ids():
            var skill := SkillCatalog.get_skill(skill_id)
            if _contextually_suitable(character, skill_id, skill) and _rank_legal(character, skill_id, false):
                var check := SkillProgression.can_purchase(character, skill_id)
                if bool(check.get("ok", false)) or String(check.get("reason", "")) == "funding_pool_choice_required":
                    candidates.append(skill_id)
        if candidates.is_empty():
            break
        var picked := candidates[rng.randi_range(0, candidates.size() - 1)]
        if not _spend_with_prerequisites(character, picked, false):
            break
    var spent_after := 0
    for value in character.skill_spent_by_pool.values():
        spent_after += int(value)
    var remaining := SkillProgression.available_points(character)
    character.npc_unspent_skill_points = remaining
    if remaining > 0:
        character.npc_progression_warnings.append({
            "type": "unspent_skill_points",
            "points": remaining,
            "pools": _remaining_pools(character)
        })
    return {"spent": spent_after - spent_before, "remaining": remaining, "priority_count": priorities.size()}

static func _remaining_pools(character: CharacterState) -> Dictionary:
    var result := {}
    for pool in character.attributes:
        if int(character.attributes[pool]) > 0:
            result[pool] = int(character.attributes[pool])
    return result

static func _check_equipment_legality(character: CharacterState) -> void:
    var armor_id := String(character.equipment.get("armor", ""))
    var missing := []
    for skill_id in _armor_training_for_item(armor_id):
        if int(character.skills.get(skill_id, 0)) <= 0:
            missing.append(skill_id)
    if not missing.is_empty():
        character.npc_equipment_legality_warnings.append({"item_id": armor_id, "missing_skills": missing})
        character.equipment.erase("armor")
    if (character.is_rider or character.tags.has("requires_riding_skill")) and int(character.skills.get("riding", 0)) <= 0:
        character.npc_equipment_legality_warnings.append({"item_id": "mount", "missing_skills": ["riding"]})
