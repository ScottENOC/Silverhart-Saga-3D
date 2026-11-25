extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const PRESENTATION = preload("res://scripts/world/world_cave_entrance_presentation.gd")

var failures := 0

func _initialize() -> void:
	_test_source_entrances()
	_test_chunk_ownership()
	if failures > 0:
		push_error("%d cave entrance presentation test(s) failed." % failures)
		quit(1)
		return
	print("Source cave entrance presentation tests passed.")
	quit(0)

func _test_source_entrances() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var expected := {
		"thieves_cove": {"hex": Vector2i(-277, 40), "node": "ThievesCoveEntrance"},
		"vessel_seekers_crypt": {"hex": Vector2i(29, -154), "node": "VesselSeekersCryptEntrance"},
		"corvin_ashgrave_barrow": {"hex": Vector2i(60, -160), "node": "CorvinAshgraveBarrowEntrance"}
	}
	for entrance in PRESENTATION.ENTRANCES:
		var entrance_id := String(entrance.get("id", ""))
		_check(expected.has(entrance_id), "Every presented cave entrance must have a source-backed test record")
		if not expected.has(entrance_id):
			continue
		var hex: Vector2i = _source_door_hex(data, entrance)
		var chunk_min := Vector2i(floori(float(hex.x) / 24.0) * 24, floori(float(hex.y) / 24.0) * 24)
		var parent := Node3D.new()
		root.add_child(parent)
		var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
		_check(bool(result.get("ok", false)), "%s owning chunk should compose" % entrance_id)
		_check(int(result.get("features", 0)) == 1, "%s should be presented exactly once" % entrance_id)
		var node_name := String(expected[entrance_id]["node"])
		var cave := parent.get_node_or_null(node_name) as Node3D
		_check(cave != null, "%s should have a stable entrance presentation root" % entrance_id)
		if cave != null:
			_check(cave.get_node_or_null("DarkCaveMouth") != null, "%s should have a dark cave mouth" % entrance_id)
			_check(cave.get_node_or_null("LeftJamb") != null and cave.get_node_or_null("RightJamb") != null, "%s should have a two-sided rock frame" % entrance_id)
			var expected_position := HexGrid.axial_to_world(hex, HexGrid.DEFAULT_RADIUS_M, data.elevation_for_hex(hex))
			_check(cave.position.distance_to(expected_position) < 0.001, "%s must use its source entrance coordinate" % entrance_id)
			var outside := HexGrid.axial_to_world(hex + Vector2i(-1, 0), HexGrid.DEFAULT_RADIUS_M)
			var centre := HexGrid.axial_to_world(hex, HexGrid.DEFAULT_RADIUS_M)
			var expected_outward := (outside - centre).normalized()
			_check(cave.transform.basis.z.normalized().dot(expected_outward) > 0.999, "%s cave mouth must face its source west doorway" % entrance_id)
		_check(parent.get_node_or_null("Wolf") == null and parent.get_node_or_null("Malachar") == null, "Map dressing must not spawn encounter actors")
		parent.free()

func _test_chunk_ownership() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	for entrance in PRESENTATION.ENTRANCES:
		var hex: Vector2i = _source_door_hex(data, entrance)
		var owning_min := Vector2i(floori(float(hex.x) / 24.0) * 24, floori(float(hex.y) / 24.0) * 24)
		var unrelated_min := owning_min + Vector2i(24, 24)
		var parent := Node3D.new()
		root.add_child(parent)
		var result := PRESENTATION.present_chunk(parent, data, unrelated_min, 24, HexGrid.DEFAULT_RADIUS_M)
		_check(bool(result.get("ok", false)), "Unrelated chunks should remain valid")
		_check(int(result.get("features", -1)) == 0 and parent.get_child_count() == 0, "Cave entrance dressing must remain chunk-owned")
		parent.free()

func _source_door_hex(data: Campaign2WorldTerrainData, entrance: Dictionary) -> Vector2i:
	var entrance_id := String(entrance.get("id", ""))
	var location: Dictionary = {}
	for candidate in data.locations:
		if candidate is Dictionary and String(candidate.get("id", "")) == entrance_id:
			location = candidate
			break
	assert(not location.is_empty(), "%s must exist in canonical geography" % entrance_id)
	var centre := Vector2i(int(location.get("q", 0)), int(location.get("r", 0)))
	return centre + (entrance["door_offset"] as Vector2i)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
