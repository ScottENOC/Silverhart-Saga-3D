class_name HollowmereVillageData
extends RefCounted
## Shared local-map layout for Hollowmere. Axial coordinates match the tavern grid.

const MAP_RADIUS: int = 40
const STREAM_R: int = -25
const STREAM_Q_MIN: int = -30
const STREAM_Q_MAX: int = 30
const CROSSROADS := Vector2i(8, 24)
const BRIDGE := Vector2i(8, STREAM_R)

const BUILDINGS := [
    {"id": "general_store", "center": Vector2i(0, 18), "half_q": 3, "half_r": 2},
    {"id": "chapel", "center": Vector2i(-14, 0), "half_q": 2, "half_r": 3},
    {"id": "elder_house", "center": Vector2i(0, -12), "half_q": 2, "half_r": 2},
    {"id": "mira_house", "center": Vector2i(12, 9), "half_q": 2, "half_r": 2},
    {"id": "oskar_house", "center": Vector2i(-6, 9), "half_q": 2, "half_r": 2}
]

static func is_in_bounds(hex: Vector2i) -> bool:
    return HexGrid.distance(Vector2i.ZERO, hex) <= MAP_RADIUS

static func is_water(hex: Vector2i) -> bool:
    return hex.y == STREAM_R and hex.x >= STREAM_Q_MIN and hex.x <= STREAM_Q_MAX and hex != BRIDGE

static func is_building(hex: Vector2i) -> bool:
    for building in BUILDINGS:
        var centre: Vector2i = building["center"]
        if absi(hex.x - centre.x) <= int(building["half_q"]) and absi(hex.y - centre.y) <= int(building["half_r"]):
            return true
    return false

static func is_blocked(hex: Vector2i) -> bool:
    if not is_in_bounds(hex):
        return true
    if is_water(hex) or is_building(hex):
        return true
    return false

static func terrain_id_at(hex: Vector2i) -> String:
    if is_water(hex):
        return "water"
    if is_building(hex):
        return "building"
    if is_path(hex):
        return "path"
    return "grass"

static func is_path(hex: Vector2i) -> bool:
    # Maintained ring road around the Hollow Tankard.
    if hex.y == -6 and hex.x >= -8 and hex.x <= 8:
        return true
    if hex.y == 6 and hex.x >= -8 and hex.x <= 8:
        return true
    if hex.x == -8 and hex.y >= -6 and hex.y <= 6:
        return true
    if hex.x == 8 and hex.y >= -6 and hex.y <= 6:
        return true

    # Door spurs: tavern, elder's house, store, chapel and two village homes.
    if hex == Vector2i(0, 5):
        return true
    if hex.x == 0 and hex.y >= -9 and hex.y <= -7:
        return true
    if hex == Vector2i(1, 14):
        return true
    if hex.x == 0 and hex.y >= 7 and hex.y <= 13:
        return true
    if hex.x == -10 and hex.y == 0 or hex.x == -9 and hex.y == 0:
        return true
    if hex == Vector2i(9, 9):
        return true
    if hex.x >= -3 and hex.x <= -1 and hex.y == 9:
        return true

    # North-south road, bridge and the signposted crossroads.
    if hex.x == CROSSROADS.x and hex.y >= -24 and hex.y <= CROSSROADS.y:
        return true
    if hex == CROSSROADS:
        return true

    # Short visible sections of the four roads leaving the crossroads.
    if hex.y == CROSSROADS.y and hex.x >= -25 and hex.x <= 16:
        return true
    return false

static func path_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    var seen: Dictionary = {}
    for q in range(-8, 9):
        _append_unique(cells, seen, Vector2i(q, -6))
        _append_unique(cells, seen, Vector2i(q, 6))
    for r in range(-6, 7):
        _append_unique(cells, seen, Vector2i(-8, r))
        _append_unique(cells, seen, Vector2i(8, r))
    for r in range(-9, -6):
        _append_unique(cells, seen, Vector2i(0, r))
    for r in range(7, 14):
        _append_unique(cells, seen, Vector2i(0, r))
    _append_unique(cells, seen, Vector2i(0, 5))
    _append_unique(cells, seen, Vector2i(1, 14))
    _append_unique(cells, seen, Vector2i(-10, 0))
    _append_unique(cells, seen, Vector2i(-9, 0))
    _append_unique(cells, seen, Vector2i(9, 9))
    for q in range(-3, 0):
        _append_unique(cells, seen, Vector2i(q, 9))
    for r in range(-24, 25):
        _append_unique(cells, seen, Vector2i(CROSSROADS.x, r))
    for q in range(-25, 17):
        _append_unique(cells, seen, Vector2i(q, CROSSROADS.y))
    return cells

static func water_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for q in range(STREAM_Q_MIN, STREAM_Q_MAX + 1):
        var hex := Vector2i(q, STREAM_R)
        if hex != BRIDGE:
            cells.append(hex)
    return cells

static func is_forest_candidate(hex: Vector2i) -> bool:
    if HexGrid.distance(Vector2i.ZERO, hex) < 17:
        return false
    if is_water(hex) or is_building(hex) or is_path(hex):
        return false
    return _stable_noise(hex.x, hex.y) > 0.18

static func _append_unique(cells: Array[Vector2i], seen: Dictionary, hex: Vector2i) -> void:
    if seen.has(hex):
        return
    seen[hex] = true
    cells.append(hex)

static func _stable_noise(q: int, r: int) -> float:
    var value: int = posmod(q * 92837111 + r * 689287499 + 1013904223, 2147483647)
    return float(value) / 2147483647.0
