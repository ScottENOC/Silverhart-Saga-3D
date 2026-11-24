extends SceneTree

func _initialize() -> void:
	_test_penetration_force()
	_test_damping_force()
	_test_separation_has_no_pull()
	_test_force_is_capped()
	_test_invalid_contact_is_ignored()
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
