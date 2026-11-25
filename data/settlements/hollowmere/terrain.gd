extends RefCounted
## Hollowmere's authored local terrain and navigation inputs.
## Shared query behaviour lives in AuthoredSettlementTerrainProvider.

const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const BUILDINGS = preload("res://data/settlements/hollowmere/buildings.gd")
const ROUTES = preload("res://data/settlements/hollowmere/routes.gd")
const HEARTLAND_BIOMES = preload("res://data/world/regions/silverhart_heartland/biomes.gd")

const STREAM_CENTRE_SAMPLES: Array[Vector2i] = [
	Vector2i(-30, -22), Vector2i(-24, -24), Vector2i(-18, -22),
	Vector2i(-12, -24), Vector2i(-6, -27), Vector2i(0, -24),
	Vector2i(5, -24), Vector2i(8, -25), Vector2i(12, -27),
	Vector2i(18, -25), Vector2i(24, -28), Vector2i(30, -25)
]
const STREAM_HALF_WIDTH_SAMPLES := [
	1.0, 1.5, 1.8, 1.4, 1.8, 1.5, 1.1, 0.65, 1.4, 1.8, 1.5, 1.0
]

const PATH_RULES := {
	"horizontal_ranges": [
		{"r": -6, "q_min": -8, "q_max": 8},
		{"r": 6, "q_min": -8, "q_max": 8},
		{"r": 0, "q_min": -10, "q_max": -9},
		{"r": 9, "q_min": -3, "q_max": -1},
		{"r": SETTLEMENT.CROSSROADS.y, "q_min": -40, "q_max": 16}
	],
	"vertical_ranges": [
		{"q": -8, "r_min": -6, "r_max": 6},
		{"q": 8, "r_min": -6, "r_max": 6},
		{"q": 0, "r_min": -9, "r_max": -7},
		{"q": 0, "r_min": 7, "r_max": 13},
		{"q": SETTLEMENT.CROSSROADS.x, "r_min": -40, "r_max": 32}
	],
	"cells": [
		# Explicit village door spurs retained from the original Hollowmere route network.
		Vector2i(0, -10), Vector2i(-11, 0), Vector2i(0, 15),
		Vector2i(10, 9), Vector2i(-4, 9), SETTLEMENT.BRIDGE, Vector2i(0, 5),
		Vector2i(1, 13), Vector2i(1, 14), Vector2i(9, 9),
		Vector2i(-10, 0), Vector2i(-9, 0), Vector2i(-3, 9),
		Vector2i(-2, 9), Vector2i(-1, 9)
	],
	"crossroads": SETTLEMENT.CROSSROADS,
	"segments": [ROUTES.SOUTH_ROAD_CENTRELINE, ROUTES.FARMYARD_CENTRELINE],
	"segment_tolerance": 1,
	"enumeration_bounds": {"q_min": -40, "q_max": 40, "r_min": -40, "r_max": 76}
}

const DEFINITION := {
	"id": SETTLEMENT.SETTLEMENT_ID,
	"map_radius": SETTLEMENT.MAP_RADIUS,
	"elevation": 0.0,
	"stream": {
		"q_min": SETTLEMENT.STREAM_Q_MIN,
		"q_max": SETTLEMENT.STREAM_Q_MAX,
		"bridge": SETTLEMENT.BRIDGE,
		"centre_samples": STREAM_CENTRE_SAMPLES,
		"half_width_samples": STREAM_HALF_WIDTH_SAMPLES
	},
	"buildings": BUILDINGS.BUILDINGS,
	"path": PATH_RULES,
	"farm_land": {"q_min": -2, "q_max": 40, "r_min": 39, "r_max": 76},
	"biome_script": HEARTLAND_BIOMES
}
