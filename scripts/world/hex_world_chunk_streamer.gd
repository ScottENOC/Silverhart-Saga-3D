class_name HexWorldChunkStreamer
extends RefCounted
## Loads deterministic axial-hex chunks around the active exploration point.
## Authored Hollowmere cells are never replaced or unloaded.

const CHUNK_SIZE: int = 16
const DEFAULT_LOAD_RADIUS: int = 1
const AUTHORED_VILLAGE_RADIUS: int = 40

var active_chunks: Dictionary = {}
var generated_cells_by_chunk: Dictionary = {}

func load_around(map_data: HexMapData, centre: Vector2i, radius: int = DEFAULT_LOAD_RADIUS, seed_value: int = 1) -> int:
    var centre_chunk := chunk_for_hex(centre)
    var wanted: Dictionary = {}
    for dq in range(-radius, radius + 1):
        for dr in range(-radius, radius + 1):
            var chunk := centre_chunk + Vector2i(dq, dr)
            var key := _chunk_key(chunk)
            wanted[key] = true
            if active_chunks.has(key):
                continue
            var generated: Array[Vector2i] = []
            for q in range(chunk.x * CHUNK_SIZE, (chunk.x + 1) * CHUNK_SIZE):
                for r in range(chunk.y * CHUNK_SIZE, (chunk.y + 1) * CHUNK_SIZE):
                    var hex := Vector2i(q, r)
                    if HexGrid.distance(Vector2i.ZERO, hex) <= AUTHORED_VILLAGE_RADIUS:
                        continue
                    if map_data.has_cell(hex):
                        continue
                    var terrain_id := terrain_for_hex(hex, seed_value)
                    map_data.add_cell(hex, elevation_for_hex(hex, seed_value), terrain_id != "water", terrain_id)
                    generated.append(hex)
            active_chunks[key] = chunk
            generated_cells_by_chunk[key] = generated
    _unload_unwanted(map_data, wanted)
    return active_chunks.size()

func chunk_for_hex(hex: Vector2i) -> Vector2i:
    return Vector2i(floori(float(hex.x) / CHUNK_SIZE), floori(float(hex.y) / CHUNK_SIZE))

func is_chunk_loaded(chunk: Vector2i) -> bool:
    return active_chunks.has(_chunk_key(chunk))

func active_chunk_count() -> int:
    return active_chunks.size()

static func terrain_for_hex(hex: Vector2i, seed_value: int = 1) -> String:
    var roll := _stable_roll(hex, seed_value)
    if roll < 0.58:
        return "grass"
    if roll < 0.82:
        return "forest"
    if roll < 0.94:
        return "rocky_outcrop"
    return "water"

static func elevation_for_hex(hex: Vector2i, seed_value: int = 1) -> float:
    var broad := _stable_roll(Vector2i(floori(float(hex.x) / 5.0), floori(float(hex.y) / 5.0)), seed_value + 71)
    var detail := _stable_roll(hex, seed_value + 193)
    return snappedf((broad * 1.8 + detail * 0.35) - 0.9, 0.05)

static func _stable_roll(hex: Vector2i, seed_value: int) -> float:
    var value := posmod(hex.x * 92837111 + hex.y * 689287499 + seed_value * 104729 + 1013904223, 2147483647)
    return float(value) / 2147483647.0

func _unload_unwanted(map_data: HexMapData, wanted: Dictionary) -> void:
    var stale: Array[String] = []
    for key in active_chunks:
        if not wanted.has(key):
            stale.append(String(key))
    for key in stale:
        for hex in generated_cells_by_chunk.get(key, []):
            map_data.cells.erase(hex)
            map_data.vertex_heights.clear()
        generated_cells_by_chunk.erase(key)
        active_chunks.erase(key)

static func _chunk_key(chunk: Vector2i) -> String:
    return "%d,%d" % [chunk.x, chunk.y]
