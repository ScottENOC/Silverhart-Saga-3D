extends SceneTree

const CELL_LOADER = preload("res://scripts/world/campaign2_world_cell_loader.gd")

var failures: int = 0

func _initialize() -> void:
    _test_authored_hollowmere_cells_are_not_overwritten()
    _test_hollowmere_cells_are_loaded_from_settlement_data()
    _test_settlement_footprints_and_paths_are_logical_cells()
    _test_generation_is_stable_across_chunk_load_order()
    _test_negative_chunk_coordinates()
    if failures > 0:
        push_error("%d Campaign 2 world cell loader test(s) failed." % failures)
        quit(1)
        return
    print("Campaign 2 world cell loader tests passed.")
    quit(0)

func _test_authored_hollowmere_cells_are_not_overwritten() -> void:
    var map_data := HexMapData.new()
    map_data.add_cell(Vector2i(8, 24), 0.25, true, "authored_path")
    var loader = CELL_LOADER.new()
    loader.load_around(map_data, Vector2i(8, 24), 0)
    _check(map_data.terrain_id_at(Vector2i(8, 24)) == "authored_path", "The authored Hollowmere map must remain authoritative")
    _check(map_data.elevation_at(Vector2i(8, 24)) == 0.25, "Authored Hollowmere elevation must not be overwritten")

func _test_hollowmere_cells_are_loaded_from_settlement_data() -> void:
    var map_data := HexMapData.new()
    var loader = CELL_LOADER.new()
    loader.load_around(map_data, Vector2i.ZERO, 4)
    var crossroads := Vector2i(8, 24)
    var elder_house := Vector2i(0, -12)
    var stream := Vector2i(7, -25)
    var bridge := Vector2i(8, -25)
    _check(map_data.has_cell(crossroads), "The Hollowmere crossroads must be materialised by the shared world loader")
    _check(map_data.terrain_id_at(crossroads) == "path", "The Hollowmere crossroads must come from settlement path data")
    _check(map_data.is_walkable(crossroads), "The Hollowmere crossroads must remain traversable")
    _check(map_data.has_cell(elder_house), "The Hollowmere elder-house footprint must be materialised")
    _check(map_data.terrain_id_at(elder_house) == "building" and not map_data.is_walkable(elder_house), "The elder-house footprint must retain blocked building terrain")
    _check(map_data.has_cell(stream) and map_data.terrain_id_at(stream) == "water" and not map_data.is_walkable(stream), "The Hollowmere stream must be materialised as blocked water")
    _check(map_data.has_cell(bridge) and map_data.terrain_id_at(bridge) == "path" and map_data.is_walkable(bridge), "The authored bridge must remain a traversable path across the stream")
    _check(map_data.has_cell(Vector2i(110, 110)), "The same loaded area must continue into regional terrain beyond the settlement boundary")
    _check(loader.loaded_chunk_count() == 81, "The opening world should be materialised as a 9x9 neighbourhood of shared world chunks")
func _test_settlement_footprints_and_paths_are_logical_cells() -> void:
    var map_data := HexMapData.new()
    var loader = CELL_LOADER.new()
    loader.load_around(map_data, Vector2i(1, -366), 0)
    _check(map_data.has_cell(Vector2i(1, -366)), "The Millbrook building footprint should be materialised")
    _check(map_data.terrain_id_at(Vector2i(1, -366)) == "building", "The Millbrook building footprint should retain authored building terrain")
    _check(not map_data.is_walkable(Vector2i(1, -366)), "The Millbrook building footprint should be blocked")
    _check(map_data.terrain_id_at(Vector2i(5, -366)) == "path", "The Millbrook entrance path should be materialised from settlement data")
    _check(map_data.is_walkable(Vector2i(5, -366)), "The Millbrook entrance path should be walkable")
func _test_generation_is_stable_across_chunk_load_order() -> void:
    var first_map := HexMapData.new()
    var second_map := HexMapData.new()
    var first_loader = CELL_LOADER.new()
    var second_loader = CELL_LOADER.new()
    first_loader.load_around(first_map, Vector2i(120, -100), 0)
    first_loader.load_around(first_map, Vector2i(216, -100), 0)
    second_loader.load_around(second_map, Vector2i(216, -100), 0)
    second_loader.load_around(second_map, Vector2i(120, -100), 0)
    for hex in [Vector2i(120, -100), Vector2i(216, -100), Vector2i(121, -99), Vector2i(217, -99)]:
        _check(first_map.terrain_id_at(hex) == second_map.terrain_id_at(hex), "Terrain must not depend on chunk load order at %s" % hex)
        _check(is_equal_approx(first_map.elevation_at(hex), second_map.elevation_at(hex)), "Elevation must not depend on chunk load order at %s" % hex)

func _test_negative_chunk_coordinates() -> void:
    var loader = CELL_LOADER.new()
    _check(loader.terrain_data.chunk_for_hex(Vector2i(-1, -1), CELL_LOADER.CHUNK_SIZE) == Vector2i(-1, -1), "Negative coordinates must use floor-based chunk ownership")
    _check(loader.terrain_data.chunk_for_hex(Vector2i(-24, -24), CELL_LOADER.CHUNK_SIZE) == Vector2i(-1, -1), "Negative chunk boundaries must be stable")
    _check(loader.terrain_data.chunk_for_hex(Vector2i(-25, -25), CELL_LOADER.CHUNK_SIZE) == Vector2i(-2, -2), "Negative coordinates below the boundary must enter the preceding chunk")
func _check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
