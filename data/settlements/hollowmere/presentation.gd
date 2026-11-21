extends RefCounted
## Hollowmere's authored exterior presentation inputs.
## Geometry, palette, actor starts and ecology rules are data; shared systems render them.

const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const BUILDINGS = preload("res://data/settlements/hollowmere/buildings.gd")
const ROUTES = preload("res://data/settlements/hollowmere/routes.gd")
const BRIDGES = preload("res://data/settlements/hollowmere/bridges.gd")
const AGRICULTURE = preload("res://data/settlements/hollowmere/agriculture.gd")
const PROPS = preload("res://data/settlements/hollowmere/props.gd")
const PLACEMENTS = preload("res://data/settlements/hollowmere/placements.gd")
const TERRAIN_DEFINITION = preload("res://data/settlements/hollowmere/terrain.gd")
const TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")
const HEARTLAND_BIOMES = preload("res://data/world/regions/silverhart_heartland/biomes.gd")

const IDENTITY := {
	"id": SETTLEMENT.SETTLEMENT_ID,
	"name": SETTLEMENT.DISPLAY_NAME
}

const PALETTE := {
	"grass": Color(0.27, 0.36, 0.23),
	"path": Color(0.43, 0.34, 0.23),
	"water": {"colour": Color(0.16, 0.31, 0.36), "roughness": 0.22},
	"bank": Color(0.22, 0.25, 0.17),
	"stone": Color(0.38, 0.37, 0.33),
	"plaster": Color(0.61, 0.53, 0.40),
	"timber": Color(0.31, 0.18, 0.10),
	"dark_wood": Color(0.16, 0.09, 0.05),
	"roof": Color(0.24, 0.25, 0.22),
	"glass": {"colour": Color(0.29, 0.45, 0.49, 0.72), "roughness": 0.18},
	"field": Color(0.30, 0.32, 0.17),
	"crop": Color(0.48, 0.43, 0.22),
	"pasture": Color(0.24, 0.34, 0.19),
	"fence": Color(0.28, 0.17, 0.09),
	"blood": Color(0.22, 0.045, 0.025)
}

const FEATURE_DATA := {
	"buildings": BUILDINGS.BUILDINGS,
	"routes": ROUTES.PRESENTATION_ROUTES,
	"bridge": BRIDGES.BRIDGE_PRESENTATION,
	"fields": AGRICULTURE.FARM_FIELDS,
	"crop_rows": AGRICULTURE.FARM_CROP_ROWS,
	"fences": AGRICULTURE.FARM_FENCES,
	"landmark_props": PROPS.LANDMARK_PROPS,
	"quest_props": PROPS.QUEST_PROPS,
	"wayfinding_props": PROPS.WAYFINDING_PROPS
}

const VEGETATION := {
	"forest": {
		"candidate_script": TERRAIN_PROVIDER, "candidate_method": "is_forest_candidate",
		"candidate_context": TERRAIN_DEFINITION.DEFINITION,
		"selector_script": TERRAIN_PROVIDER, "selector_method": "select_tree_family",
		"selector_context": TERRAIN_DEFINITION.DEFINITION,
		"min_q": -96, "max_q": 96, "min_r": -96, "max_r": 96,
		"spacing": 4, "density_offset": HEARTLAND_BIOMES.FOREST_DENSITY_OFFSET,
		"density_threshold": HEARTLAND_BIOMES.FOREST_DENSITY_THRESHOLD,
		"scale_min": 0.78, "scale_range": 0.46, "node_prefix": "HollowmereTree"
	},
	"understorey": {
		"candidate_script": TERRAIN_PROVIDER, "candidate_method": "is_understorey_candidate",
		"candidate_context": TERRAIN_DEFINITION.DEFINITION,
		"selector_script": TERRAIN_PROVIDER, "selector_method": "select_understorey_family",
		"selector_context": TERRAIN_DEFINITION.DEFINITION,
		"min_q": -96, "max_q": 96, "min_r": -96, "max_r": 96,
		"spacing": 8, "density_offset": HEARTLAND_BIOMES.UNDERSTOREY_DENSITY_OFFSET,
		"density_threshold": HEARTLAND_BIOMES.UNDERSTOREY_DENSITY_THRESHOLD,
		"scale_min": 0.68, "scale_range": 0.48, "node_prefix": "HollowmereUnderstorey",
		"understorey": true
	}
}

const DEFINITION := {
	"id": SETTLEMENT.SETTLEMENT_ID,
	"hex_radius": HexGrid.DEFAULT_RADIUS_M,
	"ground": {"name": "HollowmereGrassland", "size": 420.0, "height": -0.22, "material": "grass"},
	"palette": PALETTE,
	"features": {
		"identity": IDENTITY,
		"data": FEATURE_DATA,
		"materials": {
			"routes": {"path": "path", "water": "water", "bank": "bank"},
			"bridge": {"timber": "timber", "dark_wood": "dark_wood"},
			"agriculture": {"field": "field", "pasture": "pasture", "crop": "crop", "fence": "fence"},
			"props": {"dark_wood": "dark_wood", "stone": "stone", "timber": "timber"},
			"quest_props": {"fence": "fence", "dark_wood": "dark_wood", "blood": "blood"},
			"wayfinding_props": {"dark_wood": "dark_wood", "timber": "timber"}
		}
	},
	"creatures": PLACEMENTS.FARM_ANIMALS + PLACEMENTS.WILDERNESS_ANIMALS,
	"vegetation": VEGETATION
}

