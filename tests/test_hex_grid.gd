extends SceneTree

var _failures: int = 0

const EPSILON: float = 0.0001

func _initialize() -> void:
    _test_round_trip()
    _test_neighbors_and_distance()
    _test_flat_top_tiling_geometry()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
        return
    print("HexGrid tests passed.")
    quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
    if not condition:
        _failures += 1
        push_error(message)

func _test_round_trip() -> void:
    for q in range(-8, 9):
        for r in range(-8, 9):
            var hex := Vector2i(q, r)
            var world := HexGrid.axial_to_world(hex, 1.25)
            var actual := HexGrid.world_to_axial(world, 1.25)
            _check(actual == hex, "Axial round-trip failed for %s: got %s" % [hex, actual])

func _test_neighbors_and_distance() -> void:
    var origin := Vector2i(0, 0)
    var neighbors := HexGrid.neighbors(origin)
    _check(neighbors.size() == 6)
    for neighbor in neighbors:
        _check(HexGrid.distance(origin, neighbor) == 1)

func _test_flat_top_tiling_geometry() -> void:
    var radius: float = HexGrid.DEFAULT_RADIUS_M
    var corners := HexGrid.corner_offsets(radius)
    _check(corners.size() == HexGrid.SIDE_COUNT)

    # Every corner must lie on the requested circumradius.
    for corner in corners:
        _check(absf(corner.length() - radius) < EPSILON,
            "Hex corner is not on the configured radius")

    # Each of the six neighbours must be exactly one apothem-to-apothem
    # centre spacing away and share two vertices with the origin hex.
    var origin_centre := HexGrid.axial_to_world(Vector2i.ZERO, radius)
    for neighbor in HexGrid.neighbors(Vector2i.ZERO):
        var neighbor_centre := HexGrid.axial_to_world(neighbor, radius)
        var expected_spacing: float = HexGrid.SQRT_3 * radius
        _check(absf(origin_centre.distance_to(neighbor_centre) - expected_spacing) < EPSILON,
            "Neighbour centre spacing does not match a regular hex")

        var shared_corner_count: int = 0
        for origin_corner in corners:
            var origin_world := origin_centre + Vector3(origin_corner.x, 0.0, origin_corner.y)
            for neighbor_corner in corners:
                var neighbor_world := neighbor_centre + Vector3(neighbor_corner.x, 0.0, neighbor_corner.y)
                if origin_world.distance_to(neighbor_world) < EPSILON:
                    shared_corner_count += 1
        _check(shared_corner_count == 2,
            "Adjacent flat-top hexes should share exactly two corners; found %d" % shared_corner_count)
