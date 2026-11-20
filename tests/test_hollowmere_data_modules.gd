extends SceneTree

const DATA = preload("res://scripts/world/hollowmere_village_data.gd")
const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const BUILDINGS = preload("res://data/settlements/hollowmere/buildings.gd")
const ROUTES = preload("res://data/settlements/hollowmere/routes.gd")
const BRIDGES = preload("res://data/settlements/hollowmere/bridges.gd")
const PROPS = preload("res://data/settlements/hollowmere/props.gd")
const AGRICULTURE = preload("res://data/settlements/hollowmere/agriculture.gd")

func _initialize() -> void:
	assert(SETTLEMENT.SETTLEMENT_ID == "hollowmere")
	assert(SETTLEMENT.COORDINATE_SYSTEM == "campaign2_local_axial_qr")
	assert(SETTLEMENT.WORLD_REFERENCE_HEX == Vector2i(8, 24), "Hollowmere reference point must remain in campaign axial world coordinates")
	assert(DATA.MAP_RADIUS == 96, "Compatibility facade must preserve the authored local map extent")
	assert(DATA.CROSSROADS == SETTLEMENT.WORLD_REFERENCE_HEX)
	assert(DATA.BRIDGE == Vector2i(8, -25))

	assert(BUILDINGS.BUILDINGS.size() == 7, "All seven authored Hollowmere buildings must remain in the building data module")
	var building_ids: Dictionary = {}
	for building in BUILDINGS.BUILDINGS:
		var id := String(building.get("id", ""))
		assert(not id.is_empty() and not building_ids.has(id), "Building IDs must be stable and unique")
		building_ids[id] = true
		assert(building.get("center") is Vector2i and building.get("door") is Vector2i, "Building footprint and entrance must use axial world coordinates")

	assert(ROUTES.PRESENTATION_ROUTES.size() == 12, "All authored presentation routes must remain present")
	assert(ROUTES.FARMYARD_CENTRELINE.front() == SETTLEMENT.FARMHOUSE_DOOR)
	assert(ROUTES.FARMYARD_CENTRELINE.back() == SETTLEMENT.FARM_BARN_DOOR)
	assert(BRIDGES.BRIDGE_PRESENTATION.parts.size() == 9)
	assert(PROPS.LANDMARK_PROPS.size() == 2 and PROPS.QUEST_PROPS.size() == 2 and PROPS.WAYFINDING_PROPS.size() == 1)
	assert(AGRICULTURE.FARM_FIELDS.size() == 3 and AGRICULTURE.FARM_CROP_ROWS.size() == 17 and AGRICULTURE.FARM_FENCES.size() == 2)

	# Existing callers continue using HollowmereVillageData while authored data is independently organised.
	assert(DATA.BUILDINGS.size() == BUILDINGS.BUILDINGS.size())
	assert(DATA.PRESENTATION_ROUTES.size() == ROUTES.PRESENTATION_ROUTES.size())
	assert(DATA.BRIDGE_PRESENTATION.parts.size() == BRIDGES.BRIDGE_PRESENTATION.parts.size())
	assert(DATA.FARM_CROP_ROWS.size() == AGRICULTURE.FARM_CROP_ROWS.size())
	print("Hollowmere modular settlement data tests passed.")
	quit(0)
