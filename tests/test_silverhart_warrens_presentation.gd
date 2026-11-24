extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FEATURE_COMPOSER = preload("res://scripts/world/world_settlement_feature_composer.gd")

var failures := 0

func _initialize() -> void:
	_test_warrens_source_layout()
	_test_warrens_streamed_hut_presentation()
	if failures > 0:
		push_error("%d Silverhart Warrens presentation test(s) failed." % failures)
		quit(1)
		return
	print("Silverhart Warrens presentation tests passed.")
	quit(0)

func _test_warrens_source_layout() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var entry := _silverhart_entry(data)
	_check(not entry.is_empty(), "Silverhart must resolve from the canonical settlement registry")
	if entry.is_empty():
		return
	var layout: Dictionary = entry.get("definition", {}).get("layout", {})
	var buildings: Array = layout.get("buildings", [])
	var expected := {
		"silverhart_warrens_shack_1": {"centre": Vector2i(2, -433), "door": Vector2i(2, -431), "side": "south"},
		"silverhart_warrens_shack_2": {"centre": Vector2i(5, -427), "door": Vector2i(5, -429), "side": "north"},
		"silverhart_warrens_shack_3": {"centre": Vector2i(11, -433), "door": Vector2i(11, -431), "side": "south"}
	}
	for building_id in expected:
		var building := _find_building(buildings, building_id)
		var expected_entry: Dictionary = expected[building_id]
		_check(not building.is_empty(), "The source Warrens should retain %s" % building_id)
		if building.is_empty():
			continue
		_check(String(building.get("archetype", "")) == "hut", "%s should use the ramshackle hut exterior, not a prosperous cottage" % building_id)
		_check(_read_hex(building.get("center")) == expected_entry.get("centre", Vector2i.ZERO), "%s should retain its source position" % building_id)
		_check(_read_hex(building.get("door")) == expected_entry.get("door", Vector2i.ZERO), "%s should retain its source entrance" % building_id)
		_check(String(building.get("door_side", "")) == expected_entry.get("side", ""), "%s should retain its source-facing door" % building_id)

func _test_warrens_streamed_hut_presentation() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var entry := _silverhart_entry(data)
	if entry.is_empty():
		return
	var parent := Node3D.new()
	root.add_child(parent)
	var north_chunk: Dictionary = FEATURE_COMPOSER.compose_chunk(
		parent, entry, Vector2i(0, -456), 24, HexGrid.DEFAULT_RADIUS_M
	)
	var south_chunk: Dictionary = FEATURE_COMPOSER.compose_chunk(
		parent, entry, Vector2i(0, -432), 24, HexGrid.DEFAULT_RADIUS_M
	)
	_check(bool(north_chunk.get("ok", false)), "The northern Warrens shack chunk should compose")
	_check(bool(south_chunk.get("ok", false)), "The southern Warrens shack chunk should compose")
	for building_id in [
		"silverhart_warrens_shack_1",
		"silverhart_warrens_shack_2",
		"silverhart_warrens_shack_3"
	]:
		var building := parent.get_node_or_null(building_id)
		_check(building != null, "%s should render in its owning streamed chunk" % building_id)
		if building != null:
			_check(String(building.get_meta("archetype", "")) == "hut", "%s should be built using the smaller hut shell" % building_id)
			_check(building.get_node_or_null("RoofLeftSlope") != null, "%s should retain its roof shell" % building_id)
	parent.free()

func _silverhart_entry(data: Campaign2WorldTerrainData) -> Dictionary:
	for entry in data.settlement_layouts:
		if String(entry.get("id", "")) == "silverhart":
			return entry
	return {}

func _find_building(buildings: Array, building_id: String) -> Dictionary:
	for building in buildings:
		if String(building.get("id", "")) == building_id:
			return building
	return {}

func _read_hex(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
	return Vector2i.ZERO

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
