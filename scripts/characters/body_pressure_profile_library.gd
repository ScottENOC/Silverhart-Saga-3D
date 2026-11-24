extends RefCounted
class_name BodyPressureProfileLibrary
## Provisional game-tuning presets. These are not anatomical measurements.
## Each entry: stiffness (N/m), damping (N*s/m), effective mass (kg),
## maximum local compression (m).

const PRESETS := {
	&"left_chest": [700.0, 24.0, 0.18, 0.040],
	&"right_chest": [700.0, 24.0, 0.18, 0.040],
	&"upper_abdomen": [1050.0, 30.0, 0.24, 0.030],
	&"lower_abdomen": [950.0, 29.0, 0.25, 0.032],
	&"waist": [1350.0, 34.0, 0.28, 0.024],
	&"pelvis": [1850.0, 42.0, 0.35, 0.020],
	&"left_shoulder": [2800.0, 58.0, 0.30, 0.016],
	&"right_shoulder": [2800.0, 58.0, 0.30, 0.016],
	&"left_upper_arm": [2300.0, 52.0, 0.22, 0.018],
	&"right_upper_arm": [2300.0, 52.0, 0.22, 0.018],
	&"left_forearm": [3400.0, 64.0, 0.18, 0.012],
	&"right_forearm": [3400.0, 64.0, 0.18, 0.012],
	&"left_hand": [4800.0, 72.0, 0.10, 0.008],
	&"right_hand": [4800.0, 72.0, 0.10, 0.008],
	&"upper_back": [2900.0, 60.0, 0.32, 0.015],
	&"lower_back": [1750.0, 43.0, 0.30, 0.022],
	&"left_hip": [1650.0, 42.0, 0.32, 0.023],
	&"right_hip": [1650.0, 42.0, 0.32, 0.023],
	&"left_thigh": [2150.0, 50.0, 0.38, 0.025],
	&"right_thigh": [2150.0, 50.0, 0.38, 0.025],
	&"left_calf": [3100.0, 62.0, 0.25, 0.016],
	&"right_calf": [3100.0, 62.0, 0.25, 0.016],
	&"neck": [3300.0, 60.0, 0.12, 0.010],
	&"head": [5200.0, 78.0, 0.35, 0.008]
}

static func create_profile(region_id: StringName) -> BodyRegionProfile:
	if not PRESETS.has(region_id):
		return null
	var values: Array = PRESETS[region_id]
	var profile := BodyRegionProfile.new()
	profile.stiffness_n_per_m = float(values[0])
	profile.damping_ns_per_m = float(values[1])
	profile.effective_mass_kg = float(values[2])
	profile.max_compression_m = float(values[3])
	profile.sanitise()
	return profile

static func register_missing_regions(controller: BodyPressureController) -> int:
	if controller == null:
		return 0
	var registered := 0
	for region_id in PRESETS:
		if controller.has_region(region_id):
			continue
		controller.register_region(region_id, create_profile(region_id))
		registered += 1
	return registered

static func get_region_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for region_id in PRESETS:
		result.append(region_id)
	return result
