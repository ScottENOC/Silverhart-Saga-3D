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


def closest_contact(tree, point, particle_index, thickness):
    hit = tree.find_nearest(Vector(point))
    if hit is None:
        return None, None
    location, _face_normal, _face, distance = hit
    if location is None or distance is None:
        return None, None
    point = Vector(point)
    location = Vector(location)
    distance = float(distance)
    if distance <= 1.0e-9:
        return Contact(particle_index, 0.0, (0.0, 0.0, 1.0), thickness), 0.0

    inside = point_is_inside(tree, point)
    # Outside: move away from the surface toward the current point.
    # Inside: move through the nearest surface toward the exterior.
    direction = (location - point) if inside else (point - location)
    normal = direction.normalized()
    signed = -distance if inside else distance
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

    collider_trees = [(obj.name, world_bvh(obj, depsgraph)) for obj in body + piercings]
    report_rows = []
    max_total_displacement = 0.0
    total_contacts = 0
    for garment in garments:
        original_world = [garment.matrix_world @ vertex.co for vertex in garment.data.vertices]
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
                for _name, tree in collider_trees:
                    contact, signed = closest_contact(
                        tree, point, index, options.thickness
                    )
                    if contact is not None:
                        if signed < options.thickness:
                            contacts.append(contact)
                        if signed < 0.0 and len(initial_penetrations) < 1:
                            initial_penetrations.append(signed)
            return contacts

        # A static-pose relaxation: no arbitrary gravity direction is imposed.
        # Contact is queried against actual triangles before and after each
        # structural iteration, so the fabric cannot spring back through skin
        # or the baked piercing geometry.
        for _ in range(max(1, options.substeps)):
            solve_frame(
                particles, edge_constraints, contact_provider,
                dt=1.0 / 60.0, gravity=(0.0, 0.0, 0.0),
                iterations=max(1, options.iterations), damping=0.0
            )

        before = [point.copy() for point in original_world]
        apply_world_positions(garment, particles, original_world)
        displacements = [
            (Vector(particle.position) - before[index]).length
            for index, particle in enumerate(particles)
        ]
        max_displacement = max(displacements, default=0.0)
        max_total_displacement = max(max_total_displacement, max_displacement)
        final_penetrations = []
        for index, particle in enumerate(particles):
            for collider_name, tree in collider_trees:
                _contact, signed = closest_contact(
                    tree, particle.position, index, options.thickness
                )
                if signed is not None and signed < -0.00025:
                    final_penetrations.append({
                        "vertex": index, "collider": collider_name,
                        "penetration_m": round(-signed, 7)
                    })
        total_contacts += len(final_penetrations)
        displacement_warning = None
        if max_displacement > 1.0:
            displacement_warning = (
                f"Extreme displacement ({max_displacement:.4f}m); exported for review, "
                "not accepted as a valid fit."
            )
        report_rows.append({
            "object": garment.name,
            "vertices": len(particles),
            "faces": len(garment.data.polygons),
            "boundary_vertices": len(boundary_vertices),
            "garment_kind": "cord" if is_cord else "fabric",
            "cord_shape_constraints": cord_shape_constraints,
            "cord_cross_section_policy": (
                "preserve perimeter edges and polygon diagonals"
                if is_cord else "not applicable"
            ),
            "structural_constraints": len(edge_constraints),
            "max_vertex_displacement_m": max_displacement,
            "fit_quality": "warning" if displacement_warning else "unassessed",
            "warnings": [displacement_warning] if displacement_warning else [],
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

    no_measurable_correction = max_total_displacement <= 1.0e-7

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
        "garment_deformation_applied": not no_measurable_correction,
        "body_geometry_deformed": False,
        "body_or_skin_hidden": False,
        "body_or_skin_deleted": False,
        "piercings_hidden_or_moved": False,
        "collision_method": "triangle BVH nearest point plus three-ray majority parity signed distance",
        "colliders": [name for name, _tree in collider_trees],
        "collision_confidence": [
            obj.get("collision_preparation_warnings", "[]")
            for obj in body if obj.get("cloth_collision_role") == "rigid_contact_surface"
        ],
        "solver": {
            "type": "XPBD",
            "substeps": options.substeps,
            "iterations_per_substep": options.iterations,
            "fabric_thickness_m": options.thickness,
            "gravity": [0.0, 0.0, 0.0],
            "boundary_elasticity": "reinforced boundary-edge distance constraints",
            "body_response": "static rigid contact; compliant body deformation deferred"
        },
        "garments": report_rows,
        "max_vertex_displacement_m": max_total_displacement,
        "diagnostic_displacement_limit_m": 1.0,
        "displacement_limit_is_warning_only": True,
        "exported_for_review": True,
        "fit_quality": (
            "unchanged_no_correction" if no_measurable_correction
            else "warning" if any(row["warnings"] for row in report_rows)
            else "unassessed"
        ),
        "warnings": (
            ["Solver made no measurable correction; unchanged garment exported for diagnosis."]
            if no_measurable_correction else []
        ),
        "remaining_penetration_count": total_contacts,
        "limitations": [
            "This is a static-pose garment relaxation, not animated runtime cloth.",
            "Body and piercing are triangle-BVH colliders; body soft-tissue deformation is not yet applied.",
            "Boundary edges receive reinforced elastic constraints; garment-specific seam loops are not yet semantically tagged."
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
