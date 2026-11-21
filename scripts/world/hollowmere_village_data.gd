class_name HollowmereVillageData
extends RefCounted
## Compatibility facade for Hollowmere's logical local-map queries.
## Authored definitions live in domain files under data/settlements/hollowmere/.

const SETTLEMENT_DATA = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const BUILDING_DATA = preload("res://data/settlements/hollowmere/buildings.gd")
const ROUTE_DATA = preload("res://data/settlements/hollowmere/routes.gd")
const BRIDGE_DATA = preload("res://data/settlements/hollowmere/bridges.gd")
const PROP_DATA = preload("res://data/settlements/hollowmere/props.gd")
const AGRICULTURE_DATA = preload("res://data/settlements/hollowmere/agriculture.gd")
const TERRAIN_DEFINITION = preload("res://data/settlements/hollowmere/terrain.gd")
const TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")

# Preserve the existing public API while making each authored domain independently editable.
const MAP_RADIUS: int = SETTLEMENT_DATA.MAP_RADIUS
const STREAM_R: int = SETTLEMENT_DATA.STREAM_R
const STREAM_Q_MIN: int = SETTLEMENT_DATA.STREAM_Q_MIN
const STREAM_Q_MAX: int = SETTLEMENT_DATA.STREAM_Q_MAX
const CROSSROADS = SETTLEMENT_DATA.CROSSROADS
const BRIDGE = SETTLEMENT_DATA.BRIDGE
const FARMHOUSE = SETTLEMENT_DATA.FARMHOUSE
const FARM_BARN = SETTLEMENT_DATA.FARM_BARN
const FARMHOUSE_DOOR = SETTLEMENT_DATA.FARMHOUSE_DOOR
const FARM_BARN_DOOR = SETTLEMENT_DATA.FARM_BARN_DOOR
const BRIDGE_PRESENTATION = BRIDGE_DATA.BRIDGE_PRESENTATION
const SOUTH_ROAD_CENTRELINE = ROUTE_DATA.SOUTH_ROAD_CENTRELINE
const FARMYARD_CENTRELINE = ROUTE_DATA.FARMYARD_CENTRELINE
const LANDMARK_PROPS = PROP_DATA.LANDMARK_PROPS
const QUEST_PROPS = PROP_DATA.QUEST_PROPS
const WAYFINDING_PROPS = PROP_DATA.WAYFINDING_PROPS
const FARM_FIELDS = AGRICULTURE_DATA.FARM_FIELDS
const FARM_CROP_ROWS = AGRICULTURE_DATA.FARM_CROP_ROWS
const FARM_FENCES = AGRICULTURE_DATA.FARM_FENCES
const BUILDINGS = BUILDING_DATA.BUILDINGS
const PRESENTATION_ROUTES = ROUTE_DATA.PRESENTATION_ROUTES

static func is_in_bounds(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_in_bounds(hex, TERRAIN_DEFINITION.DEFINITION)

static func is_water(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_water(hex, TERRAIN_DEFINITION.DEFINITION)

static func _river_centre_r(q: int) -> float:
	return TERRAIN_PROVIDER.river_centre_r(q, TERRAIN_DEFINITION.DEFINITION)

static func _river_half_width(q: int) -> float:
	return TERRAIN_PROVIDER.river_half_width(q, TERRAIN_DEFINITION.DEFINITION)

static func is_building(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_building(hex, TERRAIN_DEFINITION.DEFINITION)

static func is_door(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_door(hex, TERRAIN_DEFINITION.DEFINITION)

static func is_blocked(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_blocked(hex, TERRAIN_DEFINITION.DEFINITION)

static func terrain_id_at(hex: Vector2i) -> String:
	return TERRAIN_PROVIDER.terrain_id_at(hex, TERRAIN_DEFINITION.DEFINITION)

static func is_path(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_path(hex, TERRAIN_DEFINITION.DEFINITION)

static func path_cells() -> Array[Vector2i]:
	return TERRAIN_PROVIDER.path_cells(TERRAIN_DEFINITION.DEFINITION)

static func water_cells() -> Array[Vector2i]:
	return TERRAIN_PROVIDER.water_cells(TERRAIN_DEFINITION.DEFINITION)

static func is_farm_land(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_farm_land(hex, TERRAIN_DEFINITION.DEFINITION)

static func is_forest_candidate(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_forest_candidate(hex, TERRAIN_DEFINITION.DEFINITION)

static func has_tree(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.has_tree(hex, TERRAIN_DEFINITION.DEFINITION)

static func _stable_noise(q: int, r: int) -> float:
	return TERRAIN_PROVIDER.stable_noise(q, r, TERRAIN_DEFINITION.DEFINITION)
