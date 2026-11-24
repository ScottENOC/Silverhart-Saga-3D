extends RefCounted

## Landmark, quest-dressing and wayfinding prop assemblies.

const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")

const CROSSROADS := SETTLEMENT.CROSSROADS



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
	},
	{
		## The source building_plot marker at (13,27) is represented as a
		## surveyed plot assembly; its access spur remains a separate route.
		"id": "PlayerCottagePlotMarker", "anchor": Vector2i(13, 27),
		"parts": [
			{"name": "PlotSignPost", "type": "cylinder", "position": Vector3(0.0, 0.72, 0.0), "top_radius": 0.055, "bottom_radius": 0.075, "height": 1.44, "material": "timber"},
			{"name": "PlotSignBoard", "type": "box", "position": Vector3(0.0, 1.38, -0.04), "size": Vector3(1.7, 0.48, 0.12), "material": "dark_wood"},
			{"name": "PlotSignLabel", "type": "label3d", "text": "COTTAGE PLOT", "position": Vector3(0.0, 1.38, -0.11), "font_size": 20, "pixel_size": 0.004, "modulate": Color(0.91, 0.82, 0.63), "outline_size": 4},
			{"name": "PlotStakeNorthwest", "type": "cylinder", "axial": Vector2i(-1, -1), "position": Vector3(0.0, 0.36, 0.0), "top_radius": 0.045, "bottom_radius": 0.065, "height": 0.72, "material": "timber"},
			{"name": "PlotStakeNortheast", "type": "cylinder", "axial": Vector2i(1, -1), "position": Vector3(0.0, 0.36, 0.0), "top_radius": 0.045, "bottom_radius": 0.065, "height": 0.72, "material": "timber"},
			{"name": "PlotStakeSouthwest", "type": "cylinder", "axial": Vector2i(-1, 1), "position": Vector3(0.0, 0.36, 0.0), "top_radius": 0.045, "bottom_radius": 0.065, "height": 0.72, "material": "timber"},
			{"name": "PlotStakeSoutheast", "type": "cylinder", "axial": Vector2i(1, 1), "position": Vector3(0.0, 0.36, 0.0), "top_radius": 0.045, "bottom_radius": 0.065, "height": 0.72, "material": "timber"}
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
