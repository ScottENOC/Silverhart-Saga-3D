class_name BuildingRegistry
extends RefCounted
## Runtime building catalogue and persistent door-state registry.
## Definitions are authored data; mutable door state is included in saves.

var definitions: Dictionary = {}
var doors: Dictionary = {}

func register_building(definition: Dictionary) -> bool:
    var building_id := String(definition.get("id", "")).strip_edges()
    var entrance: Variant = definition.get("entrance_hex")
    if building_id.is_empty() or not (entrance is Vector2i) or definitions.has(building_id):
        return false
    definitions[building_id] = definition.duplicate(true)
    return true

func register_door(door_id: String, building_id: String, door_hex: Vector2i, starts_open: bool = true, starts_locked: bool = false, durability: int = 20) -> bool:
    if door_id.is_empty() or doors.has(door_id) or not definitions.has(building_id):
        return false
    var door := BuildingDoorState.new()
    door.configure(door_id, building_id, door_hex, starts_open, starts_locked, durability)
    doors[door_id] = door
    return true

func get_building(building_id: String) -> Dictionary:
    var definition: Variant = definitions.get(building_id, {})
    return definition.duplicate(true) if definition is Dictionary else {}

func get_door(door_id: String) -> BuildingDoorState:
    return doors.get(door_id) as BuildingDoorState

func get_door_at(hex: Vector2i) -> BuildingDoorState:
    for value in doors.values():
        var door := value as BuildingDoorState
        if door.hex == hex:
            return door
    return null

func set_door_open(door_id: String, should_open: bool) -> bool:
    var door := get_door(door_id)
    if door == null:
        return false
    return door.open() if should_open else door.close()

func to_dict() -> Dictionary:
    var saved_doors: Dictionary = {}
    for door_id in doors:
        saved_doors[door_id] = (doors[door_id] as BuildingDoorState).to_dict()
    return {"doors": saved_doors}

func load_dict(data: Dictionary) -> void:
    var saved_doors: Dictionary = data.get("doors", {})
    for door_id in saved_doors:
        var door := get_door(String(door_id))
        var saved_state: Variant = saved_doors[door_id]
        if door != null and saved_state is Dictionary:
            door.load_dict(saved_state)
