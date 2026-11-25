extends SceneTree
## Stiffness sweep through the real Godot controller and spring solver.
## Uses a synthetic mesh: this validates mechanics, not native Wren tissue calibration.

const CONTROLLER = preload("res://scripts/characters/body_pressure_controller.gd")
const PROFILE = preload("res://scripts/characters/body_region_profile.gd")

const APPLIED_PRESSURE_PA := 1000.0
const CONTACT_AREA_M2 := 0.001 # 10 cm^2
const FORCE_N := APPLIED_PRESSURE_PA * CONTACT_AREA_M2
const HOLD_SECONDS := 15.0 # Long enough for the most compliant/high-damping case to settle.
const STEP_SECONDS := 1.0 / 60.0
const SHARED_DAMPING_NS_PER_M := 30.0
const SHARED_EFFECTIVE_MASS_KG := 0.22
const SHARED_MAX_COMPRESSION_M := 0.032
const BUTTOCK_STIFFNESSES := [850.0, 400.0, 200.0, 100.0]
const KNEE_STIFFNESS_N_PER_M := 3900.0

func _initialize() -> void:
	var mesh := _make_test_mesh()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SyntheticPressureSweepMesh"
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)

	var controller = CONTROLLER.new()
	var region_ids: Array[StringName] = []
	for stiffness in BUTTOCK_STIFFNESSES:
		var region_id := StringName("buttock_%d" % int(stiffness))
		region_ids.append(region_id)
		controller.register_region(region_id, _make_profile(stiffness))
	var knee_id := &"knee_reference"
	controller.register_region(knee_id, _make_profile(KNEE_STIFFNESS_N_PER_M))
	controller.bind_model(mesh_instance)

	for region_id in region_ids + [knee_id]:
		if not controller.has_region(region_id):
			_fail("Controller did not register region %s." % String(region_id))
			return
		if controller.get_bound_target_count(region_id) != 1:
			_fail("Expected exactly one bound synthetic shape for %s." % String(region_id))
			return

	var frame_count := int(round(HOLD_SECONDS / STEP_SECONDS))
	for _frame in range(frame_count):
		for region_id in region_ids + [knee_id]:
			controller.apply_pressure(region_id, FORCE_N)
		controller.step(STEP_SECONDS)

	var results: Array[Dictionary] = []
	for i in range(BUTTOCK_STIFFNESSES.size()):
		var stiffness: float = BUTTOCK_STIFFNESSES[i]
		var region_id := region_ids[i]
		var compression := controller.get_compression_m(region_id)
		var shape_value := mesh_instance.get_blend_shape_value(i)
		var static_expected := FORCE_N / stiffness
		results.append({
			"stiffness_n_per_m": stiffness,
			"compression_m": compression,
			"compression_mm": compression * 1000.0,
			"static_expected_mm": static_expected * 1000.0,
			"blend_shape_value": shape_value
		})
		if compression < static_expected * 0.85 or compression > static_expected * 1.10:
			_fail("%s did not settle near its spring equilibrium: %.3f mm vs %.3f mm." % [
				String(region_id), compression * 1000.0, static_expected * 1000.0
			])
			return
		if shape_value <= 0.0:
			_fail("The controller did not drive the %s blend shape." % String(region_id))
			return

	var knee_compression := controller.get_compression_m(knee_id)
	var knee_shape_value := mesh_instance.get_blend_shape_value(4)
	print("BODY_PRESSURE_STIFFNESS_SWEEP: ", JSON.stringify({
		"inputs": {
			"pressure_pa": APPLIED_PRESSURE_PA,
			"contact_area_m2": CONTACT_AREA_M2,
			"force_n_each": FORCE_N,
			"hold_seconds": HOLD_SECONDS,
			"shared_damping_ns_per_m": SHARED_DAMPING_NS_PER_M,
			"shared_effective_mass_kg": SHARED_EFFECTIVE_MASS_KG,
			"shared_max_compression_m": SHARED_MAX_COMPRESSION_M
		},
		"buttock_sweep": results,
		"knee_reference": {
			"stiffness_n_per_m": KNEE_STIFFNESS_N_PER_M,
			"compression_mm": knee_compression * 1000.0,
			"blend_shape_value": knee_shape_value
		}
	}))

	for i in range(results.size() - 1):
		if float(results[i + 1]["compression_m"]) <= float(results[i]["compression_m"]):
			_fail("Lower stiffness must produce greater compression across the sweep.")
			return
	if knee_compression >= float(results[0]["compression_m"]):
		_fail("The stiff knee reference should compress less than the 850 N/m buttock case.")
		return
	if knee_shape_value <= 0.0:
		_fail("The knee reference blend shape was not driven.")
		return

	# Release all loads and verify that the spring responses recover.
	for _frame in range(1800):
		controller.step(STEP_SECONDS)
	for region_id in region_ids + [knee_id]:
		if controller.get_compression_m(region_id) >= 0.001:
			_fail("%s did not recover below 1 mm after release." % String(region_id))
			return

	print("BODY_PRESSURE_STIFFNESS_SWEEP_TEST: PASS")
	quit(0)


func _make_profile(stiffness_n_per_m: float) -> Resource:
	var profile = PROFILE.new()
	profile.stiffness_n_per_m = stiffness_n_per_m
	profile.damping_ns_per_m = SHARED_DAMPING_NS_PER_M
	profile.effective_mass_kg = SHARED_EFFECTIVE_MASS_KG
	profile.max_compression_m = SHARED_MAX_COMPRESSION_M
	profile.sanitise()
	return profile


func _make_test_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for stiffness in BUTTOCK_STIFFNESSES:
		mesh.add_blend_shape("Pressure_buttock_%d" % int(stiffness))
	mesh.add_blend_shape("Pressure_knee_reference")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.1, 0.0, 0.0),
		Vector3(0.1, 0.0, 0.0),
		Vector3(0.0, 0.1, 0.0)
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var blend_shapes: Array = []
	for _i in range(5):
		var shape: Array = []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(-0.1, 0.0, -0.032),
			Vector3(0.1, 0.0, -0.032),
			Vector3(0.0, 0.1, -0.032)
		])
		blend_shapes.append(shape)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blend_shapes)
	return mesh


func _fail(message: String) -> void:
	push_error("BODY_PRESSURE_STIFFNESS_SWEEP_TEST: " + message)
	quit(1)
