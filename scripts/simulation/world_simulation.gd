class_name WorldSimulation
extends Node

signal character_moved(character_id: String, from_hex: Vector2i, to_hex: Vector2i)

var map_data: HexMapData = HexMapData.new()
var characters: Dictionary = {}
var occupied_hexes: Dictionary = {}
var player_character_id: String = "player"

func register_character(state: CharacterState) -> void:
    if state.id.is_empty():
        push_error("Character IDs must be stable and non-empty.")
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
