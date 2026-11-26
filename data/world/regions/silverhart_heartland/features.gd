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
## Source buildSideQuestContent: Reddale guildhouse + (14, -10), radius 3.
const MIRABEL_SPIDER_RUIN_CENTRE := Vector2i(160, 24)
const MIRABEL_SPIDER_RUIN_RADIUS := 3
const ELVEN_CAPITAL_CENTRE := Vector2i(-252, 934)
const ELVEN_CANOPY_RADIUS := 18
const ELVEN_CLEARING_RADIUS := 9

## Kragmoor's source anchor is Hollowmere's crossroads plus (+900, -650).
## The mountain is a solid 25-hex massif; only the surface Gate Hall and its
## south approach are carved into it in this terrain-only pass.
const KRAGMOOR_CENTRE := Vector2i(908, -626)
const KRAGMOOR_MASSIF_RADIUS := 25
const KRAGMOOR_GATE_HALL_CENTRE := Vector2i(908, -608)
const KRAGMOOR_GATE_DOOR := Vector2i(908, -605)
const KRAGMOOR_APPROACH_TIP := Vector2i(908, -593)
const CAMPAIGN2_CROSSROADS := Vector2i(8, 24)
## Source buildPlayerCottagePlot places the plot five east and three north of the crossroads.
const PLAYER_COTTAGE_PLOT := Vector2i(13, 27)

## Border forts use the source six-point star geometry (core radius 6,
## twelve-hex points, four-hex lateral spread). Coordinates are the canonical
## Campaign 2 POI anchors; gates and road approaches are separate features.
const NORTHWATCH_CENTRE := Vector2i(268, -21)
const NORTHWATCH_GATE := Vector2i(268, -2)
const NORTHWATCH_SPUR_START := Vector2i(268, 22)
const RIDGEHOLD_CENTRE := Vector2i(426, 43)
## The source gateHex (406, 35) falls outside the generated star-fort wall.
## Put the entrance on the actual west perimeter cell instead.
const RIDGEHOLD_GATE := Vector2i(407, 43)
const RIDGEHOLD_ROAD_END := Vector2i(398, 23)
const STAR_FORT_CORE_RADIUS := 6
const STAR_FORT_POINT_LENGTH := 12
const STAR_FORT_POINT_WIDTH := 4
const STAR_FORT_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

## Source-authored surface rooms for the northern crypt/barrow chain, the
## abandoned house, Lich Chapterhouse, Thieves' Cove and Emberlode Mine.
const ABANDONED_HOUSE_CENTRE := Vector2i(14, -176)
const CRYPT_ENTRANCE_CENTRE := Vector2i(32, -154)
const CRYPT_OSSUARY_CENTRE := Vector2i(40, -154)
const CRYPT_RITUAL_CENTRE := Vector2i(49, -154)
const BARROW_ANTECHAMBER_CENTRE := Vector2i(63, -160)
const BARROW_SANCTUM_CENTRE := Vector2i(72, -160)
const LICH_CHAPTERHOUSE_CENTRE := Vector2i(-39, -346)
const THIEVES_COVE_ENTRANCE_CENTRE := Vector2i(-274, 40)
const EMBERLODE_MINE_CENTRE := Vector2i(-252, 16)
const HOLLOWMERE_GUILD_DEN_CENTRE := Vector2i(-12, -8)

static var _orc_approach_path_cells: Dictionary = {}
static var _orc_approach_path_ready := false
static var _kragmoor_approach_path_cells: Dictionary = {}
static var _kragmoor_approach_path_ready := false
static var _kragmoor_gate_floor_cells: Dictionary = {}
static var _kragmoor_gate_floor_ready := false
static var _northwatch_cells: Dictionary = {}
static var _ridgehold_cells: Dictionary = {}
static var _border_forts_ready := false
static var _dungeon_surface_cells: Dictionary = {}
static var _player_cottage_approach_cells: Dictionary = {}
static var _player_cottage_approach_ready := false
static var _dungeon_surface_ready := false

static func terrain_override_at(hex: Vector2i) -> Dictionary:
	if is_player_cottage_plot_path(hex):
		return {"terrain": "path", "feature_id": "player_cottage_plot_approach"}
	var dungeon_override := _dungeon_surface_override(hex)
	if not dungeon_override.is_empty():
		return dungeon_override
	var spider_ruin_distance := _axial_distance(hex, MIRABEL_SPIDER_RUIN_CENTRE)
	if spider_ruin_distance <= MIRABEL_SPIDER_RUIN_RADIUS:
		return {"terrain": "rocky_outcrop", "feature_id": "reddale_mirabel_spider_ruin", "distance": spider_ruin_distance}
	var fort_override := _border_fort_override(hex)
	if not fort_override.is_empty():
		return fort_override
	if _is_kragmoor_gate_floor(hex):
		return {"terrain": "cave_floor", "feature_id": "kragmoor_gate_hall"}
	if hex == KRAGMOOR_GATE_DOOR:
		return {"terrain": "path", "feature_id": "kragmoor_gate"}
	if is_kragmoor_approach_path(hex):
		return {"terrain": "path", "feature_id": "kragmoor_approach"}
	if _axial_distance(hex, KRAGMOOR_CENTRE) <= KRAGMOOR_MASSIF_RADIUS:
		return {"terrain": "mountain", "feature_id": "kragmoor_massif", "distance": _axial_distance(hex, KRAGMOOR_CENTRE)}
	if hex == DRUID_GROVE_SPRING:
		return {"terrain": "water", "feature_id": "emberwood_grove_spring"}
	if hex == ORC_STRONGHOLD_GATE:
		return {"terrain": "path", "feature_id": "skarnaks_hold_gate"}
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

	var elven_path_start_r := ELVEN_CAPITAL_CENTRE.y - 6
	var elven_path_end_r := ELVEN_CAPITAL_CENTRE.y - ELVEN_CANOPY_RADIUS - 9
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

static func is_player_cottage_plot_path(hex: Vector2i) -> bool:
	_ensure_player_cottage_approach()
	return _player_cottage_approach_cells.has(_hex_key(hex))

static func _ensure_player_cottage_approach() -> void:
	if _player_cottage_approach_ready:
		return
	for q in range(CAMPAIGN2_CROSSROADS.x + 1, PLAYER_COTTAGE_PLOT.x + 1):
		_player_cottage_approach_cells[_hex_key(Vector2i(q, CAMPAIGN2_CROSSROADS.y))] = true
	for r in range(CAMPAIGN2_CROSSROADS.y + 1, PLAYER_COTTAGE_PLOT.y + 1):
		_player_cottage_approach_cells[_hex_key(Vector2i(PLAYER_COTTAGE_PLOT.x, r))] = true
	_player_cottage_approach_ready = true

static func is_herb_patch(hex: Vector2i) -> bool:
	return hex in HERB_PATCH_HEXES

static func is_orc_approach_path(hex: Vector2i) -> bool:
	_ensure_orc_approach_path()
	return _orc_approach_path_cells.has(_hex_key(hex))

static func is_kragmoor_approach_path(hex: Vector2i) -> bool:
	_ensure_kragmoor_approach_path()
	return _kragmoor_approach_path_cells.has(_hex_key(hex))

static func _is_kragmoor_gate_floor(hex: Vector2i) -> bool:
	_ensure_kragmoor_gate_floor()
	return _kragmoor_gate_floor_cells.has(_hex_key(hex))

static func _dungeon_surface_override(hex: Vector2i) -> Dictionary:
	_ensure_dungeon_surface_features()
	var key := _hex_key(hex)
	if _dungeon_surface_cells.has(key):
		return (_dungeon_surface_cells[key] as Dictionary).duplicate()
	return {}

static func _ensure_dungeon_surface_features() -> void:
	if _dungeon_surface_ready:
		return
	# Hollowmere Guild Den: source carveBuilding footprint with a south door.
	_add_source_building_surface_room(_dungeon_surface_cells, HOLLOWMERE_GUILD_DEN_CENTRE, 2, 2, HOLLOWMERE_GUILD_DEN_CENTRE + Vector2i(0, 2), "wood_floor", "hollowmere_guild_den")

	# Abandoned house: a corrected flat-room footprint with a west door.
	_add_flat_surface_room(_dungeon_surface_cells, ABANDONED_HOUSE_CENTRE, 3, 2, ABANDONED_HOUSE_CENTRE + Vector2i(-3, 0), "wood_floor", "abandoned_house")
	for q in range(9, 11):
		_dungeon_surface_cells[_hex_key(Vector2i(q, -176))] = {"terrain": "path", "feature_id": "abandoned_house_approach"}

	# Vessel-Seeker's Crypt: entrance, ossuary and ritual chamber, joined by
	# the short source cave-floor corridors. Lower floors and actors are not
	# represented in this surface terrain layer.
	_add_flat_surface_room(_dungeon_surface_cells, CRYPT_ENTRANCE_CENTRE, 3, 2, CRYPT_ENTRANCE_CENTRE + Vector2i(-3, 0), "cave_floor", "vessel_seeker_crypt_entrance")
	_add_flat_surface_room(_dungeon_surface_cells, CRYPT_OSSUARY_CENTRE, 3, 3, CRYPT_OSSUARY_CENTRE + Vector2i(-3, 0), "cave_floor", "vessel_seeker_crypt_ossuary")
	_add_flat_surface_room(_dungeon_surface_cells, CRYPT_RITUAL_CENTRE, 4, 3, CRYPT_RITUAL_CENTRE + Vector2i(-3, 0), "cave_floor", "vessel_seeker_crypt_ritual")
	_add_surface_corridor(_dungeon_surface_cells, Vector2i(35, -155), Vector2i(36, -154), "vessel_seeker_crypt_corridor")
	_add_surface_corridor(_dungeon_surface_cells, Vector2i(43, -154), Vector2i(45, -154), "vessel_seeker_crypt_corridor")

	# Barrow of Corvin Ashgrave: antechamber and sanctum, also joined by the
	# source horizontal cave-floor passage.
	_add_flat_surface_room(_dungeon_surface_cells, BARROW_ANTECHAMBER_CENTRE, 3, 3, BARROW_ANTECHAMBER_CENTRE + Vector2i(-3, 0), "cave_floor", "corvin_barrow_antechamber")
	_add_flat_surface_room(_dungeon_surface_cells, BARROW_SANCTUM_CENTRE, 4, 3, BARROW_SANCTUM_CENTRE + Vector2i(-3, 0), "cave_floor", "corvin_barrow_sanctum")
	_add_surface_corridor(_dungeon_surface_cells, Vector2i(66, -160), Vector2i(68, -160), "corvin_barrow_corridor")

	# Chapterhouse: source stone floor and keep-wall footprint.
	_add_flat_surface_room(_dungeon_surface_cells, LICH_CHAPTERHOUSE_CENTRE, 4, 3, LICH_CHAPTERHOUSE_CENTRE + Vector2i(3, 0), "stone_floor", "lich_chapterhouse", "keep_wall")

	# Thieves' Cove's ground entrance. The two lower cave floors and tunnel
	# network remain separate interior layers.
	_add_flat_surface_room(_dungeon_surface_cells, THIEVES_COVE_ENTRANCE_CENTRE, 3, 3, THIEVES_COVE_ENTRANCE_CENTRE + Vector2i(-3, 0), "cave_floor", "thieves_cove_entrance")

	# Emberlode's source mine room uses carveBuilding's original positive row
	# shift; retain that authored footprint rather than silently reshaping it.
	_add_source_building_surface_room(_dungeon_surface_cells, EMBERLODE_MINE_CENTRE, 3, 2, EMBERLODE_MINE_CENTRE + Vector2i(0, 2), "cave_floor", "emberlode_mine")
	for r in range(EMBERLODE_MINE_CENTRE.y + 3, 22):
		_dungeon_surface_cells[_hex_key(Vector2i(EMBERLODE_MINE_CENTRE.x, r))] = {"terrain": "path", "feature_id": "emberlode_mine_approach"}

	_dungeon_surface_ready = true

static func _add_flat_surface_room(target: Dictionary, centre: Vector2i, half_width: int, half_height: int, door: Vector2i, floor_terrain: String, prefix: String, wall_terrain: String = "climbable_wall") -> void:
	var floor_cells: Dictionary = {}
	for dq in range(-half_width + 1, half_width):
		var row_shift := -floori(float(dq) / 2.0)
		for dr in range(-half_height + 1, half_height):
			var cell := centre + Vector2i(dq, dr + row_shift)
			floor_cells[_hex_key(cell)] = true
	for key in floor_cells:
		target[key] = {"terrain": floor_terrain, "feature_id": prefix + "_floor"}
	for key in _wall_ring(floor_cells):
		if not target.has(key):
			target[key] = {"terrain": wall_terrain, "feature_id": prefix + "_wall"}
	target[_hex_key(door)] = {"terrain": "path", "feature_id": prefix + "_door"}

static func _add_source_building_surface_room(target: Dictionary, centre: Vector2i, half_width: int, half_height: int, door: Vector2i, floor_terrain: String, prefix: String, wall_terrain: String = "climbable_wall") -> void:
	var floor_cells: Dictionary = {}
	for dq in range(-half_width + 1, half_width):
		var row_shift := floori(float(dq) / 2.0)
		for dr in range(-half_height + 1, half_height):
			var cell := centre + Vector2i(dq, dr + row_shift)
			floor_cells[_hex_key(cell)] = true
	for key in floor_cells:
		target[key] = {"terrain": floor_terrain, "feature_id": prefix + "_floor"}
	for key in _wall_ring(floor_cells):
		if not target.has(key):
			target[key] = {"terrain": wall_terrain, "feature_id": prefix + "_wall"}
	target[_hex_key(door)] = {"terrain": "path", "feature_id": prefix + "_door"}

static func _add_surface_corridor(target: Dictionary, start: Vector2i, finish: Vector2i, feature_id: String) -> void:
	var line: Dictionary = {}
	_add_hex_line(line, start, finish)
	for key in line:
		target[key] = {"terrain": "cave_floor", "feature_id": feature_id}


static func _border_fort_override(hex: Vector2i) -> Dictionary:
	_ensure_border_fort_features()
	var key := _hex_key(hex)
	if _northwatch_cells.has(key):
		return (_northwatch_cells[key] as Dictionary).duplicate()
	if _ridgehold_cells.has(key):
		return (_ridgehold_cells[key] as Dictionary).duplicate()
	return {}

static func _ensure_border_fort_features() -> void:
	if _border_forts_ready:
		return
	_northwatch_cells = _build_star_fort_cells(NORTHWATCH_CENTRE, "northwatch")
	_ridgehold_cells = _build_star_fort_cells(RIDGEHOLD_CENTRE, "ridgehold")

	# Northwatch's south spur follows the source turn hex directly to the
	# gate. The gate itself remains a closed-wall terrain cell, not a path.
	for r in range(NORTHWATCH_SPUR_START.y - 1, NORTHWATCH_GATE.y - 1, -1):
		var cell := Vector2i(NORTHWATCH_SPUR_START.x, r)
		if cell == NORTHWATCH_GATE:
			continue
		_northwatch_cells[_hex_key(cell)] = {"terrain": "path", "feature_id": "northwatch_gate_approach"}

	# The source Ridgehold road is a q-stepped approximation that stops several
	# hexes short of its west gate. Replace that dotted/short spur with a
	# cube-rounded, neighbour-contiguous connection to the authored gate.
	var ridgehold_road: Dictionary = {}
	_add_hex_line(ridgehold_road, RIDGEHOLD_ROAD_END, RIDGEHOLD_GATE)
	for key in ridgehold_road:
		_ridgehold_cells[key] = {"terrain": "path", "feature_id": "ridgehold_gate_approach"}

	# Restore gate semantics after roads: Northwatch is a closable wall gate;
	# Ridgehold's source gate is an open gap in the outer ring.
	_northwatch_cells[_hex_key(NORTHWATCH_GATE)] = {"terrain": "climbable_wall", "feature_id": "northwatch_gate"}
	_ridgehold_cells[_hex_key(RIDGEHOLD_GATE)] = {"terrain": "path", "feature_id": "ridgehold_gate"}

	# Northwatch's inner keep is a radius-four hex disk, a real adjacency ring,
	# and six open corner gaps at radius five.
	var keep_floor := _hex_disk(NORTHWATCH_CENTRE, 4)
	var keep_walls := _wall_ring(keep_floor)
	for key in keep_floor:
		_northwatch_cells[key] = {"terrain": "dirt", "feature_id": "northwatch_keep_floor"}
	for key in keep_walls:
		_northwatch_cells[key] = {"terrain": "keep_wall", "feature_id": "northwatch_keep_wall"}
	for direction in STAR_FORT_DIRECTIONS:
		var gap := NORTHWATCH_CENTRE + direction * 5
		_northwatch_cells[_hex_key(gap)] = {"terrain": "dirt", "feature_id": "northwatch_keep_gap"}

	# Ridgehold's smaller keep is the source flat-room footprint. Its south
	# threshold is the source open door at centre.r + 2.
	var ridgehold_keep_floor: Dictionary = {}
	for dq in range(-2, 3):
		var row_shift := -floori(float(dq) / 2.0)
		for dr in range(-1, 2):
			var cell := RIDGEHOLD_CENTRE + Vector2i(dq, dr + row_shift)
			ridgehold_keep_floor[_hex_key(cell)] = true
	for key in ridgehold_keep_floor:
		_ridgehold_cells[key] = {"terrain": "dirt", "feature_id": "ridgehold_keep_floor"}
	var ridgehold_keep_walls := _wall_ring(ridgehold_keep_floor)
	for key in ridgehold_keep_walls:
		_ridgehold_cells[key] = {"terrain": "keep_wall", "feature_id": "ridgehold_keep_wall"}
	var ridgehold_keep_door := Vector2i(RIDGEHOLD_CENTRE.x, RIDGEHOLD_CENTRE.y + 2)
	_ridgehold_cells[_hex_key(ridgehold_keep_door)] = {"terrain": "path", "feature_id": "ridgehold_keep_door"}
	_border_forts_ready = true

static func _build_star_fort_cells(centre: Vector2i, prefix: String) -> Dictionary:
	var floor_cells := _hex_disk(centre, STAR_FORT_CORE_RADIUS)
	for direction_index in range(STAR_FORT_DIRECTIONS.size()):
		var direction := STAR_FORT_DIRECTIONS[direction_index]
		var lateral_a := STAR_FORT_DIRECTIONS[(direction_index + 2) % 6]
		var lateral_b := STAR_FORT_DIRECTIONS[(direction_index + 4) % 6]
		for step in range(STAR_FORT_CORE_RADIUS + 1, STAR_FORT_CORE_RADIUS + STAR_FORT_POINT_LENGTH + 1):
			var base := centre + direction * step
			floor_cells[_hex_key(base)] = true
			for width in range(1, STAR_FORT_POINT_WIDTH + 1):
				floor_cells[_hex_key(base + lateral_a * width)] = true
				floor_cells[_hex_key(base + lateral_b * width)] = true
	var cells: Dictionary = {}
	for key in floor_cells:
		cells[key] = {"terrain": "dirt", "feature_id": prefix + "_fort_floor"}
	for key in _wall_ring(floor_cells):
		cells[key] = {"terrain": "climbable_wall", "feature_id": prefix + "_fort_wall"}
	return cells

static func _hex_disk(centre: Vector2i, radius: int) -> Dictionary:
	var cells: Dictionary = {}
	for q in range(centre.x - radius, centre.x + radius + 1):
		for r in range(centre.y - radius, centre.y + radius + 1):
			var cell := Vector2i(q, r)
			if _axial_distance(cell, centre) <= radius:
				cells[_hex_key(cell)] = true
	return cells

static func _wall_ring(floor_cells: Dictionary) -> Dictionary:
	var walls: Dictionary = {}
	for key in floor_cells:
		var parts := String(key).split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		for direction in STAR_FORT_DIRECTIONS:
			var neighbour := cell + direction
			var neighbour_key := _hex_key(neighbour)
			if not floor_cells.has(neighbour_key):
				walls[neighbour_key] = true
	return walls

static func _ensure_kragmoor_gate_floor() -> void:
	if _kragmoor_gate_floor_ready:
		return
	# Exact flat-room footprint from source carveFlatRoom(center, 4, 3).
	for dq in range(-3, 4):
		var row_shift := -floori(float(dq) / 2.0)
		for dr in range(-2, 3):
			var cell := KRAGMOOR_GATE_HALL_CENTRE + Vector2i(dq, dr + row_shift)
			_kragmoor_gate_floor_cells[_hex_key(cell)] = true
	_kragmoor_gate_floor_ready = true

static func _ensure_kragmoor_approach_path() -> void:
	if _kragmoor_approach_path_ready:
		return
	# Source paints a continuous cube-rounded hex line from Hollowmere's
	# crossroads to the southern spur tip, then the 12-hex spur to the gate.
	_add_hex_line(_kragmoor_approach_path_cells, CAMPAIGN2_CROSSROADS, KRAGMOOR_APPROACH_TIP)
	for r in range(KRAGMOOR_GATE_DOOR.y + 1, KRAGMOOR_APPROACH_TIP.y + 1):
		_kragmoor_approach_path_cells[_hex_key(Vector2i(KRAGMOOR_GATE_DOOR.x, r))] = true
	_kragmoor_approach_path_ready = true

static func _add_hex_line(target: Dictionary, start: Vector2i, finish: Vector2i) -> void:
	var x1 := start.x
	var z1 := start.y
	var y1 := -x1 - z1
	var x2 := finish.x
	var z2 := finish.y
	var y2 := -x2 - z2
	var steps := maxi(absi(x2 - x1), maxi(absi(y2 - y1), absi(z2 - z1)))
	if steps == 0:
		target[_hex_key(start)] = true
		return
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var fx := lerpf(float(x1), float(x2), t)
		var fy := lerpf(float(y1), float(y2), t)
		var fz := lerpf(float(z1), float(z2), t)
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
		target[_hex_key(Vector2i(rx, rz))] = true

static func feature_id_at(hex: Vector2i) -> String:
	if hex == PLAYER_COTTAGE_PLOT:
		return "player_cottage_plot"
	if is_player_cottage_plot_path(hex):
		return "player_cottage_plot_approach"
	var dungeon_override := _dungeon_surface_override(hex)
	if not dungeon_override.is_empty():
		return String(dungeon_override.get("feature_id", ""))
	if _axial_distance(hex, MIRABEL_SPIDER_RUIN_CENTRE) <= MIRABEL_SPIDER_RUIN_RADIUS:
		return "reddale_mirabel_spider_ruin"
	var fort_override := _border_fort_override(hex)
	if not fort_override.is_empty():
		return String(fort_override.get("feature_id", ""))
	if _is_kragmoor_gate_floor(hex):
		return "kragmoor_gate_hall"
	if hex == KRAGMOOR_GATE_DOOR:
		return "kragmoor_gate"
	if is_kragmoor_approach_path(hex):
		return "kragmoor_approach"
	if _axial_distance(hex, KRAGMOOR_CENTRE) <= KRAGMOOR_MASSIF_RADIUS:
		return "kragmoor_massif"
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
