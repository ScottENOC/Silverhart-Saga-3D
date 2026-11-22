extends RefCounted
## Source-authored Silverhart heartland clearings and natural landmarks.
## Coordinates are derived from campaign2World.js setupVillageScene:
## CP=(8,24), westRoadEnd=(-252,22), grove centre=(-266,10).
## This module owns terrain overrides only; NPCs, tracks and quest props are
## registered separately so world terrain does not become a quest-state store.

const DRUID_GROVE_CENTRE := Vector2i(-266, 10)
const DRUID_GROVE_SPRING := Vector2i(-266, 9)
const DRUID_GROVE_DEN := Vector2i(-269, 2)
const DRUID_GROVE_RADIUS := 5
const HERB_PATCH_HEXES: Array[Vector2i] = [
	Vector2i(-265, 9),
	Vector2i(-267, 11)
]

static func terrain_override_at(hex: Vector2i) -> Dictionary:
	if hex == DRUID_GROVE_SPRING:
		return {"terrain": "water", "feature_id": "emberwood_grove_spring"}
	var distance := maxi(absi(hex.x - DRUID_GROVE_CENTRE.x), maxi(
		absi(hex.y - DRUID_GROVE_CENTRE.y),
		absi((hex.x + hex.y) - (DRUID_GROVE_CENTRE.x + DRUID_GROVE_CENTRE.y))
	))
	if distance > DRUID_GROVE_RADIUS:
		return {}
	return {
		"terrain": "forest" if distance >= DRUID_GROVE_RADIUS - 1 else "grass",
		"feature_id": "emberwood_grove_clearing",
		"distance": distance
	}

static func is_herb_patch(hex: Vector2i) -> bool:
	return hex in HERB_PATCH_HEXES

static func feature_id_at(hex: Vector2i) -> String:
	if hex == DRUID_GROVE_SPRING:
		return "emberwood_grove_spring"
	if is_herb_patch(hex):
		return "emberwood_grove_herb_patch"
	return String(terrain_override_at(hex).get("feature_id", ""))
