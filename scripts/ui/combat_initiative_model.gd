class_name CombatInitiativeModel
extends RefCounted

## Builds the source-style initiative strip from authoritative simulation state.
## The model never changes TP and never chooses the next actor.

static func build_entries(characters: Dictionary, current_character_id: String = "") -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    for value in characters.values():
        var state := value as CharacterState
        if state == null or not state.alive or state.is_rider or state.combat_dormant:
            continue
        if state.side != "player" and state.side != "enemy":
            continue

        entries.append({
            "id": state.id,
            "display_name": state.display_name,
            "side": state.side,
            "time_points": state.time_points,
            "health": state.health,
            "max_health": maxi(1, state.max_health),
            "mana": state.current_mana,
            "max_mana": maxi(0, state.max_mana),
            "portrait_texture": state.portrait_texture,
            "is_active": state.id == current_character_id,
            "is_unconscious": state.unconscious,
            "can_start_turn": state.can_start_combat_turn()
        })

    entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var a_tp := float(a.get("time_points", 0.0))
        var b_tp := float(b.get("time_points", 0.0))
        if a_tp > b_tp:
            return true
        if a_tp < b_tp:
            return false
        return String(a.get("id", "")) < String(b.get("id", ""))
    )
    return entries
