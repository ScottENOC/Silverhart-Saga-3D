extends SceneTree

func _initialize() -> void:
    _test_curved_river_cells()
    print("Organic Hollowmere geography tests passed.")
    quit()

func _test_curved_river_cells() -> void:
    assert(HollowmereVillageData.is_water(Vector2i(0, -25)), "The western river bend must retain water occupancy")
    assert(HollowmereVillageData.is_water(Vector2i(-6, -27)), "The southern meander must be represented in the logical map")
    assert(HollowmereVillageData.is_water(Vector2i(18, -25)), "The eastern bend must be represented in the logical map")
    assert(not HollowmereVillageData.is_water(HollowmereVillageData.BRIDGE), "The bridge cell must remain traversable")
    assert(not HollowmereVillageData.is_water(Vector2i(8, -24)), "The bridge crossing must be a narrow channel")
    assert(HollowmereVillageData.is_blocked(Vector2i(0, -25)), "River cells must block ordinary movement")
    assert(not HollowmereVillageData.is_blocked(HollowmereVillageData.BRIDGE), "The bridge must remain a legal crossing")

    var cells := HollowmereVillageData.water_cells()
    assert(cells.size() > 61, "Variable-width river should occupy more than one straight row of hexes")
    var distinct_rows: Dictionary = {}
    for cell in cells:
        distinct_rows[cell.y] = true
    assert(distinct_rows.size() >= 5, "The river should visibly meander across multiple axial rows")