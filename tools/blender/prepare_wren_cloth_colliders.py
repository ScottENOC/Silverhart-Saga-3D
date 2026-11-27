"""Prepare real Wren body and piercing meshes as Blender cloth colliders.

This is the first physics integration stage: it does not deform or hide skin,
move the piercing, or fake garment clearance. It builds collision geometry from
the exact accepted Wren body surface and the actual baked piercing meshes so a
later cloth-simulation pass can resolve contact before applying fabric springs.
"""
import argparse
import json
import os
import sys

import bpy
import bmesh
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-blend", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--body-material-prefix", default="skin")
    parser.add_argument("--piercing-prefix", default="Piercing_")
    return parser.parse_args(raw)


def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return {
        "min": [min(point[i] for point in points) for i in range(3)],
        "max": [max(point[i] for point in points) for i in range(3)],
    }


def add_collision_modifier(obj, outer_thickness):
    modifier = next((item for item in obj.modifiers if item.type == "COLLISION"), None)
    if modifier is None:
        modifier = obj.modifiers.new(name="Cloth Contact", type="COLLISION")
    settings = getattr(obj, "collision", None)
    if settings is not None:
        if hasattr(settings, "thickness_outer"):
            settings.thickness_outer = outer_thickness
        if hasattr(settings, "thickness_inner"):
            settings.thickness_inner = 0.001
        if hasattr(settings, "damping"):
            settings.damping = 0.15
        if hasattr(settings, "cloth_friction"):
            settings.cloth_friction = 5.0
    obj["cloth_collision_role"] = "rigid_contact_surface"
    obj["cloth_collision_thickness_m"] = outer_thickness
    return modifier


def make_skin_only_collider(source, material_prefix):
    material_slots = list(source.material_slots)
    skin_indices = {
        index for index, slot in enumerate(material_slots)
        if slot.material and slot.material.name.lower().startswith(material_prefix)
    }
    if not skin_indices:
        raise RuntimeError(
            f"No body material slots begin with {material_prefix!r} on {source.name}"
        )

    mesh = source.data.copy()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    remove_faces = [face for face in bm.faces if face.material_index not in skin_indices]
    if remove_faces:
        bmesh.ops.delete(bm, geom=remove_faces, context="FACES")
    loose = [edge for edge in bm.edges if not edge.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="EDGES")
    loose_vertices = [vertex for vertex in bm.verts if not vertex.link_edges]
    if loose_vertices:
        bmesh.ops.delete(bm, geom=loose_vertices, context="VERTS")
    # A garment collider must be a closed, manifold external shell. Open
    # boundary loops are capped on this collision-only copy; the rendered
    # Wren mesh is never changed. This also prevents ray-parity queries from
    # leaking through genuine mesh holes into interior geometry.
    boundary_edges_before = [edge for edge in bm.edges if edge.is_boundary]
    boundary_edge_count_before = len(boundary_edges_before)
    capped_faces = []
    if boundary_edges_before:
        fill_result = bmesh.ops.holes_fill(
            bm, edges=boundary_edges_before, sides=0
        )
        capped_faces = fill_result.get("faces", [])
    if capped_faces:
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.normal_update()
    boundary_edges_after = [edge for edge in bm.edges if edge.is_boundary]
    nonmanifold_edges_after = [edge for edge in bm.edges if not edge.is_manifold]
    if boundary_edges_after or nonmanifold_edges_after:
        raise RuntimeError(
            "External body collision shell is not closed/manifold after hole "
            f"repair: boundary_edges={len(boundary_edges_after)}, "
            f"nonmanifold_edges={len(nonmanifold_edges_after)}. "
            "Refusing ambiguous ray-parity collision."
        )
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    if len(mesh.polygons) < 100:
        bpy.data.meshes.remove(mesh)
        raise RuntimeError(
            f"Skin-only collider unexpectedly small: {len(mesh.polygons)} faces"
        )

    collider = bpy.data.objects.new("ClothCollider_BodySkin", mesh)
    bpy.context.scene.collection.objects.link(collider)
    collider.matrix_world = source.matrix_world.copy()
    collider.display_type = "WIRE"
    collider.hide_render = True
    collider["source_mesh"] = source.name
    collider["source_materials"] = sorted(
        material_slots[index].material.name for index in skin_indices
    )
    collider["external_shell_policy"] = "skin-only; boundary loops capped; closed manifold required"
    collider["source_boundary_edge_count"] = boundary_edge_count_before
    collider["capped_boundary_face_count"] = len(capped_faces)
    collider["collision_boundary_edge_count"] = len(boundary_edges_after)
    collider["collision_nonmanifold_edge_count"] = len(nonmanifold_edges_after)
    add_collision_modifier(collider, 0.002)
    return collider


def main():
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    body_candidates = [
        obj for obj in meshes
        if any(
            slot.material and slot.material.name.lower().startswith(args.body_material_prefix)
            for slot in obj.material_slots
        )
    ]
    if not body_candidates:
        raise RuntimeError("Could not find the accepted Wren skin mesh")
    body = max(body_candidates, key=lambda obj: len(obj.data.polygons))
    body_collider = make_skin_only_collider(body, args.body_material_prefix)

    piercing_objects = [
        obj for obj in meshes
        if obj.name.startswith(args.piercing_prefix)
        or obj.get("character_detail_type") == "piercing"
    ]
    if not piercing_objects:
        raise RuntimeError(
            "Accepted Wren GLB contains no baked piercing meshes; refusing to "
            "silently proceed without piercing collision"
        )

    piercing_rows = []
    for piercing in piercing_objects:
        if len(piercing.data.polygons) == 0:
            raise RuntimeError(f"Piercing mesh has no faces: {piercing.name}")
        add_collision_modifier(piercing, 0.00075)
        piercing["cloth_collision_role"] = "piercing_rigid_contact_surface"
        piercing_rows.append({
            "name": piercing.name,
            "vertices": len(piercing.data.vertices),
            "faces": len(piercing.data.polygons),
            "bounds_world": world_bounds(piercing),
            "collision_thickness_m": 0.00075,
        })

    report = {
        "stage": "piercing_and_body_collision_preparation",
        "simulation_run": False,
        "garment_deformation_applied": False,
        "body_or_skin_hidden": False,
        "body_or_skin_deleted": False,
        "body_source_object": body.name,
        "body_collider": {
            "name": body_collider.name,
            "vertices": len(body_collider.data.vertices),
            "faces": len(body_collider.data.polygons),
            "bounds_world": world_bounds(body_collider),
            "collision_thickness_m": 0.002,
            "source_materials": body_collider["source_materials"],
            "external_shell_policy": body_collider["external_shell_policy"],
            "source_boundary_edge_count": body_collider["source_boundary_edge_count"],
            "capped_boundary_face_count": body_collider["capped_boundary_face_count"],
            "collision_boundary_edge_count": body_collider["collision_boundary_edge_count"],
            "collision_nonmanifold_edge_count": body_collider["collision_nonmanifold_edge_count"],
        },
        "piercing_colliders": piercing_rows,
        "contact_solver_order": [
            "body_and_piercing_non_penetration",
            "fabric_edge_and_stretch_constraints",
            "body_soft_tissue_compliance",
        ],
        "notes": [
            "Piercing meshes remain ordinary visible render geometry.",
            "The body collider is a separate skin-only copy; the rendered accepted Wren mesh is unchanged.",
            "Every open boundary loop on the collision copy is capped; unresolved boundary/non-manifold edges fail the build.",
            "The collider is built from accepted Wren, not Ara's temporary anatomy fitting reference.",
            "No garment vertices are displaced in this preparation stage.",
        ],
    }

    os.makedirs(os.path.dirname(os.path.abspath(args.output_blend)), exist_ok=True)
    os.makedirs(os.path.dirname(os.path.abspath(args.report)), exist_ok=True)
    with open(args.report, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.output_blend))
    print("WREN_CLOTH_COLLIDERS_READY " + json.dumps({
        "body_faces": len(body_collider.data.polygons),
        "piercing_colliders": len(piercing_rows),
        "piercings": [row["name"] for row in piercing_rows],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
