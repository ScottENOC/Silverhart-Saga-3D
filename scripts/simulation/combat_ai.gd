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

    var target := nearest_opponent_target(simulation, combatant, enemy_ids, party_ids)
    if target == null:
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
