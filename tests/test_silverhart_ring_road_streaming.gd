extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FEATURE_COMPOSER = preload("res://scripts/world/world_settlement_feature_composer.gd")

var failures := 0

func _initialize() -> void:
	_test_ring_road_geometry()
	_test_ring_roads_are_composed_by_the_streamed_chunk_pipeline()
	if failures > 0:
		push_error("%d Silverhart ring-road streaming test(s) failed." % failures)
		quit(1)
		return
	print("Silverhart ring-road streaming tests passed.")
	quit(0)


func _test_ring_road_geometry() -> void:
	var entry := _silverhart_entry()
	_check(not entry.is_empty(), "Silverhart must resolve from the canonical settlement registry")
	if entry.is_empty():
		return
	var layout: Dictionary = entry.get("definition", {}).get("layout", {})
	var paths: Array = layout.get("paths", [])
	var expected := {
		"silverhart_outer_ring_road": [
			Vector2i(38, -496), Vector2i(38, -526), Vector2i(8, -526),
			Vector2i(-22, -496), Vector2i(-22, -466), Vector2i(8, -466),
			Vector2i(38, -496)
		],
		"silverhart_middle_ring_road": [
			Vector2i(53, -496), Vector2i(53, -541), Vector2i(8, -541),
			Vector2i(-37, -496), Vector2i(-37, -451), Vector2i(8, -451),
			Vector2i(53, -496)
		]
	}
	for route_id in expected:
		var route := _find_record(paths, route_id)
		_check(not route.is_empty(), "%s must be present in the authored city layout" % route_id)
		if route.is_empty():
			continue
		var points: Array = route.get("points", [])
		var widths: Array = route.get("widths", [])
		_check(points.size() == 7, "%s must retain six corners and its closure" % route_id)
		_check(widths.size() == points.size(), "%s must define a width at every control point" % route_id)
		if points.size() != 7:
			continue
		for index in range(7):
			_check(_read_hex(points[index]) == expected[route_id][index], "%s control point %d must retain its source position" % [route_id, index])
		_check(_read_hex(points[0]) == _read_hex(points[points.size() - 1]), "%s must close without a road gap" % route_id)


func _test_ring_roads_are_composed_by_the_streamed_chunk_pipeline() -> void:
	var entry := _silverhart_entry()
	if entry.is_empty():
		return
	# These chunks intersect the north, east, south and west portions of both
	# source ring roads. Each is composed independently, as in live streaming.
	var chunk_mins := [
		Vector2i(0, -552), Vector2i(24, -552), Vector2i(48, -552),
		Vector2i(24, -504), Vector2i(48, -504),
		Vector2i(-24, -480), Vector2i(0, -480), Vector2i(24, -480),
		Vector2i(-48, -456), Vector2i(-24, -456), Vector2i(0, -456)
	]
	var seen := {
		"silverhart_outer_ring_road": 0,
		"silverhart_middle_ring_road": 0
	}
	for chunk_min in chunk_mins:
		var parent := Node3D.new()
		root.add_child(parent)
		var result: Dictionary = FEATURE_COMPOSER.compose_chunk(
			parent, entry, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M
		)
		_check(bool(result.get("ok", false)), "Silverhart chunk %s should compose successfully" % chunk_min)
		var names: Dictionary = {}
		for child in parent.get_children():
			names[String(child.name)] = true
		for route_id in seen:
			for node_name in names:
				if String(node_name).begins_with(route_id + "_chunk_"):
					seen[route_id] += 1
		parent.free()
	for route_id in seen:
		_check(int(seen[route_id]) >= 3, "%s should render in multiple independently streamed chunks" % route_id)


func _silverhart_entry() -> Dictionary:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	for entry in data.settlement_layouts:
		if String(entry.get("id", "")) == "silverhart":
			return entry
	return {}


func _find_record(records: Array, expected_id: String) -> Dictionary:
	for record in records:
		if String(record.get("id", "")) == expected_id:
			return record
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
