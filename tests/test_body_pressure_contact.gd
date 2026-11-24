extends SceneTree

func _initialize() -> void:
	_test_penetration_force()
	_test_damping_force()
	_test_separation_has_no_pull()
	_test_force_is_capped()
	_test_invalid_contact_is_ignored()
	_test_contact_drives_region_solver()
	_test_multiple_contacts_accumulate()
	_test_garment_adds_transient_body_damping()
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
	controller.register_region(&"left_chest", profile)
	var submitted := BodyPressureContact.submit_contact(
		controller, &"left_chest", 0.012, 0.0, 1800.0, 35.0, 120.0
	)
	assert(submitted > 0.0, "A valid contact should submit compressive force.")
	for _frame in range(30):
		BodyPressureContact.submit_contact(
			controller, &"left_chest", 0.012, 0.0, 1800.0, 35.0, 120.0
		)
		controller.step(1.0 / 60.0)
	assert(controller.get_compression_m(&"left_chest") > 0.0, "Contact samples should compress the registered region.")

func _test_multiple_contacts_accumulate() -> void:
	var controller := BodyPressureController.new()
	var profile := BodyRegionProfile.new()
	controller.register_region(&"torso", profile)
	var first := BodyPressureContact.submit_contact(controller, &"torso", 0.005, 0.0, 1000.0, 0.0)
	var second := BodyPressureContact.submit_contact(controller, &"torso", 0.005, 0.0, 1000.0, 0.0)
	assert(is_equal_approx(first + second, 10.0), "Independent contact sources should each contribute their force.")
	controller.step(1.0 / 60.0)
	assert(controller.get_compression_m(&"torso") > 0.0, "Accumulated contact force should reach the solver.")

func _test_garment_adds_transient_body_damping() -> void:
	var baseline := BodyPressureController.new()
	var clothed := BodyPressureController.new()
	var base_profile := BodyRegionProfile.new()
	base_profile.stiffness_n_per_m = 900.0
	base_profile.damping_ns_per_m = 18.0
	base_profile.effective_mass_kg = 0.2
	base_profile.max_compression_m = 0.04
	var cloth_profile := BodyRegionProfile.new()
	cloth_profile.stiffness_n_per_m = base_profile.stiffness_n_per_m
	cloth_profile.damping_ns_per_m = base_profile.damping_ns_per_m
	cloth_profile.effective_mass_kg = base_profile.effective_mass_kg
	cloth_profile.max_compression_m = base_profile.max_compression_m
	baseline.register_region(&"breast_left", base_profile)
	clothed.register_region(&"breast_left", cloth_profile)
	# Give both regions identical displacement and velocity through the solver.
	for _frame in range(12):
		baseline.apply_pressure(&"breast_left", 20.0)
		clothed.apply_pressure(&"breast_left", 20.0)
		baseline.step(1.0 / 60.0)
		clothed.step(1.0 / 60.0)
	var velocity_before := clothed.get_velocity_m_per_s(&"breast_left")
	assert(velocity_before > 0.0, "Test setup should have a moving compressed region.")
	# A garment adds damping for the contact tick, but not a permanent profile change.
	BodyPressureContact.submit_garment_contact(
		clothed, &"breast_left", 0.006, 0.0, 1000.0, 0.0, 180.0
	)
	clothed.step(1.0 / 60.0)
	baseline.step(1.0 / 60.0)
	assert(clothed.get_velocity_m_per_s(&"breast_left") < baseline.get_velocity_m_per_s(&"breast_left"),
		"Garment contact should damp underlying body motion more than the uncovered region.")
	# With no garment contact submitted, damping returns to the body profile value.
	for _frame in range(60):
		clothed.step(1.0 / 60.0)
		baseline.step(1.0 / 60.0)
	assert(clothed.get_velocity_m_per_s(&"breast_left") >= 0.0,
		"Region should remain numerically stable after garment contact ends.")
