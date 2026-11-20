class_name HollowmereVillageData
extends RefCounted
## Shared local-map layout for Hollowmere. Axial coordinates match the tavern grid.

const MAP_RADIUS: int = 96
const STREAM_R: int = -25
const STREAM_Q_MIN: int = -30
const STREAM_Q_MAX: int = 30
const CROSSROADS := Vector2i(8, 24)
const BRIDGE := Vector2i(8, STREAM_R)
const BRIDGE_PRESENTATION := {
	"id": "NarrowRiverBridge",
	"centre": BRIDGE,
	"rotation_degrees": -5.0,
	"parts": [
		{"name": "StreamBridgeDeck", "position": Vector3(0.0, 0.18, 0.0), "size": Vector3(2.8, 0.24, 4.8), "material": "timber"},
		{"name": "BridgeRail_Left", "position": Vector3(-1.22, 0.62, 0.0), "size": Vector3(0.16, 0.72, 4.6), "material": "dark_wood"},
		{"name": "BridgeRail_Right", "position": Vector3(1.22, 0.62, 0.0), "size": Vector3(0.16, 0.72, 4.6), "material": "dark_wood"},
		{"name": "BridgePost_Left_North", "position": Vector3(-1.22, 0.55, -2.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Left_Centre", "position": Vector3(-1.22, 0.55, 0.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Left_South", "position": Vector3(-1.22, 0.55, 2.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Right_North", "position": Vector3(1.22, 0.55, -2.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Right_Centre", "position": Vector3(1.22, 0.55, 0.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Right_South", "position": Vector3(1.22, 0.55, 2.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"}
	]
}
const FARMHOUSE := Vector2i(12, 54)
const FARM_BARN := Vector2i(22, 51)
const FARMHOUSE_DOOR := Vector2i(12, 57)
const FARM_BARN_DOOR := Vector2i(22, 49)
const SOUTH_ROAD_CENTRELINE: Array[Vector2i] = [Vector2i(8, 24), Vector2i(9, 30), Vector2i(8, 36), Vector2i(10, 42), Vector2i(12, 48), Vector2i(12, 54), FARMHOUSE_DOOR]
const FARMYARD_CENTRELINE: Array[Vector2i] = [FARMHOUSE_DOOR, Vector2i(16, 56), Vector2i(19, 52), FARM_BARN_DOOR]

const LANDMARK_PROPS := [
	{
		"id": "StoreSignPresentation", "parent_node": "GeneralStore",
		"parts": [
			{"name": "StoreSignBoard", "type": "box", "position": Vector3(0.0, 2.75, -3.45), "size": Vector3(3.3, 0.55, 0.16), "material": "dark_wood"},
			{"name": "StoreSign", "type": "label3d", "text": "GENERAL STORE", "position": Vector3(0.0, 2.62, -3.56), "font_size": 34, "pixel_size": 0.006, "modulate": Color(0.91, 0.82, 0.63), "outline_size": 5}
		]
	},
	{
		"id": "ChapelBellTowerPresentation", "parent_node": "Chapel",
		"parts": [
			{"name": "BellTower", "type": "box", "position": Vector3(0.0, 4.2, -1.4), "size": Vector3(1.45, 2.1, 1.45), "material": "stone"},
			{"name": "BellOpening", "type": "box", "position": Vector3(0.0, 4.35, -0.64), "size": Vector3(0.72, 0.62, 0.08), "material": "dark_wood"},
			{"name": "ChapelCrossStem", "type": "box", "position": Vector3(0.0, 5.75, -1.4), "size": Vector3(0.14, 1.0, 0.14), "material": "timber"},
			{"name": "ChapelCrossBar", "type": "box", "position": Vector3(0.0, 5.85, -1.4), "size": Vector3(0.65, 0.14, 0.14), "material": "timber"}
		]
	}
]

const QUEST_PROPS := [
	{
		"id": "BrokenPastureFence", "anchor": Vector2i(1, 67), "elevation": 0.04,
		"parts": [
			{"name": "BrokenRailA", "type": "box", "position": Vector3(-0.55, 0.32, -0.25), "size": Vector3(1.3, 0.10, 0.12), "rotation_degrees": -24.0, "material": "fence"},
			{"name": "BrokenRailB", "type": "box", "position": Vector3(0.55, 0.22, 0.22), "size": Vector3(1.0, 0.10, 0.12), "rotation_degrees": 18.0, "material": "dark_wood"}
		]
	},
	{
		"id": "BloodTrailPresentation", "anchor": Vector2i(1, 67), "elevation": 0.015,
		"parts": [
			{"name": "BloodTrail_00", "type": "cylinder", "axial": Vector2i(1, 67), "position": Vector3.ZERO, "top_radius": 0.13, "bottom_radius": 0.13, "height": 0.018, "radial_segments": 7, "material": "blood"},
			{"name": "BloodTrail_01", "type": "cylinder", "axial": Vector2i(-4, 68), "position": Vector3.ZERO, "top_radius": 0.13, "bottom_radius": 0.13, "height": 0.018, "radial_segments": 7, "material": "blood"},
			{"name": "BloodTrail_02", "type": "cylinder", "axial": Vector2i(-10, 69), "position": Vector3.ZERO, "top_radius": 0.13, "bottom_radius": 0.13, "height": 0.018, "radial_segments": 7, "material": "blood"},
			{"name": "BloodTrail_03", "type": "cylinder", "axial": Vector2i(-17, 70), "position": Vector3.ZERO, "top_radius": 0.075, "bottom_radius": 0.075, "height": 0.018, "radial_segments": 7, "material": "blood"},
			{"name": "BloodTrail_04", "type": "cylinder", "axial": Vector2i(-24, 71), "position": Vector3.ZERO, "top_radius": 0.075, "bottom_radius": 0.075, "height": 0.018, "radial_segments": 7, "material": "blood"},
			{"name": "BloodTrail_05", "type": "cylinder", "axial": Vector2i(-31, 72), "position": Vector3.ZERO, "top_radius": 0.075, "bottom_radius": 0.075, "height": 0.018, "radial_segments": 7, "material": "blood"},
			{"name": "BloodTrail_06", "type": "cylinder", "axial": Vector2i(-38, 73), "position": Vector3.ZERO, "top_radius": 0.075, "bottom_radius": 0.075, "height": 0.018, "radial_segments": 7, "material": "blood"}
		]
	}
]

const WAYFINDING_PROPS := [
	{
		"id": "CrossroadsSignpost", "anchor": CROSSROADS,
		"parts": [
			{"name": "SignpostStem", "type": "cylinder", "position": Vector3(0.0, 1.3, 0.0), "top_radius": 0.10, "bottom_radius": 0.15, "height": 2.6, "material": "timber"},
			{"name": "SignboardNorth", "type": "box", "position": Vector3(0.0, 2.0, -0.05), "size": Vector3(4.2, 0.78, 0.14), "material": "dark_wood"},
			{"name": "SignboardSouth", "type": "box", "position": Vector3(0.0, 1.05, -0.05), "size": Vector3(4.2, 0.78, 0.14), "material": "dark_wood"},
			{"name": "NorthSouthLabel", "type": "label3d", "text": "N  MILLBROOK  /  SILVERHART\nS  OLD MAC'S FARMSTEAD", "position": Vector3(0.0, 2.0, -0.14), "font_size": 17, "pixel_size": 0.004, "modulate": Color(0.91, 0.82, 0.63), "outline_size": 4},
			{"name": "EastWestLabel", "type": "label3d", "text": "E  REDDALE  /  W  EMBERLODE", "position": Vector3(0.0, 1.05, -0.14), "font_size": 17, "pixel_size": 0.004, "modulate": Color(0.91, 0.82, 0.63), "outline_size": 4}
		]
	}
]

const FARM_FIELDS := [
	{"id": "NorthwestField", "corners": [Vector2i(0, 42), Vector2i(13, 40), Vector2i(19, 52), Vector2i(4, 58)], "material": "field", "elevation": -0.16},
	{"id": "EasternCropField", "corners": [Vector2i(19, 42), Vector2i(34, 40), Vector2i(38, 55), Vector2i(23, 60)], "material": "field", "elevation": -0.16},
	{"id": "SouthernPasture", "corners": [Vector2i(1, 61), Vector2i(15, 62), Vector2i(17, 74), Vector2i(2, 73)], "material": "pasture", "elevation": -0.16}
]
const FARM_CROP_ROWS := [
	{"id": "CropRowNorthwest0", "points": [Vector2i(3, 43), Vector2i(12, 53)], "midpoint_offset": Vector3(0.0, 0.0, 0.8), "widths": [0.16, 0.20, 0.16], "material": "crop"},
	{"id": "CropRowNorthwest1", "points": [Vector2i(4, 43), Vector2i(13, 53)], "midpoint_offset": Vector3(0.0, 0.0, 0.8), "widths": [0.16, 0.20, 0.16], "material": "crop"},
	{"id": "CropRowNorthwest2", "points": [Vector2i(5, 43), Vector2i(14, 53)], "midpoint_offset": Vector3(0.0, 0.0, 0.8), "widths": [0.16, 0.20, 0.16], "material": "crop"},
	{"id": "CropRowNorthwest3", "points": [Vector2i(6, 43), Vector2i(15, 53)], "midpoint_offset": Vector3(0.0, 0.0, 0.8), "widths": [0.16, 0.20, 0.16], "material": "crop"},
	{"id": "CropRowNorthwest4", "points": [Vector2i(7, 43), Vector2i(16, 53)], "midpoint_offset": Vector3(0.0, 0.0, 0.8), "widths": [0.16, 0.20, 0.16], "material": "crop"},
	{"id": "CropRowNorthwest5", "points": [Vector2i(8, 43), Vector2i(17, 53)], "midpoint_offset": Vector3(0.0, 0.0, 0.8), "widths": [0.16, 0.20, 0.16], "material": "crop"},
	{"id": "CropRowNorthwest6", "points": [Vector2i(9, 43), Vector2i(18, 53)], "midpoint_offset": Vector3(0.0, 0.0, 0.8), "widths": [0.16, 0.20, 0.16], "material": "crop"},
	{"id": "CropRowNorthwest7", "points": [Vector2i(10, 43), Vector2i(19, 53)], "midpoint_offset": Vector3(0.0, 0.0, 0.8), "widths": [0.16, 0.20, 0.16], "material": "crop"},
	{"id": "CropRowEast0", "points": [Vector2i(22, 43), Vector2i(21, 57)], "widths": [0.16, 0.16], "material": "crop"},
	{"id": "CropRowEast1", "points": [Vector2i(23, 43), Vector2i(22, 57)], "widths": [0.16, 0.16], "material": "crop"},
	{"id": "CropRowEast2", "points": [Vector2i(24, 43), Vector2i(23, 57)], "widths": [0.16, 0.16], "material": "crop"},
	{"id": "CropRowEast3", "points": [Vector2i(25, 43), Vector2i(24, 57)], "widths": [0.16, 0.16], "material": "crop"},
	{"id": "CropRowEast4", "points": [Vector2i(26, 43), Vector2i(25, 57)], "widths": [0.16, 0.16], "material": "crop"},
	{"id": "CropRowEast5", "points": [Vector2i(27, 43), Vector2i(26, 57)], "widths": [0.16, 0.16], "material": "crop"},
	{"id": "CropRowEast6", "points": [Vector2i(28, 43), Vector2i(27, 57)], "widths": [0.16, 0.16], "material": "crop"},
	{"id": "CropRowEast7", "points": [Vector2i(29, 43), Vector2i(28, 57)], "widths": [0.16, 0.16], "material": "crop"},
	{"id": "CropRowEast8", "points": [Vector2i(30, 43), Vector2i(29, 57)], "widths": [0.16, 0.16], "material": "crop"}
]
const FARM_FENCES := [
	{"id": "FarmyardFence", "points": [Vector2i(5, 50), Vector2i(8, 47), Vector2i(18, 47), Vector2i(26, 51), Vector2i(24, 59), Vector2i(15, 61), Vector2i(7, 58), Vector2i(5, 50)], "material": "fence"},
	{"id": "PastureFence", "points": [Vector2i(1, 61), Vector2i(15, 62), Vector2i(17, 74), Vector2i(2, 73), Vector2i(1, 61)], "material": "fence"}
]


const BUILDINGS := [
	{
		"id": "general_store", "node_name": "GeneralStore", "kind": "shop",
		"center": Vector2i(0, 18), "half_q": 3, "half_r": 2, "door": Vector2i(0, 15),
		"dimensions": {"width": 8.5, "depth": 6.5, "wall_height": 2.9, "roof_rise": 1.8},
		"door_side": "north", "door_width": 1.15, "windows_per_side": 1,
		"rotation_degrees": 0.0, "features": ["fireplace"]
	},
	{
		"id": "chapel", "node_name": "Chapel", "kind": "chapel",
		"center": Vector2i(-14, 0), "half_q": 2, "half_r": 3, "door": Vector2i(-11, 0),
		"dimensions": {"width": 6.8, "depth": 7.2, "wall_height": 3.2, "roof_rise": 2.0},
		"door_side": "east", "door_width": 1.15, "windows_per_side": 1,
		"rotation_degrees": 0.0
	},
	{
		"id": "elder_house", "node_name": "EldersHouse", "kind": "house",
		"center": Vector2i(0, -12), "half_q": 2, "half_r": 2, "door": Vector2i(0, -10),
		"dimensions": {"width": 6.0, "depth": 5.4, "wall_height": 2.65, "roof_rise": 1.55},
		"door_side": "south", "door_width": 1.15, "windows_per_side": 1,
		"rotation_degrees": 0.0, "features": ["fireplace"]
	},
	{
		"id": "mira_house", "node_name": "MiraHouse", "kind": "house",
		"center": Vector2i(12, 9), "half_q": 2, "half_r": 2, "door": Vector2i(10, 9),
		"dimensions": {"width": 5.5, "depth": 5.0, "wall_height": 2.5, "roof_rise": 1.45},
		"door_side": "west", "door_width": 1.15, "windows_per_side": 1,
		"rotation_degrees": 0.0, "features": ["fireplace"]
	},
	{
		"id": "oskar_house", "node_name": "OskarHouse", "kind": "house",
		"center": Vector2i(-6, 9), "half_q": 2, "half_r": 2, "door": Vector2i(-4, 9),
		"dimensions": {"width": 5.5, "depth": 5.0, "wall_height": 2.5, "roof_rise": 1.45},
		"door_side": "east", "door_width": 1.15, "windows_per_side": 1,
		"rotation_degrees": 0.0, "features": ["fireplace"]
	},
	{
		"id": "old_mac_farmhouse", "node_name": "OldMacFarmhouse", "kind": "house",
		"center": FARMHOUSE, "half_q": 3, "half_r": 2, "door": FARMHOUSE_DOOR,
		"dimensions": {"width": 8.0, "depth": 6.4, "wall_height": 2.9, "roof_rise": 1.8},
		"door_side": "south", "door_width": 1.15, "windows_per_side": 1,
		"rotation_degrees": 0.0, "features": ["fireplace"]
	},
	{
		"id": "old_mac_barn", "node_name": "OldMacBarn", "kind": "barn",
		"center": FARM_BARN, "half_q": 4, "half_r": 3, "door": FARM_BARN_DOOR,
		"dimensions": {"width": 13.0, "depth": 9.0, "wall_height": 4.0, "roof_rise": 1.7},
		"door_side": "north", "door_width": 3.1, "windows_per_side": 0,
		"rotation_degrees": 0.0, "features": ["double_door"],
		"materials": {"wall_colour": "#8c6846", "timber_colour": "#54351f", "door_colour": "#382719", "roof_colour": "#48443a", "foundation_colour": "#716b5c", "floor_colour": "#493323"}
	}
]


## Visible route geometry is authored separately from logical path occupancy.
## Widths are metres and points are axial coordinates; no movement data is derived here.
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
	{"id": "FarmyardLane", "material": "path", "points": FARMYARD_CENTRELINE, "widths": [2.2,2.0,2.0,2.0], "elevation": 0.035}
]

static func is_in_bounds(hex: Vector2i) -> bool:
	return HexGrid.distance(Vector2i.ZERO, hex) <= MAP_RADIUS

static func is_water(hex: Vector2i) -> bool:
	if hex.x < STREAM_Q_MIN or hex.x > STREAM_Q_MAX or hex == BRIDGE:
		return false
	var centre_r := _river_centre_r(hex.x)
	var half_width := _river_half_width(hex.x)
	return absf(float(hex.y) - centre_r) <= half_width

static func _river_centre_r(q: int) -> float:
	var samples: Array[Vector2i] = [
		Vector2i(-30, -22), Vector2i(-24, -24), Vector2i(-18, -22),
		Vector2i(-12, -24), Vector2i(-6, -27), Vector2i(0, -24),
		Vector2i(5, -24), Vector2i(8, -25), Vector2i(12, -27),
		Vector2i(18, -25), Vector2i(24, -28), Vector2i(30, -25)
	]
	for index in range(samples.size() - 1):
		if q <= samples[index + 1].x:
			var t := inverse_lerp(float(samples[index].x), float(samples[index + 1].x), float(q))
			return lerpf(float(samples[index].y), float(samples[index + 1].y), t)
	return float(samples[samples.size() - 1].y)

static func _river_half_width(q: int) -> float:
	var q_samples := PackedInt32Array([-30, -24, -18, -12, -6, 0, 5, 8, 12, 18, 24, 30])
	var width_samples := PackedFloat32Array([1.0, 1.5, 1.8, 1.4, 1.8, 1.5, 1.1, 0.65, 1.4, 1.8, 1.5, 1.0])
	for index in range(q_samples.size() - 1):
		if q <= q_samples[index + 1]:
			var t := inverse_lerp(float(q_samples[index]), float(q_samples[index + 1]), float(q))
			return lerpf(width_samples[index], width_samples[index + 1], t)
	return (width_samples[width_samples.size() - 1])

static func is_building(hex: Vector2i) -> bool:
	for building in BUILDINGS:
		var centre: Vector2i = building["center"]
		if absi(hex.x - centre.x) <= int(building["half_q"]) and absi(hex.y - centre.y) <= int(building["half_r"]):
			return true
	return false

static func is_door(hex: Vector2i) -> bool:
	return hex == Vector2i(0, 15) or hex == Vector2i(-11, 0) or hex == Vector2i(0, -10) or hex == Vector2i(10, 9) or hex == Vector2i(-4, 9) or hex == FARMHOUSE_DOOR or hex == FARM_BARN_DOOR

static func is_blocked(hex: Vector2i) -> bool:
	if not is_in_bounds(hex):
		return true
	if is_door(hex):
		return false
	if is_water(hex) or is_building(hex) or has_tree(hex):
		return true
	return false

static func terrain_id_at(hex: Vector2i) -> String:
	if is_water(hex):
		return "water"
	if is_path(hex):
		return "path"
	if is_building(hex):
		return "building"
	if has_tree(hex):
		return "forest"
	return "grass"

static func is_path(hex: Vector2i) -> bool:
	if hex == BRIDGE:
		return true
	# Maintained ring road around the Hollow Tankard.
	if hex.y == -6 and hex.x >= -8 and hex.x <= 8:
		return true
	if hex.y == 6 and hex.x >= -8 and hex.x <= 8:
		return true
	if hex.x == -8 and hex.y >= -6 and hex.y <= 6:
		return true
	if hex.x == 8 and hex.y >= -6 and hex.y <= 6:
		return true

	# Door spurs: tavern, elder's house, store, chapel and two village homes.
	if hex == Vector2i(0, 15) or hex == Vector2i(-11, 0) or hex == Vector2i(0, -10) or hex == Vector2i(10, 9) or hex == Vector2i(-4, 9):
		return true
	if hex == Vector2i(0, 5):
		return true
	if hex.x == 0 and hex.y >= -9 and hex.y <= -7:
		return true
	if hex == Vector2i(1, 13) or hex == Vector2i(1, 14):
		return true
	if hex.x == 0 and hex.y >= 7 and hex.y <= 13:
		return true
	if hex.x == -10 and hex.y == 0 or hex.x == -9 and hex.y == 0:
		return true
	if hex == Vector2i(9, 9):
		return true
	if hex.x >= -3 and hex.x <= -1 and hex.y == 9:
		return true

	# North-south road, bridge and the signposted crossroads.
	if hex.x == CROSSROADS.x and hex.y >= -40 and hex.y <= 32:
		return true
	if hex == CROSSROADS:
		return true

	# Short visible sections of the east-west roads leaving the crossroads.
	if hex.y == CROSSROADS.y and hex.x >= -40 and hex.x <= 16:
		return true

	# Winding southern road to Old Mac's Farmstead.
	for route in [SOUTH_ROAD_CENTRELINE, FARMYARD_CENTRELINE]:
		for index in range(route.size() - 1):
			if _is_near_axial_segment(hex, route[index], route[index + 1], 1):
				return true
	return false

static func _is_near_axial_segment(hex: Vector2i, start: Vector2i, finish: Vector2i, tolerance: int) -> bool:
	var steps := maxi(1, HexGrid.distance(start, finish) * 2)
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var sample := Vector2i(roundi(lerpf(float(start.x), float(finish.x), t)), roundi(lerpf(float(start.y), float(finish.y), t)))
		if HexGrid.distance(hex, sample) <= tolerance:
			return true
	return false

static func path_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}
	for q in range(-8, 9):
		_append_unique(cells, seen, Vector2i(q, -6))
		_append_unique(cells, seen, Vector2i(q, 6))
	for r in range(-6, 7):
		_append_unique(cells, seen, Vector2i(-8, r))
		_append_unique(cells, seen, Vector2i(8, r))
	for r in range(-9, -6):
		_append_unique(cells, seen, Vector2i(0, r))
	for r in range(7, 14):
		_append_unique(cells, seen, Vector2i(0, r))
	_append_unique(cells, seen, Vector2i(0, 5))
	_append_unique(cells, seen, Vector2i(0, 15))
	_append_unique(cells, seen, Vector2i(1, 13))
	_append_unique(cells, seen, Vector2i(1, 14))
	_append_unique(cells, seen, Vector2i(-11, 0))
	_append_unique(cells, seen, Vector2i(-10, 0))
	_append_unique(cells, seen, Vector2i(-9, 0))
	_append_unique(cells, seen, Vector2i(10, 9))
	_append_unique(cells, seen, Vector2i(9, 9))
	for q in range(-4, 0):
		_append_unique(cells, seen, Vector2i(q, 9))
	for r in range(-40, 33):
		_append_unique(cells, seen, Vector2i(CROSSROADS.x, r))
	_append_unique(cells, seen, BRIDGE)
	for q in range(-40, 17):
		_append_unique(cells, seen, Vector2i(q, CROSSROADS.y))
	# Include the curved farm road and its walkable verge in the local route data.
	for q in range(2, 31):
		for r in range(22, 61):
			var hex := Vector2i(q, r)
			if is_path(hex):
				_append_unique(cells, seen, hex)
	return cells

static func water_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for q in range(STREAM_Q_MIN, STREAM_Q_MAX + 1):
		var centre_r := _river_centre_r(q)
		var half_width := _river_half_width(q)
		for r in range(floori(centre_r - half_width), ceili(centre_r + half_width) + 1):
			var hex := Vector2i(q, r)
			if is_water(hex):
				cells.append(hex)
	return cells

static func is_farm_land(hex: Vector2i) -> bool:
	return hex.x >= -2 and hex.x <= 40 and hex.y >= 39 and hex.y <= 76

static func is_forest_candidate(hex: Vector2i) -> bool:
	if not is_in_bounds(hex):
		return false
	if is_farm_land(hex):
		return false
	if HexGrid.distance(Vector2i.ZERO, hex) < 17:
		return false
	if is_water(hex) or is_building(hex) or is_path(hex):
		return false
	return _stable_noise(hex.x, hex.y) > 0.18

static func has_tree(hex: Vector2i) -> bool:
	if posmod(hex.x, 4) != 0 or posmod(hex.y, 4) != 0:
		return false
	if not is_forest_candidate(hex):
		return false
	return _stable_noise(hex.x + 17, hex.y - 9) >= 0.56

static func _append_unique(cells: Array[Vector2i], seen: Dictionary, hex: Vector2i) -> void:
	if seen.has(hex):
		return
	seen[hex] = true
	cells.append(hex)

static func _stable_noise(q: int, r: int) -> float:
	var value: int = posmod(q * 92837111 + r * 689287499 + 1013904223, 2147483647)
	return float(value) / 2147483647.0
