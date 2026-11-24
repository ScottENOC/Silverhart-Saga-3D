extends SceneTree

const PRESENTATION = preload("res://scripts/world/world_unicorn_track_presentation.gd")
const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")

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
	assert(PRESENTATION.TRACKS.size() == 24, "Wild Unicorn trail must retain all 24 source track markers")
	assert(total == 24, "All 24 source track markers must be presented exactly once across the four streamed chunks")
	assert(PRESENTATION.TRACKS[0]["hex"] == Vector2i(-274, 24), "Trail must start at the source patrol's first rounded waypoint")
	assert(PRESENTATION.TRACKS[23]["hex"] == Vector2i(-275, 21), "Trail must retain the source patrol's final track marker")
	print("Wild Unicorn source hoofprint trail presentation tests passed.")
	quit(0)
