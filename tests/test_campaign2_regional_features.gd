extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	assert(FEATURES.DRUID_GROVE_CENTRE == Vector2i(-266, 10), "Grove centre must derive from the original west-road endpoint")
	assert(terrain.terrain_for_hex(Vector2i(-266, 10)) == "grass", "Grove interior must be a grass clearing")
	assert(terrain.terrain_for_hex(Vector2i(-266, 9)) == "water", "Grove spring must override local terrain as water")
	assert(terrain.terrain_for_hex(Vector2i(-266, 5)) == "forest", "Outer grove ring must be woodland")
	assert(terrain.terrain_for_hex(Vector2i(-266, 4)) != "forest", "Grove foliage must stop beyond the authored radius")
	assert(FEATURES.is_herb_patch(Vector2i(-265, 9)), "Eastern herb patch must retain its source coordinate")
	assert(FEATURES.is_herb_patch(Vector2i(-267, 11)), "South-western herb patch must retain its source coordinate")
	assert(not FEATURES.is_herb_patch(Vector2i(-266, 10)), "Clearing centre must not be misidentified as an herb patch")
	assert(FEATURES.DRUID_GROVE_DEN == Vector2i(-269, 2), "Druid trial den anchor must be retained as separate encounter metadata")
	# Source-authored Skarn-tooth camp and Skarnak's Hold ground.
	assert(terrain.terrain_for_hex(Vector2i(203, 23)) == "dirt", "Goblin camp must have its source dirt clearing")
	assert(terrain.terrain_for_hex(Vector2i(209, 23)) == "dirt", "Goblin camp clearing must include its radius-six edge")
	assert(terrain.terrain_for_hex(Vector2i(428, 17)) == "dirt", "Orc stronghold must have its source dirt clearing")
	assert(terrain.terrain_for_hex(Vector2i(420, 18)) == "climbable_wall", "Orc stronghold perimeter must retain its climbable wall ring")
	assert(terrain.terrain_for_hex(Vector2i(420, 17)) == "path", "Orc stronghold's corrected west gate must be traversable")
	assert(FEATURES.is_orc_approach_path(Vector2i(410, 20)), "Orc stronghold approach must be a connected hex line from the border road")

	# Ashveil's source lair is a cave-floor den inside a rocky outcrop ring.
	assert(terrain.terrain_for_hex(Vector2i(101, -366)) == "cave_floor", "Dragon lair centre must be cave floor")
	assert(terrain.terrain_for_hex(Vector2i(103, -366)) == "cave_floor", "Dragon lair inner radius must remain cave floor")
	assert(terrain.terrain_for_hex(Vector2i(104, -366)) == "rocky_outcrop", "Dragon lair outer ring must be rocky outcrop")
	assert(terrain.terrain_for_hex(Vector2i(108, -366)) != "rocky_outcrop", "Dragon lair rocky ring must stop at radius six")

	# Sil'thandriel's canopy has an explicit grass arrival clearing, a dense
	# source-noise woodland band, a foliage perimeter and a north approach.
	assert(terrain.terrain_for_hex(Vector2i(-252, 934)) == "grass", "Elven capital must retain its arrival clearing")
	assert(terrain.terrain_for_hex(Vector2i(-252, 916)) == "forest", "Elven capital outer canopy ring must be forest")
	assert(terrain.terrain_for_hex(Vector2i(-252, 925)) == "forest", "Elven canopy's dense middle band must retain a source foliage cell")
	assert(terrain.terrain_for_hex(Vector2i(-265, 934)) == "grass", "Elven canopy's sparse middle-band cells must remain clearing gaps")
	assert(terrain.terrain_for_hex(Vector2i(-252, 928)) == "path", "Elven capital north approach must start outside the tree clearing")
	assert(terrain.terrain_for_hex(Vector2i(-252, 907)) == "path", "Elven capital north approach must reach its source endpoint")

	print("Campaign 2 regional authored terrain feature tests passed.")
	quit(0)
