extends Resource
class_name BodyRegionProfile
## Mechanical response for one deformable body region.
## Stiffness is measured in N/m, damping in N*s/m, and effective mass in kg.

@export_range(0.1, 5000.0, 0.1) var stiffness_n_per_m: float = 900.0
@export_range(0.0, 500.0, 0.1) var damping_ns_per_m: float = 28.0
@export_range(0.001, 20.0, 0.001) var effective_mass_kg: float = 0.18
@export_range(0.0, 0.25, 0.001) var max_compression_m: float = 0.035

func sanitise() -> void:
	stiffness_n_per_m = maxf(0.1, stiffness_n_per_m)
	damping_ns_per_m = maxf(0.0, damping_ns_per_m)
	effective_mass_kg = maxf(0.001, effective_mass_kg)
	max_compression_m = maxf(0.0, max_compression_m)
