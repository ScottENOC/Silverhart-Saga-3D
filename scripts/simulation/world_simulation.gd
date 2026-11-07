class_name WorldSimulation
extends Node

signal character_moved(character_id: String, from_hex: Vector2i, to_hex: Vector2i)
signal world_tick(tick_index: int, world_seconds: float)
signal combat_started
signal combat_ended
signal combat_action_resolved(result: Dictionary)

var map_data: HexMapData = HexMapData.new()
var characters: Dictionary = {}
var occupied_hexes: Dictionary = {}
var player_character_id: String = "player"
var clock: WorldClock = WorldClock.new()
var turn_scheduler: CombatTurnScheduler = CombatTurnScheduler.new()
var is_in_combat: bool = false

func _init() -> void:
    clock.ticked.connect(_on_clock_ticked)

func _process(delta: float) -> void:
    advance_real_time(delta)

## Check initiative before advancing time, as the source engine does. A ready
## combatant takes their turn immediately; world time only advances when no
## one is eligible to act.
func advance_real_time(real_delta: float) -> int:
    if is_in_combat:
        if turn_scheduler.has_active_turn():
            return 0
        if turn_scheduler.select_next_ready(characters) != null:
            clock.accumulator = 0.0
            return 0
    return clock.advance_real_time(real_delta, is_in_combat)

func advance_world_seconds(delta_seconds: float) -> int:
    # Deterministic equivalent of advance_real_time, for tests and fast-forward.
    if is_in_combat:
        if turn_scheduler.has_active_turn():
            return 0
        if turn_scheduler.select_next_ready(characters) != null:
            clock.accumulator = 0.0
            return 0
    return clock.advance_world_seconds(delta_seconds)

func register_character(state: CharacterState) -> void:
    if state.id.is_empty():
        push_error("Character IDs must have stable, non-empty IDs.")
        return
    if characters.has(state.id):
        push_error("Duplicate character ID: %s" % state.id)
        return
    if occupied_hexes.has(state.axial):
        push_error("Cannot register %s: hex %s is already occupied." % [state.id, state.axial])
        return
    characters[state.id] = state
    occupied_hexes[state.axial] = state.id

func get_character(character_id: String) -> CharacterState:
    return characters.get(character_id) as CharacterState

func start_combat() -> void:
    if is_in_combat:
        return
    is_in_combat = true
    combat_started.emit()

func end_combat() -> void:
    if not is_in_combat:
        return
    turn_scheduler.clear()
    is_in_combat = false
    combat_ended.emit()

func try_attack_character(
    attacker_id: String,
    target_id: String,
    options: Dictionary = {},
    random_seed: int = 0
) -> Dictionary:
    if not is_in_combat or not turn_scheduler.has_active_turn():
        return {"ok": false, "reason": "no_active_combat_turn"}
    if turn_scheduler.current_character_id != attacker_id:
        return {"ok": false, "reason": "not_attacker_turn"}
    var attacker := get_character(attacker_id)
    var target := get_character(target_id)
    var rng := RandomNumberGenerator.new()
    if random_seed == 0:
        rng.randomize()
    else:
        rng.seed = random_seed
    var result := CombatRules.resolve_attack(attacker, target, options, rng)
    if bool(result.get("ok", false)):
        combat_action_resolved.emit(result)
        if attacker.should_end_turn():
            try_end_current_turn()
    return result

func get_current_turn_character() -> CharacterState:
    if not turn_scheduler.has_active_turn():
        return null
    return get_character(turn_scheduler.current_character_id)

func try_end_current_turn(forced: bool = false) -> bool:
    return turn_scheduler.try_end_turn(characters, forced)

func _on_clock_ticked(tick_index: int, world_seconds: float) -> void:
    # Guard direct/test-driven clock advancement as well as the normal
    # _process freeze: no TP or world tick work occurs during an active turn.
    if is_in_combat and turn_scheduler.has_active_turn():
        return
    for value in characters.values():
        var state := value as CharacterState
        if state != null and state.alive:
            state.regenerate_time_points()

    world_tick.emit(tick_index, world_seconds)

## Debug/prototype movement remains free so the M1 movement harness is usable.
## Gameplay actions should call try_move_character_action and supply the
## resolved TP cost from the movement rules.
func try_move_character(character_id: String, destination: Vector2i) -> bool:
    var state := get_character(character_id)
    if not _can_move_to(state, destination):
        return false
    _commit_move(state, destination)
    return true

func try_move_character_action(
    character_id: String,
    destination: Vector2i,
    time_point_cost: float = 5.0
) -> bool:
    var state := get_character(character_id)
    if state == null or not state.can_spend_time_points(time_point_cost):
        return false
    if not _can_move_to(state, destination):
        return false
    if not state.spend_time_points(time_point_cost):
        return false
    _commit_move(state, destination)
    return true

func find_path(character_id: String, destination: Vector2i) -> Array[Vector2i]:
    var state := get_character(character_id)
    if state == null:
        return []
    return HexPathfinder.find_path(map_data, occupied_hexes, state.axial, destination, state)

func movement_cost(character_id: String, destination: Vector2i) -> float:
    var state := get_character(character_id)
    if state == null:
        return INF
    return MovementRules.step_cost(map_data, state.axial, destination, state)

## Execute one adjacent step using the same cost used by pathfinding.
## In combat, the final step may take TP below the normal turn-end threshold,
## matching the original game's movement allowance.
func try_move_character_step(character_id: String, destination: Vector2i) -> bool:
    var state := get_character(character_id)
    if not _can_move_to(state, destination):
        return false
    if is_in_combat:
        if not turn_scheduler.has_active_turn() or turn_scheduler.current_character_id != character_id:
            return false
        if state.time_points <= float(ActionEconomy.turn_end_threshold(state.quick_recovery_rank)):
            return false
    var cost := MovementRules.step_cost(map_data, state.axial, destination, state)
    if not is_in_combat and not state.can_spend_time_points(cost):
        return false
    state.time_points -= cost
    state.total_time_points_spent += cost
    _commit_move(state, destination)
    if is_in_combat and state.should_end_turn():
        try_end_current_turn()
    return true

func _can_move_to(state: CharacterState, destination: Vector2i) -> bool:
    if state == null:
        return false
    if HexGrid.distance(state.axial, destination) != 1:
        return false
    if not map_data.is_walkable(destination):
        return false
    if occupied_hexes.has(destination):
        return false
    return true

func _commit_move(state: CharacterState, destination: Vector2i) -> void:
    var origin: Vector2i = state.axial
    occupied_hexes.erase(origin)
    state.axial = destination
    occupied_hexes[destination] = state.id
    character_moved.emit(state.id, origin, destination)

func to_dict() -> Dictionary:
    var character_data: Dictionary = {}
    for character_id in characters:
        var state := characters[character_id] as CharacterState
        character_data[character_id] = state.to_dict()
    return {
        "world_clock": clock.to_dict(),
        "is_in_combat": is_in_combat,
        "characters": character_data,
    }

func load_dict(data: Dictionary) -> void:
    characters.clear()
    occupied_hexes.clear()
    clock.load_dict(data.get("world_clock", {}))
    is_in_combat = bool(data.get("is_in_combat", false))
    var saved_characters: Dictionary = data.get("characters", {})
    for character_id in saved_characters:
        var state := CharacterState.from_dict(saved_characters[character_id])
        if state.id.is_empty():
            state.id = String(character_id)
        if occupied_hexes.has(state.axial):
            push_error("Save contains overlapping characters at %s." % state.axial)
            continue
        characters[state.id] = state
        occupied_hexes[state.axial] = state.id

    # Do not resume halfway through an unresolved turn after loading. The
    # active character's TP is preserved; initiative is selected again.
    turn_scheduler.clear()
