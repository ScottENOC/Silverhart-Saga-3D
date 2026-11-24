extends SceneTree

const PROFILE = preload("res://scripts/characters/body_region_profile.gd")
const SOLVER = preload("res://scripts/characters/body_pressure_solver.gd")

func _initialize() -> void:
	_test_force_compresses_region()
	_test_firmer_region_deforms_less()
	_test_multiple_contacts_accumulate()
	_test_release_recovers_to_rest()
	_test_compression_is_clamped()
	print("BODY_PRESSURE_SOLVER_TEST: PASS")
	quit(0)

func _make_profile(stiffness: float, max_compression: float = 0.04) -> BodyRegionProfile:
	var profile = PROFILE.new()
	profile.stiffness_n_per_m = stiffness
	profile.damping_ns_per_m = 35.0
	profile.effective_mass_kg = 0.2
	profile.max_compression_m = max_compression
	return profile

func _test_force_compresses_region() -> void:
	var solver = SOLVER.new()
	solver.register_region(&"torso", _make_profile(800.0))
	solver.apply_pressure(&"torso", 20.0)
	solver.step(1.0 / 60.0)
	assert(solver.get_compression_m(&"torso") > 0.0, "Applied force should compress the region.")

func _test_firmer_region_deforms_less() -> void:
	var solver = SOLVER.new()
	solver.register_region(&"soft", _make_profile(400.0))
	solver.register_region(&"firm", _make_profile(1600.0))
	for i in range(30):
		solver.apply_pressure(&"soft", 12.0)
		solver.apply_pressure(&"firm", 12.0)
		solver.step(1.0 / 60.0)
	assert(solver.get_compression_m(&"soft") > solver.get_compression_m(&"firm"), "Firmer region should deform less under equal force.")

func _test_multiple_contacts_accumulate() -> void:
	var single = SOLVER.new()
	var doubled = SOLVER.new()
	single.register_region(&"region", _make_profile(700.0))
	doubled.register_region(&"region", _make_profile(700.0))
	for i in range(12):
		single.apply_pressure(&"region", 5.0)
		doubled.apply_pressure(&"region", 5.0)
		doubled.apply_pressure(&"region", 5.0)
		single.step(1.0 / 60.0)
		doubled.step(1.0 / 60.0)
	assert(doubled.get_compression_m(&"region") > single.get_compression_m(&"region"), "Independent contacts should accumulate.")

func _test_release_recovers_to_rest() -> void:
	var solver = SOLVER.new()
	solver.register_region(&"region", _make_profile(900.0))
	for i in range(30):
		solver.apply_pressure(&"region", 18.0)
		solver.step(1.0 / 60.0)
	var compressed := solver.get_compression_m(&"region")
	for i in range(240):
		solver.step(1.0 / 60.0)
	assert(compressed > 0.0, "Setup should produce compression.")
	assert(solver.get_compression_m(&"region") < 0.001, "Region should recover close to rest after release.")

func _test_compression_is_clamped() -> void:
	var solver = SOLVER.new()
	solver.register_region(&"region", _make_profile(100.0, 0.006))
	for i in range(60):
		solver.apply_pressure(&"region", 1000.0)
		solver.step(1.0 / 60.0)
	assert(solver.get_compression_m(&"region") <= 0.006, "Compression must respect the profile limit.")
