extends SceneTree

func _initialize() -> void:
	var mesh := ArrayMesh.new()
	mesh.add_blend_shape("Pressure_LeftChest")
	mesh.add_blend_shape("Pressure_RightChest")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.1, 0.0, 0.0),
		Vector3(0.1, 0.0, 0.0),
		Vector3(0.0, 0.1, 0.0)
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var left_shape: Array = []
	left_shape.resize(Mesh.ARRAY_MAX)
	left_shape[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.1, 0.0, 0.02),
		Vector3(0.1, 0.0, 0.02),
		Vector3(0.0, 0.1, 0.02)
	])
	var right_shape: Array = []
	right_shape.resize(Mesh.ARRAY_MAX)
	right_shape[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.1, 0.0, -0.02),
		Vector3(0.1, 0.0, -0.02),
		Vector3(0.0, 0.1, -0.02)
	])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [left_shape, right_shape])

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)

	var controller := BodyPressureController.new()
	var left_profile := BodyRegionProfile.new()
	left_profile.stiffness_n_per_m = 700.0
	left_profile.damping_ns_per_m = 24.0
	left_profile.effective_mass_kg = 0.18
	left_profile.max_compression_m = 0.04
	controller.register_region(&"left_chest", left_profile)
	var right_profile := BodyRegionProfile.new()
	right_profile.stiffness_n_per_m = 1400.0
	right_profile.damping_ns_per_m = 24.0
	right_profile.effective_mass_kg = 0.18
	right_profile.max_compression_m = 0.04
	controller.register_region(&"right_chest", right_profile)
	controller.bind_model(mesh_instance)

	if controller.get_bound_target_count(&"left_chest") != 1:
		_fail("Left chest pressure shape was not discovered.")
		return
	if controller.get_bound_target_count(&"right_chest") != 1:
		_fail("Right chest pressure shape was not discovered.")
		return

	# A contact producer submits force on every physics tick while contact persists.
	for _frame in range(30):
		controller.apply_pressure(&"left_chest", 35.0)
		controller.step(1.0 / 60.0)
	var left_value := mesh_instance.get_blend_shape_value(0)
	var right_value := mesh_instance.get_blend_shape_value(1)
	if left_value <= 0.05:
		_fail("Left chest blend shape did not respond to sustained pressure.")
		return
	if absf(right_value) > 0.0001:
		_fail("Left-side pressure incorrectly changed the right-side blend shape.")
		return
	if controller.get_compression_m(&"left_chest") <= 0.0:
		_fail("Left chest compression was not retained by the solver.")
		return

	# No force is submitted after contact ends; the region should recover.
	for _frame in range(180):
		controller.step(1.0 / 60.0)
	if mesh_instance.get_blend_shape_value(0) > 0.01:
		_fail("Pressure blend shape did not recover after contact ended.")
		return

	print("BODY_PRESSURE_CONTROLLER_TEST: PASS (independent regions, local blend-shape response, recovery)")
	quit(0)


func _fail(message: String) -> void:
	push_error("BODY_PRESSURE_CONTROLLER_TEST: " + message)
	quit(1)
