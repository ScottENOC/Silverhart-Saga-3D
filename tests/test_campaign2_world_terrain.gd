extends SceneTree
## Millbrook's POI anchor is its house centre; the road endpoint is a separate waypoint.

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const REGIONAL_PREVIEW = preload("res://scripts/world/campaign2_regional_world_preview.gd")
const HOLLOWMERE_PLACEMENTS = preload("res://data/settlements/hollowmere/placements.gd")
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
	_check(terrain.terrain_for_hex(Vector2i(8, 934)) == "forest", "The southern elven forest belt must remain continuous")
	_check(terrain.terrain_for_hex(Vector2i(-700, 24)) == "water", "The far-west edge must resolve to the western sea")
	_check(terrain.terrain_for_hex(Vector2i(3000, 24)) == "void", "Coordinates outside the 16x16 world must not generate terrain")
	_check(terrain.location_at(Vector2i(1, -366)).get("name", "") == "Millbrook", "Millbrook POI lookup must use the settlement centre, not the road endpoint")
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

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
