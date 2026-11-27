extends SceneTree
## Millbrook's POI anchor is its house centre; the road endpoint is a separate waypoint.

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const REGIONAL_PREVIEW = preload("res://scripts/world/campaign2_regional_world_preview.gd")
const HOLLOWMERE_PLACEMENTS = preload("res://data/settlements/hollowmere/placements.gd")
const REGIONAL_HYDROLOGY = preload("res://data/world/regions/silverhart_heartland/hydrology.gd")
var failures: int = 0

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	_check(terrain.terrain_for_hex(Vector2i(8, 24)) == "path", "Hollowmere crossroads must resolve from authored settlement path data")
	_check(terrain.terrain_for_hex(Vector2i(8, -25)) == "path", "The authored bridge crossing must resolve as a traversable path")
	_check(terrain.terrain_for_hex(Vector2i(100, -27)) == "water", "The local stream must continue beyond the authored village radius")
	_check(terrain.terrain_for_hex(Vector2i(8, -176)) == "path", "The north road must follow the source road trace")
	_check(terrain.terrain_for_hex(Vector2i(1, -366)) == "authored", "Millbrook's house footprint must be authored, not procedural")
	_check(terrain.terrain_for_hex(Vector2i(5, -366)) == "path", "Millbrook's door spur must be rendered as a path")
	_check(terrain.terrain_for_hex(Vector2i(7, -366)) == "path", "The Millbrook road endpoint must be retained")
	_check(terrain.terrain_for_hex(Vector2i(908, -626)) == "mountain", "Kragmoor must sit in the north-east mountain region")
	var kragmoor_peak := terrain.elevation_for_hex(Vector2i(908, -626))
	var kragmoor_mid_slope := terrain.elevation_for_hex(Vector2i(908, -613))
	var kragmoor_foothill := terrain.elevation_for_hex(Vector2i(900, -601))
	_check(kragmoor_peak > 20.0, "Kragmoor's massif centre must rise into a distinct mountain peak")
	_check(kragmoor_peak > kragmoor_mid_slope and kragmoor_mid_slope > kragmoor_foothill, "Kragmoor's authored massif must descend from peak through slope to foothill")
	_check(kragmoor_foothill > 0.0, "Kragmoor's massif must retain a raised foothill edge")
	_check(terrain.elevation_for_hex(Vector2i(908, -626)) == kragmoor_peak, "Kragmoor mountain relief must be deterministic")
	_check(is_zero_approx(terrain.elevation_for_hex(Vector2i(908, -608))), "The Kragmoor gate hall floor must remain at the valley datum")
	_check(is_zero_approx(terrain.elevation_for_hex(Vector2i(908, -593))), "The southern Kragmoor approach must remain a level traversable road")
	_test_border_fort_gate_approaches(terrain)
	_check(terrain.terrain_for_hex(Vector2i(8, 934)) == "forest", "The southern elven forest belt must remain continuous")
	_check(terrain.terrain_for_hex(Vector2i(-700, 24)) == "water", "The far-west edge must resolve to the western sea")
	_check(terrain.terrain_for_hex(Vector2i(3000, 24)) == "void", "Coordinates outside the 16x16 world must not generate terrain")
	_check(terrain.location_at(Vector2i(1, -366)).get("name", "") == "Millbrook", "Millbrook POI lookup must use the settlement centre, not the road endpoint")
	var vampire_grave := terrain.encounter_site("vampire_grave")
	_check(vampire_grave.get("kind", "") == "grave", "Vampire Grave must be available from the canonical encounter-site registry")
	_check(terrain.encounter_site_at(Vector2i(-256, 28)).get("id", "") == "vampire_grave", "Vampire Grave lookup must resolve its source axial coordinate")
	var unicorn_vale := terrain.encounter_site("unicorn_vale")
	_check(unicorn_vale.get("kind", "") == "roaming_encounter_area", "Unicorn Vale must resolve through the canonical encounter-site lookup")
	_check(terrain.encounter_site_at(Vector2i(-286, 24)).get("id", "") == "unicorn_vale", "Unicorn Vale lookup must resolve its source patrol-area anchor")
	_check(not terrain.is_location_marker_visible(unicorn_vale), "Unicorn Vale must remain an exploration encounter area, not a permanent public map marker")
	var exploration_sites := {
		"thieves_cove": "cave_network",
		"vessel_seekers_crypt": "dungeon",
		"corvin_ashgrave_barrow": "dungeon",
	}
	for cave_id in exploration_sites:
		var cave_site := terrain.encounter_site(cave_id)
		_check(cave_site.get("kind", "") == exploration_sites[cave_id], "%s must retain its source-authored site kind in the canonical registry" % cave_id)
		var cave_hex := Vector2i(int(cave_site.get("q", 0)), int(cave_site.get("r", 0)))
		_check(terrain.encounter_site_at(cave_hex).get("id", "") == cave_id, "%s must resolve by its source geography anchor" % cave_id)
		_check(not terrain.is_location_marker_visible(cave_site), "%s must remain an exploration site, not a permanent public map marker" % cave_id)
	var farmstead_den := terrain.encounter_site("farm_wolf_den")
	_check(farmstead_den.get("kind", "") == "wolf_den", "Old Mac farmstead wolf den must be available from the encounter-site registry")
	_check(terrain.encounter_site_at(Vector2i(-59, 204)).get("id", "") == "farm_wolf_den", "Wolf den lookup must resolve its source axial coordinate")
	_check(terrain.encounter_site_at(Vector2i(-42, 72)).is_empty(), "The obsolete hard-coded farm den coordinate must no longer resolve")
	_check(HOLLOWMERE_PLACEMENTS.FARM_WOLF_DEN_HEX == Vector2i(-59, 204), "The live farm-wolf encounter must use the canonical source den coordinate")
	_check(terrain.chunk_for_hex(Vector2i(-1, -1)) == Vector2i(-1, -1), "Chunk indexing must floor negative axial coordinates")
	_check(terrain.terrain_for_hex(Vector2i(150, -200)) == "rocky_outcrop", "Unpainted grassland must use the original Campaign 2 rocky-outcrop clump")
	_check(terrain.terrain_for_hex(Vector2i(528, 284)) == "hills", "Greenskin macro terrain must retain faction-specific hills instead of being replaced by local grassland noise")
	_check(terrain.terrain_for_hex(Vector2i(528, 24)) == "badlands", "Greenskin macro terrain must retain faction-specific badlands variation")
	var preview = REGIONAL_PREVIEW.new()
	preview._create_materials()
	preview.terrain_data = terrain
	preview.ecology_simulation = WorldSimulation.new()
	preview._populate_chunk_gameplay_cells(Vector2i(0, 1))
	_check(preview.ecology_simulation.map_data.is_walkable(Vector2i(8, 24)), "Regional streamed chunks must register authored roads in the shared gameplay map")
	_check(preview.ecology_simulation.map_data.elevation_at(Vector2i(8, 24)) == terrain.elevation_for_hex(Vector2i(8, 24)), "Regional gameplay cells must retain source terrain elevation")
	preview._populate_chunk_gameplay_cells(Vector2i(4, -2))
	_check(preview.ecology_simulation.map_data.has_cell(Vector2i(100, -27)), "Regional streamed chunks must register local stream cells for movement rules")
	_check(not preview.ecology_simulation.map_data.is_walkable(Vector2i(100, -27)), "Regional water cells must block player movement")
	preview.ecology_simulation.free()
	for terrain_id in ["grass", "forest", "hills", "mountain", "badlands", "sand", "swamp", "rocky_outcrop", "dirt", "wood_floor", "stone_floor", "cave_floor", "climbable_wall", "keep_wall", "water", "path"]:
		_check(preview.materials.has(terrain_id), "Regional preview must render the %s terrain instead of leaving a hole" % terrain_id)
	preview.free()
	_check(terrain.terrain_for_hex(Vector2i(120, 40)) == terrain.terrain_for_hex(Vector2i(120, 40)), "Terrain must be deterministic")
	# Shared terrain vertices must be identical when generated from either
	# side of a chunk boundary. The same three global cells define each vertex.
	var seam_hex := Vector2i(23, -11)
	_check(is_equal_approx(
		terrain.shared_vertex_elevation(seam_hex, 0),
		terrain.shared_vertex_elevation(seam_hex + HexGrid.DIRECTIONS[0], 4)
	), "Adjacent chunks must calculate the same shared boundary vertex height")
	_check(is_equal_approx(
		terrain.shared_vertex_elevation(seam_hex, 1),
		terrain.shared_vertex_elevation(seam_hex + HexGrid.DIRECTIONS[5], 5)
	), "Shared vertex heights must agree across a second axial edge orientation")
	_check(terrain.shared_vertex_elevation(seam_hex, -1) == terrain.elevation_for_hex(seam_hex), "Invalid corner indices must safely fall back to the cell height")
	_test_strategic_road_elevation(terrain)
	_test_water_surface_and_shoreline(terrain)
	_test_heartland_stream_connectivity()
	_test_strategic_road_stream_crossings(terrain)
	_test_chunk_boundary_consistency(terrain)
	_check(terrain.terrain_for_hex(Vector2i(-43, -343)) == "keep_wall", "Chapterhouse keep wall must resolve to its own terrain type")
	_check(not terrain.is_walkable_for_hex(Vector2i(-43, -343)), "Keep-wall cells must block traversal")
	if failures > 0:
		push_error("%d Campaign 2 terrain test(s) failed." % failures)
		quit(1)
		return
	print("Campaign 2 world terrain tests passed.")
	quit(0)


func _test_strategic_road_elevation(terrain) -> void:
	_check(not terrain.road_cells.is_empty(), "The source road manifest should populate strategic road cells")
	var highest_road_elevation := 0.0
	var maximum_adjacent_grade := 0.0
	for key in terrain.road_cells:
		var coordinates := String(key).split(",")
		if coordinates.size() != 2:
			continue
		var hex := Vector2i(int(coordinates[0]), int(coordinates[1]))
		if terrain.terrain_for_hex(hex) != "path":
			continue
		var road_height: float = terrain.elevation_for_hex(hex)
		highest_road_elevation = maxf(highest_road_elevation, road_height)
		for direction in HexGrid.DIRECTIONS:
			var neighbour := hex + direction
			if not terrain.road_cells.has("%d,%d" % [neighbour.x, neighbour.y]):
				continue
			if terrain.terrain_for_hex(neighbour) != "path":
				continue
			maximum_adjacent_grade = maxf(
				maximum_adjacent_grade,
				absf(road_height - terrain.elevation_for_hex(neighbour))
			)
	_check(
		highest_road_elevation > 0.05,
		"Strategic roads outside the flat village should inherit some surrounding terrain elevation"
	)
	_check(
		maximum_adjacent_grade <= 2.0,
		"Adjacent strategic road cells should not form abrupt vertical steps (max observed %.2fm)" % maximum_adjacent_grade
	)


func _test_heartland_stream_connectivity() -> void:
	# Enumerate the deterministic authored stream footprint, then flood-fill
	# with the six axial neighbours. This catches disconnected meanders,
	# isolated width-expansion cells and breaks at the Northwatch/Ridgehold link.
	var stream_cells: Dictionary = {}
	for q in range(-90, 463):
		for r in range(-100, 101):
			var hex := Vector2i(q, r)
			if REGIONAL_HYDROLOGY.is_stream_hex(hex):
				stream_cells["%d,%d" % [q, r]] = hex
	_check(not stream_cells.is_empty(), "The heartland hydrology must generate stream cells")

	if stream_cells.is_empty():
		return

	var first_key: String = stream_cells.keys()[0]
	var queue: Array[Vector2i] = [stream_cells[first_key]]
	var visited: Dictionary = {first_key: true}
	var queue_index := 0
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		for direction in HexGrid.DIRECTIONS:
			var neighbour: Vector2i = current + direction
			var neighbour_key := "%d,%d" % [neighbour.x, neighbour.y]
			if stream_cells.has(neighbour_key) and not visited.has(neighbour_key):
				visited[neighbour_key] = true
				queue.append(neighbour)
	_check(
		visited.size() == stream_cells.size(),
		"Every Silverhart heartland stream cell must belong to one connected waterway (reachable %d of %d)" % [visited.size(), stream_cells.size()]
	)
	var ridgehold_stream_hex := Vector2i(426, roundi(REGIONAL_HYDROLOGY.stream_centre_r(426)))
	_check(
		REGIONAL_HYDROLOGY.is_stream_hex(Vector2i(268, -43))
		and REGIONAL_HYDROLOGY.is_stream_hex(Vector2i(290, 1))
		and REGIONAL_HYDROLOGY.is_stream_hex(ridgehold_stream_hex),
		"The Northwatch moat and Ridgehold downstream channel must remain part of the continuous stream"
	)


func _test_strategic_road_stream_crossings(terrain) -> void:
	var crossing_count := 0
	for key in terrain.road_cells:
		var coordinates := String(key).split(",")
		if coordinates.size() != 2:
			continue
		var hex := Vector2i(int(coordinates[0]), int(coordinates[1]))
		if not REGIONAL_HYDROLOGY.is_stream_hex(hex):
			continue
		crossing_count += 1
		_check(
			terrain.terrain_for_hex(hex) == "path",
			"An authored strategic road must remain visible where it crosses the local stream at %s" % key
		)
		_check(
			terrain.is_walkable_for_hex(hex),
			"Strategic road/stream crossings must remain traversable at %s" % key
		)
		_check(
			is_finite(terrain.elevation_for_hex(hex)),
			"Strategic road/stream crossing elevation must remain finite at %s" % key
		)
	_check(
		crossing_count > 0,
		"The authored strategic road network must retain at least one explicit local-stream crossing"
	)


func _test_chunk_boundary_consistency(terrain) -> void:
	# A q-axis seam and an r-axis seam both use negative and positive chunk
	# ownership rules. Each side must produce the same two shared edge heights.
	_assert_shared_chunk_edge(
		terrain,
		Vector2i(23, -11),
		Vector2i(24, -11),
		"Ordinary terrain across the q=24 chunk boundary"
	)
	_assert_shared_chunk_edge(
		terrain,
		Vector2i(911, -626),
		Vector2i(912, -626),
		"Kragmoor mountain relief across the q=912 chunk boundary"
	)
	var crossing_a := Vector2i(382, 23)
	var crossing_b := Vector2i(382, 24)
	_check(
		terrain.terrain_for_hex(crossing_a) == "path"
		and terrain.terrain_for_hex(crossing_b) == "path"
		and terrain.is_walkable_for_hex(crossing_a)
		and terrain.is_walkable_for_hex(crossing_b),
		"The road/stream crossing must remain a traversable road across the r=24 chunk boundary"
	)
	_assert_shared_chunk_edge(
		terrain,
		crossing_a,
		crossing_b,
		"Road-over-stream crossing across the r=24 chunk boundary"
	)

	# Find a real water-to-bank edge that is also a streamed chunk boundary.
	# This checks the shoreline vertex rule in the same independently-owned
	# chunk situation used by the renderer, not just within one chunk.
	var found_water_seam := false
	for q in range(REGIONAL_HYDROLOGY.STREAM_Q_MIN, REGIONAL_HYDROLOGY.STREAM_Q_MAX + 1):
		for r in range(-100, 101):
			var water_hex := Vector2i(q, r)
			if terrain.terrain_for_hex(water_hex) != "water":
				continue
			for direction in HexGrid.DIRECTIONS:
				var bank_hex := water_hex + direction
				if terrain.chunk_for_hex(water_hex) == terrain.chunk_for_hex(bank_hex):
					continue
				if terrain.terrain_for_hex(bank_hex) in ["water", "void"]:
					continue
				_assert_shared_chunk_edge(
					terrain,
					water_hex,
					bank_hex,
					"Water shoreline across a streamed chunk boundary"
				)
				found_water_seam = true
				break
			if found_water_seam:
				break
		if found_water_seam:
			break
	_check(
		found_water_seam,
		"The generated heartland stream must include a water-to-bank edge across a chunk boundary"
	)


func _assert_shared_chunk_edge(terrain, first_hex: Vector2i, second_hex: Vector2i, label: String) -> void:
	_check(
		terrain.chunk_for_hex(first_hex) != terrain.chunk_for_hex(second_hex),
		"%s must actually cross independently loaded chunks" % label
	)
	var corners := HexGrid.corner_offsets(HexGrid.DEFAULT_RADIUS_M)
	var first_centre := HexGrid.axial_to_world(first_hex, HexGrid.DEFAULT_RADIUS_M)
	var second_centre := HexGrid.axial_to_world(second_hex, HexGrid.DEFAULT_RADIUS_M)
	var shared_vertices := 0
	for first_corner in range(HexGrid.SIDE_COUNT):
		var first_position := first_centre + Vector3(corners[first_corner].x, 0.0, corners[first_corner].y)
		for second_corner in range(HexGrid.SIDE_COUNT):
			var second_position := second_centre + Vector3(corners[second_corner].x, 0.0, corners[second_corner].y)
			if first_position.distance_to(second_position) > 0.001:
				continue
			shared_vertices += 1
			_check(
				is_equal_approx(
					terrain.shared_vertex_elevation(first_hex, first_corner),
					terrain.shared_vertex_elevation(second_hex, second_corner)
				),
				"%s must generate identical shared vertex heights" % label
			)
	_check(
		shared_vertices == 2,
		"%s must resolve exactly two common edge vertices (found %d)" % [label, shared_vertices]
	)


func _test_water_surface_and_shoreline(terrain) -> void:
	var water_hex := Vector2i(100, -27)
	_check(terrain.terrain_for_hex(water_hex) == "water", "The shoreline test anchor must remain a stream cell")
	for corner_index in range(HexGrid.SIDE_COUNT):
		_check(
			is_equal_approx(terrain.shared_vertex_elevation(water_hex, corner_index), terrain.WATER_SURFACE_ELEVATION),
			"Every vertex around a water hex must remain on the same flat water datum"
		)
	var found_land_boundary := false
	var corners := HexGrid.corner_offsets(HexGrid.DEFAULT_RADIUS_M)
	for direction in HexGrid.DIRECTIONS:
		var neighbour := water_hex + direction
		if terrain.terrain_for_hex(neighbour) in ["water", "void"]:
			continue
		for water_corner in range(HexGrid.SIDE_COUNT):
			var water_vertex := HexGrid.axial_to_world(water_hex, HexGrid.DEFAULT_RADIUS_M) + Vector3(
				corners[water_corner].x, 0.0, corners[water_corner].y
			)
			for land_corner in range(HexGrid.SIDE_COUNT):
				var land_vertex := HexGrid.axial_to_world(neighbour, HexGrid.DEFAULT_RADIUS_M) + Vector3(
					corners[land_corner].x, 0.0, corners[land_corner].y
				)
				if water_vertex.distance_to(land_vertex) > 0.001:
					continue
				found_land_boundary = true
				_check(
					is_equal_approx(
						terrain.shared_vertex_elevation(water_hex, water_corner),
						terrain.shared_vertex_elevation(neighbour, land_corner)
					),
					"Water and adjoining land must share exactly the same shoreline vertex height"
				)
	_check(found_land_boundary, "The stream test anchor must include an adjoining land shoreline")
	_check(
		is_equal_approx(terrain.elevation_for_hex(water_hex), terrain.WATER_SURFACE_ELEVATION),
		"Water gameplay elevation must remain unchanged by shoreline presentation"
	)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _test_border_fort_gate_approaches(terrain) -> void:
	# Northwatch deliberately keeps a closed gate wall. Its approach must reach
	# the immediately adjacent outside hex without overwriting the gate itself.
	var northwatch_gate := Vector2i(268, -2)
	var northwatch_fort_tip := Vector2i(268, -3)
	_check(terrain.terrain_for_hex(northwatch_gate) == "climbable_wall", "Northwatch's gate must retain its closed-wall terrain")
	_check(not terrain.is_walkable_for_hex(northwatch_gate), "Northwatch's closed gate must block movement until opened")
	_check(terrain.terrain_for_hex(northwatch_fort_tip) == "dirt", "Northwatch's source star-fort tip must remain a fort floor")
	_check(terrain.is_walkable_for_hex(northwatch_fort_tip), "Northwatch's star-fort tip must remain traversable")
	var northwatch_path_count := 0
	for r in range(21, -5, -1):
		var cell := Vector2i(268, r)
		if cell == northwatch_gate or cell == northwatch_fort_tip:
			continue
		_check(terrain.terrain_for_hex(cell) == "path", "Northwatch's gate spur must be continuous at %s" % cell)
		_check(terrain.is_walkable_for_hex(cell), "Northwatch's gate spur must be walkable at %s" % cell)
		northwatch_path_count += 1
	_check(northwatch_path_count >= 20, "Northwatch's south approach must retain its full-length spur")

	# Ridgehold's source road terminates at the open west gate; every road cell
	# in the corridor must remain a traversable path after fort walls are built.
	var ridgehold_start := Vector2i(398, 23)
	var ridgehold_gate := Vector2i(407, 43)
	_check(terrain.terrain_for_hex(ridgehold_gate) == "path", "Ridgehold's west gate must remain an open path")
	_check(terrain.terrain_for_hex(ridgehold_start) == "path", "Ridgehold's road must retain its source approach endpoint")
	_check(terrain.is_walkable_for_hex(ridgehold_gate) and terrain.is_walkable_for_hex(ridgehold_start), "Ridgehold's road and open gate must be traversable")
	var ridgehold_corridor_cells: Dictionary = {}
	for q in range(397, 409):
		for r in range(22, 45):
			var cell := Vector2i(q, r)
			if terrain.terrain_for_hex(cell) == "path" and HexGrid.distance(cell, ridgehold_start) <= HexGrid.distance(ridgehold_start, ridgehold_gate):
				ridgehold_corridor_cells[cell] = true
	_check(ridgehold_corridor_cells.size() >= 8, "Ridgehold's corrected road must contain a connected run of approach cells")
	var visited: Dictionary = {_hex_key_for_test(ridgehold_start): true}
	var queue: Array[Vector2i] = [ridgehold_start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in HexGrid.DIRECTIONS:
			var neighbour: Vector2i = current + direction
			var key := _hex_key_for_test(neighbour)
			if ridgehold_corridor_cells.has(neighbour) and not visited.has(key):
				visited[key] = true
				queue.append(neighbour)
	_check(visited.has(_hex_key_for_test(ridgehold_gate)), "Ridgehold's road must connect continuously from its source endpoint to the open gate")


func _hex_key_for_test(hex: Vector2i) -> Vector2i:
	return hex

