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
	var grove := data.encounter_site("emberwood_grove")
	_check(String(grove.get("id", "")) == "emberwood_grove", "Druid Grove must resolve from canonical geography")
	_check(String(grove.get("kind", "")) == "druid_grove", "Druid Grove must retain its source-authored kind in the canonical site registry")
	var centre := Vector2i(int(grove.get("q", 0)), int(grove.get("r", 0)))
	_check(centre == FEATURES.DRUID_GROVE_CENTRE, "Druid Grove geography and terrain feature anchors must agree")
	var chunk_min := Vector2i(floori(float(centre.x) / 24.0) * 24, floori(float(centre.y) / 24.0) * 24)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Druid Grove presentation should succeed")
	_check(int(result.get("features", 0)) == 3, "The source spring and both herb patches should be presented")
	_check(result.get("grove_centre") == centre, "Grove dressing must report the canonical geography anchor")
	var spring := parent.get_node_or_null("DruidGroveSpringPresentation") as Node3D
	_check(spring != null, "The source spring should receive its stone rim")
	var spring_hex := centre + (FEATURES.DRUID_GROVE_SPRING - FEATURES.DRUID_GROVE_CENTRE)
	if spring != null:
		_check(spring.get_child_count() == HexGrid.SIDE_COUNT, "The spring should have one rim stone per neighbouring hex")
		var expected_spring_position := HexGrid.axial_to_world(spring_hex, HexGrid.DEFAULT_RADIUS_M, data.elevation_for_hex(spring_hex))
		_check(spring.position.distance_to(expected_spring_position) < 0.001, "The spring must retain its source offset from the canonical Grove centre")
	for source_hex in FEATURES.HERB_PATCH_HEXES:
		var hex: Vector2i = centre + (source_hex - FEATURES.DRUID_GROVE_CENTRE)
		var patch := parent.get_node_or_null("DruidGroveHerbPatch_%d_%d" % [hex.x, hex.y]) as Node3D
		_check(patch != null, "Each source herb patch should have a visual plant cluster")
		if patch != null:
			_check(patch.get_child_count() == 13, "Each herb patch should contain five stems, five leaves and three flowers")
			var expected_patch_position := HexGrid.axial_to_world(hex, HexGrid.DEFAULT_RADIUS_M, data.elevation_for_hex(hex))
			_check(patch.position.distance_to(expected_patch_position) < 0.001, "Herb patches must retain their source offsets from the canonical Grove centre")
	_check(parent.get_node_or_null("FennOakheart") == null, "Map dressing must not create the druid companion")
	_check(parent.get_node_or_null("FeralWolfDen") == null, "Map dressing must not start or represent the campaign wolf trial")
	parent.free()

func _test_chunk_scoping() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var grove := data.location_at(FEATURES.DRUID_GROVE_CENTRE)
	_check(String(grove.get("id", "")) == "emberwood_grove", "Druid Grove must resolve from canonical geography")
	_check(String(grove.get("kind", "")) == "druid_grove", "Druid Grove must retain its source-authored kind in the canonical site registry")
	var centre := Vector2i(int(grove.get("q", 0)), int(grove.get("r", 0)))
	_check(centre == FEATURES.DRUID_GROVE_CENTRE, "Druid Grove geography and terrain feature anchors must agree")
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
