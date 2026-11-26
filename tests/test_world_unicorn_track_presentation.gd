extends SceneTree

const PRESENTATION = preload("res://scripts/world/world_unicorn_track_presentation.gd")
const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")

const EXPECTED_TRACKS := [
	[Vector2i(-274, 24), Vector2i(-3, 8)],
	[Vector2i(-275, 27), Vector2i(-3, 8)],
	[Vector2i(-276, 29), Vector2i(-3, 8)],
	[Vector2i(-277, 32), Vector2i(-9, 4)],
	[Vector2i(-280, 33), Vector2i(-9, 4)],
	[Vector2i(-283, 35), Vector2i(-9, 4)],
	[Vector2i(-286, 36), Vector2i(-8, -4)],
	[Vector2i(-289, 35), Vector2i(-8, -4)],
	[Vector2i(-291, 33), Vector2i(-8, -4)],
	[Vector2i(-294, 32), Vector2i(-4, -8)],
	[Vector2i(-295, 29), Vector2i(-4, -8)],
	[Vector2i(-297, 27), Vector2i(-4, -8)],
	[Vector2i(-298, 24), Vector2i(3, -8)],
	[Vector2i(-297, 21), Vector2i(3, -8)],
	[Vector2i(-296, 19), Vector2i(3, -8)],
	[Vector2i(-295, 16), Vector2i(9, -4)],
	[Vector2i(-292, 15), Vector2i(9, -4)],
	[Vector2i(-289, 13), Vector2i(9, -4)],
	[Vector2i(-286, 12), Vector2i(8, 4)],
	[Vector2i(-283, 13), Vector2i(8, 4)],
	[Vector2i(-281, 15), Vector2i(8, 4)],
	[Vector2i(-278, 16), Vector2i(4, 8)],
	[Vector2i(-277, 19), Vector2i(4, 8)],
	[Vector2i(-275, 21), Vector2i(4, 8)]
]

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	var vale := terrain.encounter_site("unicorn_vale")
	assert(String(vale.get("kind", "")) == "roaming_encounter_area", "Unicorn Vale must resolve from canonical geography")
	assert(Vector2i(int(vale.get("q", 0)), int(vale.get("r", 0))) == Vector2i(-286, 24), "Unicorn Vale must retain its source-derived anchor")
	var total := 0
	for chunk_q in [-13, -12]:
		for chunk_r in [0, 1]:
			var parent := Node3D.new()
			var result: Dictionary = PRESENTATION.present_chunk(parent, terrain, Vector2i(chunk_q, chunk_r) * 24, 24, HexGrid.DEFAULT_RADIUS_M)
			assert(bool(result.get("ok", false)), "Unicorn track chunk should present successfully: %s" % result)
			assert(int(result.get("features", -1)) == parent.get_child_count(), "Each source hoofprint must have exactly one chunk-owned presentation")
			assert(result.get("vale_center") == Vector2i(-286, 24), "Streamed hoofprints must use the canonical vale anchor")
			total += int(result.get("features", 0))
			parent.free()
	assert(PRESENTATION.TRACKS.size() == EXPECTED_TRACKS.size(), "Wild Unicorn trail must retain all 24 source track markers")
	assert(PRESENTATION.VALE_CENTER == Vector2i(-286, 24), "Wild Unicorn Vale must retain the source-derived centre")
	assert(PRESENTATION.PATROL_RADIUS == 12.0, "Wild Unicorn Vale must retain the source patrol radius")
	var expected_waypoints: Array[Vector2i] = [
		Vector2i(-274, 24), Vector2i(-277, 32), Vector2i(-286, 36), Vector2i(-294, 32),
		Vector2i(-298, 24), Vector2i(-295, 16), Vector2i(-286, 12), Vector2i(-278, 16)
	]
	assert(PRESENTATION.PATROL_WAYPOINTS.size() == expected_waypoints.size(), "Wild Unicorn patrol must retain all eight source waypoints")
	for waypoint_index in range(expected_waypoints.size()):
		assert(PRESENTATION.PATROL_WAYPOINTS[waypoint_index] == expected_waypoints[waypoint_index], "Wild Unicorn patrol waypoint must match the source hex rounding")
		assert(PRESENTATION.TRACKS[waypoint_index * 3]["hex"] == expected_waypoints[waypoint_index], "Each three-marker trail segment must begin at its source patrol waypoint")
	assert(total == EXPECTED_TRACKS.size(), "All source track markers must be presented exactly once across the four streamed chunks")
	# Presentation coverage alone does not prove the unicorn can traverse its
	# source patrol loop. Check every waypoint and a walkable hex route between
	# each consecutive pair, including the closing leg.
	for waypoint in expected_waypoints:
		assert(terrain.is_walkable_for_hex(waypoint), "Unicorn patrol waypoint must be on walkable terrain: %s (%s)" % [waypoint, terrain.gameplay_terrain_for_hex(waypoint)])
	for waypoint_index in range(expected_waypoints.size()):
		var start: Vector2i = expected_waypoints[waypoint_index]
		var finish: Vector2i = expected_waypoints[(waypoint_index + 1) % expected_waypoints.size()]
		assert(_has_walkable_route(terrain, start, finish), "Unicorn patrol leg must have a continuous walkable route: %s -> %s" % [start, finish])
	for index in range(EXPECTED_TRACKS.size()):
		var actual: Dictionary = PRESENTATION.TRACKS[index]
		assert(actual.get("hex") == EXPECTED_TRACKS[index][0], "Unicorn hoofprint %d must retain its exact source axial coordinate" % index)
		assert(actual.get("direction") == EXPECTED_TRACKS[index][1], "Unicorn hoofprint %d must retain its exact source travel direction" % index)
	# Moving the canonical POI must move its entire source hoofprint loop,
	# rather than leaving the physical trail behind at the old hard-coded anchor.
	terrain.encounter_sites_by_id["unicorn_vale"]["q"] = -285
	var shifted_parent := Node3D.new()
	var shifted_result: Dictionary = PRESENTATION.present_chunk(
		shifted_parent, terrain, Vector2i(-288, 24), 24, HexGrid.DEFAULT_RADIUS_M
	)
	assert(bool(shifted_result.get("ok", false)), "A corrected canonical vale anchor should still present")
	assert(shifted_result.get("vale_center") == Vector2i(-285, 24), "The trail should report a corrected canonical vale anchor")
	assert(shifted_parent.get_node_or_null("UnicornHoofprints_-273_24") != null, "The first hoofprint must move with the corrected vale anchor")
	shifted_parent.free()
	print("Wild Unicorn source hoofprint trail presentation tests passed.")
	quit(0)


func _has_walkable_route(terrain: Campaign2WorldTerrainData, start: Vector2i, finish: Vector2i) -> bool:
	if not terrain.is_walkable_for_hex(start) or not terrain.is_walkable_for_hex(finish):
		return false
	var margin := 8
	var min_q := mini(start.x, finish.x) - margin
	var max_q := maxi(start.x, finish.x) + margin
	var min_r := mini(start.y, finish.y) - margin
	var max_r := maxi(start.y, finish.y) + margin
	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {"%d,%d" % [start.x, start.y]: true}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == finish:
			return true
		for direction in HexGrid.DIRECTIONS:
			var neighbour: Vector2i = current + direction
			if neighbour.x < min_q or neighbour.x > max_q or neighbour.y < min_r or neighbour.y > max_r:
				continue
			var key := "%d,%d" % [neighbour.x, neighbour.y]
			if visited.has(key) or not terrain.is_walkable_for_hex(neighbour):
				continue
			visited[key] = true
			frontier.append(neighbour)
	return false
