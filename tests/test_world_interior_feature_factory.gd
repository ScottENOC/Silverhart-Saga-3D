extends SceneTree

const FACTORY = preload("res://scripts/world/world_interior_feature_factory.gd")
const TAPROOM = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_taproom.gd")
const UPPER_ROOMS = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_upper_rooms.gd")
const STRUCTURE = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_structure.gd")
const TAVERN = preload("res://scripts/world/hollow_tankard.gd")

func _initialize() -> void:
	_test_authored_taproom_features()
	_test_invalid_interior_is_atomic()
	_test_tavern_delegates_furniture()
	_test_upper_rooms_use_authored_data()
	_test_building_structure_uses_authored_data()
	_test_tavern_building_assembly_keeps_live_door_and_floor_groups()
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

func _test_building_structure_uses_authored_data() -> void:
	var parent := Node3D.new()
	var materials := _materials()
	materials["plaster"] = StandardMaterial3D.new()
	materials["glass"] = StandardMaterial3D.new()
	materials["roof"] = StandardMaterial3D.new()
	var shell := FACTORY.present(parent, STRUCTURE.BUILDING_SHELL, materials)
	var upper := FACTORY.present(parent, STRUCTURE.UPPER_EXTERIOR, materials)
	var floor := FACTORY.present(parent, STRUCTURE.UPPER_FLOOR, materials)
	var roof := FACTORY.present(parent, STRUCTURE.ROOF, materials)
	assert(shell != null and shell.name == "HollowTankardBuilding")
	assert(upper != null and upper.name == "UpperStoreyExterior")
	assert(floor != null and floor.name == "UpperFloorPresentation")
	assert(roof != null and roof.name == "RoofCutaway")
	assert(shell.get_node_or_null("StoneFloorFoundation") != null)
	assert(shell.get_node_or_null("StairStep_00") != null)
	assert(shell.get_node_or_null("StairStep_09") != null)
	assert(shell.get_node_or_null("DoorLintel") != null)
	assert(upper.get_node_or_null("UpperNorthWall") != null)
	assert(roof.get_node_or_null("NorthRoofSlope") != null)
	var foundation := shell.get_node("StoneFloorFoundation") as MeshInstance3D
	assert((foundation.mesh as BoxMesh).size == Vector3(16.7, 0.16, 11.7))
	parent.free()

func _test_tavern_building_assembly_keeps_live_door_and_floor_groups() -> void:
	var tavern := TAVERN.new() as Node3D
	tavern.call("_create_materials")
	tavern.simulation = WorldSimulation.new()
	tavern.tile_mesh = tavern.call("_create_hex_tile_mesh")
	tavern.call("_create_building")
	var building := tavern.get_node_or_null("HollowTankardBuilding")
	var upper_shell := tavern.get_node_or_null("UpperStoreyExterior")
	var upper_floor := tavern.get_node_or_null("UpperFloorPresentation")
	var roof := tavern.get_node_or_null("RoofCutaway")
	assert(building != null and upper_shell != null and upper_floor != null and roof != null)
	assert(building.get_node_or_null("FrontDoorHinge/FrontDoorLeaf") != null)
	assert(upper_floor.get_node_or_null("UpperHexFloor") != null)
	assert(upper_floor.get_node("UpperHexFloor").get_child_count() == 45)
	assert(upper_floor.get_node_or_null("UpperBedrooms/UpperRoomPresentation") != null)
	assert(roof.get_node_or_null("NorthRoofSlope") != null)
	assert(not roof.visible)
	tavern.simulation.free()
	tavern.free()
