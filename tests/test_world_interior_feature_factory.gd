extends SceneTree

const FACTORY = preload("res://scripts/world/world_interior_feature_factory.gd")
const TAPROOM = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_taproom.gd")
const UPPER_ROOMS = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_upper_rooms.gd")
const TAVERN = preload("res://scripts/world/hollow_tankard.gd")

func _initialize() -> void:
	_test_authored_taproom_features()
	_test_invalid_interior_is_atomic()
	_test_tavern_delegates_furniture()
	_test_upper_rooms_use_authored_data()
	print("World interior feature tests passed.")
	quit(0)

func _materials() -> Dictionary:
	var result := {}
	for key in ["dark_wood", "timber", "stone", "bottle_green"]:
		result[key] = StandardMaterial3D.new()
	return result

func _test_authored_taproom_features() -> void:
	var parent := Node3D.new()
	var root := FACTORY.present(parent, TAPROOM.DEFINITION, _materials())
	assert(root != null)
	assert(root.name == "TaproomFurniture")
	assert(root.get_child_count() == TAPROOM.DEFINITION.features.size())
	assert(root.get_node_or_null("BarFront") != null)
	assert(root.get_node_or_null("FireplaceStone") != null)
	assert(root.get_node_or_null("TableTop") != null)
	assert(root.get_node_or_null("StorageChest") != null)
	var bar := root.get_node("BarFront") as MeshInstance3D
	assert((bar.mesh as BoxMesh).size == Vector3(5.2, 1.15, 0.85))
	assert(bar.position.is_equal_approx(Vector3(2.5, 0.62, -4.45)))
	parent.free()

func _test_invalid_interior_is_atomic() -> void:
	var parent := Node3D.new()
	var bad := {"id":"BadInterior","features":[{"name":"Broken","position":Vector3.ZERO,"size":Vector3(1,0,1),"material":"timber"}]}
	assert(FACTORY.present(parent, bad, _materials()) == null)
	assert(parent.get_child_count() == 0)
	parent.free()

func _test_tavern_delegates_furniture() -> void:
	var tavern := TAVERN.new() as Node3D
	tavern.call("_create_materials")
	tavern.call("_create_furniture")
	assert(tavern.get_node_or_null("TaproomFurniture") != null)
	assert(tavern.get_node("TaproomFurniture").get_child_count() == TAPROOM.DEFINITION.features.size())
	tavern.free()

func _test_upper_rooms_use_authored_data() -> void:
	var tavern := TAVERN.new() as Node3D
	tavern.call("_create_materials")
	var parent := Node3D.new()
	tavern.call("_create_upper_floor_rooms", parent)
	var presentation := parent.get_node_or_null("UpperRoomPresentation")
	assert(presentation != null)
	assert(presentation.get_child_count() == UPPER_ROOMS.DEFINITION.features.size())
	assert(presentation.get_node_or_null("WestPartitionNorth") != null)
	assert(presentation.get_node_or_null("GarrickRoomLabel") != null)
	assert(parent.get_node_or_null("GarrickBed") != null)
	assert(parent.get_node_or_null("SouthGuestBedB") != null)
	assert(parent.get_node_or_null("LandingTable") == null)
	parent.free()
	tavern.free()
