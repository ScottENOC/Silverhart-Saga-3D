extends RefCounted

## Authored presentation routes. These do not define logical navigation occupancy.

const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")

const CROSSROADS := SETTLEMENT.CROSSROADS

const FARMHOUSE_DOOR := SETTLEMENT.FARMHOUSE_DOOR

const FARM_BARN_DOOR := SETTLEMENT.FARM_BARN_DOOR



const SOUTH_ROAD_CENTRELINE: Array[Vector2i] = [Vector2i(8, 24), Vector2i(9, 30), Vector2i(8, 36), Vector2i(10, 42), Vector2i(12, 48), Vector2i(12, 54), FARMHOUSE_DOOR]

const FARMYARD_CENTRELINE: Array[Vector2i] = [FARMHOUSE_DOOR, Vector2i(16, 56), Vector2i(19, 52), FARM_BARN_DOOR]

const PLAYER_COTTAGE_PLOT_CENTRELINE: Array[Vector2i] = [
	Vector2i(8, 24), Vector2i(9, 24), Vector2i(10, 24), Vector2i(11, 24),
	Vector2i(12, 24), Vector2i(13, 24), Vector2i(13, 25), Vector2i(13, 26),
	Vector2i(13, 27)
]

const PRESENTATION_ROUTES := [
	{"id": "VillageStream", "material": "water", "points": [Vector2i(-30,-22), Vector2i(-24,-24), Vector2i(-18,-22), Vector2i(-12,-24), Vector2i(-6,-27), Vector2i(0,-24), Vector2i(5,-24), Vector2i(8,-25), Vector2i(12,-27), Vector2i(18,-25), Vector2i(24,-28), Vector2i(30,-25)], "widths": [3.0,3.8,4.5,3.2,4.2,3.5,2.7,2.0,3.1,4.3,3.6,2.8], "elevation": -0.055, "samples_per_segment": 10},
	{"id": "StreamBanks", "material": "bank", "points": [Vector2i(-30,-22), Vector2i(-24,-24), Vector2i(-18,-22), Vector2i(-12,-24), Vector2i(-6,-27), Vector2i(0,-24), Vector2i(5,-24), Vector2i(8,-25), Vector2i(12,-27), Vector2i(18,-25), Vector2i(24,-28), Vector2i(30,-25)], "widths": [4.25,5.05,5.75,4.45,5.45,4.75,3.95,3.25,4.35,5.55,4.85,4.05], "elevation": -0.055, "y_offset": -0.035, "samples_per_segment": 10},
	{"id": "NorthSouthRoad", "material": "path", "points": [Vector2i(8,-40),Vector2i(9,-32),Vector2i(8,-25),Vector2i(7,-17),Vector2i(8,-9),Vector2i(7,-2),Vector2i(8,7),Vector2i(8,16),Vector2i(8,24),Vector2i(11,28),Vector2i(16,32),Vector2i(14,38),Vector2i(11,44),Vector2i(12,50),Vector2i(12,54),FARMHOUSE_DOOR], "widths": [2.5,2.8,2.6,2.4,2.5,2.8,2.5,2.6,3.1,2.8,2.4,2.6,2.4,2.6,2.8,2.5], "elevation": 0.025, "samples_per_segment": 8},
	{"id": "EastWestRoad", "material": "path", "points": [Vector2i(-40,24),Vector2i(-30,23),Vector2i(-20,25),Vector2i(-10,24),Vector2i(0,23),Vector2i(8,24),Vector2i(16,25),Vector2i(26,23),Vector2i(36,24)], "widths": [2.2,2.4,2.6,2.3,2.5,3.1,2.6,2.4,2.2], "elevation": 0.025, "samples_per_segment": 8},
	{"id": "TavernVillageLane", "material": "path", "points": [Vector2i(8,16),Vector2i(5,12),Vector2i(2,8),Vector2i(0,5),Vector2i(0,0),Vector2i(1,-5),Vector2i(8,-9)], "widths": [2.1,2.0,2.0,2.4,2.2,2.0,2.2], "elevation": 0.03, "samples_per_segment": 8},
	{"id": "TavernRingRoad", "material": "path", "points": [Vector2i(-8,-6),Vector2i(0,-6),Vector2i(8,-6),Vector2i(8,0),Vector2i(8,6),Vector2i(0,6),Vector2i(-8,6),Vector2i(-8,0),Vector2i(-8,-6)], "widths": [1.9,2.0,2.1,2.0,2.1,2.0,2.1,2.0,1.9], "elevation": 0.028, "samples_per_segment": 6},
	{"id": "StoreLane", "material": "path", "points": [Vector2i(0,6),Vector2i(0,10),Vector2i(0,15)], "widths": [1.8,1.7,1.6], "elevation": 0.032},
	{"id": "ChapelLane", "material": "path", "points": [Vector2i(-8,0),Vector2i(-10,0),Vector2i(-11,0)], "widths": [1.8,1.7,1.6], "elevation": 0.032},
	{"id": "ElderLane", "material": "path", "points": [Vector2i(0,-6),Vector2i(0,-8),Vector2i(0,-10)], "widths": [1.8,1.7,1.6], "elevation": 0.032},
	{"id": "MiraLane", "material": "path", "points": [Vector2i(8,6),Vector2i(9,8),Vector2i(10,9)], "widths": [1.8,1.7,1.6], "elevation": 0.032},
	{"id": "OskarLane", "material": "path", "points": [Vector2i(-4,6),Vector2i(-4,8),Vector2i(-4,9)], "widths": [1.8,1.7,1.6], "elevation": 0.032},
	{"id": "FarmyardLane", "material": "path", "points": FARMYARD_CENTRELINE, "widths": [2.2,2.0,2.0,2.0], "elevation": 0.035},
	{"id": "PlayerCottagePlotAccess", "material": "path", "points": PLAYER_COTTAGE_PLOT_CENTRELINE, "widths": [1.7,1.7,1.7,1.7,1.7,1.6,1.6,1.6,1.5], "elevation": 0.035}
]
