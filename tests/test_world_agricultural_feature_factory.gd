extends SceneTree

const FACTORY = preload("res://scripts/world/world_agricultural_feature_factory.gd")
const VILLAGE_DATA = preload("res://scripts/world/hollowmere_village_data.gd")
const VILLAGE_SCRIPT = preload("res://scripts/world/hollowmere_village.gd")

func _initialize() -> void:
	_test_authored_agriculture_renders()
	_test_invalid_definitions_are_rejected_atomically()
	_test_hollowmere_delegates_to_shared_factory()
	print("World agricultural feature factory tests passed.")
	quit(0)

func _materials() -> Dictionary:
	return {
		"field": StandardMaterial3D.new(),
		"pasture": StandardMaterial3D.new(),
		"crop": StandardMaterial3D.new(),
		"fence": StandardMaterial3D.new()
	}

func _test_authored_agriculture_renders() -> void:
	var parent := Node3D.new()
	var result: Dictionary = FACTORY.render_features(
		parent, VILLAGE_DATA.FARM_FIELDS, VILLAGE_DATA.FARM_CROP_ROWS,
		VILLAGE_DATA.FARM_FENCES, _materials(), HexGrid.DEFAULT_RADIUS_M
	)
	assert(bool(result.get("ok", false)), "All authored agricultural definitions should validate")
	assert(int(result.get("fields", 0)) == 3, "Three authored field surfaces should render")
	assert(int(result.get("crop_rows", 0)) == 17, "All seventeen crop rows should render")
	assert(int(result.get("fences", 0)) == 2, "Both authored fence runs should render")
	for field in VILLAGE_DATA.FARM_FIELDS:
		var node := parent.get_node_or_null(String(field["id"])) as MeshInstance3D
		assert(node != null and node.mesh != null, "Each authored field should produce a mesh")
	for row in VILLAGE_DATA.FARM_CROP_ROWS:
		var node := parent.get_node_or_null(String(row["id"])) as MeshInstance3D
		assert(node != null and node.mesh != null, "Each authored crop row should produce a ribbon mesh")
	for fence in VILLAGE_DATA.FARM_FENCES:
		var root := parent.get_node_or_null(String(fence["id"])) as Node3D
		assert(root != null and root.get_child_count() > 0, "Each authored fence should contain posts and rails")
		assert(root.find_child("Rail_Lower_00", true, false) != null, "Fence rails should have stable segment names")
	assert(VILLAGE_DATA.is_farm_land(Vector2i(10, 60)), "Presentation extraction must preserve farm-land classification")
	assert(not VILLAGE_DATA.is_forest_candidate(Vector2i(10, 60)), "Procedural forest exclusion must remain unchanged")
	parent.free()

func _test_invalid_definitions_are_rejected_atomically() -> void:
	var parent := Node3D.new()
	var materials := _materials()
	var invalid_fields: Array = [{"id": "BadField", "corners": [Vector2i.ZERO, Vector2i.ONE], "material": "field"}]
	var result: Dictionary = FACTORY.render_features(parent, invalid_fields, [], [], materials, HexGrid.DEFAULT_RADIUS_M)
	assert(not bool(result.get("ok", true)), "A field polygon with fewer than three corners should be rejected")
	assert(parent.get_child_count() == 0, "Invalid field data must not leave partial nodes")
	var duplicate_fields: Array = [
		{"id": "Duplicate", "corners": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN], "material": "field"},
		{"id": "Duplicate", "corners": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN], "material": "field"}
	]
	result = FACTORY.render_features(parent, duplicate_fields, [], [], materials, HexGrid.DEFAULT_RADIUS_M)
	assert(not bool(result.get("ok", true)), "Feature IDs must be unique across the agricultural data set")
	assert(parent.get_child_count() == 0, "Duplicate IDs must be rejected before rendering")
	var invalid_row: Array = [{"id": "BadRow", "points": [Vector2i.ZERO, Vector2i.ONE], "widths": [0.0, 0.2], "material": "crop"}]
	result = FACTORY.render_features(parent, [], invalid_row, [], materials, HexGrid.DEFAULT_RADIUS_M)
	assert(not bool(result.get("ok", true)), "Crop rows with non-positive widths should be rejected")
	assert(parent.get_child_count() == 0, "Invalid crop rows must not leave partial nodes")
	var invalid_fence: Array = [{"id": "BadFence", "points": [Vector2i.ZERO, Vector2i.ONE], "material": "fence", "post_spacing": 0.0}]
	result = FACTORY.render_features(parent, [], [], invalid_fence, materials, HexGrid.DEFAULT_RADIUS_M)
	assert(not bool(result.get("ok", true)), "Fences with non-positive post spacing should be rejected")
	assert(parent.get_child_count() == 0, "Invalid fences must not leave partial nodes")
	var missing_material: Array = [{"id": "BadMaterialField", "corners": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN], "material": "missing"}]
	result = FACTORY.render_features(parent, missing_material, [], [], materials, HexGrid.DEFAULT_RADIUS_M)
	assert(not bool(result.get("ok", true)), "Agricultural features with unresolved materials should be rejected")
	assert(parent.get_child_count() == 0, "Missing materials must be rejected before rendering")
	parent.free()

func _test_hollowmere_delegates_to_shared_factory() -> void:
	var village := VILLAGE_SCRIPT.new() as Node3D
	village.call("_create_materials")
	village.call("_present_authored_settlement")
	for field in VILLAGE_DATA.FARM_FIELDS:
		assert(village.get_node_or_null(String(field["id"])) != null, "Hollowmere should render each field through the shared factory")
	for row in VILLAGE_DATA.FARM_CROP_ROWS:
		assert(village.get_node_or_null(String(row["id"])) != null, "Hollowmere should render each crop row through the shared factory")
	for fence in VILLAGE_DATA.FARM_FENCES:
		assert(village.get_node_or_null(String(fence["id"])) != null, "Hollowmere should render each fence through the shared factory")
	assert(village.get_node_or_null("BrokenPastureFence") != null, "Quest-specific broken fence dressing should remain present")
	assert(village.get_node_or_null("BloodTrailPresentation/BloodTrail_00") != null, "Quest-specific blood trail dressing should remain present")
	village.free()
