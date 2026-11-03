class_name HexGrid
extends RefCounted

# Flat-top axial coordinates. Radius is provisional and must be validated
# against character size, doors, furniture and combat during M1.
const DEFAULT_RADIUS_M: float = 1.25
const SQRT_3: float = 1.7320508075688772

const DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
]

static func axial_to_world(hex: Vector2i, radius: float = DEFAULT_RADIUS_M, elevation: float = 0.0) -> Vector3:
    var x: float = 1.5 * radius * float(hex.x)
    var z: float = SQRT_3 * radius * (float(hex.y) + float(hex.x) * 0.5)
    return Vector3(x, elevation, z)

static func world_to_axial(position: Vector3, radius: float = DEFAULT_RADIUS_M) -> Vector2i:
    var qf: float = (2.0 / 3.0 * position.x) / radius
    var rf: float = (-1.0 / 3.0 * position.x + SQRT_3 / 3.0 * position.z) / radius

    var cube_x: float = qf
    var cube_z: float = rf
    var cube_y: float = -cube_x - cube_z

    var rx: int = roundi(cube_x)
    var ry: int = roundi(cube_y)
    var rz: int = roundi(cube_z)

    var x_diff: float = absf(float(rx) - cube_x)
    var y_diff: float = absf(float(ry) - cube_y)
    var z_diff: float = absf(float(rz) - cube_z)

    if x_diff > y_diff and x_diff > z_diff:
        rx = -ry - rz
    elif y_diff > z_diff:
        ry = -rx - rz
    else:
        rz = -rx - ry

    return Vector2i(rx, rz)

static func neighbors(hex: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for direction in DIRECTIONS:
        result.append(hex + direction)
    return result

static func distance(a: Vector2i, b: Vector2i) -> int:
    var dq: int = a.x - b.x
    var dr: int = a.y - b.y
    return maxi(absi(dq), maxi(absi(dr), absi(dq + dr)))
