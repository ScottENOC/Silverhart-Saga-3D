extends SceneTree

func _initialize() -> void:
	var controller := BodyPressureController.new()
	var registered := BodyPressureProfileLibrary.register_missing_regions(controller)
	assert(registered == BodyPressureProfileLibrary.get_region_ids().size(), "All default body regions should be registered.")
	assert(controller.has_region(&"left_chest"), "Left chest preset should exist.")
	assert(controller.has_region(&"right_chest"), "Right chest preset should exist.")
	assert(controller.get_max_compression_m(&"left_chest") > controller.get_max_compression_m(&"left_hand"), "Soft-tissue regions should allow more compression than the hand preset.")
	var custom := BodyRegionProfile.new()
	custom.stiffness_n_per_m = 1234.0
	controller.register_region(&"left_chest", custom)
	var after := BodyPressureProfileLibrary.register_missing_regions(controller)
	assert(after == 0, "Default registration must preserve caller overrides.")
	assert(is_equal_approx(controller.get_max_compression_m(&"left_chest"), custom.max_compression_m), "Caller profile should remain in place.")
	print("BODY_PRESSURE_PROFILE_LIBRARY_TEST: PASS")
	quit(0)
