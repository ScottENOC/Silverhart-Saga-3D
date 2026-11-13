extends SceneTree

const DOOR_SCRIPT = preload("res://scripts/world/building_door_state.gd")
const REGISTRY_SCRIPT = preload("res://scripts/world/building_registry.gd")
const MAP_SCRIPT = preload("res://scripts/core/hex_map_data.gd")
const WORLD_SIM_SCRIPT = preload("res://scripts/simulation/world_simulation.gd")
const BUILDING_LAYOUT_REGISTRAR = preload("res://scripts/world/building_layout_registrar.gd")

func _initialize() -> void:
    _test_door_lifecycle()
    _test_registry_and_save_round_trip()
    _test_door_map_blocking()
    _test_world_simulation_save_round_trip()
    _test_character_floor_relocation()
    _test_building_layout_registration()
    print("Building framework tests passed.")
    quit()

func _test_door_lifecycle() -> void:
    var door = DOOR_SCRIPT.new()
    door.configure("front", "test_house", Vector2i(2, 3), false, true, 20)
    assert(not door.is_passable(), "A closed door must block movement.")
    assert(not door.open(), "A locked door must not open.")
    assert(door.lock(), "Locking a closed door should succeed.")
    assert(door.unlock(), "A closed door can be unlocked.")
    assert(door.open() and door.is_passable(), "An unlocked door can open.")
    assert(not door.lock(), "An open door cannot be locked.")
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

func _test_world_simulation_save_round_trip() -> void:
    var source = WORLD_SIM_SCRIPT.new()
    source.building_registry.register_building({"id": "test_house", "name": "Test House", "entrance_hex": Vector2i.ZERO})
    source.building_registry.register_door("front", "test_house", Vector2i(0, 1), false)
    assert(source.building_registry.set_door_open("front", true))
    var saved: Dictionary = source.to_dict()

    var restored = WORLD_SIM_SCRIPT.new()
    restored.building_registry.register_building({"id": "test_house", "name": "Test House", "entrance_hex": Vector2i.ZERO})
    restored.building_registry.register_door("front", "test_house", Vector2i(0, 1), false)
    restored.map_data.add_cell(Vector2i(0, 1), 0.0, false, "timber_floor")
    restored.load_dict(saved)
    assert(restored.building_registry.get_door("front").is_passable(), "World saves must retain door state.")
    assert(restored.map_data.is_walkable(Vector2i(0, 1)), "Loaded door state must restore map walkability.")
    source.free()
    restored.free()

func _test_character_floor_relocation() -> void:
    var simulation = WORLD_SIM_SCRIPT.new()
    simulation.map_data.add_cell(Vector2i(0, 0), 0.0, true, "timber_floor")
    simulation.map_data.add_cell(Vector2i(100, 100), 3.38, true, "timber_floor")
    simulation.map_data.add_cell(Vector2i(101, 100), 3.38, true, "timber_floor")
    simulation.building_registry.register_building({"id": "test_inn", "name": "Test Inn", "entrance_hex": Vector2i.ZERO, "virtual_floor_bounds": [95, 105, 97, 103]})
    var character = CharacterState.new("player", "Test Player", Vector2i.ZERO)
    simulation.register_character(character)
    assert(simulation.relocate_character("player", Vector2i(100, 100)), "A character should be able to use a connected stair.")
    assert(character.axial == Vector2i(100, 100), "The character should occupy the upper-floor coordinate.")
    assert(simulation.occupied_hexes.get(Vector2i(100, 100), "") == "player", "Upper-floor occupancy must be registered.")
    var upstairs_path: Array[Vector2i] = simulation.find_path("player", Vector2i(101, 100))
    assert(upstairs_path.size() == 2, "Upper-floor navigation should use the normal hex pathfinder.")
    assert(not simulation.relocate_character("player", Vector2i(200, 200)), "A transition to a missing floor cell must fail.")
    var saved_character: Dictionary = character.to_dict()
    var restored_character = CharacterState.from_dict(saved_character)
    assert(restored_character.axial == Vector2i(100, 100), "An upstairs location must persist in character saves.")
    assert(simulation.relocate_character("player", Vector2i.ZERO), "The character should be able to descend.")
    assert(character.axial == Vector2i.ZERO and simulation.occupied_hexes.get(Vector2i.ZERO, "") == "player")
    simulation.free()
func _test_building_layout_registration() -> void:
    var simulation = WORLD_SIM_SCRIPT.new()
    simulation.map_data.add_cell(Vector2i.ZERO, 0.0, true, "grass")
    simulation.map_data.add_cell(Vector2i(0, 1), 0.0, true, "path")
    var building_definition := {
        "id": "test_inn",
        "name": "Test Inn",
        "entrance_hex": Vector2i(0, 1),
        "floor_count": 2,
    }
    var door_definition := {
        "id": "test_inn_front",
        "building_id": "test_inn",
        "hex": Vector2i(0, 1),
        "starts_open": false,
        "starts_locked": true,
        "durability": 30,
    }
    var floors: Array[Dictionary] = [
        {"hex": Vector2i(100, 100), "elevation": 3.38, "walkable": true, "terrain_id": "timber_floor"},
        {"hex": Vector2i(101, 100), "elevation": 3.38, "walkable": false, "terrain_id": "timber_floor"},
    ]
    assert(BUILDING_LAYOUT_REGISTRAR.register_layout(simulation, building_definition, door_definition, floors))
    assert(simulation.building_registry.get_building("test_inn").get("floor_count", 0) == 2)
    assert(not simulation.building_registry.get_door("test_inn_front").is_passable())
    assert(not simulation.map_data.is_walkable(Vector2i(0, 1)), "A closed starting door must block its map cell.")
    assert(simulation.map_data.is_walkable(Vector2i(100, 100)))
    assert(not simulation.map_data.is_walkable(Vector2i(101, 100)))
    assert(is_equal_approx(simulation.map_data.elevation_at(Vector2i(100, 100)), 3.38))
    assert(not BUILDING_LAYOUT_REGISTRAR.register_layout(simulation, building_definition, door_definition, floors), "Duplicate building layouts must be rejected.")
    var missing_door_cell_simulation = WORLD_SIM_SCRIPT.new()
    assert(not BUILDING_LAYOUT_REGISTRAR.register_layout(missing_door_cell_simulation, building_definition, door_definition, floors), "A door without a registered map cell must be rejected.")
    assert(not missing_door_cell_simulation.building_registry.definitions.has("test_inn"), "Invalid layouts must not partially register buildings.")
    missing_door_cell_simulation.free()
    simulation.free()
