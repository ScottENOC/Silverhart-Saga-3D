class_name HexMapData
extends RefCounted

# Gameplay map data only. Rendering and collision nodes are separate.
var cells: Dictionary = {}

const TERRAIN_MOVE_MULTIPLIERS := {
    "grass": 1.0,
    "forest": 1.5,
    "mountain": 2.0,
    "sand": 1.5,
    "swamp": 2.0,
    "water": 2.0,
    "cave_floor": 1.0,
    "wood_floor": 1.0,
    "timber_floor": 1.0,
    "path": 0.9,
    "dirt": 1.0,
    "pedestal": 2.0,
    "foliage": 1.5,
    "rocky_outcrop": 1.5,
    "rubble": 1.5,
    "high_ground": 1.3,
    "climbable_wall": 5.0,
    "palisade_wall": 15.0,
    "lava": 1.0,
}

func add_cell(hex: Vector2i, elevation: float = 0.0, walkable: bool = true, terrain_id: String = "grass", movement_multiplier: float = -1.0) -> void:
    var resolved_multiplier := movement_multiplier
    if resolved_multiplier <= 0.0:
        resolved_multiplier = float(TERRAIN_MOVE_MULTIPLIERS.get(terrain_id, 1.0))
    cells[hex] = {
        "elevation": elevation,
        "walkable": walkable,
        "terrain_id": terrain_id,
        "movement_multiplier": resolved_multiplier,
    }

func has_cell(hex: Vector2i) -> bool:
    return cells.has(hex)

func is_walkable(hex: Vector2i) -> bool:
    if not cells.has(hex):
        return false
    return bool(cells[hex].get("walkable", false))

func elevation_at(hex: Vector2i) -> float:
    if not cells.has(hex):
        return 0.0
    return float(cells[hex].get("elevation", 0.0))

func terrain_id_at(hex: Vector2i) -> String:
    if not cells.has(hex):
        return ""
    return String(cells[hex].get("terrain_id", ""))

func movement_multiplier_at(hex: Vector2i) -> float:
    if not cells.has(hex):
        return 1.0
    return float(cells[hex].get("movement_multiplier", 1.0))
