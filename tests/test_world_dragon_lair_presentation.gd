extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const PRESENTATION = preload("res://scripts/world/world_dragon_lair_presentation.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

var failures := 0

func _initialize() -> void:
	_test_lair_outcrop_dressing()
	_test_chunk_scoping()
	if failures > 0:
		push_error("%d Ashveil lair presentation test(s) failed." % failures)
		quit(1)
		return
	print("Ashveil lair presentation tests passed.")
	quit(0)

func _test_lair_outcrop_dressing() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var site := data.encounter_site("ashveil_lair")
	_check(String(site.get("kind", "")) == "dragon_lair", "Ashveil's lair must resolve from canonical geography")
	var centre := Vector2i(int(site.get("q", 0)), int(site.get("r", 0)))
	_check(centre == FEATURES.DRAGON_LAIR_CENTRE, "Ashveil's canonical map anchor must match the terrain feature anchor")
	var chunk_min := Vector2i(floori(float(centre.x) / 24.0) * 24, floori(float(centre.y) / 24.0) * 24)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Ashveil lair presentation should succeed")
	_check(int(result.get("rock_count", 0)) >= 8, "The radius-six outcrop should receive a visible ring of jagged rocks")
	_check(result.get("anchor") == centre, "The outcrop dressing must report and use the canonical lair anchor")
	_check(parent.get_child_count() == int(result.get("rock_count", 0)), "Each generated outcrop rock should have one stable root")
	for child in parent.get_children():
		var parts := String(child.name).split("_")
		_check(parts.size() >= 3 and parts[0] == "AshveilOutcropRock", "Outcrop props should use stable Ashveil IDs")
		if parts.size() >= 3:
			var hex := Vector2i(int(parts[1]), int(parts[2]))
			var distance := _axial_distance(hex, centre)
			_check(distance > FEATURES.DRAGON_LAIR_DEN_RADIUS and distance <= FEATURES.DRAGON_LAIR_OUTER_RADIUS, "Outcrop rocks must stay outside the cave-floor den and inside the source radius")
			_check(data.terrain_for_hex(hex) == "rocky_outcrop", "Outcrop props must sit on source-authored rocky terrain")
	_check(parent.get_node_or_null("Ashveil") == null, "Map dressing must not create or own the Ashveil dragon actor")
	parent.free()

func _test_chunk_scoping() -> void:
	var data := TERRAIN_DATA.new() as Campaign2WorldTerrainData
	var site := data.encounter_site("ashveil_lair")
	_check(String(site.get("kind", "")) == "dragon_lair", "Ashveil's lair must resolve from canonical geography")
	var centre := Vector2i(int(site.get("q", 0)), int(site.get("r", 0)))
	_check(centre == FEATURES.DRAGON_LAIR_CENTRE, "Ashveil's canonical map anchor must match the terrain feature anchor")
	var chunk_min := Vector2i(floori(float(centre.x) / 24.0) * 24 + 24, floori(float(centre.y) / 24.0) * 24)
	var parent := Node3D.new()
	root.add_child(parent)
	var result := PRESENTATION.present_chunk(parent, data, chunk_min, 24, HexGrid.DEFAULT_RADIUS_M)
	_check(bool(result.get("ok", false)), "Unrelated chunks should still validate")
	_check(int(result.get("rock_count", -1)) == 0 and parent.get_child_count() == 0, "Ashveil props should not leak into neighbouring chunks")
	parent.free()

func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
