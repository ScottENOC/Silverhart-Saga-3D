class_name FarmsteadDireWolfEncounter
extends RefCounted
## Combat setup for the dire wolf raiding Old Mac's grain stores.

const DIRE_WOLF_ID := "old_mac_grain_dire_wolf"

static func create_dire_wolf(simulation: WorldSimulation, hex: Vector2i) -> Dictionary:
    if simulation == null:
        return {"ok": false, "reason": "missing_simulation"}
    if simulation.get_character(DIRE_WOLF_ID) != null:
        return {"ok": false, "reason": "dire_wolf_already_exists"}
    var wolf := CharacterState.new(DIRE_WOLF_ID, "Grain-raiding dire wolf", hex)
    wolf.race = "wolf"
    wolf.character_class = "beast"
    wolf.health = 150
    wolf.max_health = 150
    wolf.base_damage = 7
    wolf.to_hit_melee = 7.0
    wolf.skills = {"bite_hit": 2, "bite_dmg": 2, "health": 3}
    wolf.tags.append("animal")
    wolf.tags.append("wolf")
    wolf.tags.append("dire_wolf")
    wolf.side = "enemy"
    wolf.combat_dormant = true
    wolf.time_points = 100.0
    simulation.register_character(wolf)
    return {"ok": true, "character_id": DIRE_WOLF_ID}


static func start(simulation: WorldSimulation, party_ids: Array[String]) -> Dictionary:
    if simulation == null:
        return {"ok": false, "reason": "missing_simulation"}
    if simulation.is_in_combat:
        return {"ok": false, "reason": "combat_already_active"}
    var wolf := simulation.get_character(DIRE_WOLF_ID)
    if wolf == null:
        return {"ok": false, "reason": "missing_dire_wolf"}
    if party_ids.is_empty():
        return {"ok": false, "reason": "empty_party"}
    var valid_party: Array[String] = []
    for character_id in party_ids:
        var member := simulation.get_character(character_id)
        if member != null and member.can_act() and not valid_party.has(character_id):
            valid_party.append(character_id)
    if valid_party.is_empty():
        return {"ok": false, "reason": "no_able_party_members"}
    for character_value in simulation.characters.values():
        var state: CharacterState = character_value
        state.combat_dormant = true
    for character_id in valid_party:
        var member := simulation.get_character(character_id)
        member.side = "player"
        member.combat_dormant = false
        member.time_points = 100.0
    wolf.health = wolf.max_health
    wolf.alive = true
    wolf.unconscious = false
    wolf.side = "enemy"
    wolf.combat_dormant = false
    wolf.time_points = 100.0
    simulation.start_combat()
    return {"ok": true, "party_ids": valid_party, "enemy_ids": [DIRE_WOLF_ID]}


static func finish(simulation: WorldSimulation, party_ids: Array[String]) -> void:
    if simulation == null:
        return
    for character_id in party_ids:
        var member := simulation.get_character(character_id)
        if member != null:
            member.side = "player"
            member.combat_dormant = false
    var wolf := simulation.get_character(DIRE_WOLF_ID)
    if wolf != null:
        wolf.combat_dormant = true


static func party_defeated(simulation: WorldSimulation, party_ids: Array[String]) -> bool:
    if simulation == null:
        return true
    for character_id in party_ids:
        var member := simulation.get_character(character_id)
        if member != null and member.can_act():
            return false
    return true


static func dire_wolf_defeated(simulation: WorldSimulation) -> bool:
    var wolf := simulation.get_character(DIRE_WOLF_ID) if simulation != null else null
    return wolf == null or not wolf.can_act()
