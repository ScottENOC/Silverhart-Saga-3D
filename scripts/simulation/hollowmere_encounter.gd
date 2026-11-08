class_name HollowmereEncounter
extends RefCounted
## First authored Hollowmere combat encounter. Combat resolution stays in WorldSimulation.

const PLAYER_CONTROLLED_IDS: Array[String] = ["player", "companion_wren_talbot"]
const ALLY_IDS: Array[String] = ["garrick_holt", "mira_ashbrook", "oskar_vinn"]
const COMBAT_ALLY_IDS: Array[String] = ["player", "companion_wren_talbot", "garrick_holt", "mira_ashbrook", "oskar_vinn"]
const ENEMY_IDS: Array[String] = ["dray_coltayne", "tomlin_brask", "hask_greel"]

const ALLY_PROFILES := {
    "garrick_holt": {"health": 100, "damage": 3, "melee_hit": 5, "skills": {"club_hit": 1, "club_dmg": 1}},
    "mira_ashbrook": {"health": 100, "damage": 1, "melee_hit": 5, "skills": {"dagger_hit": 1, "stealth_agility": 1}},
    "oskar_vinn": {"health": 100, "damage": 3, "melee_hit": 5, "skills": {"sword_hit": 1, "sword_dmg": 1}}
}

const ENEMY_PROFILES := {
    "dray_coltayne": {"health": 130, "damage": 3, "melee_hit": 5, "skills": {"sword_hit": 1, "sword_dmg": 1, "sword_parry": 1}},
    "tomlin_brask": {"health": 115, "damage": 3, "melee_hit": 5, "skills": {"spear_hit": 1, "spear_dmg": 1}},
    "hask_greel": {"health": 115, "damage": 3, "melee_hit": 5, "skills": {"axe_hit": 1, "axe_dmg": 1}}
}


static func start(simulation: WorldSimulation) -> Dictionary:
    if simulation == null:
        return {"ok": false, "reason": "missing_simulation"}
    if simulation.is_in_combat:
        return {"ok": false, "reason": "combat_already_active"}
    for character_id in COMBAT_ALLY_IDS + ENEMY_IDS:
        if simulation.get_character(character_id) == null:
            return {"ok": false, "reason": "missing_combatant", "character_id": character_id}

    for value in simulation.characters.values():
        var state: CharacterState = value
        state.combat_dormant = true
        if state.id in COMBAT_ALLY_IDS:
            state.side = "player"
            state.combat_dormant = false

    for ally_id in ALLY_IDS:
        var ally := simulation.get_character(ally_id)
        var ally_profile: Dictionary = ALLY_PROFILES[ally_id]
        ally.max_health = int(ally_profile["health"])
        ally.health = ally.max_health
        ally.base_damage = int(ally_profile["damage"])
        ally.to_hit_melee = float(ally_profile["melee_hit"])
        var ally_skills: Dictionary = ally_profile.get("skills", {})
        ally.skills = ally_skills.duplicate(true)
        ally.tags.append("hollowmere_defender")
        ally.time_points = ally.max_time_points

    for enemy_id in ENEMY_IDS:
        var enemy := simulation.get_character(enemy_id)
        var enemy_profile: Dictionary = ENEMY_PROFILES[enemy_id]
        enemy.side = "enemy"
        enemy.combat_dormant = false
        enemy.max_health = int(enemy_profile["health"])
        enemy.health = enemy.max_health
        enemy.base_damage = int(enemy_profile["damage"])
        enemy.to_hit_melee = float(enemy_profile["melee_hit"])
        var enemy_skills: Dictionary = enemy_profile.get("skills", {})
        enemy.skills = enemy_skills.duplicate(true)
        enemy.tags.append("ironbond_soldier")
        enemy.time_points = enemy.max_time_points

    simulation.start_combat()
    return {"ok": true, "enemy_ids": ENEMY_IDS.duplicate(), "party_ids": COMBAT_ALLY_IDS.duplicate()}


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
    for party_id in COMBAT_ALLY_IDS:
        var member := simulation.get_character(party_id)
        if member != null and member.can_act():
            return false
    return true

