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


def pelvis_landmark_from_leg_roots(source):
    """Return the hip-joint height from paired upper-leg roots."""
    armature = next(
        (modifier.object for modifier in source.modifiers
         if modifier.type == "ARMATURE" and modifier.object is not None),
        None,
    )
    if armature is None:
        raise RuntimeError("Cannot build anatomical collision proxy without Wren's armature")
    aliases = {
        "left": {"leftupleg", "leftupperleg", "upleg_l", "upperleg_l",
                 "thigh_l", "leftthigh", "lthigh", "thigh.l"},
        "right": {"rightupleg", "rightupperleg", "upleg_r", "upperleg_r",
                  "thigh_r", "rightthigh", "rthigh", "thigh.r"},
    }
    found = {}
    for side, names in aliases.items():
        bone = next(
            (item for item in armature.data.bones
             if item.name.lower().replace(" ", "").replace("-", "_") in names),
            None,
        )
        if bone is not None:
            found[side] = armature.matrix_world @ bone.head_local
    if len(found) != 2:
        raise RuntimeError(
            "Cannot locate paired femur roots for external pelvis collision proxy; "
            f"found {sorted(found)}"
        )
    return 0.5 * (found["left"].z + found["right"].z)


def smooth_pelvic_recesses(bm, source):
    """Soften only the collision copy's midline genital/perineal relief.

    This removes small recessed folds from nearest-surface contact queries.
    The rendered skin and its anatomical detail remain completely untouched.
    """
    bounds = world_bounds(source)
    height = bounds["max"][2] - bounds["min"][2]
    if height <= 0.0:
        raise RuntimeError("Invalid Wren skin bounds for pelvic collision proxy")
    scale = height / 1.687
    hipline_z = pelvis_landmark_from_leg_roots(source)
    selected = []
    for vertex in bm.verts:
        point = source.matrix_world @ vertex.co
        if abs(point.x) <= 0.045 * scale and abs(point.z - hipline_z) <= 0.075 * scale:
            selected.append(vertex)
    if len(selected) < 8:
        raise RuntimeError(
            "Pelvic collision smoothing selected too few vertices; refusing an "
            "unverified genital/perineal contact surface"
        )
    # The proxy keeps the broad body envelope but not fine central recesses
    # that could attract garment vertices into the vulval/perineal region.
    for _ in range(5):
        bmesh.ops.smooth_vert(
            bm, verts=selected, factor=0.22,
            use_axis_x=True, use_axis_y=True, use_axis_z=True,
        )
    bm.normal_update()
    return len(selected), hipline_z


def boundary_edge_components(bm):
    """Return connected boundary-edge loops/components for independent capping."""
    remaining = {edge for edge in bm.edges if edge.is_boundary}
    components = []
    while remaining:
        start = remaining.pop()
        component = [start]
        stack = [start]
        while stack:
            edge = stack.pop()
            for vertex in edge.verts:
                for linked in vertex.link_edges:
                    if linked in remaining and linked.is_boundary:
                        remaining.remove(linked)
                        component.append(linked)
                        stack.append(linked)
        components.append(component)
    return components


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
    preparation_warnings = []
    try:
        smoothed_pelvic_vertices, pelvis_z = smooth_pelvic_recesses(bm, source)
    except Exception as error:
        smoothed_pelvic_vertices, pelvis_z = 0, None
        preparation_warnings.append("Pelvic relief smoothing failed: " + repr(error))
    boundary_components_before = boundary_edge_components(bm)
    boundary_edge_count_before = sum(len(component) for component in boundary_components_before)
    capped_faces = []
    cap_methods = []
    for component in boundary_components_before:
        # Fill one closed loop at a time. Passing every loop to holes_fill in
        # one call can leave valid loops untouched on dense imported GLBs.
        faces = []
        method = "holes_fill"
        try:
            fill_result = bmesh.ops.holes_fill(bm, edges=component, sides=0)
            faces = list(fill_result.get("faces", []))
        except Exception as error:
            preparation_warnings.append(
                f"holes_fill failed for {len(component)} boundary edges: {error!r}"
            )
        if not faces:
            method = "edgenet_fill"
            try:
                fallback = bmesh.ops.edgenet_fill(
                    bm, edges=component, mat_nr=0,
                    use_smooth=True, use_dissolve=False,
                )
                faces = list(fallback.get("faces", []))
            except Exception as error:
                preparation_warnings.append(
                    f"edgenet_fill failed for {len(component)} boundary edges: {error!r}"
                )
        if not faces:
            method = "unrepaired"
            preparation_warnings.append(
                f"Boundary component with {len(component)} edges remains open"
            )
        capped_faces.extend(faces)
        cap_methods.append({
            "boundary_edges": len(component),
            "created_faces": len(faces),
            "method": method,
        })
    if capped_faces:
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.normal_update()
    boundary_components_after = boundary_edge_components(bm)
    boundary_edges_after = [edge for component in boundary_components_after for edge in component]
    nonmanifold_edges_after = [edge for edge in bm.edges if not edge.is_manifold]
    remaining_sizes = sorted((len(component) for component in boundary_components_after), reverse=True)
    if boundary_edges_after or nonmanifold_edges_after:
        preparation_warnings.append(
            "Collision shell is not watertight; ray-parity inside/outside results "
            "are diagnostic only. "
            f"remaining_boundary_edges={len(boundary_edges_after)}, "
            f"remaining_loop_sizes={remaining_sizes[:12]}, "
            f"nonmanifold_edges={len(nonmanifold_edges_after)}"
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
    collider["external_shell_policy"] = "skin-only; pelvic recesses softened; boundary loops capped; closed manifold required"
    collider["pelvic_recess_smoothing_vertices"] = smoothed_pelvic_vertices
    collider["pelvis_landmark_z"] = pelvis_z
    collider["source_boundary_edge_count"] = boundary_edge_count_before
    collider["capped_boundary_face_count"] = len(capped_faces)
    collider["boundary_loop_count"] = len(boundary_components_before)
    collider["boundary_cap_methods"] = str(cap_methods)
    collider["collision_boundary_edge_count"] = len(boundary_edges_after)
    collider["collision_nonmanifold_edge_count"] = len(nonmanifold_edges_after)
    collider["collision_preparation_warnings"] = json.dumps(preparation_warnings)
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
            "pelvic_recess_smoothing_vertices": body_collider["pelvic_recess_smoothing_vertices"],
            "pelvis_landmark_z": body_collider["pelvis_landmark_z"],
            "source_boundary_edge_count": body_collider["source_boundary_edge_count"],
            "capped_boundary_face_count": body_collider["capped_boundary_face_count"],
            "boundary_loop_count": body_collider["boundary_loop_count"],
            "boundary_cap_methods": body_collider["boundary_cap_methods"],
            "collision_boundary_edge_count": body_collider["collision_boundary_edge_count"],
            "collision_nonmanifold_edge_count": body_collider["collision_nonmanifold_edge_count"],
            "preparation_warnings": json.loads(body_collider["collision_preparation_warnings"]),
            "collision_confidence": (
                "closed_manifold" if not boundary_edges_after and not nonmanifold_edges_after
                else "open_or_nonmanifold_diagnostic_only"
            ),
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
            "Midline pelvic recesses are softened on the collision-only copy so internal-looking vulval/perineal relief does not attract nearest-surface contacts.",
            "Open boundary loops are capped where possible; unresolved boundaries are recorded as warnings and fitting continues with diagnostic-only collision confidence.",
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
        "boundary_edges": len(boundary_edges_after),
        "nonmanifold_edges": len(nonmanifold_edges_after),
        "warnings": preparation_warnings,
        "piercings": [row["name"] for row in piercing_rows],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
