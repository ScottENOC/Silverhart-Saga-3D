extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FEATURE_COMPOSER = preload("res://scripts/world/world_settlement_feature_composer.gd")

var failures := 0

func _initialize() -> void:
	_test_silverhart_wall_manifest()
	_test_city_gate_chunk_presentation()
	_test_wall_and_gate_traversal()
	if failures > 0:
		push_error("%d Silverhart city wall/gate test(s) failed." % failures)
		quit(1)
		return
	print("Silverhart city wall and gate tests passed.")
	quit(0)

func _test_silverhart_wall_manifest() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var entry := _silverhart_entry(data)
	_check(not entry.is_empty(), "Silverhart must be present in the canonical settlement registry")
	if entry.is_empty():
		return
	var definition: Dictionary = entry.get("definition", {})
	var layout: Dictionary = definition.get("layout", {})
	var props: Array = layout.get("props", [])
	var city_wall_segments := 0
	var curtain_wall_segments := 0
	var gate_arches := 0
	var watchtowers := 0
	var wall_ladders := 0
	for prop in props:
		var prop_id := String(prop.get("id", ""))
		if prop_id.begins_with("silverhart_city_wall_") and not prop_id.contains("watchtower"):
			city_wall_segments += 1
		elif prop_id.begins_with("silverhart_curtain_wall_"):
			curtain_wall_segments += 1
		elif prop_id == "silverhart_city_gate_arch":
			gate_arches += 1
		elif prop_id.begins_with("silverhart_city_wall_watchtower_"):
			watchtowers += 1
		elif prop_id.begins_with("silverhart_wall_ladder_"):
			wall_ladders += 1
	_check(city_wall_segments == 357, "The source-derived outer city wall should retain all 357 palisade segments")
	_check(curtain_wall_segments == 138, "The palace curtain wall should retain all 138 source-derived segments")
	_check(gate_arches == 1, "The city wall should retain its authored gate arch")
	_check(watchtowers == 2, "The city gate should retain both source-authored watchtowers")
	_check(wall_ladders == 2, "The palace curtain wall should retain both source-authored climbing ladders")

func _test_city_gate_chunk_presentation() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var entry := _silverhart_entry(data)
	if entry.is_empty():
		return
	var parent := Node3D.new()
	root.add_child(parent)
	# This 24-hex chunk contains the source city gate, both gate towers and
	# the adjoining wall runs, but not the distant palace curtain wall.
	var result: Dictionary = FEATURE_COMPOSER.compose_chunk(
		parent, entry, Vector2i(0, -456), 24, HexGrid.DEFAULT_RADIUS_M
	)
	_check(bool(result.get("ok", false)), "The city gate chunk should compose without missing materials or malformed props")
	_check(parent.get_node_or_null("silverhart_city_gate_arch") != null, "The gate arch should render in its owning chunk")
	_check(parent.get_node_or_null("silverhart_city_wall_watchtower_1") != null, "The western gate watchtower should render")
	_check(parent.get_node_or_null("silverhart_city_wall_watchtower_2") != null, "The eastern gate watchtower should render")
	_check(int(result.get("props", 0)) >= 11, "The gate chunk should render the arch, two towers and adjoining wall segments")
	var arch := parent.get_node_or_null("silverhart_city_gate_arch")
	if arch != null:
		_check(arch.get_child_count() == 3, "The source gate arch should contain two posts and its lintel")
	parent.free()

func _test_wall_and_gate_traversal() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var wall_hex := Vector2i(3, -436)
	var gate_hex := Vector2i(7, -436)
	_check(data.terrain_for_hex(wall_hex) == "palisade_wall", "The outer wall should remain explicitly represented as palisade terrain")
	_check(data.is_walkable_for_hex(wall_hex), "The source wall should remain climbable rather than becoming an impassable terrain tile")
	_check(is_equal_approx(data.movement_multiplier_for_hex(wall_hex), 15.0), "Crossing a palisade should retain its high movement cost")
	_check(is_equal_approx(data.movement_multiplier_for_hex(Vector2i(20, -519)), 2.0), "The source ladder should provide the authored reduced wall-crossing cost")
	_check(is_equal_approx(data.movement_multiplier_for_hex(Vector2i(-4, -507)), 2.0), "The second source ladder should provide the authored reduced wall-crossing cost")
	_check(data.terrain_for_hex(gate_hex) == "path", "The city gate opening should remain a road/path cell, not a wall cell")
	_check(data.is_walkable_for_hex(gate_hex), "The city gate opening should remain traversable")
	var south_approach := Vector2i(8, -436)
	_check(HexGrid.distance(gate_hex, south_approach) == 1, "The city gate arch must touch the south approach road at the wall opening")
	_check(data.terrain_for_hex(south_approach) == "path", "The source south approach must reach the city gate without a wall or terrain gap")
	_check(data.is_walkable_for_hex(south_approach), "The source south approach must remain traversable into the city gate")

func _silverhart_entry(data: Campaign2WorldTerrainData) -> Dictionary:
	for entry in data.settlement_layouts:
		if String(entry.get("id", "")) == "silverhart":
			return entry
	return {}

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
