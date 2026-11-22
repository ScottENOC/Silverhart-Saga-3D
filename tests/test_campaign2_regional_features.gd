extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	var failures: int = 0
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
	_check(terrain.terrain_for_hex(Vector2i(203, 23)) == "dirt", "Goblin camp must have its source dirt clearing")
	_check(terrain.terrain_for_hex(Vector2i(209, 23)) == "dirt", "Goblin camp clearing must include its radius-six edge")
	_check(terrain.terrain_for_hex(Vector2i(428, 17)) == "dirt", "Orc stronghold must have its source dirt clearing")
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

	# Sil'thandriel's canopy has an explicit grass arrival clearing, a dense
	# source-noise woodland band, a foliage perimeter and a north approach.
	_check(terrain.terrain_for_hex(Vector2i(-252, 934)) == "grass", "Elven capital must retain its arrival clearing")
	_check(terrain.terrain_for_hex(Vector2i(-252, 916)) == "forest", "Elven capital outer canopy ring must be forest")
	_check(terrain.terrain_for_hex(Vector2i(-252, 925)) == "forest", "Elven canopy's dense middle band must retain a source foliage cell")
	_check(terrain.terrain_for_hex(Vector2i(-265, 934)) == "grass", "Elven canopy's sparse middle-band cells must remain clearing gaps")
	_check(terrain.terrain_for_hex(Vector2i(-252, 928)) == "path", "Elven capital north approach must start outside the tree clearing")
	_check(terrain.terrain_for_hex(Vector2i(-252, 907)) == "path", "Elven capital north approach must reach its source endpoint")

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
