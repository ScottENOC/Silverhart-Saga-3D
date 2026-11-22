class_name Campaign2WorldCellLoader
extends RefCounted
## Materialises logical HexMapData cells from the same Campaign 2 world provider
## used by the regional preview. Logical cells persist after exploration so
## unloading presentation can never erase gameplay changes.

const TERRAIN_DATA_SCRIPT = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const CHUNK_SIZE: int = 24
const DEFAULT_LOAD_RADIUS: int = 1

var terrain_data: Campaign2WorldTerrainData
var loaded_chunks: Dictionary = {}

func _init(source: Campaign2WorldTerrainData = null) -> void:
    if source == null:
        terrain_data = TERRAIN_DATA_SCRIPT.new() as Campaign2WorldTerrainData
    else:
        terrain_data = source

## Load a square neighbourhood of global axial chunks around a world coordinate.
## Already materialised cells are never replaced, preserving runtime mutations.
func load_around(map_data: HexMapData, centre: Vector2i, radius: int = DEFAULT_LOAD_RADIUS) -> int:
    if map_data == null:
        return loaded_chunks.size()
    var centre_chunk := terrain_data.chunk_for_hex(centre, CHUNK_SIZE)
    for dq in range(-radius, radius + 1):
        for dr in range(-radius, radius + 1):
            var chunk := centre_chunk + Vector2i(dq, dr)
            var key := _chunk_key(chunk)
            if loaded_chunks.has(key):
                continue
            var chunk_min := chunk * CHUNK_SIZE
            for q in range(chunk_min.x, chunk_min.x + CHUNK_SIZE):
                for r in range(chunk_min.y, chunk_min.y + CHUNK_SIZE):
                    var hex := Vector2i(q, r)
                    if map_data.has_cell(hex):
                        continue
                    var terrain_id := terrain_data.gameplay_terrain_for_hex(hex)
                    if terrain_id in ["authored", "void"]:
                        continue
                    var walkable := terrain_data.is_walkable_for_hex(hex)
                    map_data.add_cell(hex, terrain_data.elevation_for_hex(hex), walkable, terrain_id, terrain_data.movement_multiplier_for_hex(hex))
            loaded_chunks[key] = chunk
    return loaded_chunks.size()

func is_chunk_loaded(chunk: Vector2i) -> bool:
    return loaded_chunks.has(_chunk_key(chunk))

func loaded_chunk_count() -> int:
    return loaded_chunks.size()

func _chunk_key(chunk: Vector2i) -> String:
    return "%d,%d" % [chunk.x, chunk.y]
