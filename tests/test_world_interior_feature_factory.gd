extends SceneTree

const FACTORY = preload("res://scripts/world/world_interior_feature_factory.gd")
const TAPROOM = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_taproom.gd")
const UPPER_ROOMS = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_upper_rooms.gd")
const STRUCTURE = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_structure.gd")
const LAYOUT = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_layout.gd")
const PRESENTER = preload("res://scripts/world/world_interior_layout_presenter.gd")
const TAVERN = preload("res://scripts/world/hollow_tankard.gd")
const LOCATION_LOADER = preload("res://scripts/world/campaign2_location_loader.gd")
const LOCATION_COMPONENT = preload("res://tests/fixtures/test_location_component.gd")
const LOGICAL_INTERIOR_REGISTRAR = preload("res://scripts/world/world_interior_layout_registrar.gd")
const TAVERN_LAYOUT = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_layout.gd")
const WORLD_CELL_LOADER = preload("res://scripts/world/campaign2_world_cell_loader.gd")

func _initialize() -> void:
	_test_authored_taproom_features()
	_test_invalid_interior_is_atomic()
	_test_tavern_uses_shared_interior_layout()
	_test_upper_rooms_use_authored_data()
	_test_building_structure_uses_authored_data()
	_test_tavern_building_assembly_keeps_live_door_and_floor_groups()
	_test_location_loader_instantiates_data_components()
	_test_authored_logical_interior_registration()
	print("World interior feature tests passed.")
	quit(0)

func _materials() -> Dictionary:
	var result := {}
	for key in ["dark_wood", "timber", "stone", "bottle_green", "plaster", "glass", "roof", "grass", "floor", "blocked"]:
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

func _test_tavern_uses_shared_interior_layout() -> void:
	var tavern := TAVERN.new() as Node3D
	tavern.call("_create_materials")
	tavern.simulation = WorldSimulation.new()
	tavern.call("_present_interior_layout")
	assert(tavern.get_node_or_null("TaproomFurniture") != null)
	assert(tavern.get_node("TaproomFurniture").get_child_count() == TAPROOM.DEFINITION.features.size())
	assert(tavern.get_node_or_null("HollowTankardBuilding/FrontDoorHinge/FrontDoorLeaf") != null)
	assert(tavern.get_node_or_null("UpperFloorPresentation/UpperBedrooms/UpperRoomPresentation") != null)
	assert(tavern.get_node_or_null("UpperFloorPresentation/UpperBedrooms/GarrickBed") != null)
	assert(tavern.get_node_or_null("UpperFloorPresentation/UpperBedrooms/SouthGuestBedB") != null)
	tavern.simulation.free()
	tavern.free()

func _test_upper_rooms_use_authored_data() -> void:
	assert(UPPER_ROOMS.BEDS.size() == 6, "All six upper-floor beds should be authored as axial data")
	var parent := Node3D.new()
	var simulation := WorldSimulation.new()
	var result: Dictionary = PRESENTER.present(parent, LAYOUT.DEFINITION, _materials(), simulation.map_data, HexGrid.DEFAULT_RADIUS_M)
	assert(bool(result.get("ok", false)), "The shared presenter should compose all authored upper-room features")
	var upper_floor := result.get("upper_floor") as Node3D
	var bedrooms := upper_floor.get_node_or_null("UpperBedrooms")
	assert(bedrooms != null)
	var presentation := bedrooms.get_node_or_null("UpperRoomPresentation")
	assert(presentation != null)
	assert(presentation.get_child_count() == UPPER_ROOMS.DEFINITION.features.size())
	assert(presentation.get_node_or_null("WestPartitionNorth") != null)
	assert(presentation.get_node_or_null("GarrickRoomLabel") != null)
	assert(bedrooms.get_node_or_null("GarrickBed") != null)
	assert(bedrooms.get_node_or_null("SouthGuestBedB") != null)
	assert(bedrooms.get_node_or_null("LandingTable") == null)
	parent.free()
	simulation.free()

func _test_building_structure_uses_authored_data() -> void:
	var parent := Node3D.new()
	var materials := _materials()
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

func _test_location_loader_instantiates_data_components() -> void:
	var parent := Node3D.new()
	var simulation := WorldSimulation.new()
	var profile := {"name": "Test Adventurer"}
	var save_data := {"campaign_tick": 42}
	var definition := {
		"id": "test_location",
		"components": [
			{"role": "settlement", "node_name": "TestSettlement", "script": LOCATION_COMPONENT, "configure_location": true, "location_data": {"settlement_id": "test_settlement"}},
			{"role": "interior_controller", "node_name": "TestInterior", "script": LOCATION_COMPONENT, "configure_campaign": true}
		]
	}
	var result: Dictionary = LOCATION_LOADER.load_location(parent, definition, simulation, profile, save_data)
	assert(bool(result.get("ok", false)), "The generic location loader should instantiate configured component scripts")
	assert(parent.get_node_or_null("TestSettlement") != null)
	assert(parent.get_node("TestSettlement").get("received_location_data") == {"settlement_id": "test_settlement"})
	var controller := parent.get_node("TestInterior")
	assert(controller.get("received_simulation") == simulation)
	assert(controller.get("received_profile") == profile)
	assert(controller.get("received_save_data") == save_data)
	var invalid := LOCATION_LOADER.load_location(parent, {"components": [{"role": "duplicate", "node_name": "A", "script": LOCATION_COMPONENT}, {"role": "duplicate", "node_name": "B", "script": LOCATION_COMPONENT}]}, simulation, profile, save_data)
	assert(not bool(invalid.get("ok", false)), "Duplicate component roles should be rejected before presentation")
	assert(parent.get_child_count() == 2, "Invalid location definitions must not partially add components")
	parent.free()
	simulation.free()

func _test_authored_logical_interior_registration() -> void:
	var simulation := WorldSimulation.new()
	var cell_loader := WORLD_CELL_LOADER.new() as Campaign2WorldCellLoader
	cell_loader.load_around(simulation.map_data, Vector2i.ZERO, 4)
	var registered := LOGICAL_INTERIOR_REGISTRAR.register_layout(simulation, TAVERN_LAYOUT.LOGICAL_DEFINITION, HexGrid.DEFAULT_RADIUS_M)
	assert(registered, "The shared logical registrar should register the authored tavern layout")
	assert(simulation.building_registry.definitions.has(TAVERN_LAYOUT.BUILDING_ID))
	assert(simulation.building_registry.doors.has(TAVERN_LAYOUT.FRONT_DOOR_ID))
	var upper_floor := TAVERN_LAYOUT.UPPER_FLOOR_ORIGIN
	var floor_count := 0
	for q in range(-4, 5):
		var row_shift := -floori(float(q) / 2.0)
		for row in range(-2, 3):
			var local_hex := Vector2i(q, row + row_shift)
			assert(simulation.map_data.has_cell(upper_floor + local_hex), "Every authored upper-floor cell must be registered")
			floor_count += 1
	assert(floor_count == 45, "The upper floor must retain its 45-cell footprint")
	simulation.free()

func _test_tavern_building_assembly_keeps_live_door_and_floor_groups() -> void:
	var tavern := TAVERN.new() as Node3D
	tavern.call("_create_materials")
	tavern.simulation = WorldSimulation.new()
	tavern.call("_present_interior_layout")
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
