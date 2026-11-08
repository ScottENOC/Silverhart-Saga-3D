class_name MainCampaignWorldMapData
extends RefCounted
## Strategic 16x16 map translated from Hex-crpg/worldMap.js Campaign 2.
## Local settlement maps remain separate, detailed axial hex maps.

const WORLD_SIZE: int = 16
const WORLD_HEX_SIZE: int = 130
const HOLLOWMERE_ORIGIN := Vector2i(6, 6) # (column, row)

# The river path is copied from the original Campaign 2 worldMap.js.
const RIVER_PATH: Array[Vector2i] = [
    Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5),
    Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5),
    Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 6), Vector2i(12, 6),
    Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 4)
]

# These are the opening-region locations whose world-map positions are
# explicit in the original Campaign 2 layout/comments. More distant POIs
# should be added by converting their actual local axial coordinates with
# world_cell_from_local_hex(), never by eyeballing the map.
const LOCATIONS: Array[Dictionary] = [
    {"id": "silverhart", "name": "Silverhart", "short": "K", "kind": "capital", "cell": Vector2i(6, 2)},
    {"id": "millbrook", "name": "Millbrook", "short": "V", "kind": "village", "cell": Vector2i(6, 3)},
    {"id": "emberlode", "name": "Emberlode", "short": "V", "kind": "village", "cell": Vector2i(4, 6)},
    {"id": "hollowmere", "name": "Hollowmere", "short": "V", "kind": "starting_village", "cell": Vector2i(6, 6)},
    {"id": "reddale", "name": "Reddale", "short": "T", "kind": "town", "cell": Vector2i(7, 6)},
    {"id": "old_mac_farmstead", "name": "Old Mac's Farmstead", "short": "F", "kind": "farmstead", "cell": Vector2i(6, 7)}
]

static func world_cell_from_local_hex(local_hex: Vector2i) -> Vector2i:
    # Return Vector2i(column, row), matching campaign2World.js's
    # worldMapCellFromLocalHex() and the 16x16 world map's odd-q layout.
    var column := HOLLOWMERE_ORIGIN.x + roundi(float(local_hex.x - 8) / float(WORLD_HEX_SIZE))
    var row := HOLLOWMERE_ORIGIN.y + roundi(float(local_hex.y - 24) / float(WORLD_HEX_SIZE))
    return Vector2i(column, row)

static func generate_grid() -> Array:
    var grid: Array = []
    for row in range(WORLD_SIZE):
        var cells: Array = []
        for column in range(WORLD_SIZE):
            var is_ocean := column < 2
            var is_orc_lands := column >= 10
            var is_mountain_range := column >= 12 and row < 5
            var is_forest := not is_ocean and column <= 9 and row >= 12
            var rough := _pseudo_random(float(column) * 2.3 + 5.0, float(row) * 1.7 + 3.0)

            var terrain := "grass"
            if is_ocean:
                terrain = "ocean"
            elif is_mountain_range:
                terrain = "mountain"
            elif is_forest:
                terrain = "forest"
            elif is_orc_lands and rough > 0.8:
                terrain = "mountain"
            elif is_orc_lands and rough > 0.6:
                terrain = "hills"

            var faction := ""
            if not is_ocean:
                if is_mountain_range:
                    faction = "dwarves"
                elif is_forest:
                    faction = "elves"
                elif is_orc_lands:
                    faction = "orcs"
                else:
                    faction = "humans"

            # The original map deliberately trades four border cells each
            # way so the dwarves and orcs meet in the north-east.
            if column >= 10 and column <= 11 and row <= 1:
                faction = "dwarves"
            if column >= 12 and column <= 15 and row == 4:
                faction = "orcs"

            cells.append({
                "terrain": terrain,
                "faction": faction,
                "poi": {}
            })
        grid.append(cells)

    for location in LOCATIONS:
        var cell: Vector2i = location["cell"]
        if cell.x >= 0 and cell.x < WORLD_SIZE and cell.y >= 0 and cell.y < WORLD_SIZE:
            grid[cell.y][cell.x]["poi"] = location.duplicate(true)
    return grid

static func location_at(cell: Vector2i) -> Dictionary:
    for location in LOCATIONS:
        if location["cell"] == cell:
            return location.duplicate(true)
    return {}

static func _pseudo_random(x: float, y: float) -> float:
    # Same deterministic hash used by the original browser game.
    var value := sin(x * 12.9898 + y * 78.233) * 43758.5453
    return value - floorf(value)
