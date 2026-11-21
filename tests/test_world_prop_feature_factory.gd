extends SceneTree

const FACTORY = preload("res://scripts/world/world_prop_feature_factory.gd")
const PROPS = preload("res://data/settlements/hollowmere/props.gd")
const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")

func _initialize() -> void:
	_test_authored_prop_assemblies()
	_test_invalid_prop_data_is_rejected_atomically()
	print("World prop feature factory tests passed.")
	quit(0)

func _materials() -> Dictionary:
	return {
		"dark_wood": StandardMaterial3D.new(),
		"stone": StandardMaterial3D.new(),
		"timber": StandardMaterial3D.new(),
		"fence": StandardMaterial3D.new(),
		"blood": StandardMaterial3D.new()
	}

func _test_authored_prop_assemblies() -> void:
	var parent := Node3D.new()
	var store_parent := Node3D.new()
	store_parent.name = "GeneralStore"
	parent.add_child(store_parent)
	var chapel_parent := Node3D.new()
	chapel_parent.name = "Chapel"
	parent.add_child(chapel_parent)
	var materials := _materials()
	var result := FACTORY.render_features(parent, PROPS.LANDMARK_PROPS, materials, HexGrid.DEFAULT_RADIUS_M)
	assert(result, "Store and chapel landmark props should render")
	var store_assembly := parent.get_node_or_null("GeneralStore/StoreSignPresentation") as Node3D
	assert(store_assembly != null, "Store sign assembly should attach to the authored store building")
	assert(store_assembly.get_node_or_null("StoreSignBoard") != null and store_assembly.get_node_or_null("StoreSign") is Label3D, "Store sign should preserve its board and label")
	var chapel_assembly := parent.get_node_or_null("Chapel/ChapelBellTowerPresentation") as Node3D
	assert(chapel_assembly != null, "Chapel tower assembly should attach to the authored chapel")
	assert(chapel_assembly.get_node_or_null("BellTower") != null and chapel_assembly.get_node_or_null("ChapelCrossBar") != null, "Chapel tower parts should preserve their authored names")
	result = FACTORY.render_features(parent, PROPS.QUEST_PROPS, materials, HexGrid.DEFAULT_RADIUS_M)
	assert(result, "Broken fence and blood trail should render as quest dressing")
	assert(parent.get_node_or_null("BrokenPastureFence/BrokenRailA") != null, "Broken fence rails should remain separate visual parts")
	assert(parent.get_node_or_null("BloodTrailPresentation/BloodTrail_00") != null and parent.get_node_or_null("BloodTrailPresentation/BloodTrail_06") != null, "All blood trail marks should be assembled under a stable root")
	var blood_second := parent.get_node("BloodTrailPresentation/BloodTrail_01") as MeshInstance3D
	var expected_second := HexGrid.axial_to_world(Vector2i(-4, 68), HexGrid.DEFAULT_RADIUS_M, 0.015)
	var assembly_origin := HexGrid.axial_to_world(Vector2i(1, 67), HexGrid.DEFAULT_RADIUS_M, 0.015)
	assert(blood_second.position.distance_to(expected_second - assembly_origin) < 0.001, "Blood trail should retain authored axial placement relative to its assembly anchor")
	result = FACTORY.render_features(parent, PROPS.WAYFINDING_PROPS, materials, HexGrid.DEFAULT_RADIUS_M)
	assert(result, "Crossroads wayfinding prop should render")
	var signpost := parent.get_node_or_null("CrossroadsSignpost") as Node3D
	assert(signpost != null and signpost.get_node_or_null("NorthSouthLabel") is Label3D, "Crossroads signpost should retain both text labels")
	assert(signpost.position.distance_to(HexGrid.axial_to_world(SETTLEMENT.CROSSROADS, HexGrid.DEFAULT_RADIUS_M, 0.0)) < 0.001, "Signpost should retain the crossroads anchor")
	parent.free()

func _test_invalid_prop_data_is_rejected_atomically() -> void:
	var parent := Node3D.new()
	var materials := _materials()
	var invalid: Array = [{"id": "BadProp", "anchor": Vector2i.ZERO, "parts": [{"name": "BadBox", "type": "box", "size": Vector3.ZERO, "material": "timber"}]}]
	assert(not FACTORY.render_features(parent, invalid, materials, HexGrid.DEFAULT_RADIUS_M), "Zero-size box props should be rejected")
	assert(parent.get_child_count() == 0, "Invalid prop definitions must not create partial nodes")
	invalid = [{"id": "BadLabel", "anchor": Vector2i.ZERO, "parts": [{"name": "EmptyLabel", "type": "label3d", "text": ""}]}]
	assert(not FACTORY.render_features(parent, invalid, materials, HexGrid.DEFAULT_RADIUS_M), "Empty labels should be rejected")
	assert(parent.get_child_count() == 0, "Invalid label definitions must not create partial nodes")
	invalid = [
		{"id": "Duplicate", "anchor": Vector2i.ZERO, "parts": [{"name": "A", "type": "box", "size": Vector3.ONE, "material": "timber"}]},
		{"id": "Duplicate", "anchor": Vector2i.ONE, "parts": [{"name": "B", "type": "box", "size": Vector3.ONE, "material": "timber"}]}
	]
	assert(not FACTORY.render_features(parent, invalid, materials, HexGrid.DEFAULT_RADIUS_M), "Duplicate assembly IDs should be rejected")
	assert(parent.get_child_count() == 0, "Duplicate IDs must be rejected before rendering")
	invalid = [{"id": "MissingParent", "parent_node": "NoSuchBuilding", "parts": [{"name": "Part", "type": "box", "size": Vector3.ONE, "material": "timber"}]}]
	assert(not FACTORY.render_features(parent, invalid, materials, HexGrid.DEFAULT_RADIUS_M), "Missing parent nodes should be rejected")
	assert(parent.get_child_count() == 0, "Missing parents must not create partial nodes")
	parent.free()
