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
	assert(FEATURES.feature_id_at(Vector2i(-269, 2)) == "druid_grove_trial_den", "Druid trial den must retain its separate feature identity")
	assert(FEATURES.feature_id_at(Vector2i(-265, 9)) == "emberwood_grove_herb_patch", "Herb patch anchors must expose their feature identity")
	assert(FEATURES.ORC_STRONGHOLD_GATE == Vector2i(420, 17), "Orc stronghold gate must be on the actual west wall ring")
	assert(FEATURES.feature_id_at(Vector2i(420, 17)) == "skarnaks_hold_gate", "Orc gate must retain its own feature identity")
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

	# Kragmoor is a solid source-sized mountain with a carved surface Gate Hall.
	assert(FEATURES.KRAGMOOR_CENTRE == Vector2i(908, -626), "Kragmoor anchor must derive from the crossroads plus the source offset")
	assert(FEATURES.KRAGMOOR_MASSIF_RADIUS == 25, "Kragmoor massif must retain its source radius")
	assert(terrain.terrain_for_hex(Vector2i(908, -626)) == "mountain", "Kragmoor centre must be solid mountain")
	assert(terrain.terrain_for_hex(Vector2i(933, -626)) == "mountain", "Kragmoor massif must include its radius-25 edge")
	assert(FEATURES.feature_id_at(Vector2i(934, -626)) != "kragmoor_massif", "Kragmoor massif must stop beyond radius 25")
	assert(terrain.terrain_for_hex(Vector2i(908, -608)) == "cave_floor", "Surface Gate Hall must be excavated from the massif")
	assert(terrain.terrain_for_hex(Vector2i(908, -610)) == "cave_floor", "Gate Hall must preserve the full source room footprint")
	assert(terrain.terrain_for_hex(Vector2i(908, -605)) == "path", "Gate Hall door must remain an open traversable threshold")
	assert(terrain.terrain_for_hex(Vector2i(908, -600)) == "path", "Kragmoor's south approach spur must connect to the gate")
	assert(FEATURES.is_kragmoor_approach_path(Vector2i(8, 24)), "Kragmoor road must begin at Hollowmere's crossroads")
	assert(FEATURES.is_kragmoor_approach_path(Vector2i(908, -593)), "Kragmoor road must reach the source spur tip")
	assert(FEATURES.feature_id_at(Vector2i(908, -608)) == "kragmoor_gate_hall", "Gate Hall must expose its own feature identity")
	assert(FEATURES.feature_id_at(Vector2i(908, -626)) == "kragmoor_massif", "Massif must expose its own feature identity")

	# Northwatch and Ridgehold preserve their source six-point star-fort ground,
	# wall rings, keep footprints, gates and connected approaches.
	assert(FEATURES.NORTHWATCH_CENTRE == Vector2i(268, -21), "Northwatch centre must match the canonical geography anchor")
	assert(terrain.terrain_for_hex(Vector2i(268, -21)) == "dirt", "Northwatch core must be a fort floor")
	assert(terrain.terrain_for_hex(Vector2i(268, -3)) == "dirt", "Northwatch south star point must reach its source 18-hex tip")
	assert(terrain.terrain_for_hex(Vector2i(268, -4)) == "climbable_wall", "Northwatch outer ring must wrap the star-fort point")
	assert(terrain.terrain_for_hex(Vector2i(268, -2)) == "climbable_wall", "Northwatch south gate must retain its closed wall terrain")
	assert(terrain.terrain_for_hex(Vector2i(268, 10)) == "path", "Northwatch's south approach spur must reach the outer gate")
	assert(terrain.terrain_for_hex(Vector2i(268, -21)) == "dirt", "Northwatch keep must retain its central floor")
	assert(terrain.terrain_for_hex(Vector2i(268, -16)) == "dirt", "Northwatch keep must retain its six open corner gaps")
	assert(FEATURES.feature_id_at(Vector2i(268, -2)) == "northwatch_gate", "Northwatch gate must have its own feature identity")

	assert(FEATURES.RIDGEHOLD_CENTRE == Vector2i(426, 43), "Ridgehold centre must match the canonical geography anchor")
	assert(FEATURES.RIDGEHOLD_GATE == Vector2i(407, 43), "Ridgehold gate must be corrected onto the actual west wall ring")
	assert(terrain.terrain_for_hex(Vector2i(426, 43)) == "dirt", "Ridgehold core must be a fort floor")
	assert(terrain.terrain_for_hex(Vector2i(408, 43)) == "dirt", "Ridgehold west star point must reach its source tip")
	assert(terrain.terrain_for_hex(Vector2i(407, 43)) == "path", "Ridgehold gate must be an open gap on the actual wall ring")
	assert(terrain.terrain_for_hex(Vector2i(402, 33)) == "path", "Ridgehold's approach must use a continuous corrected hex line")
	assert(terrain.terrain_for_hex(Vector2i(426, 45)) == "path", "Ridgehold keep must retain its open south door")
	assert(terrain.terrain_for_hex(Vector2i(427, 44)) == "climbable_wall", "Ridgehold keep must retain its wall ring")
	assert(FEATURES.feature_id_at(Vector2i(407, 43)) == "ridgehold_gate", "Ridgehold gate must have its own feature identity")

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
