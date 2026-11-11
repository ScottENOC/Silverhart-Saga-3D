class_name VisionRules
extends RefCounted

## Source-backed starting values from Hex-crpg. This class is simulation-only:
## presentation, fog rendering and AI policy consume these queries separately.
const BASE_VISION_RANGE: int = 25
const EXPLORATION_RANGE: int = 30
const DEFAULT_EYE_HEIGHT_M: float = 1.6
const DEFAULT_OPAQUE_HEIGHT_M: float = 2.2
const LOW_LIGHT_RANGE_FACTOR: float = 0.2

const OPAQUE_TERRAIN_IDS: Array[String] = [
    "wall",
    "keep_wall",
    "climbable_wall",
]

## Racial/sensory skills alter range; darkvision traits remove the low-light
## penalty rather than granting an unconditional range increase.
static func vision_range(
    observer: CharacterState,
    indoors: bool = false,
    low_light: bool = false,
    target_illuminated: bool = false
) -> int:
    if observer == null:
        return 0

    var result := BASE_VISION_RANGE
    result += 4 * _skill_rank(observer, "elf_vision")
    result += 3 * _skill_rank(observer, "goblin_keen_senses")
    if indoors:
        result += 4 * _skill_rank(observer, "deep_sense")

    if low_light and not target_illuminated:
        var has_low_light_vision := (
            _skill_rank(observer, "elf_darkvision") > 0
            or _skill_rank(observer, "goblin_low_light_eyes") > 0
        )
        if not has_low_light_vision:
            result = int(floor(float(result) * LOW_LIGHT_RANGE_FACTOR))
    return maxi(0, result)


static func exploration_range() -> int:
    return EXPLORATION_RANGE


## A single reusable spatial query. Missing map cells are treated as unknown
## and therefore block sight; callers should load the relevant map area first.
static func has_line_of_sight(
    map_data: HexMapData,
    origin: Vector2i,
    target: Vector2i,
    eye_height_m: float = DEFAULT_EYE_HEIGHT_M
) -> bool:
    if map_data == null or not map_data.has_cell(origin) or not map_data.has_cell(target):
        return false
    if origin == target:
        return true

    var ray := _hex_line(origin, target)
    var total_steps := ray.size() - 1
    var origin_eye := map_data.elevation_at(origin) + eye_height_m
    var target_eye := map_data.elevation_at(target) + eye_height_m

    # Endpoints are deliberately excluded: an entity can see out of its own
    # occupied hex and can see a target standing in an opaque-terrain hex.
    for index in range(1, ray.size() - 1):
        var hex: Vector2i = ray[index]
        if not map_data.has_cell(hex):
            return false

        var cell: Dictionary = map_data.cells[hex]
        var terrain_id := map_data.terrain_id_at(hex)
        var line_height := lerpf(origin_eye, target_eye, float(index) / float(total_steps))
        var surface_height := map_data.elevation_at(hex)

        if bool(cell.get("blocks_vision", false)):
            var blocker_height := float(cell.get("vision_block_height", DEFAULT_OPAQUE_HEIGHT_M))
            if surface_height + blocker_height >= line_height:
                return false
        elif OPAQUE_TERRAIN_IDS.has(terrain_id):
            var wall_height := float(cell.get("vision_block_height", DEFAULT_OPAQUE_HEIGHT_M))
            if surface_height + wall_height >= line_height:
                return false
        elif surface_height > line_height:
            # A ridge/high hex can occlude sight without being a wall.
            return false

    return true


static func can_see(
    map_data: HexMapData,
    observer: CharacterState,
    target: CharacterState,
    indoors: bool = false,
    low_light: bool = false,
    target_illuminated: bool = false
) -> bool:
    if observer == null or target == null or not target.alive:
        return false
    var distance := HexGrid.distance(observer.axial, target.axial)
    if distance > vision_range(observer, indoors, low_light, target_illuminated):
        return false
    return has_line_of_sight(map_data, observer.axial, target.axial)


## Detection bonuses are kept separate from spatial visibility. A target can
## be in sight without being detected while hidden; AI policy will consume this.
static func stealth_detection_bonus(observer: CharacterState) -> int:
    if observer == null:
        return 0
    return 10 * _skill_rank(observer, "keen_perception")


static func stealth_check_bonus(target: CharacterState) -> int:
    if target == null:
        return 0
    return 5 * (
        _skill_rank(target, "inconspicuous")
        + _skill_rank(target, "shadow_weaver")
    )


static func _skill_rank(state: CharacterState, skill_id: String) -> int:
    var value: Variant = state.skills.get(skill_id, 0)
    if value is Dictionary:
        return maxi(0, int(value.get("rank", value.get("value", 0))))
    return maxi(0, int(value))


static func _hex_line(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
    var distance := HexGrid.distance(start, finish)
    var result: Array[Vector2i] = []
    if distance == 0:
        result.append(start)
        return result

    var start_cube := Vector3(float(start.x), float(-start.x - start.y), float(start.y))
    var finish_cube := Vector3(float(finish.x), float(-finish.x - finish.y), float(finish.y))
    for step in range(distance + 1):
        var t := float(step) / float(distance)
        var sample := start_cube.lerp(finish_cube, t)
        result.append(_cube_round(sample))
    return result


static func _cube_round(cube: Vector3) -> Vector2i:
    var q := roundi(cube.x)
    var r_cube := roundi(cube.z)
    var s := roundi(cube.y)
    var q_diff := absf(float(q) - cube.x)
    var r_diff := absf(float(r_cube) - cube.z)
    var s_diff := absf(float(s) - cube.y)

    if q_diff > r_diff and q_diff > s_diff:
        q = -r_cube - s
    elif r_diff > s_diff:
        r_cube = -q - s
    return Vector2i(q, r_cube)
