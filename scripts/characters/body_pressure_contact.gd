extends RefCounted
class_name BodyPressureContact
## Converts a detected collision's penetration and closing speed into a
## compressive force. Collision detection and region selection remain the
## responsibility of the caller (hand, garment, self-contact, or another actor).

static func calculate_force_n(
	penetration_m: float,
	closing_speed_m_per_s: float,
	contact_stiffness_n_per_m: float,
	contact_damping_ns_per_m: float,
	max_force_n: float = 250.0
) -> float:
	var penetration := maxf(0.0, penetration_m)
	var closing_speed := maxf(0.0, closing_speed_m_per_s)
	var stiffness := maxf(0.0, contact_stiffness_n_per_m)
	var damping := maxf(0.0, contact_damping_ns_per_m)
	var force := penetration * stiffness + closing_speed * damping
	return clampf(force, 0.0, maxf(0.0, max_force_n))

## Convenience bridge for a detected contact. Call once per physics tick while
## the contact persists; the controller accumulates simultaneous sources.
static func submit_contact(
	controller: BodyPressureController,
	region_id: StringName,
	penetration_m: float,
	closing_speed_m_per_s: float,
	contact_stiffness_n_per_m: float,
	contact_damping_ns_per_m: float,
	max_force_n: float = 250.0
) -> float:
	if controller == null or not controller.has_region(region_id):
		return 0.0
	var force := calculate_force_n(
		penetration_m,
		closing_speed_m_per_s,
		contact_stiffness_n_per_m,
		contact_damping_ns_per_m,
		max_force_n
	)
	if force > 0.0:
		controller.apply_pressure(region_id, force)
	return force
