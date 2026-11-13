class_name FarmsteadBearEncounter
extends RefCounted
## Reusable combat setup for the Old Mac's Farmstead bear encounter.

const BEAR_ID := "old_mac_grain_bear"

static func create_bear(simulation: WorldSimulation, hex: Vector2i) -> Dictionary:
    if simulation == null:
        return {"ok": false, "reason": "missing_simulation"}
    if simulation.get_character(BEAR_ID) != null:
        return {"ok": false, "reason": "bear_already_exists"}
    var bear := CharacterState.new(BEAR_ID, "Grain-raiding bear", hex)
    bear.race = "bear"
    bear.character_class = "beast"
    bear.health = 180
    bear.max_health = 180
    bear.base_damage = 8
    bear.to_hit_melee = 7.0
    bear.skills = {"claw_hit": 2, "claw_dmg": 2, "health": 4}
    bear.tags.append("animal")
    bear.tags.append("bear")
    bear.side = "enemy"
    bear.combat_dormant = true
    bear.time_points = 100.0
    simulation.register_character(bear)
    return {"ok": true, "character_id": BEAR_ID}


static func start(simulation: WorldSimulation, party_ids: Array[String]) -> Dictionary:
    if simulation == null:
        return {"ok": false, "reason": "missing_simulation"}
    if simulation.is_in_combat:
        return {"ok": false, "reason": "combat_already_active"}
    var bear := simulation.get_character(BEAR_ID)
    if bear == null:
        return {"ok": false, "reason": "missing_bear"}
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
    bear.health = bear.max_health
    bear.alive = true
    bear.unconscious = false
    bear.side = "enemy"
    bear.combat_dormant = false
    bear.time_points = 100.0
    simulation.start_combat()
    return {"ok": true, "party_ids": valid_party, "enemy_ids": [BEAR_ID]}


static func finish(simulation: WorldSimulation, party_ids: Array[String]) -> void:
    if simulation == null:
        return
    for character_id in party_ids:
        var member := simulation.get_character(character_id)
        if member != null:
            member.side = "player"
            member.combat_dormant = false
    var bear := simulation.get_character(BEAR_ID)
    if bear != null:
        bear.combat_dormant = true


static func party_defeated(simulation: WorldSimulation, party_ids: Array[String]) -> bool:
    if simulation == null:
        return true
    for character_id in party_ids:
        var member := simulation.get_character(character_id)
        if member != null and member.can_act():
            return false
    return true


static func bear_defeated(simulation: WorldSimulation) -> bool:
    var bear := simulation.get_character(BEAR_ID) if simulation != null else null
    return bear == null or not bear.can_act()
