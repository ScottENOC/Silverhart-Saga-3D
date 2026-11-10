class_name SkillProgression
extends RefCounted
## Shared point accounting and legal skill purchases, based on Hex-crpg's
## learnSkill() rules. Skill effects are intentionally applied by later ports.

const STANDARD_TREES := [
    "arcane", "divine", "nature", "strength", "endurance", "agility", "weapons", "misc",
    "fighter", "rogue", "cleric", "wizard", "druid", "monk", "Way of the open palm",
    "dwarf", "elf", "goblin", "orc"
]
const NON_PURCHASABLE_TREES := [
    "monster_skills", "paladin", "lich", "runesmith", "leatherworker"
]

static func initialise(character: CharacterState) -> void:
    if character == null or character.skill_progression_initialized:
        return
    character.skill_budget_by_pool = {}
    character.skill_spent_by_pool = {}
    character.skill_spent_by_id = {}
    character.skill_point_grants = {}
    for pool in character.attributes:
        var remaining := maxi(0, int(character.attributes.get(pool, 0)))
        character.skill_budget_by_pool[String(pool)] = remaining
        character.skill_spent_by_pool[String(pool)] = 0
    character.skill_progression_initialized = true

static func available_points(character: CharacterState) -> int:
    if character == null:
        return 0
    var total := 0
    for value in character.attributes.values():
        total += maxi(0, int(value))
    return total

static func _pool_options(character: CharacterState, skill: Dictionary) -> Array[String]:
    var tree := String(skill.get("tree", ""))
    var options: Array[String] = []
    if tree == "misc":
        for pool in character.attributes:
            if int(character.attributes.get(pool, 0)) > 0:
                options.append(String(pool))
        options.sort()
        return options
    if int(character.attributes.get(tree, 0)) > 0:
        options.append(tree)
    elif tree != "misc" and int(character.attributes.get("wildcard", 0)) > 0:
        options.append("wildcard")
    return options

static func _dynamic_prerequisite_met(character: CharacterState, skill: Dictionary, context: Dictionary) -> bool:
    var rule := String(skill.get("dynamic_prerequisite_rule", ""))
    if rule.is_empty():
        return not bool(skill.get("dynamic_prerequisite", false))
    match rule:
        "protector_parry":
            return int(character.skills.get("sword_parry", 0)) > 0 or int(character.skills.get("dagger_parry", 0)) > 0
        "knowledge_nature":
            return int(character.skills.get("druid_knowledge_nature", 0)) > 0 or int(character.skills.get("elf_knowledge_nature", 0)) > 0
        "elven_grace":
            return int(character.skills.get("elf_foliage_expertise", 0)) > 0 or int(character.skills.get("elf_darkvision", 0)) > 0
        "axe_cleave":
            return int(character.skills.get("axe_dmg", 0)) >= 2
        "headsmans_blow":
            return int(character.skills.get("axe_dmg", 0)) >= 3
        "quest_granted_only":
            return false
        _:
            return false

static func can_purchase(character: CharacterState, skill_id: String, context: Dictionary = {}) -> Dictionary:
    if character == null:
        return {"ok": false, "reason": "missing_character"}
    initialise(character)
    var skill := SkillCatalog.get_skill(skill_id)
    if skill.is_empty():
        return {"ok": false, "reason": "unknown_skill"}
    var tree := String(skill.get("tree", ""))
    if NON_PURCHASABLE_TREES.has(tree):
        return {"ok": false, "reason": "skill_tree_not_player_purchasable"}
    if bool(skill.get("quest_granted_only", false)) or String(skill.get("dynamic_prerequisite_rule", "")) == "quest_granted_only":
        return {"ok": false, "reason": "quest_granted_only"}
    var current_rank := maxi(0, int(character.skills.get(skill_id, 0)))
    var max_ranks := int(skill.get("max_ranks", 0))
    if max_ranks > 0 and current_rank >= max_ranks:
        return {"ok": false, "reason": "maximum_rank_reached"}
    var prerequisite_value: Variant = skill.get("prerequisite", null)
    var prerequisite := "" if prerequisite_value == null else String(prerequisite_value)
    if not prerequisite.is_empty() and int(character.skills.get(prerequisite, 0)) <= 0:
        return {"ok": false, "reason": "prerequisite_missing", "prerequisite": prerequisite}
    var anti_prerequisite := String(skill.get("anti_prerequisite", ""))
    if not anti_prerequisite.is_empty() and int(character.skills.get(anti_prerequisite, 0)) > 0:
        return {"ok": false, "reason": "incompatible_skill_learned", "incompatible_skill": anti_prerequisite}
    if not _dynamic_prerequisite_met(character, skill, context):
        return {"ok": false, "reason": "dynamic_prerequisite_missing"}
    if skill_id in ["riding", "riding_druid", "riding_paladin"]:
        for riding_id in ["riding", "riding_druid", "riding_paladin"]:
            if int(character.skills.get(riding_id, 0)) > 0:
                return {"ok": false, "reason": "already_knows_riding"}
    var pools := _pool_options(character, skill)
    if pools.is_empty():
        return {"ok": false, "reason": "insufficient_skill_points"}
    var requested_pool := String(context.get("funding_pool", ""))
    if not requested_pool.is_empty():
        if not pools.has(requested_pool):
            return {"ok": false, "reason": "invalid_funding_pool", "available_pools": pools}
        return {"ok": true, "reason": "ok", "funding_pool": requested_pool, "skill": skill}
    if tree == "misc" and pools.size() > 1:
        return {"ok": false, "reason": "funding_pool_choice_required", "available_pools": pools}
    return {"ok": true, "reason": "ok", "funding_pool": pools[0], "skill": skill}

static func purchase(character: CharacterState, skill_id: String, funding_pool: String = "") -> Dictionary:
    var result := can_purchase(character, skill_id, {"funding_pool": funding_pool})
    if not bool(result.get("ok", false)):
        return result
    var pool := String(result.get("funding_pool", ""))
    character.attributes[pool] = int(character.attributes.get(pool, 0)) - 1
    character.skills[skill_id] = int(character.skills.get(skill_id, 0)) + 1
    character.skill_spent_by_pool[pool] = int(character.skill_spent_by_pool.get(pool, 0)) + 1
    character.skill_spent_by_id[skill_id] = int(character.skill_spent_by_id.get(skill_id, 0)) + 1
    return {
        "ok": true,
        "reason": "purchased",
        "skill_id": skill_id,
        "rank": int(character.skills[skill_id]),
        "funding_pool": pool
    }

static func grant_points(character: CharacterState, pool: String, amount: int, grant_id: String) -> Dictionary:
    if character == null or pool.is_empty() or amount <= 0 or grant_id.is_empty():
        return {"ok": false, "reason": "invalid_grant"}
    initialise(character)
    var grant_key := "pool:%s:%s" % [pool, grant_id]
    if character.skill_point_grants.has(grant_key):
        return {"ok": false, "reason": "grant_already_applied"}
    character.attributes[pool] = int(character.attributes.get(pool, 0)) + amount
    character.skill_budget_by_pool[pool] = int(character.skill_budget_by_pool.get(pool, 0)) + amount
    character.skill_point_grants[grant_key] = {"pool": pool, "amount": amount}
    return {"ok": true, "reason": "granted", "pool": pool, "amount": amount}


static func grant_level(character: CharacterState, class_id: String, grant_id: String) -> Dictionary:
    if character == null or class_id.is_empty() or grant_id.is_empty():
        return {"ok": false, "reason": "invalid_level_grant"}
    initialise(character)
    var grant_key := "level:" + grant_id
    if character.skill_point_grants.has(grant_key):
        return {"ok": false, "reason": "grant_already_applied"}
    var profession := CharacterCreationRules.class_definition(class_id)
    if profession.is_empty():
        return {"ok": false, "reason": "unknown_class"}
    var class_bonus: Dictionary = profession.get("bonus", {})
    var pools: Dictionary = {}
    for pool in class_bonus:
        var amount := int(class_bonus.get(pool, 0))
        if amount == 0:
            continue
        character.attributes[pool] = int(character.attributes.get(pool, 0)) + amount
        character.skill_budget_by_pool[pool] = int(character.skill_budget_by_pool.get(pool, 0)) + amount
        pools[pool] = amount
    character.class_levels[class_id] = int(character.class_levels.get(class_id, 0)) + 1
    character.class_level_sequence.append(class_id)
    character.level += 1
    if character.progression_mode != "player":
        var granted_total := 0
        for amount in pools.values():
            granted_total += int(amount)
        character.npc_skill_point_budget += granted_total
        character.npc_unspent_skill_points += granted_total
    character.skill_point_grants[grant_key] = {
        "type": "class_level",
        "class_id": class_id,
        "pools": pools.duplicate(true)
    }
    return {"ok": true, "reason": "level_granted", "level": character.level, "class_id": class_id, "pools": pools}

static func accounting_report(character: CharacterState) -> Dictionary:
    if character == null:
        return {}
    initialise(character)
    var pools: Dictionary = {}
    var keys := {}
    for pool in character.skill_budget_by_pool:
        keys[String(pool)] = true
    for pool in character.attributes:
        keys[String(pool)] = true
    for pool in keys:
        var budget := int(character.skill_budget_by_pool.get(pool, 0))
        var spent := int(character.skill_spent_by_pool.get(pool, 0))
        var remaining := int(character.attributes.get(pool, 0))
        pools[pool] = {
            "budget": budget,
            "spent": spent,
            "remaining": remaining,
            "balanced": budget == spent + remaining
        }
    return {
        "pools": pools,
        "available_points": available_points(character),
        "spent_by_skill": character.skill_spent_by_id.duplicate(true),
        "free_ranks": character.free_skill_ranks.duplicate(true)
    }
