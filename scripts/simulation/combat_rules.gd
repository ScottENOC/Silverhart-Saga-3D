class_name CombatRules
extends RefCounted

## Deterministic core of Hex-crpg's resolveAttack rule. Visual effects,
## messages, reactions and campaign callbacks remain outside this resolver.

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
    if bool(options.get("weapon_skill_hit", false)):
        chance += 5.0
    if bool(options.get("unarmed_skill_hit", false)) and not bool(options.get("has_weapon", false)):
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
    if not target.climbing:
        reduction += target.shield_reduction
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
    if not attacker.alive or not target.alive:
        return {"ok": false, "reason": "combatant_unavailable"}
    if attacker == target:
        return {"ok": false, "reason": "cannot_attack_self"}

    var cost := float(options.get("time_point_cost", 0.0))
    if cost < 0.0 or not attacker.can_spend_time_points(cost):
        return {"ok": false, "reason": "insufficient_time_points"}

    var chance := hit_chance(attacker, target, options)
    var roll := rng.randi_range(0, 99)
    if not attacker.spend_time_points(cost):
        return {"ok": false, "reason": "insufficient_time_points"}

    if roll >= chance:
        return {
            "ok": true, "hit": false, "roll": roll,
            "hit_chance": chance, "raw_damage": 0,
            "reduction": 0, "damage": 0, "target_defeated": false
        }

    var raw := raw_damage(attacker, options)
    var reduction := damage_reduction(target)
    var final_damage := maxi(1, raw - reduction)
    if bool(options.get("hard_difficulty", false)):
        if attacker.side == "player":
            final_damage = maxi(1, roundi(final_damage * 0.9))
        if target.side == "player":
            final_damage = roundi(final_damage * 1.1)

    target.health -= final_damage
    if target.health <= 0:
        target.health = 0
        target.alive = false
    return {
        "ok": true, "hit": true, "roll": roll,
        "hit_chance": chance, "raw_damage": raw,
        "reduction": reduction, "damage": final_damage,
        "target_defeated": not target.alive
    }
