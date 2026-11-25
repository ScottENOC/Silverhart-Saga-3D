extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const PRESENTATION = preload("res://scripts/world/world_wolf_den_presentation.gd")

var failures := 0

func _initialize() -> void:
	_test_source_anchored_den_dressing()
	_test_chunk_scoping()
	if failures > 0:
		push_error("%d Old Mac wolf den presentation test(s) failed." % failures)
		quit(1)
		return
	print("Old Mac wolf den presentation tests passed.")
	quit(0)

func _test_source_anchored_den_dressing() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var site := data.encounter_site("farm_wolf_den")
	_check(not site.is_empty(), "The wolf den should resolve from the canonical encounter-site manifest")
	var centre := Vector2i(int(site.get("q", 0)), int(site.get("r", 0)))
	_check(centre == Vector2i(-59, 204), "Wolf den presentation must use the source-derived farmhouse offset")
	var chunk_min := Vector2i(floori(float(centre.x) / 24.0) * 24, floori(float(centre.y) / 24.0) * 24)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Wolf den presentation should succeed in its owning chunk")
	_check(int(result.get("features", 0)) == 1, "The owning chunk should receive one den entrance")
	var den := parent.get_node_or_null("OldMacWolfDenPresentation") as Node3D
	_check(den != null, "The den entrance should have a stable presentation root")
	if den != null:
		_check(den.get_node_or_null("ShadowedDenMouth") != null, "The den should have a visibly dark natural entrance")
		_check(den.get_child_count() == 7, "The den should contain three rock forms, a mouth and three scattered bones")
	_check(parent.get_node_or_null("Wolf") == null, "Map dressing must not spawn or own quest wolves")
	parent.free()

func _test_chunk_scoping() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var site := data.encounter_site("farm_wolf_den")
	var centre := Vector2i(int(site.get("q", 0)), int(site.get("r", 0)))
	var chunk_min := Vector2i(floori(float(centre.x) / 24.0) * 24 + 24, floori(float(centre.y) / 24.0) * 24)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Unrelated chunks should still validate")
	_check(int(result.get("features", -1)) == 0 and parent.get_child_count() == 0, "Wolf den dressing must not leak into neighbouring chunks")
	parent.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
