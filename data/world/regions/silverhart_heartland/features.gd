extends RefCounted
## Source-authored Campaign 2 regional clearings, natural landmarks and site ground.
## Anchors are taken from the canonical geography manifest and original
## campaign2World.js road/build functions. This module owns terrain only;
## NPCs, buildings, props, patrols and quest state remain separate.

const DRUID_GROVE_CENTRE := Vector2i(-266, 10)
const DRUID_GROVE_SPRING := Vector2i(-266, 9)
const DRUID_GROVE_DEN := Vector2i(-269, 2)
const DRUID_GROVE_RADIUS := 5
const HERB_PATCH_HEXES: Array[Vector2i] = [
	Vector2i(-265, 9),
	Vector2i(-267, 11)
]

const GOBLIN_CAMP_CENTRE := Vector2i(203, 23)
const GOBLIN_CAMP_RADIUS := 6
const ORC_STRONGHOLD_CENTRE := Vector2i(428, 17)
const ORC_STRONGHOLD_RADIUS := 7
## The source gateHex is one hex inside the clearing, not on its wall ring.
## The intended west-facing gate is therefore the west ring hex at q-8.
const ORC_STRONGHOLD_GATE := Vector2i(420, 17)
const ORC_ROAD_END := Vector2i(398, 23)
const DRAGON_LAIR_CENTRE := Vector2i(101, -366)
const DRAGON_LAIR_DEN_RADIUS := 2
const DRAGON_LAIR_OUTER_RADIUS := 6
const ELVEN_CAPITAL_CENTRE := Vector2i(-252, 934)
const ELVEN_CANOPY_RADIUS := 18
const ELVEN_CLEARING_RADIUS := 9

static var _orc_approach_path_cells: Dictionary = {}
static var _orc_approach_path_ready := false

static func terrain_override_at(hex: Vector2i) -> Dictionary:
	if hex == DRUID_GROVE_SPRING:
		return {"terrain": "water", "feature_id": "emberwood_grove_spring"}
	if is_orc_approach_path(hex):
		return {"terrain": "path", "feature_id": "skarnaks_hold_approach"}

	var grove_distance := _axial_distance(hex, DRUID_GROVE_CENTRE)
	if grove_distance <= DRUID_GROVE_RADIUS:
		return {
			"terrain": "forest" if grove_distance >= DRUID_GROVE_RADIUS - 1 else "grass",
			"feature_id": "emberwood_grove_clearing",
			"distance": grove_distance
		}

	var dragon_distance := _axial_distance(hex, DRAGON_LAIR_CENTRE)
	if dragon_distance <= DRAGON_LAIR_OUTER_RADIUS:
		return {
			"terrain": "cave_floor" if dragon_distance <= DRAGON_LAIR_DEN_RADIUS else "rocky_outcrop",
			"feature_id": "ashveil_dragon_lair",
			"distance": dragon_distance
		}

	var goblin_distance := _axial_distance(hex, GOBLIN_CAMP_CENTRE)
	if goblin_distance <= GOBLIN_CAMP_RADIUS:
		return {"terrain": "dirt", "feature_id": "skarn_tooth_camp_clearing", "distance": goblin_distance}

	var orc_distance := _axial_distance(hex, ORC_STRONGHOLD_CENTRE)
	if orc_distance <= ORC_STRONGHOLD_RADIUS:
		return {"terrain": "dirt", "feature_id": "skarnaks_hold_clearing", "distance": orc_distance}
	if orc_distance == ORC_STRONGHOLD_RADIUS + 1 and hex != ORC_STRONGHOLD_GATE:
		return {"terrain": "climbable_wall", "feature_id": "skarnaks_hold_wall", "distance": orc_distance}
	if hex == ORC_STRONGHOLD_GATE:
		return {"terrain": "path", "feature_id": "skarnaks_hold_gate"}

	var elven_path_start_r := ELVEN_CAPITAL_CENTRE.y - 6
	var elven_path_end_r := ELVEN_CAPITAL_CENTRE.y - ELVEN_CANOPY_RADIUS - 4
	if hex.x == ELVEN_CAPITAL_CENTRE.x and hex.y <= elven_path_start_r and hex.y >= elven_path_end_r:
		return {"terrain": "path", "feature_id": "silthandriel_approach"}

	var canopy_distance := _axial_distance(hex, ELVEN_CAPITAL_CENTRE)
	if canopy_distance <= ELVEN_CLEARING_RADIUS:
		return {"terrain": "grass", "feature_id": "silthandriel_arrival_clearing", "distance": canopy_distance}
	if canopy_distance <= ELVEN_CANOPY_RADIUS:
		var foliage_roll := _source_pseudo_random(float(hex.x) * 1.7 + 3.0, float(hex.y) * 2.1 + 9.0)
		var is_foliage := canopy_distance >= ELVEN_CANOPY_RADIUS - 3 or foliage_roll < 0.7
		return {
			"terrain": "forest" if is_foliage else "grass",
			"feature_id": "silthandriel_canopy",
			"distance": canopy_distance
		}
	return {}

static func is_herb_patch(hex: Vector2i) -> bool:
	return hex in HERB_PATCH_HEXES

static func is_orc_approach_path(hex: Vector2i) -> bool:
	_ensure_orc_approach_path()
	return _orc_approach_path_cells.has(_hex_key(hex))

static func feature_id_at(hex: Vector2i) -> String:
	if hex == DRUID_GROVE_DEN:
		return "druid_grove_trial_den"
	if hex == DRUID_GROVE_SPRING:
		return "emberwood_grove_spring"
	if is_herb_patch(hex):
		return "emberwood_grove_herb_patch"
	return String(terrain_override_at(hex).get("feature_id", ""))

static func _ensure_orc_approach_path() -> void:
	if _orc_approach_path_ready:
		return
	var start := ORC_ROAD_END
	var finish := ORC_STRONGHOLD_GATE
	var x1 := start.x
	var z1 := start.y
	var y1 := -x1 - z1
	var x2 := finish.x
	var z2 := finish.y
	var y2 := -x2 - z2
	var steps := maxi(absi(x2 - x1), maxi(absi(y2 - y1), absi(z2 - z1)))
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var fx := lerpf(float(x1), float(x2), t)
		var fy := lerpf(float(y1), float(y2), t)
		var fz := lerpf(float(z1), float(z2), t)
		# Match JavaScript Math.round for the original axial cube-line convention.
		var rx := floori(fx + 0.5)
		var ry := floori(fy + 0.5)
		var rz := floori(fz + 0.5)
		var x_diff := absf(float(rx) - fx)
		var y_diff := absf(float(ry) - fy)
		var z_diff := absf(float(rz) - fz)
		if x_diff > y_diff and x_diff > z_diff:
			rx = -ry - rz
		elif y_diff > z_diff:
			ry = -rx - rz
		else:
			rz = -rx - ry
		_orc_approach_path_cells[_hex_key(Vector2i(rx, rz))] = true
	_orc_approach_path_ready = true

static func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), maxi(absi(a.y - b.y), absi((a.x + a.y) - (b.x + b.y))))

static func _source_pseudo_random(x: float, y: float) -> float:
	var value := sin(x * 12.9898 + y * 78.233) * 43758.5453
	return value - floorf(value)

static func _hex_key(hex: Vector2i) -> String:
	return "%d,%d" % [hex.x, hex.y]
