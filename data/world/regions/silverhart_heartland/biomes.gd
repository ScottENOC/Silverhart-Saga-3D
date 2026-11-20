extends RefCounted
## Silverhart heartland woodland rules.
## Settlement geometry is supplied as context; this module owns regional ecology.

const FOREST_DENSITY_OFFSET := Vector2i(17, -9)
const FOREST_DENSITY_THRESHOLD := 0.56
const UNDERSTOREY_DENSITY_OFFSET := Vector2i(977, -337)
const UNDERSTOREY_DENSITY_THRESHOLD := 0.70
const TREE_OCCUPANCY_THRESHOLD := 0.56
const FOREST_CLEARING_RADIUS := 17
const STREAM_INFLUENCE_Q_RADIUS := 34

static func is_forest_candidate(hex: Vector2i, settlement_context: Dictionary) -> bool:
	if not bool(settlement_context.get("in_bounds", false)):
		return false
	if bool(settlement_context.get("farm_land", false)):
		return false
	if int(settlement_context.get("distance_from_centre", 0)) < FOREST_CLEARING_RADIUS:
		return false
	if bool(settlement_context.get("water", false)):
		return false
	if bool(settlement_context.get("building", false)):
		return false
	if bool(settlement_context.get("path", false)):
		return false
	return stable_noise(hex.x, hex.y) > 0.18

static func has_tree(hex: Vector2i, is_candidate: bool) -> bool:
	if not is_candidate or posmod(hex.x, 4) != 0 or posmod(hex.y, 4) != 0:
		return false
	return stable_noise(hex.x + 17, hex.y - 9) >= TREE_OCCUPANCY_THRESHOLD

static func is_near_stream(hex: Vector2i, distance: float, stream_centre_r: float) -> bool:
	if absi(hex.x) > STREAM_INFLUENCE_Q_RADIUS:
		return false
	return absf(float(hex.y) - stream_centre_r) <= distance

static func select_understorey_family(near_stream: bool, density_roll: float) -> String:
	if near_stream and density_roll < 0.84:
		return "tree_fern"
	if density_roll > 0.91:
		return "low_poly_bush"
	return "bush"

static func select_tree_family(hex: Vector2i, near_stream: bool) -> String:
	var roll := stable_noise(hex.x + 401, hex.y - 719)
	if near_stream:
		if roll < 0.48:
			return "willow"
		if roll < 0.66:
			return "ash"
		if roll < 0.82:
			return "laurel"
		if roll < 0.94:
			return "cherry"
		return "spruce"
	if roll < 0.18:
		return "ash"
	if roll < 0.33:
		return "cherry"
	if roll < 0.46:
		return "laurel"
	if roll < 0.64:
		return "pine"
	if roll < 0.80:
		return "spruce"
	if roll < 0.92:
		return "winter_oak"
	return "low_poly_tree"

static func stable_noise(q: int, r: int) -> float:
	var value: int = posmod(q * 92837111 + r * 689287499 + 1013904223, 2147483647)
	return float(value) / 2147483647.0
