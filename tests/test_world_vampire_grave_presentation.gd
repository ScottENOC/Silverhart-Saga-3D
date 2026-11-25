extends SceneTree

const PRESENTATION = preload("res://scripts/world/world_vampire_grave_presentation.gd")
const TERRAIN_DATA_SCRIPT = preload("res://scripts/world/campaign2_world_terrain_data.gd")

func _initialize() -> void:
	_test_vampire_grave_is_owned_by_one_streamed_chunk()
	print("Vampire Grave presentation tests passed.")
	quit(0)


func _test_vampire_grave_is_owned_by_one_streamed_chunk() -> void:
	var terrain_data = TERRAIN_DATA_SCRIPT.new()
	var parent := Node3D.new()
	var wrong_chunk := PRESENTATION.present_chunk(parent, terrain_data, Vector2i(-288, 0), 24, HexGrid.DEFAULT_RADIUS_M)
	assert(bool(wrong_chunk.get("ok", false)), "A non-owning chunk should be valid")
	assert(int(wrong_chunk.get("features", -1)) == 0, "A non-owning chunk must not emit the grave")
	assert(parent.get_child_count() == 0, "A non-owning chunk must remain empty")

	var owner_chunk := PRESENTATION.present_chunk(parent, terrain_data, Vector2i(-264, 24), 24, HexGrid.DEFAULT_RADIUS_M)
	assert(bool(owner_chunk.get("ok", false)), "The grave's owning chunk should compose")
	assert(int(owner_chunk.get("features", 0)) == 1, "The grave should be emitted exactly once by its owning chunk")
	var grave := parent.get_node_or_null("VampireGravePresentation") as Node3D
	assert(grave != null, "The physical grave-site presentation should have a stable root")
	assert(grave.get_node_or_null("ShallowDisturbedEarth") != null, "The site should show shallow disturbed earth")
	assert(grave.get_node_or_null("SheepCarcass/PartlyBuriedTorso") != null, "The site should show the partly buried sheep")
	assert(grave.get_node_or_null("SheepCarcass/Skull") != null, "The sheep carcass should have a recognisable head")
	assert(grave.get_node_or_null("SheepCarcass/ThroatPuncture_00") != null and grave.get_node_or_null("SheepCarcass/ThroatPuncture_01") != null, "The throat should show the two source-described punctures")
	assert(grave.get_node_or_null("ShatteredFang") != null, "The source-described fang should be visible")
	assert(grave.get_node_or_null("BuriedJournal/LeatherCover") != null, "The source Vampire Grave journal should be physically visible")
	assert(grave.get_node_or_null("BuriedJournal/ParchmentPages") != null, "The source journal should retain a visible parchment block")
	var expected := HexGrid.axial_to_world(Vector2i(-256, 28), HexGrid.DEFAULT_RADIUS_M, terrain_data.elevation_for_hex(Vector2i(-256, 28)))
	assert(grave.position.distance_to(expected) < 0.001, "The presentation must use the canonical geography anchor")
	parent.free()
