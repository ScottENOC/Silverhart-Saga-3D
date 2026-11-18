class_name SpellCastingRules
extends RefCounted

## Shared simulation resolver for player and NPC spell casts.
## This first slice intentionally supports direct Firebolt damage and Heal only.
## Cost, target and range validation happens before either resource is spent.

static func resolve_cast(
    caster: CharacterState,
    target: CharacterState,
    prepared_data: Dictionary,
    random_seed: int = 0
) -> Dictionary:
    if caster == null or target == null:
        return {"ok": false, "reason": "missing_combatant"}
    if not caster.can_act() or not target.can_be_targeted():
        return {"ok": false, "reason": "combatant_unavailable"}

    var prepared := PreparedSpell.from_dict(prepared_data)
    if prepared == null:
        return {"ok": false, "reason": "invalid_prepared_spell"}
    if not caster.unlocked_base_spells.has(prepared.base_spell_id):
        return {"ok": false, "reason": "base_spell_not_unlocked"}

    var is_prepared := false
    for saved_value in caster.prepared_spells:
        if not saved_value is Dictionary:
            continue
        var saved := PreparedSpell.from_dict(saved_value)
        if saved != null and saved.base_spell_id == prepared.base_spell_id \
        and saved.modifiers == prepared.modifiers:
            is_prepared = true
            break
    if not is_prepared:
        return {"ok": false, "reason": "spell_not_prepared"}

    var variant := SpellRules.compute_variant(prepared.base_spell_id, prepared.modifiers, caster.skills)
    if not bool(variant.get("ok", false)):
        return {"ok": false, "reason": String(variant.get("reason", "invalid_spell_variant"))}
    var spell := SpellRules.get_base_spell(prepared.base_spell_id)
    var spell_type := String(variant.get("type", ""))
    if prepared.base_spell_id == "firebolt" and spell_type != "damage":
        return {"ok": false, "reason": "unsupported_spell_variant"}
    if prepared.base_spell_id == "heal" and spell_type != "heal":
        return {"ok": false, "reason": "unsupported_spell_variant"}
    if prepared.base_spell_id not in ["firebolt", "heal"]:
        return {"ok": false, "reason": "unsupported_spell_effect"}

    if bool(spell.get("self_target", false)) and target != caster:
        return {"ok": false, "reason": "spell_requires_self_target"}
    if prepared.base_spell_id == "firebolt":
        if caster.side == "neutral" or target.side == "neutral" or caster.side == target.side:
            return {"ok": false, "reason": "invalid_hostile_spell_target"}
    elif caster.side == "neutral" or target.side != caster.side:
        return {"ok": false, "reason": "invalid_friendly_spell_target"}

    var distance := HexGrid.distance(caster.axial, target.axial)
    if distance > int(variant.get("range", 1)):
        return {"ok": false, "reason": "target_out_of_range"}

    var mana_cost := int(variant.get("mana_cost", 0))
    var time_point_cost := float(variant.get("time_point_cost", 0))
    if mana_cost < 0 or time_point_cost < 0.0:
        return {"ok": false, "reason": "invalid_spell_cost"}
    if caster.current_mana < mana_cost:
        return {"ok": false, "reason": "insufficient_mana"}
    if not caster.can_spend_time_points(time_point_cost):
        return {"ok": false, "reason": "insufficient_time_points"}

    # The two affordability checks above make these payments atomic in the
    # simulation's single-threaded action path: no resource is spent on rejection.
    if not caster.spend_time_points(time_point_cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    caster.current_mana -= mana_cost

    var magnitude := maxi(1, roundi(float(variant.get("magnitude", 0.0))))
    var effect_result := ""
    var hit := true
    var hit_chance := 100.0
    if prepared.base_spell_id == "firebolt":
        var rng := RandomNumberGenerator.new()
        if random_seed == 0:
            rng.randomize()
        else:
            rng.seed = random_seed
        hit_chance = CombatRules.hit_chance(caster, target, {"is_ranged": true})
        hit = float(rng.randi_range(0, 99)) < hit_chance
        if hit:
            effect_result = target.apply_damage(magnitude)
    else:
        effect_result = target.apply_healing(magnitude)

    return {
        "ok": true,
        "spell_id": prepared.base_spell_id,
        "spell_name": String(spell.get("name", prepared.base_spell_id)),
        "effect": spell_type,
        "magnitude": magnitude,
        "mana_cost": mana_cost,
        "time_point_cost": time_point_cost,
        "hit": hit,
        "hit_chance": hit_chance,
        "effect_result": effect_result,
        "target_health": target.health,
        "target_unconscious": target.unconscious,
        "target_alive": target.alive
    }
