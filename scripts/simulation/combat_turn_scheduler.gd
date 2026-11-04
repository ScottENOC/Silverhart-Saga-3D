class_name CombatTurnScheduler
extends RefCounted

signal turn_started(character_id: String)
signal turn_ended(character_id: String)

var current_character_id: String = ""
var rng := RandomNumberGenerator.new()

func _init(random_seed: int = 0) -> void:
    if random_seed == 0:
        rng.randomize()
    else:
        rng.seed = random_seed

func has_active_turn() -> bool:
    return not current_character_id.is_empty()

func select_next_ready(characters: Dictionary) -> CharacterState:
    if has_active_turn():
        return null

    var ready: Array[CharacterState] = []
    for value in characters.values():
        var state := value as CharacterState
        if state != null and state.can_start_combat_turn():
            ready.append(state)
    if ready.is_empty():
        return null

    var highest_tp := -INF
    for state in ready:
        highest_tp = maxf(highest_tp, state.time_points)

    var tied: Array[CharacterState] = []
    for state in ready:
        if is_equal_approx(state.time_points, highest_tp):
            tied.append(state)
    tied.sort_custom(func(a: CharacterState, b: CharacterState) -> bool: return a.id < b.id)

    var selected := tied[rng.randi_range(0, tied.size() - 1)]
    current_character_id = selected.id
    turn_started.emit(selected.id)
    return selected

func try_end_turn(characters: Dictionary, forced: bool = false) -> bool:
    if not has_active_turn():
        return false
    var state := characters.get(current_character_id) as CharacterState
    if state == null:
        current_character_id = ""
        return false
    if not state.should_end_turn(forced):
        return false

    var ended_id := current_character_id
    current_character_id = ""
    turn_ended.emit(ended_id)
    return true

func clear() -> void:
    current_character_id = ""
