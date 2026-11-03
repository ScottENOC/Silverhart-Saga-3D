class_name HexMapData
extends RefCounted

# Gameplay map data only. Rendering and collision nodes are separate.
var cells: Dictionary = {}

func add_cell(hex: Vector2i, elevation: float = 0.0, walkable: bool = true, terrain_id: String = "grass") -> void:
    cells[hex] = {
        "elevation": elevation,
        "walkable": walkable,
        "terrain_id": terrain_id,
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
