class_name WorldSimulation
extends Node

signal character_moved(character_id: String, from_hex: Vector2i, to_hex: Vector2i)
signal world_tick(tick_index: int, world_seconds: float)
signal combat_started
signal combat_ended

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
    # The source simulation pauses world-time/TP advancement while an entity
    # is taking its turn. Combat time resumes between turns.
    if is_in_combat and turn_scheduler.has_active_turn():
        return
    clock.advance_real_time(delta, is_in_combat)

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

func get_current_turn_character() -> CharacterState:
    if not turn_scheduler.has_active_turn():
        return null
    return get_character(turn_scheduler.current_character_id)

func try_end_current_turn(forced: bool = false) -> bool:
    return turn_scheduler.try_end_turn(characters, forced)

func _on_clock_ticked(tick_index: int, world_seconds: float) -> void:
    # The original game does not regenerate other entities while a character
    # is actively taking a turn. _process freezes the clock for that interval.
    for value in characters.values():
        var state := value as CharacterState
        if state != null and state.alive:
            state.regenerate_time_points()

    if is_in_combat:
        turn_scheduler.select_next_ready(characters)
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
        "current_turn_character_id": turn_scheduler.current_character_id,
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
