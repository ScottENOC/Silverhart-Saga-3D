extends SceneTree

func _initialize() -> void:
	_test_penetration_force()
	_test_damping_force()
	_test_separation_has_no_pull()
	_test_force_is_capped()
	_test_invalid_contact_is_ignored()
	_test_contact_drives_region_solver()
	_test_multiple_contacts_accumulate()
	print("BODY_PRESSURE_CONTACT_TEST: PASS")
	quit(0)

func _test_penetration_force() -> void:
	var force := BodyPressureContact.calculate_force_n(0.01, 0.0, 1000.0, 0.0)
	assert(is_equal_approx(force, 10.0), "10 mm penetration at 1000 N/m should produce 10 N.")

func _test_damping_force() -> void:
	var force := BodyPressureContact.calculate_force_n(0.0, 0.5, 100.0, 20.0)
	assert(is_equal_approx(force, 10.0), "Closing velocity should add damping force.")

func _test_separation_has_no_pull() -> void:
	var force := BodyPressureContact.calculate_force_n(0.0, -0.5, 100.0, 20.0)
	assert(is_equal_approx(force, 0.0), "A separating contact must not pull the body.")

func _test_force_is_capped() -> void:
	var force := BodyPressureContact.calculate_force_n(0.1, 10.0, 10000.0, 1000.0, 50.0)
	assert(is_equal_approx(force, 50.0), "Contact force must respect its safety cap.")

func _test_invalid_contact_is_ignored() -> void:
	var controller := BodyPressureController.new()
	var submitted := BodyPressureContact.submit_contact(controller, &"missing", 0.01, 0.0, 1000.0, 0.0)
	assert(is_equal_approx(submitted, 0.0), "Unregistered regions must ignore contacts.")

func _test_contact_drives_region_solver() -> void:
	var controller := BodyPressureController.new()
	var profile := BodyRegionProfile.new()
	profile.stiffness_n_per_m = 700.0
	profile.damping_ns_per_m = 24.0
	profile.effective_mass_kg = 0.18
	profile.max_compression_m = 0.04
	controller.register_region(&"breast_left", profile)
	var submitted := BodyPressureContact.submit_contact(
		controller, &"breast_left", 0.012, 0.0, 1800.0, 35.0, 120.0
	)
	assert(submitted > 0.0, "A valid contact should submit compressive force.")
	for _frame in range(30):
		# Re-submit each tick while the detected contact remains present.
		BodyPressureContact.submit_contact(
			controller, &"breast_left", 0.012, 0.0, 1800.0, 35.0, 120.0
		)
		controller.step(1.0 / 60.0)
	assert(controller.get_compression_m(&"breast_left") > 0.0, "Contact samples should compress the registered region.")

func _test_multiple_contacts_accumulate() -> void:
	var controller := BodyPressureController.new()
	var profile := BodyRegionProfile.new()
	controller.register_region(&"torso", profile)
	var first := BodyPressureContact.submit_contact(controller, &"torso", 0.005, 0.0, 1000.0, 0.0)
	var second := BodyPressureContact.submit_contact(controller, &"torso", 0.005, 0.0, 1000.0, 0.0)
	assert(is_equal_approx(first + second, 10.0), "Independent contact sources should each contribute their force.")
	controller.step(1.0 / 60.0)
	assert(controller.get_compression_m(&"torso") > 0.0, "Accumulated contact force should reach the solver.")
