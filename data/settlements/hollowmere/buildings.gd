extends RefCounted

## Authored building footprints, entrances and construction parameters.

const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")

const FARMHOUSE := SETTLEMENT.FARMHOUSE

const FARM_BARN := SETTLEMENT.FARM_BARN

const FARMHOUSE_DOOR := SETTLEMENT.FARMHOUSE_DOOR

const FARM_BARN_DOOR := SETTLEMENT.FARM_BARN_DOOR



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
		"id": "hollowmere_guild_den", "node_name": "GuildDenExterior", "kind": "house",
		"center": Vector2i(-12, -8), "half_q": 2, "half_r": 2, "door": Vector2i(-12, -6),
		"dimensions": {"width": 5.5, "depth": 5.0, "wall_height": 2.5, "roof_rise": 1.35},
		"door_side": "south", "door_width": 0.95, "windows_per_side": 0,
		"rotation_degrees": 0.0
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
