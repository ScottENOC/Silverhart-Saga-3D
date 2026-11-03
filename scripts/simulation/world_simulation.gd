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
    characters[state.id] = state
    occupied_hexes[state.axial] = state.id

func get_character(character_id: String) -> CharacterState:
    return characters.get(character_id) as CharacterState

func try_move_character(character_id: String, destination: Vector2i) -> bool:
    var state := get_character(character_id)
    if state == null:
        return false
    if HexGrid.distance(state.axial, destination) != 1:
        return false
    if not map_data.is_walkable(destination):
        return false
    if occupied_hexes.has(destination):
        return false

    var origin: Vector2i = state.axial
    occupied_hexes.erase(origin)
    state.axial = destination
    occupied_hexes[destination] = character_id
    character_moved.emit(character_id, origin, destination)
    return true
