extends SceneTree

const TERRAIN = preload("res://data/world/regions/silverhart_heartland/terrain.gd")
const BIOMES = preload("res://data/world/regions/silverhart_heartland/biomes.gd")

func _initialize() -> void:
	assert(TERRAIN.terrain_from_roll("ocean", "orcs", 0.99) == "water")
	assert(TERRAIN.terrain_from_roll("mountain", "", 0.99) == "mountain")
	assert(TERRAIN.terrain_from_roll("forest", "", 0.99) == "forest")
	assert(TERRAIN.terrain_from_roll("hills", "", 0.99) == "hills")
	assert(TERRAIN.terrain_from_roll("grass", "orcs", 0.29) == "badlands")
	assert(TERRAIN.terrain_from_roll("grass", "orcs", 0.30) == "hills")
	assert(TERRAIN.terrain_from_roll("grass", "orcs", 0.58) == "grass")
	assert(TERRAIN.terrain_from_roll("grass", "", 0.10) == "forest")
	assert(TERRAIN.terrain_from_roll("grass", "", 0.11) == "hills")
	assert(TERRAIN.terrain_from_roll("grass", "", 0.22) == "grass")

	assert(TERRAIN.elevation_from_rolls("water", 0.5, 0.5) == 0.0)
	assert(TERRAIN.elevation_from_rolls("path", 0.5, 0.5) == 0.0)
	assert(is_equal_approx(TERRAIN.elevation_from_rolls("mountain", 0.5, 0.5), 4.95))
	assert(is_equal_approx(TERRAIN.elevation_from_rolls("hills", 0.5, 0.5), 1.125))
	assert(is_equal_approx(TERRAIN.elevation_from_rolls("badlands", 0.5, 0.5), 0.6))
	assert(is_equal_approx(TERRAIN.elevation_from_rolls("forest", 0.5, 0.5), 0.14))
	assert(is_equal_approx(TERRAIN.elevation_from_rolls("grass", 0.5, 0.5), 0.09))

	assert(TERRAIN.rock_outcrop_from_roll("hills", 0.17))
	assert(TERRAIN.rock_outcrop_from_roll("badlands", 0.17))
	assert(not TERRAIN.rock_outcrop_from_roll("hills", 0.18))
	assert(not TERRAIN.rock_outcrop_from_roll("grass", 0.01))
	assert(BIOMES.has_regional_tree("forest", 0.33))
	assert(not BIOMES.has_regional_tree("forest", 0.34))
	assert(not BIOMES.has_regional_tree("hills", 0.01))

	var sample := Vector2i(-187, 263)
	assert(TERRAIN.stable_roll(sample, TERRAIN.SEED) == TERRAIN.stable_roll(sample, TERRAIN.SEED))
	var roll := TERRAIN.stable_roll(sample, TERRAIN.SEED)
	assert(roll >= 0.0 and roll < 1.0)
	print("Silverhart heartland regional terrain tests passed.")
	quit(0)
