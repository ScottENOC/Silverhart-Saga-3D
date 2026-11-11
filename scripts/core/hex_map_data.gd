class_name HexMapData
extends RefCounted

# Gameplay map data only. Rendering and collision nodes are separate.
# Cell centres hold gameplay elevation; shared vertex samples define the
# continuous rendered surface and prevent cracks between adjacent hexes.
var cells: Dictionary = {}
var vertex_heights: Dictionary = {}

const TERRAIN_MOVE_MULTIPLIERS := {
    "grass": 1.0, "forest": 1.5, "mountain": 2.0, "sand": 1.5,
    "swamp": 2.0, "water": 2.0, "cave_floor": 1.0, "wood_floor": 1.0,
    "timber_floor": 1.0, "path": 0.9, "dirt": 1.0, "pedestal": 2.0,
    "foliage": 1.5, "rocky_outcrop": 1.5, "rubble": 1.5,
    "high_ground": 1.3, "climbable_wall": 5.0, "palisade_wall": 15.0,
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

func set_walkable(hex: Vector2i, walkable: bool) -> bool:
    if not cells.has(hex):
        return false
    cells[hex]["walkable"] = walkable
    return true

func has_cell(hex: Vector2i) -> bool:
    return cells.has(hex)

func is_walkable(hex: Vector2i) -> bool:
    return cells.has(hex) and bool(cells[hex].get("walkable", false))

func elevation_at(hex: Vector2i) -> float:
    return float(cells[hex].get("elevation", 0.0)) if cells.has(hex) else 0.0

func terrain_id_at(hex: Vector2i) -> String:
    return String(cells[hex].get("terrain_id", "")) if cells.has(hex) else ""

func movement_multiplier_at(hex: Vector2i) -> float:
    return float(cells[hex].get("movement_multiplier", 1.0)) if cells.has(hex) else 1.0

static func vertex_key(world_x: float, world_z: float) -> String:
    return "%d:%d" % [roundi(world_x * 10000.0), roundi(world_z * 10000.0)]

func set_vertex_height(hex: Vector2i, corner_index: int, height: float, radius: float = HexGrid.DEFAULT_RADIUS_M) -> void:
    if not has_cell(hex) or corner_index < 0 or corner_index >= HexGrid.SIDE_COUNT:
        return
    var centre := HexGrid.axial_to_world(hex, radius)
    var corner := HexGrid.corner_offsets(radius)[corner_index]
    vertex_heights[vertex_key(centre.x + corner.x, centre.z + corner.y)] = height

func vertex_height_at(hex: Vector2i, corner_index: int, radius: float = HexGrid.DEFAULT_RADIUS_M) -> float:
    if not has_cell(hex) or corner_index < 0 or corner_index >= HexGrid.SIDE_COUNT:
        return 0.0
    var centre := HexGrid.axial_to_world(hex, radius)
    var corner := HexGrid.corner_offsets(radius)[corner_index]
    var key := vertex_key(centre.x + corner.x, centre.z + corner.y)
    return float(vertex_heights.get(key, elevation_at(hex)))

func corner_world_position(hex: Vector2i, corner_index: int, radius: float = HexGrid.DEFAULT_RADIUS_M) -> Vector3:
    var centre := HexGrid.axial_to_world(hex, radius)
    var corner := HexGrid.corner_offsets(radius)[corner_index]
    return Vector3(centre.x + corner.x, vertex_height_at(hex, corner_index, radius), centre.z + corner.y)
