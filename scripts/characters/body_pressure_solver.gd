extends RefCounted
class_name BodyPressureSolver
## Deterministic spring-damper solver for local body-region compression.
## Callers provide contact force in Newtons and read compression in metres.
## Contact damping is transient and must be submitted again while contact persists.

var _regions: Dictionary = {}

func register_region(region_id: StringName, profile: BodyRegionProfile) -> void:
	if region_id == StringName() or profile == null:
		push_warning("BodyPressureSolver: region id and profile are required.")
		return
	profile.sanitise()
	_regions[region_id] = {
		"profile": profile,
		"force_n": 0.0,
		"contact_damping_ns_per_m": 0.0,
		"compression_m": 0.0,
		"velocity_m_per_s": 0.0
	}

func unregister_region(region_id: StringName) -> void:
	_regions.erase(region_id)

func has_region(region_id: StringName) -> bool:
	return _regions.has(region_id)

## Multiple contact sources can add force before the physics step.
func apply_pressure(region_id: StringName, force_n: float) -> void:
	if not _regions.has(region_id):
		return
	var state: Dictionary = _regions[region_id]
	state["force_n"] = maxf(0.0, float(state["force_n"]) + maxf(0.0, force_n))
	_regions[region_id] = state

## Adds damping for this physics tick. Garments use this for the body region
## they touch; callers resubmit it on each tick while contact persists.
func apply_contact_damping(region_id: StringName, damping_ns_per_m: float) -> void:
	if not _regions.has(region_id):
		return
	var state: Dictionary = _regions[region_id]
	state["contact_damping_ns_per_m"] = maxf(
		0.0,
		float(state["contact_damping_ns_per_m"]) + maxf(0.0, damping_ns_per_m)
	)
	_regions[region_id] = state

## Advances all region springs. Prefer a fixed physics timestep.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	var remaining := minf(delta, 0.25)
	while remaining > 0.000001:
		var dt := minf(remaining, 1.0 / 120.0)
		for region_id in _regions:
			var state: Dictionary = _regions[region_id]
			var profile := state["profile"] as BodyRegionProfile
			var displacement := float(state["compression_m"])
			var velocity := float(state["velocity_m_per_s"])
			var force := float(state["force_n"])
			var damping := profile.damping_ns_per_m + float(state["contact_damping_ns_per_m"])
			var acceleration := (force - profile.stiffness_n_per_m * displacement - damping * velocity) / profile.effective_mass_kg
			velocity += acceleration * dt
			displacement = clampf(displacement + velocity * dt, 0.0, profile.max_compression_m)
			if displacement <= 0.0 and velocity < 0.0:
				velocity = 0.0
			if displacement >= profile.max_compression_m and velocity > 0.0:
				velocity = 0.0
			state["compression_m"] = displacement
			state["velocity_m_per_s"] = velocity
			_regions[region_id] = state
		remaining -= dt
	for region_id in _regions:
		var state: Dictionary = _regions[region_id]
		state["force_n"] = 0.0
		state["contact_damping_ns_per_m"] = 0.0
		_regions[region_id] = state

func get_compression_m(region_id: StringName) -> float:
	return float(_regions[region_id]["compression_m"]) if _regions.has(region_id) else 0.0

func get_velocity_m_per_s(region_id: StringName) -> float:
	return float(_regions[region_id]["velocity_m_per_s"]) if _regions.has(region_id) else 0.0

func get_region_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _regions.keys():
		result.append(key as StringName)
	return result

func clear_region(region_id: StringName) -> void:
	if not _regions.has(region_id):
		return
	var state: Dictionary = _regions[region_id]
	state["force_n"] = 0.0
	state["contact_damping_ns_per_m"] = 0.0
	state["compression_m"] = 0.0
	state["velocity_m_per_s"] = 0.0
	_regions[region_id] = state

func get_max_compression_m(region_id: StringName) -> float:
	if not _regions.has(region_id):
		return 0.0
	var profile := _regions[region_id]["profile"] as BodyRegionProfile
	return profile.max_compression_m
