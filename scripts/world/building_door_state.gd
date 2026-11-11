class_name BuildingDoorState
extends RefCounted
## Persistent gameplay state for a door. Visuals and collision are owned by the
## building presentation; this object is the authoritative gameplay state.

enum Condition { OPEN, CLOSED, BROKEN }

var id: String = ""
var building_id: String = ""
var hex: Vector2i = Vector2i.ZERO
var condition: Condition = Condition.OPEN
var locked: bool = false
var health: int = 20
var max_health: int = 20

func configure(door_id: String, owner_building_id: String, door_hex: Vector2i, starts_open: bool = true, starts_locked: bool = false, durability: int = 20) -> void:
    id = door_id
    building_id = owner_building_id
    hex = door_hex
    max_health = maxi(1, durability)
    health = max_health
    condition = Condition.OPEN if starts_open else Condition.CLOSED
    locked = starts_locked and not starts_open

func is_open() -> bool:
    return condition == Condition.OPEN or condition == Condition.BROKEN

func is_passable() -> bool:
    return is_open()

func is_broken() -> bool:
    return condition == Condition.BROKEN

func open() -> bool:
    if is_broken():
        return true
    if locked:
        return false
    condition = Condition.OPEN
    return true

func close() -> bool:
    if is_broken() or locked:
        return false
    condition = Condition.CLOSED
    return true

func lock() -> bool:
    if is_broken() or is_open():
        return false
    locked = true
    return true

func unlock() -> bool:
    if is_broken():
        return false
    locked = false
    return true

func damage(amount: int) -> bool:
    if amount <= 0 or is_broken():
        return false
    health = maxi(0, health - amount)
    if health == 0:
        condition = Condition.BROKEN
        locked = false
        return true
    return false

func to_dict() -> Dictionary:
    return {
        "id": id,
        "building_id": building_id,
        "hex": [hex.x, hex.y],
        "condition": "broken" if is_broken() else ("open" if is_open() else "closed"),
        "locked": locked,
        "health": health,
        "max_health": max_health,
    }

func load_dict(data: Dictionary) -> void:
    if String(data.get("id", id)) != id or String(data.get("building_id", building_id)) != building_id:
        return
    var coordinates: Array = data.get("hex", [hex.x, hex.y])
    if coordinates.size() >= 2:
        hex = Vector2i(int(coordinates[0]), int(coordinates[1]))
    max_health = maxi(1, int(data.get("max_health", max_health)))
    health = clampi(int(data.get("health", max_health)), 0, max_health)
    var condition_name := String(data.get("condition", "closed"))
    match condition_name:
        "broken":
            condition = Condition.BROKEN
            health = 0
            locked = false
        "open":
            condition = Condition.OPEN
        _:
            condition = Condition.CLOSED
    locked = bool(data.get("locked", false)) and condition == Condition.CLOSED
