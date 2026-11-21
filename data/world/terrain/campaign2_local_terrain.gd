extends RefCounted
## Regional terrain classification, elevation and geological resource rules.
## Settlement feature precedence and the strategic geography index are resolved by the caller.

const SEED := 2047
const ROCK_OUTCROP_SEED_OFFSET := 431
const ROCK_OUTCROP_THRESHOLD := 0.18
const TREE_DENSITY_SEED_OFFSET := 317
const TREE_DENSITY_THRESHOLD := 0.34

static func terrain_for_hex(hex: Vector2i, base_terrain: String, faction: String) -> String:
	return terrain_from_roll(base_terrain, faction, stable_roll(hex, SEED))

static func terrain_from_roll(base_terrain: String, faction: String, roll: float) -> String:
	match base_terrain:
		"ocean":
			return "water"
		"mountain":
			return "mountain"
		"forest":
			return "forest"
		"hills":
			return "hills"
		_:
			if faction == "orcs":
				return "badlands" if roll < 0.30 else ("hills" if roll < 0.58 else "grass")
			if roll < 0.11:
				return "forest"
			if roll < 0.22:
				return "hills"
			return "grass"

static func elevation_for_hex(hex: Vector2i, terrain: String) -> float:
	if terrain in ["water", "path", "authored", "void"]:
		return 0.0
	var broad_hex := Vector2i(floori(float(hex.x) / 7.0), floori(float(hex.y) / 7.0))
	var broad := stable_roll(broad_hex, SEED + 71)
	var detail := stable_roll(hex, SEED + 193)
	return elevation_from_rolls(terrain, broad, detail)

static func elevation_from_rolls(terrain: String, broad: float, detail: float) -> float:
	if terrain in ["water", "path", "authored", "void"]:
		return 0.0
	match terrain:
		"mountain":
			return 2.8 + broad * 3.8 + detail * 0.5
		"hills":
			return 0.45 + broad * 1.1 + detail * 0.25
		"badlands":
			return 0.25 + broad * 0.7
		"forest":
			return broad * 0.28
		_:
			return broad * 0.18

static func has_tree(hex: Vector2i, terrain: String) -> bool:
	return has_tree_from_roll(terrain, stable_roll(hex, SEED + TREE_DENSITY_SEED_OFFSET))

static func has_tree_from_roll(terrain: String, density_roll: float) -> bool:
	return terrain == "forest" and density_roll < TREE_DENSITY_THRESHOLD

static func has_rock_outcrop(hex: Vector2i, terrain: String) -> bool:
	return rock_outcrop_from_roll(terrain, stable_roll(hex, SEED + ROCK_OUTCROP_SEED_OFFSET))

static func rock_outcrop_from_roll(terrain: String, density_roll: float) -> bool:
	return terrain in ["hills", "badlands"] and density_roll < ROCK_OUTCROP_THRESHOLD

static func stable_roll(hex: Vector2i, seed_value: int) -> float:
	var value := posmod(hex.x * 92837111 + hex.y * 689287499 + seed_value * 104729 + 1013904223, 2147483647)
	return float(value) / 2147483647.0
