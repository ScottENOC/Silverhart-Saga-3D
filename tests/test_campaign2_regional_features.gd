extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

var failures: int = 0

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()

	_check(FEATURES.MIRABEL_SPIDER_RUIN_CENTRE == Vector2i(160, 24), "Mirabel ruin centre must derive from Reddale guildhouse + (14, -10)")
	_check(terrain.terrain_for_hex(Vector2i(160, 24)) == "rocky_outcrop", "Mirabel ruin centre must be source rocky outcrop")
	_check(FEATURES.feature_id_at(Vector2i(163, 24)) == "reddale_mirabel_spider_ruin", "Mirabel ruin must include its radius-three edge")
	_check(FEATURES.feature_id_at(Vector2i(164, 24)) != "reddale_mirabel_spider_ruin", "Mirabel ruin must stop beyond source radius three")

	_check(FEATURES.DRUID_GROVE_CENTRE == Vector2i(-266, 10), "Grove centre must derive from the original west-road endpoint")
	_check(terrain.terrain_for_hex(Vector2i(-266, 10)) == "grass", "Grove interior must be a grass clearing")
	_check(terrain.terrain_for_hex(Vector2i(-266, 9)) == "water", "Grove spring must override local terrain as water")
	_check(terrain.terrain_for_hex(Vector2i(-266, 5)) == "forest", "Outer grove ring must be woodland")
	_check(terrain.terrain_for_hex(Vector2i(-266, 4)) != "forest", "Grove foliage must stop beyond the authored radius")
	_check(FEATURES.is_herb_patch(Vector2i(-265, 9)), "Eastern herb patch must retain its source coordinate")
	_check(FEATURES.is_herb_patch(Vector2i(-267, 11)), "South-western herb patch must retain its source coordinate")
	_check(not FEATURES.is_herb_patch(Vector2i(-266, 10)), "Clearing centre must not be misidentified as an herb patch")
	_check(FEATURES.DRUID_GROVE_DEN == Vector2i(-269, 2), "Druid trial den anchor must be retained as separate encounter metadata")
	_check(FEATURES.feature_id_at(Vector2i(-269, 2)) == "druid_grove_trial_den", "Druid trial den must retain its separate feature identity")
	_check(FEATURES.feature_id_at(Vector2i(-265, 9)) == "emberwood_grove_herb_patch", "Herb patch anchors must expose their feature identity")
	_check(FEATURES.ORC_STRONGHOLD_GATE == Vector2i(420, 17), "Orc stronghold gate must be on the actual west wall ring")
	_check(FEATURES.feature_id_at(Vector2i(420, 17)) == "skarnaks_hold_gate", "Orc gate must retain its own feature identity")
	# Source-authored Skarn-tooth camp and Skarnak's Hold ground.
	_check(terrain.terrain_for_hex(Vector2i(203, 23)) == "authored", "Goblin campfire must retain its authored building footprint")
	_check(terrain.terrain_for_hex(Vector2i(204, 23)) == "dirt", "Goblin camp must retain dirt clearing around its central campfire")
	_check(terrain.terrain_for_hex(Vector2i(209, 23)) == "dirt", "Goblin camp clearing must include its radius-six edge")
	_check(terrain.terrain_for_hex(Vector2i(428, 17)) == "authored", "Orc stronghold central fire must retain its authored building footprint")
	_check(terrain.terrain_for_hex(Vector2i(427, 17)) == "dirt", "Orc stronghold must retain dirt clearing around its central fire")
	_check(terrain.terrain_for_hex(Vector2i(420, 18)) == "climbable_wall", "Orc stronghold perimeter must retain its climbable wall ring")
	_check(terrain.terrain_for_hex(Vector2i(420, 17)) == "path", "Orc stronghold's corrected west gate must be traversable")
	_check(FEATURES.is_orc_approach_path(Vector2i(410, 20)), "Orc stronghold approach must be a connected hex line from the border road")

	# Ashveil's source lair is a cave-floor den inside a rocky outcrop ring.
	_check(terrain.terrain_for_hex(Vector2i(101, -366)) == "cave_floor", "Dragon lair centre must be cave floor")
	_check(terrain.terrain_for_hex(Vector2i(103, -366)) == "cave_floor", "Dragon lair inner radius must remain cave floor")
	_check(terrain.terrain_for_hex(Vector2i(104, -366)) == "rocky_outcrop", "Dragon lair outer ring must be rocky outcrop")
	_check(terrain.terrain_for_hex(Vector2i(108, -366)) != "rocky_outcrop", "Dragon lair rocky ring must stop at radius six")

	# Kragmoor is a solid source-sized mountain with a carved surface Gate Hall.
	_check(FEATURES.KRAGMOOR_CENTRE == Vector2i(908, -626), "Kragmoor anchor must derive from the crossroads plus the source offset")
	_check(FEATURES.KRAGMOOR_MASSIF_RADIUS == 25, "Kragmoor massif must retain its source radius")
	_check(terrain.terrain_for_hex(Vector2i(908, -626)) == "mountain", "Kragmoor centre must be solid mountain")
	_check(terrain.terrain_for_hex(Vector2i(933, -626)) == "mountain", "Kragmoor massif must include its radius-25 edge")
	_check(FEATURES.feature_id_at(Vector2i(934, -626)) != "kragmoor_massif", "Kragmoor massif must stop beyond radius 25")
	_check(terrain.terrain_for_hex(Vector2i(908, -608)) == "cave_floor", "Surface Gate Hall must be excavated from the massif")
	_check(terrain.terrain_for_hex(Vector2i(908, -610)) == "cave_floor", "Gate Hall must preserve the full source room footprint")
	_check(terrain.terrain_for_hex(Vector2i(908, -605)) == "path", "Gate Hall door must remain an open traversable threshold")
	_check(terrain.terrain_for_hex(Vector2i(908, -600)) == "path", "Kragmoor's south approach spur must connect to the gate")
	_check(FEATURES.is_kragmoor_approach_path(Vector2i(8, 24)), "Kragmoor road must begin at Hollowmere's crossroads")
	_check(FEATURES.is_kragmoor_approach_path(Vector2i(908, -593)), "Kragmoor road must reach the source spur tip")
	_check(FEATURES.feature_id_at(Vector2i(908, -608)) == "kragmoor_gate_hall", "Gate Hall must expose its own feature identity")
	_check(FEATURES.feature_id_at(Vector2i(908, -626)) == "kragmoor_massif", "Massif must expose its own feature identity")

	# Northwatch and Ridgehold preserve their source six-point star-fort ground,
	# wall rings, keep footprints, gates and connected approaches.
	_check(FEATURES.NORTHWATCH_CENTRE == Vector2i(268, -21), "Northwatch centre must match the canonical geography anchor")
	_check(terrain.terrain_for_hex(Vector2i(268, -21)) == "dirt", "Northwatch core must be a fort floor")
	_check(terrain.terrain_for_hex(Vector2i(268, -3)) == "dirt", "Northwatch south star point must reach its source 18-hex tip")
	_check(terrain.terrain_for_hex(Vector2i(267, -2)) == "climbable_wall", "Northwatch outer ring must wrap the south gate")
	_check(terrain.terrain_for_hex(Vector2i(268, -2)) == "climbable_wall", "Northwatch south gate must retain its closed wall terrain")
	_check(terrain.terrain_for_hex(Vector2i(268, 10)) == "path", "Northwatch's south approach spur must reach the outer gate")
	_check(terrain.terrain_for_hex(Vector2i(268, -21)) == "dirt", "Northwatch keep must retain its central floor")
	_check(terrain.terrain_for_hex(Vector2i(268, -16)) == "dirt", "Northwatch keep must retain its six open corner gaps")
	_check(FEATURES.feature_id_at(Vector2i(268, -2)) == "northwatch_gate", "Northwatch gate must have its own feature identity")

	_check(FEATURES.RIDGEHOLD_CENTRE == Vector2i(426, 43), "Ridgehold centre must match the canonical geography anchor")
	_check(FEATURES.RIDGEHOLD_GATE == Vector2i(407, 43), "Ridgehold gate must be corrected onto the actual west wall ring")
	_check(terrain.terrain_for_hex(Vector2i(426, 43)) == "dirt", "Ridgehold core must be a fort floor")
	_check(terrain.terrain_for_hex(Vector2i(408, 43)) == "dirt", "Ridgehold west star point must reach its source tip")
	_check(terrain.terrain_for_hex(Vector2i(407, 43)) == "path", "Ridgehold gate must be an open gap on the actual wall ring")
	_check(terrain.terrain_for_hex(Vector2i(402, 33)) == "path", "Ridgehold's approach must use a continuous corrected hex line")
	_check(terrain.terrain_for_hex(Vector2i(426, 45)) == "path", "Ridgehold keep must retain its open south door")
	_check(terrain.terrain_for_hex(Vector2i(429, 43)) == "keep_wall", "Ridgehold keep must retain its wall ring")
	_check(FEATURES.feature_id_at(Vector2i(407, 43)) == "ridgehold_gate", "Ridgehold gate must have its own feature identity")

	# Sil'thandriel's canopy has an explicit grass arrival clearing, a dense
	# source-noise woodland band, a foliage perimeter and a north approach.
	_check(terrain.terrain_for_hex(Vector2i(-252, 934)) == "grass", "Elven capital must retain its arrival clearing")
	_check(terrain.terrain_for_hex(Vector2i(-252, 916)) == "path", "Elven capital north approach must cut through the canopy ring")
	_check(terrain.terrain_for_hex(Vector2i(-251, 923)) == "forest", "Elven canopy dense middle band must retain a source foliage cell")
	_check(terrain.terrain_for_hex(Vector2i(-265, 934)) == "grass", "Elven canopy's sparse middle-band cells must remain clearing gaps")
	_check(terrain.terrain_for_hex(Vector2i(-252, 928)) == "path", "Elven capital north approach must start outside the tree clearing")
	_check(terrain.terrain_for_hex(Vector2i(-252, 907)) == "path", "Elven capital north approach must reach its source endpoint")

	_check(terrain.terrain_for_hex(Vector2i(-12, -8)) == "wood_floor", "Hollowmere Guild Den must retain its source timber floor")
	_check(terrain.terrain_for_hex(Vector2i(-12, -6)) == "path", "Hollowmere Guild Den south door must remain open")

	# Surface footprints for the abandoned house, crypt/barrow chain,
	# chapterhouse, Thieves' Cove and Emberlode Mine.
	_check(terrain.terrain_for_hex(Vector2i(14, -176)) == "wood_floor", "Abandoned House must retain its source timber floor")
	_check(terrain.terrain_for_hex(Vector2i(14, -174)) == "climbable_wall", "Abandoned House must retain its surrounding wall ring")
	_check(terrain.terrain_for_hex(Vector2i(11, -176)) == "path", "Abandoned House west door must remain open")
	_check(terrain.terrain_for_hex(Vector2i(9, -176)) == "path", "Abandoned House must retain its short road approach")
	_check(FEATURES.feature_id_at(Vector2i(14, -176)) == "abandoned_house_floor", "Abandoned House floor must expose its feature identity")

	_check(terrain.terrain_for_hex(Vector2i(32, -154)) == "cave_floor", "Crypt entrance chamber must be cave floor")
	_check(terrain.terrain_for_hex(Vector2i(40, -154)) == "cave_floor", "Crypt ossuary must be cave floor")
	_check(terrain.terrain_for_hex(Vector2i(49, -154)) == "cave_floor", "Crypt ritual chamber must be cave floor")
	_check(terrain.terrain_for_hex(Vector2i(36, -154)) == "cave_floor", "Crypt entrance corridor must connect to the ossuary")
	_check(terrain.terrain_for_hex(Vector2i(29, -154)) == "path", "Crypt entrance door must remain open")

	_check(terrain.terrain_for_hex(Vector2i(63, -160)) == "cave_floor", "Corvin barrow antechamber must be cave floor")
	_check(terrain.terrain_for_hex(Vector2i(72, -160)) == "cave_floor", "Corvin barrow sanctum must be cave floor")
	_check(terrain.terrain_for_hex(Vector2i(67, -160)) == "cave_floor", "Barrow corridor must connect the two chambers")

	_check(terrain.terrain_for_hex(Vector2i(267, -16)) == "keep_wall", "Northwatch keep must use its solid keep-wall ring")
	_check(terrain.terrain_for_hex(Vector2i(-39, -346)) == "stone_floor", "Lich Chapterhouse must retain its source stone floor")
	_check(terrain.terrain_for_hex(Vector2i(-36, -346)) == "path", "Lich Chapterhouse east door must remain open")
	_check(terrain.terrain_for_hex(Vector2i(-43, -343)) == "keep_wall", "Lich Chapterhouse must retain its source keep-wall ring")
	_check(terrain.terrain_for_hex(Vector2i(-274, 40)) == "cave_floor", "Thieves' Cove entrance must be cave floor")
	_check(terrain.terrain_for_hex(Vector2i(-277, 40)) == "path", "Thieves' Cove entrance door must remain open")

	_check(terrain.terrain_for_hex(Vector2i(-252, 16)) == "cave_floor", "Emberlode Mine entrance must be cave floor")
	_check(terrain.terrain_for_hex(Vector2i(-252, 18)) == "path", "Emberlode Mine south door must remain open")
	_check(terrain.terrain_for_hex(Vector2i(-252, 20)) == "path", "Emberlode Mine approach must connect to the west road")

	if failures > 0:
		push_error("%d Campaign 2 regional feature test(s) failed." % failures)
		quit(1)
		return
	print("Campaign 2 regional authored terrain feature tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
