extends SceneTree

func _initialize() -> void:
    _test_round_trip()
    _test_neighbors_and_distance()
    print("HexGrid tests passed.")
    quit()

func _test_round_trip() -> void:
    for q in range(-8, 9):
        for r in range(-8, 9):
            var hex := Vector2i(q, r)
            var world := HexGrid.axial_to_world(hex, 1.25)
            var actual := HexGrid.world_to_axial(world, 1.25)
            assert(actual == hex, "Axial round-trip failed for %s: got %s" % [hex, actual])

func _test_neighbors_and_distance() -> void:
    var origin := Vector2i(0, 0)
    var neighbors := HexGrid.neighbors(origin)
    assert(neighbors.size() == 6)
    for neighbor in neighbors:
        assert(HexGrid.distance(origin, neighbor) == 1)
