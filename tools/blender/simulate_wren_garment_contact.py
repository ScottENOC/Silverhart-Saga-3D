"""Offline XPBD garment contact/deformation pass for the accepted Wren GLB.

Uses the extracted Ara garment meshes and triangle BVHs built from the actual
Wren skin and piercing meshes. Only garment vertices are displaced; the
accepted body, rig, skin materials and visible piercing meshes are preserved.
"""
import argparse
import json
import os
import sys

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from cloth.xpbd_solver import Particle, DistanceConstraint, Contact, solve_frame


def args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-blend", required=True)
    parser.add_argument("--output-blend", required=True)
    parser.add_argument("--output-glb", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--iterations", type=int, default=18)
    parser.add_argument("--substeps", type=int, default=8)
    parser.add_argument("--thickness", type=float, default=0.0015)
    return parser.parse_args(raw)


def world_bvh(obj, depsgraph):
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.transform(evaluated.matrix_world)
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm, epsilon=0.0)
    bm.free()
    evaluated.to_mesh_clear()
    if tree is None:
        raise RuntimeError("Could not build triangle BVH for " + obj.name)
    return tree


def point_is_inside(tree, point):
    """Classify a point by majority-vote ray parity, not triangle-normal sign.

    Three non-axis-aligned rays reduce edge/vertex grazing ambiguity. Each ray
    counts successive BVH intersections; odd parity means inside a closed
    surface. The small post-hit advance prevents counting the same face twice.
    """
    origin_point = Vector(point)
    directions = (
        Vector((1.0, 0.371, 0.127)).normalized(),
        Vector((-0.219, 1.0, 0.413)).normalized(),
        Vector((0.337, -0.173, 1.0)).normalized(),
    )
    inside_votes = 0
    for direction in directions:
        origin = origin_point.copy()
        intersections = 0
        for _ in range(64):
            location, _normal, _face, _distance = tree.ray_cast(
                origin, direction, 100.0
            )
            if location is None:
                break
            intersections += 1
            origin = location + direction * 1.0e-5
        if intersections % 2 == 1:
            inside_votes += 1
    return inside_votes >= 2


def closest_contact(tree, point, particle_index, thickness, two_sided=False):
    """Local signed contact; does not require a watertight body shell.

    Body skin uses its oriented surface normal, so a point on the inner side
    receives an outward correction. Thin piercing meshes are two-sided and
    use the nearest-point direction instead of volume/parity classification.
    """
    hit = tree.find_nearest(Vector(point))
    if hit is None:
        return None, None
    location, face_normal, _face, distance = hit
    if location is None or distance is None:
        return None, None
    point = Vector(point)
    location = Vector(location)
    face_normal = Vector(face_normal)
    distance = float(distance)
    if face_normal.length_squared < 1.0e-12:
        return None, None
    face_normal.normalize()
    offset = point - location
    if two_sided:
        normal = offset.normalized() if distance > 1.0e-9 else face_normal
        signed = distance
    else:
        signed = offset.dot(face_normal)
        normal = face_normal
    return Contact(particle_index, signed, tuple(normal), thickness), signed


def apply_world_positions(obj, particles, original_world):
    inverse = obj.matrix_world.inverted_safe()
    offsets = []
    for index, particle in enumerate(particles):
        delta_world = Vector(particle.position) - original_world[index]
        offsets.append(delta_world)
    # Apply the same solved offset to every shape key so morph deltas survive.
    # With shape keys present, write the Basis and every key block exactly once.
    keys = obj.data.shape_keys
    if keys:
        for block in keys.key_blocks:
            for index, delta_world in enumerate(offsets):
                block.data[index].co += inverse.to_3x3() @ delta_world
    else:
        for index, particle in enumerate(particles):
            obj.data.vertices[index].co = inverse @ Vector(particle.position)
    obj.data.update()


def main():
    options = args()
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(options.input_blend))
    depsgraph = bpy.context.evaluated_depsgraph_get()

    colliders = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH" and (
            obj.get("cloth_collision_role") in (
                "rigid_contact_surface", "piercing_rigid_contact_surface"
            )
        )
    ]
    body = [obj for obj in colliders if obj.get("cloth_collision_role") == "rigid_contact_surface"]
    piercings = [obj for obj in colliders if obj.get("cloth_collision_role") == "piercing_rigid_contact_surface"]
    garments = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH" and obj.get("cloth_role") == "garment_surface"
    ]
    if len(body) != 1 or not piercings or not garments:
        raise RuntimeError(
            f"Expected one skin collider, piercing colliders and extracted garments; "
            f"got body={len(body)}, piercings={len(piercings)}, garments={len(garments)}"
        )

    collider_trees = [
        (obj.name, world_bvh(obj, depsgraph), obj in piercings)
        for obj in body + piercings
    ]
    report_rows = []
    max_total_displacement = 0.0
    max_attempted_displacement = 0.0
    total_contacts = 0
    collision_available = bool(body and piercings)
    collision_warning = (
        "Body collision shell is open/nonmanifold; using local oriented surface-normal contact "
        "instead of closed-volume ray parity. Validate normals and the external envelope visually."
        if any(obj.get("collision_confidence", "unknown") != "closed_manifold" for obj in body)
        else ""
    )
    for garment in garments:
        original_world = [garment.matrix_world @ vertex.co for vertex in garment.data.vertices]
        normal_matrix = garment.matrix_world.to_3x3().inverted_safe().transposed()
        normal_anchors = []
        for vertex in garment.data.vertices:
            normal = normal_matrix @ vertex.normal
            if normal.length_squared < 1.0e-12:
                normal = Vector((0.0, 0.0, 1.0))
            normal.normalize()
            normal_anchors.append((tuple(original_world[vertex.index]), tuple(normal)))
        particles = [Particle.at(tuple(point), 1.0) for point in original_world]
        edge_constraints = []
        boundary_vertices = set()
        material_labels = " ".join(
            [garment.name] + list(garment.get("cloth_source_materials", []))
        ).lower()
        is_cord = any(token in material_labels for token in ("string", "cord", "strap"))
        edge_compliance = 1.0e-10 if is_cord else 1.0e-8
        edge_stiffness = 0.998 if is_cord else 0.96
        for edge in garment.data.edges:
            a, b = edge.vertices
            rest = (original_world[a] - original_world[b]).length
            edge_constraints.append(DistanceConstraint(
                a, b, rest, compliance=edge_compliance, stiffness=edge_stiffness
            ))
        # Preserve each panel's triangulated shape, not only its perimeter.
        panel_shape_constraints = 0
        seen_diagonals = set()
        for polygon in garment.data.polygons:
            vertices = list(polygon.vertices)
            if len(vertices) < 4:
                continue
            for offset in range(2, len(vertices) - 1):
                pair = tuple(sorted((vertices[0], vertices[offset])))
                if pair in seen_diagonals:
                    continue
                seen_diagonals.add(pair)
                a, b = pair
                rest = (original_world[a] - original_world[b]).length
                edge_constraints.append(DistanceConstraint(
                    a, b, rest, compliance=1.0e-9, stiffness=0.985
                ))
                panel_shape_constraints += 1

        # Cord meshes are tube-like surfaces, not fabric sheets. In addition
        # to preserving their perimeter edges, preserve each polygon's
        # diagonals so quad cross-sections cannot shear flat during contact.
        cord_shape_constraints = 0
        if is_cord:
            for polygon in garment.data.polygons:
                vertices = list(polygon.vertices)
                if len(vertices) < 4:
                    continue
                for offset in range(2, len(vertices) - 1):
                    a, b = vertices[0], vertices[offset]
                    rest = (original_world[a] - original_world[b]).length
                    edge_constraints.append(DistanceConstraint(
                        a, b, rest, compliance=1.0e-11, stiffness=0.999
                    ))
                    cord_shape_constraints += 1
        edge_use = {}
        for polygon in garment.data.polygons:
            for key in polygon.edge_keys:
                pair = tuple(sorted(key))
                edge_use[pair] = edge_use.get(pair, 0) + 1
        for (a, b), count in edge_use.items():
            if count == 1:
                boundary_vertices.update((a, b))
                rest = (original_world[a] - original_world[b]).length
                edge_constraints.append(DistanceConstraint(
                    a, b, rest,
                    compliance=1.0e-11 if is_cord else 2.0e-9,
                    stiffness=0.999 if is_cord else 0.995
                ))

        initial_penetrations = []
        def contact_provider(current_particles):
            contacts = []
            for index, particle in enumerate(current_particles):
                point = particle.position
                for _name, tree, two_sided in collider_trees:
                    contact_thickness = 0.00075 if two_sided else options.thickness
                    contact, signed = closest_contact(
                        tree, point, index, contact_thickness, two_sided=two_sided
                    )
                    if contact is not None:
                        if signed < contact_thickness:
                            contacts.append(contact)
                        if signed < 0.0 and len(initial_penetrations) < 1:
                            initial_penetrations.append(signed)
            return contacts

        # Contact is resolved against local oriented skin normals. Every
        # garment vertex is constrained to its original normal line, allowing
        # substantial outward anatomical accommodation without tangential
        # vertex wandering. There is deliberately no absolute displacement cap.
        if collision_available:
            for _ in range(max(1, options.substeps)):
                solve_frame(
                    particles, edge_constraints, contact_provider,
                    dt=1.0 / 60.0, gravity=(0.0, 0.0, 0.0),
                    iterations=max(1, options.iterations), damping=0.0,
                    normal_anchors=normal_anchors
                )

        before = [point.copy() for point in original_world]
        candidate_displacements = [
            (Vector(particle.position) - before[index]).length
            for index, particle in enumerate(particles)
        ]
        attempted_max_displacement = max(candidate_displacements, default=0.0)
        max_attempted_displacement = max(max_attempted_displacement, attempted_max_displacement)

        # Validate that fitting has not stretched edges or collapsed panels.
        # The original mesh topology is immutable: this solver may move vertices,
        # but it must never split, merge, add, or remove garment neighbours.
        edge_strains = []
        for edge in garment.data.edges:
            a, b = edge.vertices
            rest = (before[a] - before[b]).length
            current = (Vector(particles[a].position) - Vector(particles[b].position)).length
            if rest > 1.0e-9:
                edge_strains.append(abs(current / rest - 1.0))
        max_edge_strain = max(edge_strains, default=0.0)

        def polygon_normal(points, polygon):
            vertices = list(polygon.vertices)
            if len(vertices) < 3:
                return Vector((0.0, 0.0, 0.0))
            origin = Vector(points[vertices[0]])
            normal = Vector((0.0, 0.0, 0.0))
            for offset in range(1, len(vertices) - 1):
                a = Vector(points[vertices[offset]]) - origin
                b = Vector(points[vertices[offset + 1]]) - origin
                normal += a.cross(b)
            return normal.normalized() if normal.length_squared > 1.0e-16 else normal

        candidate_world = [Vector(particle.position) for particle in particles]
        face_area_strains = []
        face_normal_dots = []
        for polygon in garment.data.polygons:
            rest_normal = polygon_normal(before, polygon)
            current_normal = polygon_normal(candidate_world, polygon)
            # Evaluate geometry in world space, including deformation.
            rest_area = 0.0
            current_area = 0.0
            vertices = list(polygon.vertices)
            if len(vertices) >= 3:
                origin_before = Vector(before[vertices[0]])
                origin_after = candidate_world[vertices[0]]
                for offset in range(1, len(vertices) - 1):
                    a0 = Vector(before[vertices[offset]]) - origin_before
                    b0 = Vector(before[vertices[offset + 1]]) - origin_before
                    a1 = candidate_world[vertices[offset]] - origin_after
                    b1 = candidate_world[vertices[offset + 1]] - origin_after
                    rest_area += a0.cross(b0).length * 0.5
                    current_area += a1.cross(b1).length * 0.5
            if rest_area > 1.0e-10:
                face_area_strains.append(abs(current_area / rest_area - 1.0))
            if rest_normal.length_squared > 1.0e-12 and current_normal.length_squared > 1.0e-12:
                face_normal_dots.append(rest_normal.dot(current_normal))
        max_face_area_strain = max(face_area_strains, default=0.0)
        min_face_normal_dot = min(face_normal_dots, default=1.0)

        # Detect non-adjacent triangle intersections after deformation. Adjacent
        # triangles share vertices by construction and are not counted as folds.
        garment.data.calc_loop_triangles()
        triangle_vertices = [tuple(triangle.vertices) for triangle in garment.data.loop_triangles]
        self_intersection_count = 0
        if triangle_vertices:
            candidate_tree = BVHTree.FromPolygons(
                candidate_world, triangle_vertices, all_triangles=True
            )
            for first, second in candidate_tree.overlap(candidate_tree):
                if first >= second:
                    continue
                first_vertices = triangle_vertices[first]
                second_vertices = triangle_vertices[second]
                if not set(first_vertices).isdisjoint(second_vertices):
                    continue
                # Material-separated seams can have coincident boundary
                # vertices with distinct indices; touching there is not a fold.
                closest_pair = min(
                    (candidate_world[a] - candidate_world[b]).length
                    for a in first_vertices for b in second_vertices
                )
                if closest_pair > 1.0e-6:
                    self_intersection_count += 1

        candidate_penetrations = []
        if collision_available:
            for index, particle in enumerate(particles):
                for collider_name, tree, two_sided in collider_trees:
                    contact_thickness = 0.00075 if two_sided else options.thickness
                    _contact, signed = closest_contact(
                        tree, particle.position, index, contact_thickness, two_sided=two_sided
                    )
                    if signed is not None and signed < contact_thickness - 0.00025:
                        candidate_penetrations.append({
                            "vertex": index, "collider": collider_name,
                            "penetration_m": round(contact_thickness - signed, 7)
                        })

        rejection_reasons = []
        if not collision_available:
            rejection_reasons.append(collision_skip_reason)
        if candidate_penetrations:
            rejection_reasons.append(
                f"Candidate still has {len(candidate_penetrations)} residual penetrations; "
                "the garment is restored rather than accepted as a bad fit."
            )
        if max_edge_strain > 0.12:
            rejection_reasons.append(
                f"Candidate changed an edge length by up to {max_edge_strain:.1%}."
            )
        if max_face_area_strain > 0.30:
            rejection_reasons.append(
                f"Candidate changed a panel triangle area by up to {max_face_area_strain:.1%}."
            )
        if min_face_normal_dot < 0.15:
            rejection_reasons.append(
                f"Candidate folded or inverted a panel (minimum face-normal alignment {min_face_normal_dot:.3f})."
            )
        if self_intersection_count:
            rejection_reasons.append(
                f"Candidate contains {self_intersection_count} non-adjacent triangle self-intersections."
            )

        accepted_candidate = not rejection_reasons
        if accepted_candidate:
            apply_world_positions(garment, particles, original_world)
            displacements = candidate_displacements
        else:
            # Reject the whole garment, not just isolated vertices. Partial
            # rollback would itself tear seams and alter panel relationships.
            particles = [Particle.at(tuple(point), 1.0) for point in original_world]
            displacements = [0.0 for _ in particles]

        max_displacement = max(displacements, default=0.0)
        max_total_displacement = max(max_total_displacement, max_displacement)
        final_penetrations = []
        for index, particle in enumerate(particles):
            for collider_name, tree, two_sided in collider_trees:
                contact_thickness = 0.00075 if two_sided else options.thickness
                _contact, signed = closest_contact(
                    tree, particle.position, index, contact_thickness, two_sided=two_sided
                )
                if signed is not None and signed < contact_thickness - 0.00025:
                    final_penetrations.append({
                        "vertex": index, "collider": collider_name,
                        "penetration_m": round(contact_thickness - signed, 7)
                    })
        total_contacts += len(final_penetrations)
        garment_warnings = list(rejection_reasons)
        if final_penetrations:
            garment_warnings.append(
                f"{len(final_penetrations)} residual body/piercing penetrations remain."
            )
        report_rows.append({
            "object": garment.name,
            "vertices": len(particles),
            "faces": len(garment.data.polygons),
            "boundary_vertices": len(boundary_vertices),
            "garment_kind": "cord" if is_cord else "fabric",
            "cord_shape_constraints": cord_shape_constraints,
            "panel_shape_constraints": panel_shape_constraints,
            "motion_constraint": "original garment vertex-normal line; unrestricted signed scalar displacement",
            "cord_cross_section_policy": (
                "preserve perimeter edges and polygon diagonals"
                if is_cord else "not applicable"
            ),
            "structural_constraints": len(edge_constraints),
            "max_vertex_displacement_m": max_displacement,
            "attempted_max_vertex_displacement_m": attempted_max_displacement,
            "max_edge_length_strain": max_edge_strain,
            "max_panel_triangle_area_strain": max_face_area_strain,
            "minimum_face_normal_alignment": min_face_normal_dot,
            "self_intersection_pair_count": self_intersection_count,
            "candidate_remaining_penetration_count": len(candidate_penetrations),
            "candidate_accepted": accepted_candidate,
            "rejection_reasons": rejection_reasons,
            "topology": {
                "vertices": len(garment.data.vertices),
                "edges": len(garment.data.edges),
                "faces": len(garment.data.polygons),
                "unchanged": True,
                "neighbour_relationships_preserved": True
            },
            "fit_quality": (
                "skipped_unreliable_collision_geometry" if not collision_available
                else "rejected_original_preserved" if not accepted_candidate
                else "accepted_within_integrity_limits"
            ),
            "warnings": garment_warnings,
            "mean_vertex_displacement_m": (
                sum(displacements) / len(displacements) if displacements else 0.0
            ),
            "remaining_penetration_count": len(final_penetrations),
            "remaining_penetrations_sample": final_penetrations[:20],
            "shape_key_count": (
                len(garment.data.shape_keys.key_blocks)
                if garment.data.shape_keys else 0
            ),
        })

    # Export the actual visible character only. Collision proxy meshes are
    # deliberately omitted; the accepted skin and piercing render meshes stay.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj.get("cloth_collision_role"):
            continue
        if obj.type in {"MESH", "ARMATURE", "EMPTY"} and not obj.hide_render:
            obj.select_set(True)
    selected = [obj for obj in bpy.context.selected_objects]
    if not selected:
        raise RuntimeError("No visible character objects selected for GLB export")

    report = {
        "stage": "xpbd_static_pose_garment_contact_and_deformation",
        "simulation_run": True,
        "garment_deformation_applied": max_total_displacement > 1.0e-7,
        "body_geometry_deformed": False,
        "body_or_skin_hidden": False,
        "body_or_skin_deleted": False,
        "piercings_hidden_or_moved": False,
        "collision_method": "triangle BVH nearest point plus local oriented skin-normal signed distance; two-sided nearest-point contact for piercings",
        "colliders": [name for name, _tree, _two_sided in collider_trees],
        "collision_confidence": [
            {
                "object": obj.name,
                "status": obj.get("collision_confidence", "unknown"),
                "warnings": json.loads(obj.get("collision_preparation_warnings", "[]")),
            }
            for obj in body if obj.get("cloth_collision_role") == "rigid_contact_surface"
        ],
        "solver": {
            "type": "XPBD",
            "substeps": options.substeps,
            "iterations_per_substep": options.iterations,
            "fabric_thickness_m": options.thickness,
            "maximum_edge_length_strain": 0.12,
            "maximum_panel_triangle_area_strain": 0.30,
            "minimum_face_normal_alignment": 0.15,
            "self_intersections_allowed": 0,
            "vertex_motion_constraint": "original garment vertex-normal line; no absolute displacement cap",
            "gravity": [0.0, 0.0, 0.0],
            "boundary_elasticity": "reinforced boundary-edge distance constraints plus per-panel diagonal constraints",
            "body_response": "static rigid contact; compliant body deformation deferred"
        },
        "garments": report_rows,
        "max_vertex_displacement_m": max_total_displacement,
        "max_attempted_vertex_displacement_m": max_attempted_displacement,
        "diagnostic_displacement_limit_m": None,
        "displacement_limit_is_hard_acceptance_gate": False,
        "exported_for_review": True,
        "fit_quality": (
            "skipped_unreliable_collision_geometry" if not collision_available
            else "rejected_original_preserved" if any(not row["candidate_accepted"] for row in report_rows)
            else "accepted_within_integrity_limits"
        ),
        "warnings": [collision_warning] if collision_warning else [],
        "remaining_penetration_count": total_contacts,
        "limitations": [
            "This is a static-pose garment relaxation, not animated runtime cloth.",
            "Body and piercing are triangle-BVH colliders; body soft-tissue deformation is not yet applied.",
            "Garment topology and vertex-neighbour relationships are immutable during fitting.",
            "Vertices move only along their original garment-normal lines; displacement magnitude is not capped.",
            "Panel diagonals and edge constraints resist shear and shape loss; candidates are rejected for excessive edge strain, panel-area change, or residual penetration.",
            "Open body shells use local oriented surface-normal contact rather than closed-volume ray parity; visually inspect external-envelope normals."
        ]
    }
    os.makedirs(os.path.dirname(os.path.abspath(options.report)), exist_ok=True)
    with open(options.report, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")

    os.makedirs(os.path.dirname(os.path.abspath(options.output_blend)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(options.output_blend))
    os.makedirs(os.path.dirname(os.path.abspath(options.output_glb)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(options.output_glb),
        export_format="GLB", use_selection=True,
        export_apply=False, export_animations=False
    )
    print("WREN_CLOTH_SIMULATION_COMPLETE " + json.dumps({
        "garments": len(report_rows),
        "max_vertex_displacement_m": max_total_displacement,
        "remaining_penetrations": total_contacts
    }, sort_keys=True))


if __name__ == "__main__":
    main()
