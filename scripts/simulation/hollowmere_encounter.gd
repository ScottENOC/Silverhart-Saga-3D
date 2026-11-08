class_name HollowmereEncounter
extends RefCounted
## First authored Hollowmere combat encounter. Combat resolution stays in WorldSimulation.

const PLAYER_IDS: Array[String] = ["player", "companion_wren_talbot"]
const ENEMY_IDS: Array[String] = ["dray_coltayne", "tomlin_brask", "hask_greel"]

const ENEMY_PROFILES := {
    "dray_coltayne": {"health": 38, "damage": 3, "melee_hit": 5},
    "tomlin_brask": {"health": 30, "damage": 2, "melee_hit": 4},
    "hask_greel": {"health": 34, "damage": 3, "melee_hit": 2}
}


static func start(simulation: WorldSimulation) -> Dictionary:
    if simulation == null:
        return {"ok": false, "reason": "missing_simulation"}
    if simulation.is_in_combat:
        return {"ok": false, "reason": "combat_already_active"}

    for value in simulation.characters.values():
        var state: CharacterState = value
        state.combat_dormant = true
        if state.id in PLAYER_IDS:
            state.side = "player"
            state.combat_dormant = false

    for enemy_id in ENEMY_IDS:
        var enemy := simulation.get_character(enemy_id)
        if enemy == null:
            return {"ok": false, "reason": "missing_enemy", "character_id": enemy_id}
        var profile: Dictionary = ENEMY_PROFILES[enemy_id]
        enemy.side = "enemy"
        enemy.combat_dormant = false
        enemy.max_health = int(profile["health"])
        enemy.health = enemy.max_health
        enemy.base_damage = int(profile["damage"])
        enemy.to_hit_melee = float(profile["melee_hit"])
        enemy.tags.append("ironbond_soldier")
        enemy.time_points = enemy.max_time_points

    for party_id in PLAYER_IDS:
        if simulation.get_character(party_id) == null:
            return {"ok": false, "reason": "missing_party_member", "character_id": party_id}

    simulation.start_combat()
    return {"ok": true, "enemy_ids": ENEMY_IDS.duplicate(), "party_ids": PLAYER_IDS.duplicate()}


static func enemies_defeated(simulation: WorldSimulation) -> bool:
    if simulation == null:
        return false
    for enemy_id in ENEMY_IDS:
        var enemy := simulation.get_character(enemy_id)
        if enemy != null and enemy.can_act():
            return false
    return true


static func party_defeated(simulation: WorldSimulation) -> bool:
    if simulation == null:
        return true
    for party_id in PLAYER_IDS:
        var member := simulation.get_character(party_id)
        if member != null and member.can_act():
            return false
    return true
