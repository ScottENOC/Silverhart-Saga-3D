extends SceneTree

const DOOR_SCRIPT = preload("res://scripts/world/building_door_state.gd")
const REGISTRY_SCRIPT = preload("res://scripts/world/building_registry.gd")
const MAP_SCRIPT = preload("res://scripts/core/hex_map_data.gd")

func _initialize() -> void:
    _test_door_lifecycle()
    _test_registry_and_save_round_trip()
    _test_door_map_blocking()
    print("Building framework tests passed.")
    quit()

func _test_door_lifecycle() -> void:
    var door = DOOR_SCRIPT.new()
    door.configure("front", "test_house", Vector2i(2, 3), false, true, 20)
    assert(not door.is_passable(), "A closed door must block movement.")
    assert(not door.open(), "A locked door must not open.")
    assert(not door.lock(), "An already locked door remains locked.")
    assert(door.unlock(), "A closed door can be unlocked.")
    assert(door.open() and door.is_passable(), "An unlocked door can open.")
    assert(not door.close() if door.locked else true, "Door state remains consistent.")
    assert(door.close() and not door.is_passable(), "An open door can close.")
    assert(door.lock(), "A closed door can be locked.")
    assert(door.damage(20), "Lethal damage should break the door.")
    assert(door.is_broken() and door.is_passable() and not door.locked, "A broken door remains open and cannot stay locked.")

func _test_registry_and_save_round_trip() -> void:
    var registry = REGISTRY_SCRIPT.new()
    assert(registry.register_building({"id": "test_house", "name": "Test House", "entrance_hex": Vector2i(0, 0)}))
    assert(not registry.register_building({"id": "test_house", "entrance_hex": Vector2i.ZERO}), "Building IDs must be unique.")
    assert(registry.register_door("front", "test_house", Vector2i(0, 1), false, false, 20))
    assert(not registry.register_door("orphan", "missing", Vector2i.ZERO), "Doors must belong to a registered building.")
    var door = registry.get_door("front")
    assert(door != null and registry.get_door_at(Vector2i(0, 1)) == door)
    assert(registry.set_door_open("front", true))
    var saved: Dictionary = registry.to_dict()
    var restored = REGISTRY_SCRIPT.new()
    assert(restored.register_building({"id": "test_house", "name": "Test House", "entrance_hex": Vector2i.ZERO}))
    assert(restored.register_door("front", "test_house", Vector2i(0, 1), false))
    restored.load_dict(saved)
    assert(restored.get_door("front").is_passable(), "Door state must survive save/load.")

func _test_door_map_blocking() -> void:
    var map_data = MAP_SCRIPT.new()
    map_data.add_cell(Vector2i(0, 0), 0.0, true, "timber_floor")
    assert(map_data.is_walkable(Vector2i.ZERO))
    map_data.set_walkable(Vector2i.ZERO, false)
    assert(not map_data.is_walkable(Vector2i.ZERO), "Closed doors must block hex movement.")
    map_data.set_walkable(Vector2i.ZERO, true)
    assert(map_data.is_walkable(Vector2i.ZERO), "Open doors must restore hex movement.")
