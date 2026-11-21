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
	var preview = REGIONAL_PREVIEW.new()
	preview._create_materials()
	for terrain_id in ["grass", "forest", "hills", "mountain", "badlands", "sand", "swamp", "rocky_outcrop", "water", "path"]:
		_check(preview.materials.has(terrain_id), "Regional preview must render the %s terrain instead of leaving a hole" % terrain_id)
	preview.free()
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
