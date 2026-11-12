class_name StatusEffectRules
extends RefCounted

## Status and on-hit effects ported from Hex-crpg's successful-attack path.
## Durations are measured in gained Time Points, not wall-clock seconds.

const POISON_DURATION_TP: float = 10.0
const POISON_DAMAGE_PER_TP: float = 2.0
const WITHERING_DURATION_PER_HIT_TP: float = 5.0
const HAMSTRING_COST_PER_STACK: float = 0.2

static func apply_on_hit(
    attacker: CharacterState,
    target: CharacterState,
    options: Dictionary,
    damage_dealt: int,
    rng: RandomNumberGenerator
) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    if attacker == null or target == null or damage_dealt <= 0:
        return events

    var is_ranged := bool(options.get("is_ranged", false))
    var has_weapon := bool(options.get("has_weapon", false))

    if not has_weapon and int(attacker.skills.get("unarmed_reaction_block", 0)) > 0:
        target.reaction_blocked = true
        events.append({"effect": "reaction_block", "target_id": target.id})

    if not is_ranged and int(attacker.skills.get("poison_bite", 0)) > 0 and rng.randf() < 0.5:
        target.poison_remaining_tp = POISON_DURATION_TP
        target.poison_damage_per_tp = POISON_DAMAGE_PER_TP
        target.poison_damage_remainder = 0.0
        target.poison_source_id = attacker.id
        events.append({"effect": "poison", "target_id": target.id, "duration_tp": POISON_DURATION_TP, "damage_per_tp": POISON_DAMAGE_PER_TP})

    if not is_ranged and int(attacker.skills.get("life_drain", 0)) > 0:
        var drained := mini(damage_dealt, 2)
        var health_before := attacker.health
        attacker.apply_healing(drained)
        var healed := attacker.health - health_before
        if healed > 0:
            events.append({"effect": "life_drain", "target_id": target.id, "healing": healed})

    var grave_chill_rank := maxi(0, int(attacker.skills.get("lich_grave_chill", 0)))
    if not is_ranged and grave_chill_rank > 0:
        var before := attacker.health
        attacker.apply_healing(2 * grave_chill_rank)
        var healed := attacker.health - before
        if healed > 0:
            events.append({"effect": "lich_grave_chill", "target_id": target.id, "healing": healed})

    var withering_rank := maxi(0, int(attacker.skills.get("lich_withering_touch", 0)))
    if withering_rank > 0:
        target.wither_remaining_tp += WITHERING_DURATION_PER_HIT_TP
        target.wither_damage_per_tp = float(withering_rank)
        target.wither_source_id = attacker.id
        events.append({"effect": "withering_touch", "target_id": target.id, "duration_added_tp": WITHERING_DURATION_PER_HIT_TP, "damage_per_tp": withering_rank})

    if not is_ranged:
        var sunder_rank := maxi(0, int(attacker.skills.get("sunder_armor", 0)))
        if sunder_rank > target.sunder_stacks:
            target.sunder_stacks += 1
            target.base_reduction = maxi(0, target.base_reduction - 1)
            events.append({"effect": "sunder_armor", "target_id": target.id, "stacks": target.sunder_stacks})

        var hamstring_rank := maxi(0, int(attacker.skills.get("hamstring", 0)))
        if hamstring_rank > target.hobbled_stacks:
            target.hobbled_stacks += 1
            events.append({"effect": "hamstring", "target_id": target.id, "stacks": target.hobbled_stacks})

    return events


## Advance damage-over-time by the TP actually gained this world tick.
## Poison follows the original game's lethal-at-zero rule; withering uses the
## normal character damage/downed lifecycle.
static func advance(state: CharacterState, gained_tp: float) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    if state == null or not state.alive or gained_tp <= 0.0:
        return events

    if state.poison_remaining_tp > 0.0:
        var consumed := minf(gained_tp, state.poison_remaining_tp)
        var accumulated := state.poison_damage_per_tp * consumed + state.poison_damage_remainder
        var damage := maxi(0, floori(accumulated + 0.000001))
        state.poison_damage_remainder = maxf(0.0, accumulated - float(damage))
        state.poison_remaining_tp = maxf(0.0, state.poison_remaining_tp - consumed)
        if damage > 0:
            var outcome := state.apply_poison_damage(damage)
            events.append({"effect": "poison_tick", "damage": damage, "source_id": state.poison_source_id, "outcome": outcome})
        if state.poison_remaining_tp <= 0.0:
            state.poison_damage_remainder = 0.0
            state.poison_source_id = ""
            events.append({"effect": "poison_expired"})

    if state.alive and state.wither_remaining_tp > 0.0:
        var consumed := minf(gained_tp, state.wither_remaining_tp)
        var accumulated := state.wither_damage_per_tp * consumed + state.wither_damage_remainder
        var damage := maxi(0, floori(accumulated + 0.000001))
        state.wither_damage_remainder = maxf(0.0, accumulated - float(damage))
        state.wither_remaining_tp = maxf(0.0, state.wither_remaining_tp - consumed)
        if damage > 0:
            var outcome := state.apply_damage(damage)
            events.append({"effect": "withering_tick", "damage": damage, "source_id": state.wither_source_id, "outcome": outcome})
        if state.wither_remaining_tp <= 0.0:
            state.wither_damage_remainder = 0.0
            state.wither_source_id = ""
            events.append({"effect": "withering_expired"})

    return events


static func movement_multiplier(state: CharacterState) -> float:
    if state == null or state.hobbled_stacks <= 0:
        return 1.0
    return 1.0 + float(state.hobbled_stacks) * HAMSTRING_COST_PER_STACK
