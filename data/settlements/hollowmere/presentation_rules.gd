extends RefCounted
## Settlement-specific ecology context adapters; regional species rules remain
## owned by the Silverhart heartland biome module.

const SETTLEMENT_QUERIES = preload("res://scripts/world/hollowmere_village_data.gd")
const HEARTLAND_BIOMES = preload("res://data/world/regions/silverhart_heartland/biomes.gd")

static func is_understorey_candidate(hex: Vector2i) -> bool:
	return SETTLEMENT_QUERIES.is_forest_candidate(hex) and not SETTLEMENT_QUERIES.has_tree(hex)

static func select_tree_family(hex: Vector2i, _density_roll: float = 0.0) -> String:
	var near_stream := HEARTLAND_BIOMES.is_near_stream(
		hex, 7.0, SETTLEMENT_QUERIES._river_centre_r(hex.x)
	)
	return HEARTLAND_BIOMES.select_tree_family(hex, near_stream)

static func select_understorey_family(hex: Vector2i, density_roll: float) -> String:
	var near_stream := HEARTLAND_BIOMES.is_near_stream(
		hex, 7.0, SETTLEMENT_QUERIES._river_centre_r(hex.x)
	)
	return HEARTLAND_BIOMES.select_understorey_family(near_stream, density_roll)
