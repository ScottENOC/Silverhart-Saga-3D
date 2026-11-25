extends SceneTree
## Synthetic pressure-input experiment. This validates the real Godot pressure
## controller and spring solver, but deliberately uses a test mesh rather than
## claiming that Wren's native GLB has authored buttock/knee shapes.

const CONTROLLER = preload("res://scripts/characters/body_pressure_controller.gd")
const PROFILE_LIBRARY = preload("res://scripts/characters/body_pressure_profile_library.gd")

const BUTTOCK_PRESSURE_PA := 10000.0 # 10 kPa; experimental, not a tissue measurement.
const KNEE_PRESSURE_PA := 2000.0 # 2 kPa; experimental, not a tissue measurement.
const BUTTOCK_CONTACT_AREA_M2 := 0.0025 # 25 cm^2 assumed patch.
const KNEE_CONTACT_AREA_M2 := 0.001 # 10 cm^2 assumed patch.
const HOLD_SECONDS := 5.0
const STEP_SECONDS := 1.0 / 60.0

func _initialize() -> void:
	var mesh := _make_test_mesh()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SyntheticPressureTestMesh"
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)

	var controller = CONTROLLER.new()
	controller.register_region(&"buttock_left", PROFILE_LIBRARY.create_profile(&"buttock_left"))
	controller.register_region(&"knee_left", PROFILE_LIBRARY.create_profile(&"knee_left"))
	controller.bind_model(mesh_instance)

	if controller.get_bound_target_count(&"buttock_left") != 1:
		_fail("Synthetic left buttock pressure shape was not bound.")
		return
	if controller.get_bound_target_count(&"knee_left") != 1:
		_fail("Synthetic left knee pressure shape was not bound.")
		return

	var buttock_force_n := BUTTOCK_PRESSURE_PA * BUTTOCK_CONTACT_AREA_M2
	var knee_force_n := KNEE_PRESSURE_PA * KNEE_CONTACT_AREA_M2
	var frame_count := int(round(HOLD_SECONDS / STEP_SECONDS))
	for _frame in range(frame_count):
		controller.apply_pressure(&"buttock_left", buttock_force_n)
		controller.apply_pressure(&"knee_left", knee_force_n)
		controller.step(STEP_SECONDS)

	var buttock_compression := controller.get_compression_m(&"buttock_left")
	var knee_compression := controller.get_compression_m(&"knee_left")
	var buttock_shape_value := mesh_instance.get_blend_shape_value(0)
	var knee_shape_value := mesh_instance.get_blend_shape_value(1)

	print("SYNTHETIC_PASCAL_PRESSURE_SCENARIO: ", JSON.stringify({
		"inputs": {
			"buttock_left": {
				"pressure_pa": BUTTOCK_PRESSURE_PA,
				"contact_area_m2": BUTTOCK_CONTACT_AREA_M2,
				"force_n": buttock_force_n
			},
			"knee_left": {
				"pressure_pa": KNEE_PRESSURE_PA,
				"contact_area_m2": KNEE_CONTACT_AREA_M2,
				"force_n": knee_force_n
			},
			"hold_seconds": HOLD_SECONDS
		},
		"outputs": {
			"buttock_compression_m": buttock_compression,
			"knee_compression_m": knee_compression,
			"buttock_blend_shape_value": buttock_shape_value,
			"knee_blend_shape_value": knee_shape_value
		}
	}))

	if buttock_compression <= knee_compression * 5.0:
		_fail("Buttock should deform substantially more than the knee in this contrast scenario.")
		return
	if buttock_shape_value <= knee_shape_value:
		_fail("Buttock blend-shape response should exceed the knee response.")
		return
	if buttock_shape_value <= 0.0 or knee_shape_value <= 0.0:
		_fail("Both independently driven regions should show non-zero deformation.")
		return

	for _frame in range(600):
		controller.step(STEP_SECONDS)
	if controller.get_compression_m(&"buttock_left") >= 0.001:
		_fail("Buttock region did not recover after pressure release.")
		return
	if controller.get_compression_m(&"knee_left") >= 0.001:
		_fail("Knee region did not recover after pressure release.")
		return

	print("BODY_PRESSURE_PASCAL_SCENARIO_TEST: PASS (Pa-to-N conversion, independent regional response, relative deformation, recovery)")
	quit(0)


func _make_test_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_blend_shape("Pressure_buttock_left")
	mesh.add_blend_shape("Pressure_knee_left")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.1, 0.0, 0.0),
		Vector3(0.1, 0.0, 0.0),
		Vector3(0.0, 0.1, 0.0)
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var buttock_shape: Array = []
	buttock_shape.resize(Mesh.ARRAY_MAX)
	buttock_shape[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.1, 0.0, -0.032),
		Vector3(0.1, 0.0, -0.032),
		Vector3(0.0, 0.1, -0.032)
	])
	var knee_shape: Array = []
	knee_shape.resize(Mesh.ARRAY_MAX)
	knee_shape[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.1, 0.0, -0.010),
		Vector3(0.1, 0.0, -0.010),
		Vector3(0.0, 0.1, -0.010)
	])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [buttock_shape, knee_shape])
	return mesh


func _fail(message: String) -> void:
	push_error("BODY_PRESSURE_PASCAL_SCENARIO_TEST: " + message)
	quit(1)
