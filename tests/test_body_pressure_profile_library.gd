extends SceneTree

func _initialize() -> void:
	var controller := BodyPressureController.new()
	# Use the canonical resource's full vocabulary when this change is tested
	# with the anatomy branch; on dev alone, exercise representative IDs.
	var region_ids := BodyPressureProfileLibrary.get_anatomy_region_ids()
	if region_ids.is_empty():
		region_ids = [
			&"breast_left", &"breast_right", &"underbust", &"areola_left",
			&"abdomen_upper", &"abdomen_lower", &"waist_front", &"hip_left",
			&"buttock_left", &"shoulder_left", &"bicep_left", &"forearm_right",
			&"palm_left", &"index_finger_left", &"upper_back", &"lumbar_back",
			&"thigh_inner_left", &"calf_right", &"ankle_left", &"foot_sole_right",
			&"neck_front", &"head_top", &"jaw_left", &"nose_tip"
		]
	var registered := BodyPressureProfileLibrary.register_anatomy_regions(controller, region_ids)
	assert(registered == region_ids.size(), "Every supplied canonical anatomy ID should register.")
	assert(controller.has_region(&"breast_left"), "Fine left breast anatomy ID should be registered.")
	assert(controller.has_region(&"breast_right"), "Fine right breast anatomy ID should be registered.")
	assert(controller.has_region(&"index_finger_left"), "Fine finger anatomy ID should be registered.")
	assert(controller.has_region(&"foot_sole_right"), "Fine foot anatomy ID should be registered.")
	assert(not controller.has_region(&"left_chest"), "Pressure library must not introduce legacy parallel anatomy IDs.")
	assert(controller.get_max_compression_m(&"breast_left") > controller.get_max_compression_m(&"index_finger_left"), "Compliant tissue should allow more compression than a finger region.")
	var custom := BodyRegionProfile.new()
	custom.stiffness_n_per_m = 1234.0
	controller.register_region(&"breast_left", custom)
	var after := BodyPressureProfileLibrary.register_anatomy_regions(controller, region_ids)
	assert(after == 0, "Default registration must preserve caller overrides.")
	assert(is_equal_approx(controller.get_max_compression_m(&"breast_left"), custom.max_compression_m), "Caller profile should remain in place.")
	print("BODY_PRESSURE_PROFILE_LIBRARY_TEST: PASS (%d canonical anatomy IDs)" % registered)
	quit(0)
