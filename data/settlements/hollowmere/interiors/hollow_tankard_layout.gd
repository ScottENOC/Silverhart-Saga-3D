extends RefCounted
## Complete authored presentation layout for the Hollow Tankard.
## This is data only; shared interior presentation code interprets the definitions.

const STRUCTURE = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_structure.gd")
const TAPROOM = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_taproom.gd")
const UPPER_ROOMS = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_upper_rooms.gd")
const TERRAIN_DEFINITION = preload("res://data/settlements/hollowmere/terrain.gd")
const TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")

const TILE_THICKNESS := 0.12
const ROOM_HALF_WIDTH := 8.0
const ROOM_HALF_DEPTH := 5.5
const UPPER_FLOOR_Y := 3.38


const BUILDING_ID := "hollow_tankard"
const FRONT_DOOR_ID := "hollow_tankard_front_door"
const DOOR_HEX := Vector2i(0, 3)
const UPPER_FLOOR_ORIGIN := Vector2i(100, 100)
const STAIR_GROUND_HEX := Vector2i(3, 0)
const STAIR_UPPER_HEX := UPPER_FLOOR_ORIGIN + Vector2i(3, -1)
const UPPER_BED_HEXES: Array[Vector2i] = [
	Vector2i(-3, 0), Vector2i(-3, 2),
	Vector2i(2, -2), Vector2i(3, -2),
	Vector2i(2, 0), Vector2i(3, 0)
]

const LOGICAL_DEFINITION := {
	"ground_overlay": {
		"query_script": TERRAIN_PROVIDER,
		"query_context": TERRAIN_DEFINITION.DEFINITION,
		"in_bounds_method": "is_in_bounds",
		"blocked_method": "is_blocked",
		"map_radius": 96,
		"room_half_width": ROOM_HALF_WIDTH,
		"room_half_depth": ROOM_HALF_DEPTH,
		"wall_blockers": [
			{"x_min": -9.1, "x_max": -6.9, "z_min": -5.5, "z_max": 5.5},
			{"x_min": 6.9, "x_max": 9.1, "z_min": -5.5, "z_max": 5.5},
			{"x_min": -INF, "x_max": INF, "z_min": -6.6, "z_max": -4.4},
			{"x_min": -INF, "x_max": -1.1, "z_min": 4.4, "z_max": 6.6},
			{"x_min": 1.1, "x_max": INF, "z_min": 4.4, "z_max": 6.6}
		],
		"furniture_blockers": [
			{"x_min": -1.2, "x_max": 6.2, "z_min": -5.5, "z_max": -4.0},
			{"x_min": -8.0, "x_max": -6.0, "z_min": -3.8, "z_max": 1.5},
			{"x_min": -4.0, "x_max": -1.2, "z_min": -0.95, "z_max": 0.95},
			{"x_min": 1.2, "x_max": 4.0, "z_min": -0.95, "z_max": 0.95},
			{"x_min": -4.0, "x_max": -1.2, "z_min": -2.0, "z_max": -1.0},
			{"x_min": 1.2, "x_max": 4.0, "z_min": -2.0, "z_max": -1.0},
			{"x_min": -4.0, "x_max": -1.2, "z_min": 1.0, "z_max": 2.0},
			{"x_min": 1.2, "x_max": 4.0, "z_min": 1.0, "z_max": 2.0}
		]
	},
	"upper_floor": {
		"origin": UPPER_FLOOR_ORIGIN,
		"q_min": -4,
		"q_max": 4,
		"row_min": -2,
		"row_max": 2,
		"elevation": UPPER_FLOOR_Y,
		"terrain_id": "timber_floor",
		"blocked_hexes": UPPER_BED_HEXES,
		"partition_rules": [
			{"q_min": 0, "q_max": 0, "z_abs_min": 1.1},
			{"q_min": 1, "q_max": 4, "z_abs_max": 0.55, "exclude_q": [3]}
		]
	},
	"building": {
		"id": BUILDING_ID,
		"name": "The Hollow Tankard",
		"entrance_hex": DOOR_HEX,
		"floor_count": 2,
		"lodging_capacity": 8,
		"sleeping_beds": 6,
		"virtual_floor_bounds": [96, 104, 96, 104],
		"source_location": "campaign2World.js: Hollow Tankard; hollowmereSocialFabric.js: buildTankardUpperFloor",
		"source_stair_hex": STAIR_GROUND_HEX,
		"upper_landing_hex": STAIR_UPPER_HEX
	},
	"door": {
		"id": FRONT_DOOR_ID,
		"building_id": BUILDING_ID,
		"hex": DOOR_HEX,
		"starts_open": true,
		"starts_locked": false,
		"durability": 20
	}
}

const DEFINITION := {
	"ground": {
		"name": "HollowTankardGround",
		"size": Vector2(34.0, 30.0),
		"y": -0.18,
		"material": "grass"
	},
	"hex_floor": {
		"q_min": -7,
		"q_max": 7,
		"r_min": -7,
		"r_max": 7,
		"tile_thickness": TILE_THICKNESS,
		"room_half_width": ROOM_HALF_WIDTH,
		"room_half_depth": ROOM_HALF_DEPTH,
		"inside_y": 0.06,
		"outside_y": -0.07,
		"walkable_material": "grass",
		"interior_material": "floor",
		"blocked_material": "blocked"
	},
	"building_shell": STRUCTURE.BUILDING_SHELL,
	"upper_exterior": STRUCTURE.UPPER_EXTERIOR,
	"upper_floor": STRUCTURE.UPPER_FLOOR,
	"roof": STRUCTURE.ROOF,
	"taproom": TAPROOM.DEFINITION,
	"upper_rooms": UPPER_ROOMS.DEFINITION,
	"upper_floor_tiles": {
		"q_min": -4,
		"q_max": 4,
		"row_min": -2,
		"row_max": 2,
		"floor_y": UPPER_FLOOR_Y,
		"material": "floor"
	},
	"beds": UPPER_ROOMS.BEDS,
	"door": {
		"parent": "HollowTankardBuilding",
		"pivot_name": "FrontDoorHinge",
		"pivot_position": Vector3(-0.8, 0.0, 5.5),
		"leaf_name": "FrontDoorLeaf",
		"leaf_position": Vector3(0.65, 1.25, 0.0),
		"leaf_size": Vector3(1.3, 2.5, 0.16),
		"leaf_material": "dark_wood"
	}
}
