extends SceneTree

const FACTORY = preload("res://scripts/world/world_building_factory.gd")
const SETTLEMENT_BUILDER = preload("res://scripts/world/campaign2_settlement_builder.gd")

func _initialize() -> void:
	_test_supported_archetypes()
	_test_data_driven_dimensions_and_metadata()
	_test_invalid_definitions_are_rejected()
	_test_settlement_builder_delegates_to_factory()
	print("World building factory tests passed.")
	quit(0)

func _test_supported_archetypes() -> void:
	var parent := Node3D.new()
	var settlement := {"id": "factory_test_settlement"}
	var definitions := [
		{"id": "cottage_01", "kind": "house", "center": {"q": 1, "r": 2}, "door": {"q": 4, "r": 2}, "features": ["fireplace"]},
		{"id": "shop_01", "archetype": "shop", "center": {"q": 5, "r": 2}},
		{"id": "chapel_01", "archetype": "chapel", "center": {"q": 9, "r": 2}},
		{"id": "barn_01", "kind": "barn", "center": {"q": 13, "r": 2}, "features": ["double_door"], "door_side": "north", "door_width": 3.1},
		{"id": "manor_01", "archetype": "manor", "center": {"q": 17, "r": 2}}
	]
	for definition in definitions:
		assert(FACTORY.supports_definition(definition), "Expected supported archetype for %s" % definition.id)
		var node := FACTORY.create_building(parent, settlement, definition)
		assert(node != null, "Factory should construct %s" % definition.id)
		assert(node.get_meta("settlement_id") == "factory_test_settlement")
		assert(node.get_meta("building_id") == definition.id)
		if definition.id == "barn_01":
			assert(node.find_child("DoorLeaf_Left", true, false) != null)
			assert(node.find_child("DoorLeaf_Right", true, false) != null)
	assert(parent.get_child_count() == definitions.size(), "Each definition should create exactly one building root")
	parent.free()

func _test_data_driven_dimensions_and_metadata() -> void:
	var parent := Node3D.new()
	var definition := {
		"id": "custom_house",
		"style": "timber_cottage",
		"center": {"q": -3, "r": 7},
		"door": {"q": 0, "r": 7},
		"door_side": "north",
		"dimensions": {"width": 17.0, "depth": 14.0, "wall_height": 3.8},
		"windows_per_side": 1,
		"materials": {"wall_colour": "#fefefe"},
		"features": ["fireplace"]
	}
	var node := FACTORY.create_building(parent, {"id": "test_village"}, definition)
	assert(node != null)
	assert(node.name == "custom_house")
	assert(node.get_meta("archetype") == "cottage")
	assert(node.get_meta("source_door_hex") == Vector2i(0, 7))
	assert(node.find_child("FireplaceHearth", true, false) != null, "Optional features should be data-controlled")
	var wall := node.find_child("SouthWall_Plaster", true, false) as MeshInstance3D
	assert(wall != null and (wall.material_override as StandardMaterial3D).albedo_color == Color("#fefefe"), "Material overrides should be data-controlled")
	assert(node.find_child("DoorLeaf", true, false) != null, "The selected entrance should be constructed")
	assert(node.find_child("EastWall_DoorLintel", true, false) != null or node.find_child("NorthWall_DoorLintel", true, false) != null, "The entrance opening must be closed above the door")
	parent.free()

func _test_invalid_definitions_are_rejected() -> void:
	var parent := Node3D.new()
	assert(not FACTORY.supports_definition({"kind": "house"}), "Building IDs are mandatory")
	assert(not FACTORY.supports_definition({"id": "unknown", "archetype": "wizard_tower"}), "Unknown archetypes must not silently become cottages")
	assert(FACTORY.create_building(parent, {}, {"id": "unknown", "archetype": "wizard_tower"}) == null)
	assert(FACTORY.create_building(parent, {}, {"id": "bad_dimensions", "archetype": "cottage", "dimensions": {"width": 1.0}}) == null)
	assert(parent.get_child_count() == 0, "Invalid definitions must not leave partial scene nodes")
	parent.free()

func _test_settlement_builder_delegates_to_factory() -> void:
	var builder = SETTLEMENT_BUILDER.new([{
		"id": "data_only_village",
		"origin": Vector2i.ZERO,
		"definition": {
			"id": "data_only_village",
			"presentation": {"mode": "chunked"},
			"layout": {
				"buildings": [{
					"id": "data_only_house",
					"kind": "house",
					"center": {"q": 3, "r": 4},
					"door": {"q": 6, "r": 4}
				}]
			},
			"placements": {"characters": []}
		}
	}])
	var parent := Node3D.new()
	builder.add_settlements_in_chunk(parent, Vector2i.ZERO, 16)
	assert(parent.get_child_count() == 1, "Settlement builder should delegate its building to the shared factory")
	assert(parent.get_child(0).get_meta("building_id") == "data_only_house")
	parent.free()
