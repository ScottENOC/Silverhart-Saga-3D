class_name TerrainElevationRules
extends RefCounted

## Elevation is a continuous height field sampled at cell centres and shared
## hex vertices. These thresholds classify gameplay access, not rendered mesh
## geometry: the terrain itself remains continuous.

const GENTLE_GRADE := 0.35
const STEEP_GRADE := 0.80
const CLIMBABLE_GRADE := 1.35

static func signed_grade(map_data: HexMapData, from_hex: Vector2i, to_hex: Vector2i) -> float:
    if not map_data.has_cell(from_hex) or not map_data.has_cell(to_hex):
        return INF
    var from_world := HexGrid.axial_to_world(from_hex)
    var to_world := HexGrid.axial_to_world(to_hex)
    var horizontal_distance := Vector2(to_world.x - from_world.x, to_world.z - from_world.z).length()
    if horizontal_distance <= 0.0001:
        return 0.0
    return (map_data.elevation_at(to_hex) - map_data.elevation_at(from_hex)) / horizontal_distance

static func movement_multiplier(map_data: HexMapData, from_hex: Vector2i, to_hex: Vector2i, state: CharacterState) -> float:
    var grade := signed_grade(map_data, from_hex, to_hex)
    if is_inf(grade):
        return INF
    var magnitude := absf(grade)
    var climbing_rank := int(state.skills.get("climbing", state.skills.get("climb", 0)))

    if magnitude <= GENTLE_GRADE:
        return 1.0 + grade * 0.35 if grade > 0.0 else maxf(0.75, 1.0 + grade * 0.20)
    if magnitude <= STEEP_GRADE:
        return 1.35 + maxf(0.0, grade) * 0.45 if grade > 0.0 else 1.10
    if magnitude <= CLIMBABLE_GRADE:
        if climbing_rank < 1:
            return INF
        return 2.0 + maxf(0.0, grade) * 0.8 if grade > 0.0 else 1.35
    if climbing_rank < 3:
        return INF
    return 4.0 + maxf(0.0, grade) if grade > 0.0 else 2.0
