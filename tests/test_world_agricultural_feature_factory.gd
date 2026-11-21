extends SceneTree

const FACTORY = preload("res://scripts/world/world_agricultural_feature_factory.gd")
const AGRICULTURE = preload("res://data/settlements/hollowmere/agriculture.gd")
const TERRAIN = preload("res://data/settlements/hollowmere/terrain.gd")
const TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")

func _initialize() -> void:
	_test_authored_agriculture_renders()
	_test_invalid_definitions_are_rejected_atomically()
	_test_farm_classification_remains_in_authored_terrain()
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
		parent, AGRICULTURE.FARM_FIELDS, AGRICULTURE.FARM_CROP_ROWS,
		AGRICULTURE.FARM_FENCES, _materials(), HexGrid.DEFAULT_RADIUS_M
	)
	assert(bool(result.get("ok", false)), "All authored agricultural definitions should validate")
	assert(int(result.get("fields", 0)) == 3, "Three authored field surfaces should render")
	assert(int(result.get("crop_rows", 0)) == 17, "All seventeen crop rows should render")
	assert(int(result.get("fences", 0)) == 2, "Both authored fence runs should render")
	for field in AGRICULTURE.FARM_FIELDS:
		var node := parent.get_node_or_null(String(field["id"])) as MeshInstance3D
		assert(node != null and node.mesh != null, "Each authored field should produce a mesh")
	for row in AGRICULTURE.FARM_CROP_ROWS:
		var node := parent.get_node_or_null(String(row["id"])) as MeshInstance3D
		assert(node != null and node.mesh != null, "Each authored crop row should produce a ribbon mesh")
	for fence in AGRICULTURE.FARM_FENCES:
		var root := parent.get_node_or_null(String(fence["id"])) as Node3D
		assert(root != null and root.get_child_count() > 0, "Each authored fence should contain posts and rails")
		assert(root.find_child("Rail_Lower_00", true, false) != null, "Fence rails should have stable segment names")
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

func _test_farm_classification_remains_in_authored_terrain() -> void:
	assert(TERRAIN_PROVIDER.is_farm_land(Vector2i(10, 60), TERRAIN.DEFINITION), "Presentation extraction must preserve farm-land classification")
	assert(not TERRAIN_PROVIDER.is_forest_candidate(Vector2i(10, 60), TERRAIN.DEFINITION), "Procedural forest exclusion must remain unchanged")
