extends RefCounted
## Complete authored presentation layout for the Hollow Tankard.
## This is data only; shared interior presentation code interprets the definitions.

const STRUCTURE = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_structure.gd")
const TAPROOM = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_taproom.gd")
const UPPER_ROOMS = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_upper_rooms.gd")

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
		"tile_thickness": 0.12,
		"room_half_width": 8.0,
		"room_half_depth": 5.5,
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
		"floor_y": 3.38,
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
