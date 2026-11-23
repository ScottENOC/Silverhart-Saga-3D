extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FORT_PRESENTATION = preload("res://scripts/world/world_border_fort_presentation.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

var failures := 0

func _initialize() -> void:
	_test_northwatch_keep_dressing()
	_test_northwatch_siege_engine()
	_test_northwatch_catapult()
	_test_northwatch_oil_barrels()
	_test_ridgehold_keep_dressing()
	if failures > 0:
		push_error("%d border fort presentation test(s) failed." % failures)
		quit(1)
		return
	print("Border fort presentation tests passed.")
	quit(0)

func _test_northwatch_keep_dressing() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var centre: Vector2i = FEATURES.NORTHWATCH_CENTRE
	var parent := Node3D.new()
	root.add_child(parent)
	var result := _present_at(data, parent, centre)
	_check(bool(result.get("ok", false)), "Northwatch presentation should succeed")
	_check(parent.get_node_or_null("BorderFortHearth_%d_%d" % [centre.x, centre.y]) != null, "Northwatch keep should have its source-authored hearth")
	_check(_count_named_prefix(parent, "NorthwatchWallLadder_") > 0, "Northwatch's six source ladder posts should be dressed in the chunks that contain them")
	parent.free()

func _test_northwatch_siege_engine() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var hex: Vector2i = FORT_PRESENTATION.NORTHWATCH_SIEGE_ENGINE
	var parent := Node3D.new()
	root.add_child(parent)
	var result := _present_at(data, parent, hex)
	_check(int(result.get("props", 0)) == 1, "Northwatch siege-engine chunk should contain one authored prop")
	_check(parent.get_node_or_null("NorthwatchSiegeEngine") != null, "Northwatch should visibly retain its source siege engine")
	parent.free()

func _test_northwatch_catapult() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var hex: Vector2i = FORT_PRESENTATION.NORTHWATCH_CATAPULT
	var parent := Node3D.new()
	root.add_child(parent)
	var result := _present_at(data, parent, hex)
	_check(int(result.get("props", 0)) == 1, "Greenskin catapult chunk should contain one authored prop")
	_check(parent.get_node_or_null("NorthwatchGreenskinCatapult") != null, "Northwatch should visibly retain the distant greenskin catapult")
	parent.free()

func _test_northwatch_oil_barrels() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var hex := Vector2i(267, -6)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := _present_at(data, parent, hex)
	_check(int(result.get("props", 0)) >= 2, "Northwatch oil-barrel chunk should include both authored barrels (and may include other fort props)")
	_check(_count_named_prefix(parent, "NorthwatchOilBarrel_") == 2, "Both Northwatch oil barrels should be rendered in their shared authored chunk")
	parent.free()

func _test_ridgehold_keep_dressing() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var centre: Vector2i = FEATURES.RIDGEHOLD_CENTRE
	var parent := Node3D.new()
	root.add_child(parent)
	var result := _present_at(data, parent, centre)
	_check(int(result.get("props", 0)) >= 1, "Ridgehold should receive its source-authored keep hearth")
	_check(parent.get_node_or_null("BorderFortHearth_%d_%d" % [centre.x, centre.y]) != null, "Ridgehold keep should have a hearth")
	_check(parent.get_node_or_null("NorthwatchSiegeEngine") == null, "Ridgehold must remain the non-besieged reserve fort")
	parent.free()

func _present_at(data: Campaign2WorldTerrainData, parent: Node3D, hex: Vector2i) -> Dictionary:
	var chunk := data.chunk_for_hex(hex, 24)
	return FORT_PRESENTATION.present_chunk(parent, data, chunk * 24, 24, HexGrid.DEFAULT_RADIUS_M)

func _count_named_prefix(parent: Node, prefix: String) -> int:
	var count := 0
	for child in parent.get_children():
		if String(child.name).begins_with(prefix):
			count += 1
	return count

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
