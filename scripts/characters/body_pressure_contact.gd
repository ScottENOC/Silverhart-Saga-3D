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

## Resolves a triangle contact against authored, overlapping anatomy channels and
## submits membership-weighted force to each matching spring. The caller must
## resolve the collision hit to the three source vertices of the exact mesh surface.
static func submit_surface_contact(
    controller: BodyPressureController,
    surface_regions: CharacterSurfaceRegions,
    mesh_node_path: NodePath,
    surface_index: int,
    triangle_vertex_indices: PackedInt32Array,
    barycentric_weights: PackedFloat32Array,
    penetration_m: float,
    closing_speed_m_per_s: float,
    contact_stiffness_n_per_m: float,
    contact_damping_ns_per_m: float,
    max_force_n: float = 250.0,
    minimum_region_weight: float = 0.01
) -> Dictionary:
    var submitted: Dictionary = {}
    if controller == null or surface_regions == null:
        return submitted
    var memberships := surface_regions.get_authored_triangle_region_weights(
        mesh_node_path,
        surface_index,
        triangle_vertex_indices,
        barycentric_weights,
        minimum_region_weight
    )
    if memberships.is_empty():
        return submitted
    var contact_force := calculate_force_n(
        penetration_m,
        closing_speed_m_per_s,
        contact_stiffness_n_per_m,
        contact_damping_ns_per_m,
        max_force_n
    )
    if contact_force <= 0.0:
        return submitted
    var total_membership := 0.0
    for membership_variant in memberships.values():
        total_membership += clampf(float(membership_variant), 0.0, 1.0)
    # Overlapping channels remain independent, but their combined force cannot
    # exceed the physical contact force when their weights sum above one.
    var membership_scale := maxf(1.0, total_membership)
    for region_variant in memberships:
        var region_id := StringName(str(region_variant))
        if not controller.has_region(region_id):
            continue
        var membership := clampf(float(memberships[region_variant]), 0.0, 1.0)
        var weighted_force := contact_force * membership / membership_scale
        if weighted_force <= 0.0:
            continue
        controller.apply_pressure(region_id, weighted_force)
        submitted[String(region_variant)] = weighted_force
    return submitted

