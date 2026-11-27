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


def closest_contact(tree, point, particle_index, thickness):
    hit = tree.find_nearest(Vector(point))
    if hit is None:
        return None, None
    location, normal, _face, distance = hit
    if location is None or normal is None:
        return None, None
    signed = (Vector(point) - location).dot(normal)
    return Contact(particle_index, signed, tuple(normal), thickness), signed


def apply_world_positions(obj, particles, original_world):
    inverse = obj.matrix_world.inverted_safe()
    offsets = []
    for index, particle in enumerate(particles):
        delta_world = Vector(particle.position) - original_world[index]
        offsets.append(delta_world)
        obj.data.vertices[index].co = inverse @ (original_world[index] + delta_world)
    # Apply the same solved offset to every shape key so morph deltas survive.
    keys = obj.data.shape_keys
    if keys:
        for block in keys.key_blocks:
            for index, delta_world in enumerate(offsets):
                base_world = obj.matrix_world @ Vector(obj.data.vertices[index].co)
                block.data[index].co += inverse.to_3x3() @ delta_world
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
        for edge in garment.data.edges:
            a, b = edge.vertices
            rest = (original_world[a] - original_world[b]).length
            edge_constraints.append(DistanceConstraint(
                a, b, rest, compliance=1.0e-8, stiffness=0.92
            ))
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
                    a, b, rest, compliance=2.0e-9, stiffness=0.995
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
        if max_displacement > 0.03:
            raise RuntimeError(
                f"{garment.name} required implausible {max_displacement:.4f}m "
                "vertex displacement; refusing to export"
            )
        report_rows.append({
            "object": garment.name,
            "vertices": len(particles),
            "faces": len(garment.data.polygons),
            "boundary_vertices": len(boundary_vertices),
            "structural_constraints": len(edge_constraints),
            "max_vertex_displacement_m": max_displacement,
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

    if max_total_displacement <= 1.0e-7:
        raise RuntimeError(
            "The solver made no measurable garment correction; refusing to "
            "label an unchanged mesh as a simulated fit"
        )

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
        "garment_deformation_applied": True,
        "body_geometry_deformed": False,
        "body_or_skin_hidden": False,
        "body_or_skin_deleted": False,
        "piercings_hidden_or_moved": False,
        "collision_method": "triangle BVH nearest-point signed-distance contact",
        "colliders": [name for name, _tree in collider_trees],
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
