extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const PRESENTATION = preload("res://scripts/world/world_druid_grove_presentation.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

var failures := 0

func _initialize() -> void:
	_test_spring_and_herbs()
	_test_chunk_scoping()
	if failures > 0:
		push_error("%d Druid Grove presentation test(s) failed." % failures)
		quit(1)
		return
	print("Druid Grove presentation tests passed.")
	quit(0)

func _test_spring_and_herbs() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var centre: Vector2i = FEATURES.DRUID_GROVE_CENTRE
	var chunk_min := Vector2i(floori(float(centre.x) / 24.0) * 24, floori(float(centre.y) / 24.0) * 24)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Druid Grove presentation should succeed")
	_check(int(result.get("features", 0)) == 3, "The source spring and both herb patches should be presented")
	var spring := parent.get_node_or_null("DruidGroveSpringPresentation") as Node3D
	_check(spring != null, "The source spring should receive its stone rim")
	if spring != null:
		_check(spring.get_child_count() == HexGrid.SIDE_COUNT, "The spring should have one rim stone per neighbouring hex")
	for hex in FEATURES.HERB_PATCH_HEXES:
		var patch := parent.get_node_or_null("DruidGroveHerbPatch_%d_%d" % [hex.x, hex.y]) as Node3D
		_check(patch != null, "Each source herb patch should have a visual plant cluster")
		if patch != null:
			_check(patch.get_child_count() == 13, "Each herb patch should contain five stems, five leaves and three flowers")
	_check(parent.get_node_or_null("FennOakheart") == null, "Map dressing must not create the druid companion")
	_check(parent.get_node_or_null("FeralWolfDen") == null, "Map dressing must not start or represent the campaign wolf trial")
	parent.free()

func _test_chunk_scoping() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var centre: Vector2i = FEATURES.DRUID_GROVE_CENTRE
	var chunk_min := Vector2i(floori(float(centre.x) / 24.0) * 24 + 24, floori(float(centre.y) / 24.0) * 24)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Unrelated chunks should still validate")
	_check(int(result.get("features", -1)) == 0 and parent.get_child_count() == 0, "Grove features should not leak into neighbouring chunks")
	parent.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
