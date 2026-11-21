extends RefCounted

## Authored fields, crop rows and fence runs.



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
