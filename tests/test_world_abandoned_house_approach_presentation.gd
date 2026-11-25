extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const PRESENTATION = preload("res://scripts/world/world_abandoned_house_approach_presentation.gd")

var failures := 0

func _initialize() -> void:
	_test_source_path()
	_test_chunk_scoping()
	if failures > 0:
		push_error("%d abandoned-house approach presentation test(s) failed." % failures)
		quit(1)
		return
	print("Abandoned-house approach presentation tests passed.")
	quit(0)

func _test_source_path() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var site := data.encounter_site("abandoned_house")
	_check(String(site.get("kind", "")) == "haunted_house", "Abandoned House must resolve from canonical geography")
	var centre := Vector2i(int(site.get("q", 0)), int(site.get("r", 0)))
	_check(centre == Vector2i(14, -176), "Abandoned House must retain its source axial anchor")
	_check(centre + PRESENTATION.WAYPOINT_OFFSET == Vector2i(8, -176), "Approach must start at the source north-road waypoint")
	_check(centre + PRESENTATION.DOORWAY_OFFSET == Vector2i(11, -176), "Approach must terminate at the source west doorway")
	var expected: Array[Vector2i] = [centre + Vector2i(-5, 0), centre + Vector2i(-4, 0)]
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, Vector2i(0, -192), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Owning chunk should compose the abandoned-house approach")
	_check(int(result.get("features", 0)) == expected.size(), "All source path cells should be presented exactly once")
	_check(result.get("anchor") == centre and result.get("waypoint") == centre + PRESENTATION.WAYPOINT_OFFSET and result.get("doorway") == centre + PRESENTATION.DOORWAY_OFFSET, "Approach presentation must use the canonical house anchor and source offsets")
	_check(result.get("path_hexes") == expected, "Returned path cells must be derived from the canonical house anchor")
	var path_root := parent.get_node_or_null("AbandonedHouseApproach")
	_check(path_root != null, "Path should have a stable presentation root")
	if path_root != null:
		_check(path_root.get_child_count() == expected.size() * 3, "Each source path cell should receive three restrained worn-earth patches")
	parent.free()

func _test_chunk_scoping() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, Vector2i(24, -192), 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Unrelated chunks should remain valid")
	_check(int(result.get("features", -1)) == 0 and parent.get_child_count() == 0, "Approach dressing must remain in its owning chunk")
	parent.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
