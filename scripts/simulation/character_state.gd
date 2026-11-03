class_name CharacterState
extends RefCounted

var id: String
var display_name: String
var axial: Vector2i
var health: int = 100
var max_health: int = 100

func _init(character_id: String = "", character_name: String = "", start_hex: Vector2i = Vector2i.ZERO) -> void:
    id = character_id
    display_name = character_name
    axial = start_hex

func to_dict() -> Dictionary:
    return {
        "id": id,
        "display_name": display_name,
        "axial_q": axial.x,
        "axial_r": axial.y,
        "health": health,
        "max_health": max_health,
    }

static func from_dict(data: Dictionary) -> CharacterState:
    var state := CharacterState.new(
        String(data.get("id", "")),
        String(data.get("display_name", "")),
        Vector2i(int(data.get("axial_q", 0)), int(data.get("axial_r", 0)))
    )
    state.health = int(data.get("health", 100))
    state.max_health = int(data.get("max_health", 100))
    return state
