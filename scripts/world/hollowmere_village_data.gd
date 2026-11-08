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
    if hex.x < STREAM_Q_MIN or hex.x > STREAM_Q_MAX or hex == BRIDGE:
        return false
    var centre_r := _river_centre_r(hex.x)
    var half_width := _river_half_width(hex.x)
    return absf(float(hex.y) - centre_r) <= half_width

static func _river_centre_r(q: int) -> float:
    var samples: Array[Vector2i] = [
        Vector2i(-30, -22), Vector2i(-24, -24), Vector2i(-18, -22),
        Vector2i(-12, -24), Vector2i(-6, -27), Vector2i(0, -23),
        Vector2i(5, -24), Vector2i(8, -25), Vector2i(12, -27),
        Vector2i(18, -25), Vector2i(24, -28), Vector2i(30, -25)
    ]
    for index in range(samples.size() - 1):
        if q <= samples[index + 1].x:
            var t := inverse_lerp(float(samples[index].x), float(samples[index + 1].x), float(q))
            return lerpf(float(samples[index].y), float(samples[index + 1].y), t)
    return float(samples.back().y)

static func _river_half_width(q: int) -> float:
    var q_samples := PackedInt32Array([-30, -24, -18, -12, -6, 0, 5, 8, 12, 18, 24, 30])
    var width_samples := PackedFloat32Array([1.0, 1.5, 1.8, 1.4, 1.8, 1.5, 1.1, 0.65, 1.4, 1.8, 1.5, 1.0])
    for index in range(q_samples.size() - 1):
        if q <= q_samples[index + 1]:
            var t := inverse_lerp(float(q_samples[index]), float(q_samples[index + 1]), float(q))
            return lerpf(width_samples[index], width_samples[index + 1], t)
    return width_samples.back()

static func is_building(hex: Vector2i) -> bool:
    for building in BUILDINGS:
        var centre: Vector2i = building["center"]
        if absi(hex.x - centre.x) <= int(building["half_q"]) and absi(hex.y - centre.y) <= int(building["half_r"]):
            return true
    return false

static func is_door(hex: Vector2i) -> bool:
    return hex == Vector2i(0, 15) or hex == Vector2i(-11, 0) or hex == Vector2i(0, -10) or hex == Vector2i(10, 9) or hex == Vector2i(-4, 9)

static func is_blocked(hex: Vector2i) -> bool:
    if not is_in_bounds(hex):
        return true
    if is_door(hex):
        return false
    if is_water(hex) or is_building(hex) or has_tree(hex):
        return true
    return false

static func terrain_id_at(hex: Vector2i) -> String:
    if is_water(hex):
        return "water"
    if is_path(hex):
        return "path"
    if is_building(hex):
        return "building"
    if has_tree(hex):
        return "forest"
    return "grass"

static func is_path(hex: Vector2i) -> bool:
    if hex == BRIDGE:
        return true
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
    if hex == Vector2i(0, 15) or hex == Vector2i(-11, 0) or hex == Vector2i(0, -10) or hex == Vector2i(10, 9) or hex == Vector2i(-4, 9):
        return true
    if hex == Vector2i(0, 5):
        return true
    if hex.x == 0 and hex.y >= -9 and hex.y <= -7:
        return true
    if hex == Vector2i(1, 13) or hex == Vector2i(1, 14):
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
    if hex.x == CROSSROADS.x and hex.y >= -40 and hex.y <= 32:
        return true
    if hex == CROSSROADS:
        return true

    # Short visible sections of the four roads leaving the crossroads.
    if hex.y == CROSSROADS.y and hex.x >= -40 and hex.x <= 16:
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
    _append_unique(cells, seen, Vector2i(0, 15))
    _append_unique(cells, seen, Vector2i(1, 13))
    _append_unique(cells, seen, Vector2i(1, 14))
    _append_unique(cells, seen, Vector2i(-11, 0))
    _append_unique(cells, seen, Vector2i(-10, 0))
    _append_unique(cells, seen, Vector2i(-9, 0))
    _append_unique(cells, seen, Vector2i(10, 9))
    _append_unique(cells, seen, Vector2i(9, 9))
    for q in range(-4, 0):
        _append_unique(cells, seen, Vector2i(q, 9))
    for r in range(-40, 33):
        _append_unique(cells, seen, Vector2i(CROSSROADS.x, r))
    _append_unique(cells, seen, BRIDGE)
    for q in range(-40, 17):
        _append_unique(cells, seen, Vector2i(q, CROSSROADS.y))
    return cells

static func water_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for q in range(STREAM_Q_MIN, STREAM_Q_MAX + 1):
        var centre_r := _river_centre_r(q)
        var half_width := _river_half_width(q)
        for r in range(floori(centre_r - half_width), ceili(centre_r + half_width) + 1):
            var hex := Vector2i(q, r)
            if is_water(hex):
                cells.append(hex)
    return cells

static func is_forest_candidate(hex: Vector2i) -> bool:
    if not is_in_bounds(hex):
        return false
    if HexGrid.distance(Vector2i.ZERO, hex) < 17:
        return false
    if is_water(hex) or is_building(hex) or is_path(hex):
        return false
    return _stable_noise(hex.x, hex.y) > 0.18

static func has_tree(hex: Vector2i) -> bool:
    if posmod(hex.x, 4) != 0 or posmod(hex.y, 4) != 0:
        return false
    if not is_forest_candidate(hex):
        return false
    return _stable_noise(hex.x + 17, hex.y - 9) >= 0.56

static func _append_unique(cells: Array[Vector2i], seen: Dictionary, hex: Vector2i) -> void:
    if seen.has(hex):
        return
    seen[hex] = true
    cells.append(hex)

static func _stable_noise(q: int, r: int) -> float:
    var value: int = posmod(q * 92837111 + r * 689287499 + 1013904223, 2147483647)
    return float(value) / 2147483647.0
