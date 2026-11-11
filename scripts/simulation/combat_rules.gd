class_name CombatRules
extends RefCounted

## Deterministic core of Hex-crpg's resolveAttack rule. Visual effects,
## messages, reactions and campaign callbacks remain outside this resolver.

static func weapon_skill_family(weapon_id: String, definition: Dictionary = {}) -> String:
    var subtype := String(definition.get("subType", definition.get("sub_type", ""))).to_lower()
    if subtype != "melee" and subtype != "ranged":
        return ""
    if weapon_id in ["sword", "sword_arrow_deflection", "starforged_blade"]:
        return "sword"
    if weapon_id == "axe":
        return "axe"
    if weapon_id in ["bow", "nightowl_bow", "hunting_bow"]:
        return "bow"
    if weapon_id in ["spear", "stormcaller_spear"]:
        return "spear"
    if weapon_id in ["dagger", "featherweight_dagger"]:
        return "dagger"
    if weapon_id in ["club", "ashenwood_club"]:
        return "club"
    return ""


static func options_with_skill_ranks(attacker: CharacterState, target: CharacterState, options: Dictionary) -> Dictionary:
    var resolved := options.duplicate(true)
    if attacker == null:
        return resolved
    var slot := "offhand" if bool(resolved.get("is_offhand", false)) else "weapon"
    var equipped: Dictionary = attacker.equipped_item_data.get(slot, {})
    var weapon_id := String(resolved.get("weapon_id", ""))
    if weapon_id.is_empty():
        weapon_id = String(attacker.equipment.get(slot, equipped.get("id", "")))
    if weapon_id.is_empty():
        weapon_id = String(equipped.get("id", ""))
    var definition := ItemCatalog.get_definition(weapon_id)
    if definition.is_empty():
        definition = equipped
    var subtype := String(definition.get("subType", definition.get("sub_type", ""))).to_lower()
    var has_weapon := not weapon_id.is_empty()
    var family := weapon_skill_family(weapon_id, definition)
    resolved["weapon_id"] = family if not family.is_empty() else weapon_id
    resolved["has_weapon"] = has_weapon
    if not resolved.has("is_ranged"):
        resolved["is_ranged"] = subtype == "ranged"
    if not family.is_empty():
        resolved["weapon_skill_hit_rank"] = maxi(0, int(attacker.skills.get("%s_hit" % family, 0)))
        resolved["weapon_skill_damage"] = maxi(0, int(attacker.skills.get("%s_dmg" % family, 0)))
    elif not has_weapon:
        resolved["unarmed_skill_hit_rank"] = maxi(0, int(attacker.skills.get("unarmed_hit", 0)))
        resolved["unarmed_skill_damage"] = maxi(0, int(attacker.skills.get("unarmed_dmg", 0)))
    if target != null:
        resolved["target_caught_off_guard"] = bool(resolved.get("target_caught_off_guard", false)) or target.caught_off_guard
        resolved["elf_foliage_expertise"] = bool(resolved.get("elf_foliage_expertise", false)) or int(target.skills.get("elf_foliage_expertise", 0)) > 0
        resolved["druid_foliage_expertise"] = bool(resolved.get("druid_foliage_expertise", false)) or int(target.skills.get("druid_foliage_expertise", 0)) > 0
    return resolved


static func hit_chance(attacker: CharacterState, target: CharacterState, options: Dictionary = {}) -> float:
    if attacker == null or target == null:
        return 0.0
    var ranged := bool(options.get("is_ranged", false))
    var base_hit := attacker.to_hit_ranged if ranged else attacker.to_hit_melee
    var chance := 50.0 + base_hit
    chance += float(options.get("attacker_terrain_hit_bonus", 0.0))
    chance -= target.passive_dodge
    chance -= float(options.get("target_terrain_dodge_bonus", 0.0))
    if target.climbing:
        chance += 5.0
    if bool(options.get("covered_from_ranged", false)):
        chance -= 15.0
    if bool(options.get("dual_wielding", false)):
        chance -= 5.0
    if bool(options.get("is_offhand", false)):
        chance -= 5.0
    var weapon_hit_rank := int(options.get("weapon_skill_hit_rank", 0))
    var unarmed_hit_rank := int(options.get("unarmed_skill_hit_rank", 0))
    chance += float(weapon_hit_rank) * 5.0
    if weapon_hit_rank == 0 and bool(options.get("weapon_skill_hit", false)):
        chance += 5.0
    if not bool(options.get("has_weapon", false)):
        chance += float(unarmed_hit_rank) * 5.0
        if unarmed_hit_rank == 0 and bool(options.get("unarmed_skill_hit", false)):
            chance += 5.0
    var animal_bonus := float(options.get("to_hit_vs_animal", 0.0))
    if animal_bonus != 0.0 and target.tags.has("animal"):
        chance += animal_bonus
    if String(options.get("target_terrain", "")).to_lower() == "foliage":
        if ranged:
            chance -= 10.0
        if bool(options.get("elf_foliage_expertise", false)) or bool(options.get("druid_foliage_expertise", false)):
            chance -= 10.0
    return clampf(chance, 0.0, 100.0)

static func raw_damage(attacker: CharacterState, options: Dictionary = {}) -> int:
    var weapon_damage := int(options.get("weapon_damage", 0))
    var weapon_skill_damage := int(options.get("weapon_skill_damage", 0))
    var damage := attacker.base_damage + weapon_damage + weapon_skill_damage * 2
    damage += int(options.get("unarmed_skill_damage", 0)) * 2
    damage += int(options.get("wild_fury_bonus", 0))
    damage += int(attacker.skills.get("meleeDamage", 0))
    damage += int(options.get("bonus_damage", 0))
    var equipped_weapon: Dictionary = attacker.equipped_item_data.get("weapon", {})
    damage += int(equipped_weapon.get("damage", 0))
    if bool(options.get("is_offhand", false)):
        damage -= 2
    if String(options.get("weapon_id", "")) == "axe" and int(attacker.skills.get("dwarf_axe_mastery", 0)) > 0:
        damage += 2
    damage += int(attacker.skills.get("orc_brute_strength", 0)) * 2
    if int(attacker.skills.get("orc_ferocity", 0)) > 0 and attacker.health <= attacker.max_health / 2:
        damage += 4
    if bool(options.get("target_caught_off_guard", false)):
        damage += 3 * int(attacker.skills.get("goblin_opportunist", 0))
    damage += int(options.get("flank_bonus", 0))
    damage += int(options.get("sneak_attack_bonus", 0))
    return maxi(1, damage)

static func damage_reduction(target: CharacterState) -> int:
    if target.caught_off_guard:
        return 0
    var reduction := target.base_reduction + target.armour_reduction
    var equipped_armour: Dictionary = target.equipped_item_data.get("armour", {})
    reduction += int(equipped_armour.get("reduction", 0))
    if not target.climbing:
        reduction += target.shield_reduction
        var equipped_shield: Dictionary = target.equipped_item_data.get("offhand", {})
        var shield_id := String(target.equipment.get("offhand", equipped_shield.get("id", "")))
        if equipped_shield.is_empty() and not shield_id.is_empty():
            equipped_shield = ItemCatalog.get_definition(shield_id)
        if String(equipped_shield.get("type", "")) == "shield":
            reduction += int(equipped_shield.get("reduction", 0))
            reduction += int(target.skills.get("shield_proficiency", 0))
    reduction += target.helmet_reduction + target.temp_reduction
    reduction += 2 * int(target.skills.get("spectral_form", 0) > 0)
    return maxi(0, reduction)

static func resolve_attack(
    attacker: CharacterState,
    target: CharacterState,
    options: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    if attacker == null or target == null:
        return {"ok": false, "reason": "missing_combatant"}
    if not attacker.can_act() or not target.can_be_targeted():
        return {"ok": false, "reason": "combatant_unavailable"}
    if attacker == target:
        return {"ok": false, "reason": "cannot_attack_self"}

    var cost := float(options.get("time_point_cost", 0.0))
    if cost < 0.0 or not attacker.can_spend_time_points(cost):
        return {"ok": false, "reason": "insufficient_time_points"}

    var resolved_options := options_with_skill_ranks(attacker, target, options)
    var chance := hit_chance(attacker, target, resolved_options)
    var roll := rng.randi_range(0, 99)
    if not attacker.spend_time_points(cost):
        return {"ok": false, "reason": "insufficient_time_points"}

    if roll >= chance:
        return {
            "ok": true, "hit": false, "roll": roll,
            "hit_chance": chance, "raw_damage": 0,
            "reduction": 0, "damage": 0, "target_defeated": false
        }

    var raw := raw_damage(attacker, resolved_options)
    var reduction := damage_reduction(target)
    var final_damage := maxi(1, raw - reduction)
    if bool(options.get("hard_difficulty", false)) or attacker.difficulty_mode == "hard" or target.difficulty_mode == "hard":
        if attacker.side == "player":
            final_damage = maxi(1, roundi(final_damage * 0.9))
        if target.side == "player":
            final_damage = roundi(final_damage * 1.1)

    var lifecycle := target.apply_damage(final_damage)
    return {
        "ok": true, "hit": true, "roll": roll,
        "hit_chance": chance, "raw_damage": raw,
        "reduction": reduction, "damage": final_damage,
        "target_defeated": not target.alive,
        "target_unconscious": target.unconscious,
        "target_lifecycle": lifecycle,
        "target_health": target.health
    }
