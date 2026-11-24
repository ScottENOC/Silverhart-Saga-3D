extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FEATURE_COMPOSER = preload("res://scripts/world/world_settlement_feature_composer.gd")

var failures := 0

func _initialize() -> void:
	_test_diplomatic_quarter_source_inventory()
	_test_plaza_chunk_presentation()
	if failures > 0:
		push_error("%d Silverhart Diplomatic Quarter test(s) failed." % failures)
		quit(1)
		return
	print("Silverhart Diplomatic Quarter tests passed.")
	quit(0)

func _test_diplomatic_quarter_source_inventory() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var entry := _silverhart_entry(data)
	_check(not entry.is_empty(), "Silverhart must resolve from the canonical settlement registry")
	if entry.is_empty():
		return
	var layout: Dictionary = entry.get("definition", {}).get("layout", {})
	var buildings: Array = layout.get("buildings", [])
	var paths: Array = layout.get("paths", [])
	var props: Array = layout.get("props", [])
	var diplomatic_buildings := [
		"silverhart_elven_embassy",
		"silverhart_dwarven_embassy",
		"silverhart_aldenreach_embassy",
		"silverhart_corvane_embassy",
		"silverhart_ironbond_office",
		"silverhart_grand_cathedral"
	]
	for building_id in diplomatic_buildings:
		_check(_has_id(buildings, building_id), "Diplomatic Quarter should retain %s" % building_id)
	for path_id in [
		"silverhart_diplomatic_main_road",
		"silverhart_elven_embassy_approach",
		"silverhart_dwarven_embassy_approach",
		"silverhart_aldenreach_embassy_approach",
		"silverhart_corvane_embassy_approach",
		"silverhart_ironbond_approach",
		"silverhart_cathedral_approach"
	]:
		_check(_has_id(paths, path_id), "Diplomatic Quarter should retain road %s" % path_id)
	var fountains := 0
	var benches := 0
	for prop in props:
		var prop_id := String(prop.get("id", ""))
		if prop_id == "silverhart_diplomatic_plaza_fountain" or prop_id == "silverhart_diplomatic_fountain":
			fountains += 1
		if prop_id in ["silverhart_diplomatic_plaza_bench_west", "silverhart_diplomatic_plaza_bench_east"]:
			benches += 1
	_check(fountains == 1, "The source plaza should have one fountain, not overlapping duplicate fountain assemblies")
	_check(benches == 2, "The diplomatic plaza should retain its two flanking benches")

func _test_plaza_chunk_presentation() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var entry := _silverhart_entry(data)
	if entry.is_empty():
		return
	var parent := Node3D.new()
	root.add_child(parent)
	# Includes the fountain and both benches at (8,-455), plus the
	# southern embassy/cathedral approaches in the same streamed chunk.
	var result: Dictionary = FEATURE_COMPOSER.compose_chunk(
		parent, entry, Vector2i(0, -468), 24, HexGrid.DEFAULT_RADIUS_M
	)
	_check(bool(result.get("ok", false)), "The Diplomatic Quarter chunk should compose through the production feature pipeline")
	_check(parent.get_node_or_null("silverhart_diplomatic_plaza_fountain") != null, "The plaza fountain should render")
	_check(parent.get_node_or_null("silverhart_diplomatic_plaza_bench_west") != null, "The west plaza bench should render")
	_check(parent.get_node_or_null("silverhart_diplomatic_plaza_bench_east") != null, "The east plaza bench should render")
	_check(parent.get_node_or_null("silverhart_diplomatic_fountain") == null, "The obsolete overlapping fountain assembly must not render")
	var fountain := parent.get_node_or_null("silverhart_diplomatic_plaza_fountain")
	if fountain != null:
		_check(fountain.get_child_count() == 2, "The retained stone fountain should contain its basin and column")
	parent.free()

func _silverhart_entry(data: Campaign2WorldTerrainData) -> Dictionary:
	for entry in data.settlement_layouts:
		if String(entry.get("id", "")) == "silverhart":
			return entry
	return {}

func _has_id(records: Array, expected_id: String) -> bool:
	for record in records:
		if String(record.get("id", "")) == expected_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
