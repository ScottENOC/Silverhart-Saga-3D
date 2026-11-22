extends SceneTree

const TERRAIN = preload("res://data/world/terrain/campaign2_local_terrain.gd")

var failures: int = 0

func _initialize() -> void:
	_check(TERRAIN.terrain_from_roll("ocean", "orcs", 0.99) == "water")
	_check(TERRAIN.terrain_from_roll("mountain", "", 0.99) == "mountain")
	_check(TERRAIN.terrain_from_roll("forest", "", 0.99) == "forest")
	_check(TERRAIN.terrain_from_roll("hills", "", 0.99) == "hills")
	_check(TERRAIN.terrain_from_roll("grass", "orcs", 0.29) == "badlands")
	_check(TERRAIN.terrain_from_roll("grass", "orcs", 0.30) == "hills")
	_check(TERRAIN.terrain_from_roll("grass", "orcs", 0.58) == "grass")
	_check(TERRAIN.terrain_from_roll("grass", "", 0.10) == "forest")
	_check(TERRAIN.terrain_from_roll("grass", "", 0.11) == "hills")
	_check(TERRAIN.terrain_from_roll("grass", "", 0.22) == "grass")

	_check(TERRAIN.elevation_from_rolls("water", 0.5, 0.5) == 0.0)
	_check(TERRAIN.elevation_from_rolls("path", 0.5, 0.5) == 0.0)
	_check(TERRAIN.elevation_from_rolls("dirt", 0.5, 0.5) == 0.0)
	_check(TERRAIN.elevation_from_rolls("wood_floor", 0.5, 0.5) == 0.0)
	_check(TERRAIN.elevation_from_rolls("stone_floor", 0.5, 0.5) == 0.0)
	_check(TERRAIN.elevation_from_rolls("cave_floor", 0.5, 0.5) == 0.0)
	_check(TERRAIN.elevation_from_rolls("keep_wall", 0.5, 0.5) == 0.0)
	_check(is_equal_approx(TERRAIN.elevation_from_rolls("mountain", 0.5, 0.5), 4.95))
	_check(is_equal_approx(TERRAIN.elevation_from_rolls("hills", 0.5, 0.5), 1.125))
	_check(is_equal_approx(TERRAIN.elevation_from_rolls("badlands", 0.5, 0.5), 0.6))
	_check(is_equal_approx(TERRAIN.elevation_from_rolls("forest", 0.5, 0.5), 0.14))
	_check(is_equal_approx(TERRAIN.elevation_from_rolls("grass", 0.5, 0.5), 0.09))

	_check(TERRAIN.rock_outcrop_from_roll("hills", 0.17))
	_check(TERRAIN.rock_outcrop_from_roll("badlands", 0.17))
	_check(not TERRAIN.rock_outcrop_from_roll("hills", 0.18))
	_check(not TERRAIN.rock_outcrop_from_roll("grass", 0.01))
	_check(TERRAIN.has_tree_from_roll("forest", 0.33))
	_check(not TERRAIN.has_tree_from_roll("forest", 0.34))
	_check(not TERRAIN.has_tree_from_roll("hills", 0.01))

	_check(TERRAIN.source_terrain_from_rolls(true, 0.99, 0.99, 0.99) == "grass")
	_check(TERRAIN.source_terrain_from_rolls(false, 0.90, 0.76, 0.90) == "swamp")
	_check(TERRAIN.source_terrain_from_rolls(false, 0.90, 0.56, 0.49) == "forest")
	_check(TERRAIN.source_terrain_from_rolls(false, 0.90, 0.55, 0.49) == "grass")
	_check(TERRAIN.source_terrain_from_rolls(false, 0.11, 0.71, 0.90) == "sand")
	_check(TERRAIN.source_terrain_from_rolls(false, 0.11, 0.70, 0.10) == "grass")
	_check(TERRAIN.source_terrain_from_rolls(false, 0.50, 0.89, 0.90) == "rocky_outcrop")
	_check(TERRAIN.source_terrain_from_rolls(false, 0.50, 0.56, 0.49) == "forest")
	_check(TERRAIN.source_terrain_from_rolls(false, 0.50, 0.55, 0.49) == "grass")
	_check(TERRAIN.source_local_terrain(Vector2i(8, 24)) == "grass")
	_check(TERRAIN.source_local_terrain(Vector2i(32, -32)) == "grass")
	var sample := Vector2i(-187, 263)
	_check(TERRAIN.stable_roll(sample, TERRAIN.SEED) == TERRAIN.stable_roll(sample, TERRAIN.SEED))
	var roll := TERRAIN.stable_roll(sample, TERRAIN.SEED)
	_check(roll >= 0.0 and roll < 1.0)
	if failures > 0:
		push_error("%d local terrain test(s) failed." % failures)
		quit(1)
		return
	print("Silverhart heartland regional terrain tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Local terrain assertion failed") -> void:
	if not condition:
		failures += 1
		push_error(message)
