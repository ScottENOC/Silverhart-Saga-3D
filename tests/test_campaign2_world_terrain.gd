extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
var failures: int = 0

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	_check(terrain.terrain_for_hex(Vector2i(8, 24)) == "authored", "Hollowmere's authored village area must not be procedurally overwritten")
	_check(terrain.terrain_for_hex(Vector2i(8, -25)) == "authored", "The authored village scene must retain its bridge crossing")
	_check(terrain.terrain_for_hex(Vector2i(100, -27)) == "water", "The local stream must continue beyond the authored village radius")
	_check(terrain.terrain_for_hex(Vector2i(8, -176)) == "path", "The north road must follow the source road trace")
	_check(terrain.terrain_for_hex(Vector2i(7, -366)) == "path", "The Millbrook road waypoint must be retained")
	_check(terrain.terrain_for_hex(Vector2i(908, -626)) == "mountain", "Kragmoor must sit in the north-east mountain region")
	_check(terrain.terrain_for_hex(Vector2i(8, 934)) == "forest", "Sil'thandriel must sit in the southern forest belt")
	_check(terrain.terrain_for_hex(Vector2i(-700, 24)) == "water", "The far-west edge must resolve to the western sea")
	_check(terrain.terrain_for_hex(Vector2i(3000, 24)) == "void", "Coordinates outside the 16x16 world must not generate terrain")
	_check(terrain.location_at(Vector2i(7, -366)).get("name", "") == "Millbrook", "POI lookup must resolve source-anchored locations")
	_check(terrain.chunk_for_hex(Vector2i(-1, -1)) == Vector2i(-1, -1), "Chunk indexing must floor negative axial coordinates")
	_check(terrain.terrain_for_hex(Vector2i(120, 40)) == terrain.terrain_for_hex(Vector2i(120, 40)), "Terrain must be deterministic")
	if failures > 0:
		push_error("%d Campaign 2 terrain test(s) failed." % failures)
		quit(1)
		return
	print("Campaign 2 world terrain tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
