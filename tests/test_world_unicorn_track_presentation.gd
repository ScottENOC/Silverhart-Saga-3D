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
	var total := 0
	for chunk_q in [-13, -12]:
		for chunk_r in [0, 1]:
			var parent := Node3D.new()
			var result: Dictionary = PRESENTATION.present_chunk(parent, terrain, Vector2i(chunk_q, chunk_r) * 24, 24, HexGrid.DEFAULT_RADIUS_M)
			assert(bool(result.get("ok", false)), "Unicorn track chunk should present successfully: %s" % result)
			assert(int(result.get("features", -1)) == parent.get_child_count(), "Each source hoofprint must have exactly one chunk-owned presentation")
			total += int(result.get("features", 0))
			parent.free()
	assert(PRESENTATION.TRACKS.size() == EXPECTED_TRACKS.size(), "Wild Unicorn trail must retain all 24 source track markers")
	assert(total == EXPECTED_TRACKS.size(), "All source track markers must be presented exactly once across the four streamed chunks")
	for index in range(EXPECTED_TRACKS.size()):
		var actual: Dictionary = PRESENTATION.TRACKS[index]
		assert(actual.get("hex") == EXPECTED_TRACKS[index][0], "Unicorn hoofprint %d must retain its exact source axial coordinate" % index)
		assert(actual.get("direction") == EXPECTED_TRACKS[index][1], "Unicorn hoofprint %d must retain its exact source travel direction" % index)
	print("Wild Unicorn source hoofprint trail parity tests passed.")
	quit(0)
