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
    assert(HollowmereVillageData.is_in_bounds(HollowmereVillageData.FARM_BARN), "The southern farm must be inside the expanded local map")
    assert(HollowmereVillageData.is_building(HollowmereVillageData.FARMHOUSE), "The farmhouse must occupy blocked building cells")
    assert(HollowmereVillageData.is_building(HollowmereVillageData.FARM_BARN), "The barn must occupy blocked building cells")
    assert(HollowmereVillageData.is_path(Vector2i(9, 27)), "The southern road must connect continuously beyond the crossroads")
    assert(HollowmereVillageData.is_path(Vector2i(11, 44)), "The southern road must reach the farm approach")
    assert(not HollowmereVillageData.is_forest_candidate(Vector2i(10, 60)), "Farm fields must remain clear of procedural forest placement")

    var cells := HollowmereVillageData.water_cells()
    assert(cells.size() > 61, "Variable-width river should occupy more than one straight row of hexes")
    var distinct_rows: Dictionary = {}
    for cell in cells:
        distinct_rows[cell.y] = true
    assert(distinct_rows.size() >= 5, "The river should visibly meander across multiple axial rows")