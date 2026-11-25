class_name CombatAI
extends RefCounted

## Tactical decision-making for non-player combatants.
## The simulation remains responsible for validating and resolving every action.

static func take_turn(
    simulation: WorldSimulation,
    combatant: CharacterState,
    enemy_ids: Array[String],
    party_ids: Array[String]
) -> bool:
    if simulation == null or combatant == null:
        return false
    var calm_effect := combatant.get_spell_effect("calmed")
    if not calm_effect.is_empty():
        var caster := simulation.get_character(String(calm_effect.get("source_id", "")))
        if combatant.time_points >= 10.0 and caster != null and caster.alive:
            var mode := String(calm_effect.get("mode", "stay"))
            var destination := INVALID_HEX
            if mode == "come":
                destination = best_approach_step(simulation, combatant, caster)
            elif mode == "chase":
                var candidates := HexGrid.neighbors(combatant.axial)
                var best_distance := HexGrid.distance(combatant.axial, caster.axial)
                for candidate in candidates:
                    if not simulation.map_data.is_walkable(candidate) or simulation.is_hex_occupied(candidate):
                        continue
                    var candidate_distance := HexGrid.distance(candidate, caster.axial)
                    if candidate_distance > best_distance:
                        best_distance = candidate_distance
                        destination = candidate
            if destination != INVALID_HEX:
                simulation.relocate_character(combatant.id, destination)
            combatant.spend_time_points(10.0)
        else:
            combatant.time_points = 0.0
        simulation.try_end_current_turn(true)
        return false

    # Healing is considered before choosing an offensive target. The AI
    # submits the same PreparedSpell action as the player; the simulation
    # remains authoritative for all validation and payment.
    var healing_result := _try_heal_ally(simulation, combatant, enemy_ids, party_ids)
    if bool(healing_result.get("ok", false)):
        if bool(healing_result.get("pending", false)) or simulation.has_pending_reaction():
            return true
        simulation.try_end_current_turn(true)
        return false

    var target := nearest_opponent_target(simulation, combatant, enemy_ids, party_ids)
    if target == null:
        simulation.try_end_current_turn(true)
        return false

    var spell_result := _try_firebolt(simulation, combatant, target)
    if bool(spell_result.get("ok", false)):
        if bool(spell_result.get("pending", false)) or simulation.has_pending_reaction():
            return true
        simulation.try_end_current_turn(true)
        return false

    if HexGrid.distance(combatant.axial, target.axial) <= attack_range_for(combatant):
        var result := simulation.try_attack_character(
            combatant.id,
            target.id,
            attack_options_for(combatant),
            int(combatant.id.hash())
        )
        if bool(result.get("pending", false)) or simulation.has_pending_reaction():
            return true
        simulation.try_end_current_turn(true)
        return false

    var next_step := best_approach_step(simulation, combatant, target)
    if next_step == INVALID_HEX:
        simulation.try_end_current_turn(true)
        return false

    var moved := simulation.try_move_character_step(combatant.id, next_step)
    if moved and simulation.has_pending_reaction():
        return true
    simulation.try_end_current_turn(true)
    return false


static func _prepared_spell_for(combatant: CharacterState, spell_id: String) -> PreparedSpell:
    if combatant == null:
        return null
    for saved_spell in combatant.prepared_spells:
        var prepared := PreparedSpell.from_dict(saved_spell)
        if prepared == null or prepared.base_spell_id != spell_id:
            continue
        var prepared_variant := SpellRules.compute_variant(spell_id, prepared.modifiers, combatant.skills)
        if SpellRules.supports_initial_cast(spell_id, prepared_variant):
            return prepared
    if combatant.unlocked_base_spells.has(spell_id) or int(combatant.skills.get("learn_%s" % spell_id, 0)) > 0:
        # NPCs receive a deterministic base preparation when their template
        # grants the spell but has not authored a prepared variant yet.
        var default_preparation := PreparedSpell.create(spell_id)
        combatant.prepared_spells.append(default_preparation.to_dict())
        return default_preparation
    return null


static func _can_afford_spell(combatant: CharacterState, prepared: PreparedSpell) -> bool:
    if combatant == null or prepared == null:
        return false
    var variant := SpellRules.compute_variant(prepared.base_spell_id, prepared.modifiers, combatant.skills)
    if not SpellRules.supports_initial_cast(prepared.base_spell_id, variant):
        return false
    var total_cost := int(variant.get("mana_cost", 0)) + SpellRules.armour_mana_penalty(combatant, String(variant.get("school", "")))
    return bool(SpellRules.cast_affordability(combatant, total_cost).get("ok", false)) \
        and combatant.can_spend_time_points(float(variant.get("time_point_cost", 0.0)))


static func _try_heal_ally(
    simulation: WorldSimulation,
    combatant: CharacterState,
    enemy_ids: Array[String],
    party_ids: Array[String]
) -> Dictionary:
    var spell := _prepared_spell_for(combatant, "heal")
    if spell == null or not _can_afford_spell(combatant, spell):
        return {}
    var friendly_ids: Array[String] = enemy_ids if combatant.side == "enemy" else party_ids
    var best_target: CharacterState
    var best_ratio := 0.56
    var candidates: Array[CharacterState] = []
    candidates.append(combatant)
    for ally_id in friendly_ids:
        var ally := simulation.get_character(ally_id)
        if ally != null and ally != combatant:
            candidates.append(ally)
    for ally in candidates:
        if ally == null or not ally.can_be_targeted() or ally.side != combatant.side:
            continue
        if ally.health >= ally.max_health or ally.max_health <= 0:
            continue
        var ratio := float(ally.health) / float(ally.max_health)
        if ratio < best_ratio:
            best_ratio = ratio
            best_target = ally
    if best_target == null or HexGrid.distance(combatant.axial, best_target.axial) > 1:
        return {}
    return simulation.submit_action(
        SimulationActionRequest.cast_spell(combatant.id, best_target.id, spell),
        int(combatant.id.hash())
    )


static func _try_firebolt(simulation: WorldSimulation, combatant: CharacterState, target: CharacterState) -> Dictionary:
    var spell := _prepared_spell_for(combatant, "firebolt")
    if spell == null or not _can_afford_spell(combatant, spell):
        return {}
    var variant := SpellRules.compute_variant(spell.base_spell_id, spell.modifiers, combatant.skills)
    var spell_range := maxi(1, int(variant.get("range", 1)))
    var distance := HexGrid.distance(combatant.axial, target.axial)
    # Keep melee as the preferred close-range action; Firebolt is the AI's
    # ranged option and prevents a caster from endlessly pathing into melee.
    if distance <= attack_range_for(combatant) or distance > spell_range:
        return {}
    return simulation.submit_action(
        SimulationActionRequest.cast_spell(combatant.id, target.id, spell),
        int(combatant.id.hash())
    )


static func nearest_opponent_target(
    simulation: WorldSimulation,
    combatant: CharacterState,
    enemy_ids: Array[String],
    party_ids: Array[String]
) -> CharacterState:
    if simulation == null or combatant == null:
        return null

    var best: CharacterState
    var best_distance := 999
    var opponent_ids: Array[String] = party_ids if combatant.side == "enemy" else enemy_ids
    for opponent_id in opponent_ids:
        var opponent := simulation.get_character(opponent_id)
        if opponent == null or not opponent.can_act():
            continue
        var distance := HexGrid.distance(combatant.axial, opponent.axial)
        if distance < best_distance:
            best_distance = distance
            best = opponent
    return best


static func best_approach_step(
    simulation: WorldSimulation,
    enemy: CharacterState,
    target: CharacterState
) -> Vector2i:
    if simulation == null or enemy == null or target == null:
        return INVALID_HEX

    var best_path: Array[Vector2i] = []
    for destination in HexGrid.neighbors(target.axial):
        if not simulation.map_data.is_walkable(destination) or simulation.is_hex_occupied(destination):
            continue
        var path := simulation.find_path(enemy.id, destination)
        if path.size() < 2:
            continue
        if best_path.is_empty() or path.size() < best_path.size():
            best_path = path
    return best_path[1] if best_path.size() > 1 else INVALID_HEX


static func attack_range_for(attacker: CharacterState) -> int:
    if attacker == null:
        return 1
    var weapon: Dictionary = attacker.equipped_item_data.get("weapon", {})
    return maxi(1, 1 + int(weapon.get("range", 0)))


static func attack_options_for(attacker: CharacterState) -> Dictionary:
    if attacker == null:
        return {}

    var weapon_id := String(attacker.equipment.get("weapon", ""))
    var weapon: Dictionary = attacker.equipped_item_data.get("weapon", {})
    var options := {
        "time_point_cost": 10.0,
        "weapon_id": weapon_id,
        "is_ranged": String(weapon.get("subType", "")) == "ranged"
    }
    if attacker.race == "bear" or attacker.tags.has("farm_quest_wolf") or attacker.tags.has("dire_wolf"):
        var natural_hit_rank := int(attacker.skills.get("bite_hit", attacker.skills.get("claw_hit", 0)))
        var natural_damage_rank := int(attacker.skills.get("bite_dmg", attacker.skills.get("claw_dmg", 0)))
        options["unarmed_skill_hit"] = natural_hit_rank > 0
        options["unarmed_skill_damage"] = natural_damage_rank
    return options


const INVALID_HEX := Vector2i(2147483647, 2147483647)
