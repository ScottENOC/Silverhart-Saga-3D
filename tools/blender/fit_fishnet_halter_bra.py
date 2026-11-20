#!/usr/bin/env python3
"""One-garment fitting experiment: Ara halter fishnet bra on two companion bodies.

Only the two halter-fishnet-bra material regions are modified. The companion
skin, rig, other garments, and approved body profiles are never changed.

The source garment's authored rest placement is retained as the starting pose.
A bounded, bidirectional surface correction then tests whether small
penetrations can be pushed outward and small gaps drawn inward. This is a
prototype fit pass, not a cloth simulation or a claim of physically accurate
fabric strain.
"""
import argparse
import json
import os
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

MATERIALS = {"Halter fishnet bra cups", "Halter fishnet bra straps"}


def parse_args():
    raw = __import__("sys").argv
    raw = raw[raw.index("--") + 1:] if "--" in raw else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--reference-rig", required=True, help="Original Ara garment GLB used to provide the reference skeleton anchors")
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--clearance", type=float, default=0.0035)
    parser.add_argument("--max-gap", type=float, default=0.020)
    parser.add_argument("--max-correction", type=float, default=0.020)
    return parser.parse_args(raw)


def material_names(obj, polygon):
    i = polygon.material_index
    if i >= len(obj.material_slots):
        return ""
    material = obj.material_slots[i].material
    return material.name if material else ""


def make_skin_bvh(skin):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = skin.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    matrix = skin.matrix_world
    skin_slots = {
        i for i, slot in enumerate(skin.material_slots)
        if slot.material and "skin" in slot.material.name.lower()
    }
    verts = [matrix @ v.co for v in mesh.vertices]
    # The imported GLB may combine skin and garment primitives into one mesh.
    # Build the BVH from skin-material triangles only, never from the bra itself.
    polys = [
        tuple(triangle.vertices)
        for triangle in mesh.loop_triangles
        if mesh.polygons[triangle.polygon_index].material_index in skin_slots
    ]
    if not verts or not polys:
        evaluated.to_mesh_clear()
        raise RuntimeError("Skin mesh has no skin-material triangles")
    tree = BVHTree.FromPolygons(verts, polys, all_triangles=True)
    evaluated.to_mesh_clear()
    return tree


def bone_head_world(armature, name):
    bone = armature.data.bones.get(name)
    if bone is None:
        raise RuntimeError(f"Required fit anchor bone is missing: {name}")
    return armature.matrix_world @ bone.head_local


def nipple_socket_world(armature, side):
    """Read the existing surface-derived breast reference socket."""
    name = f"SOCKET_Nipple_{side}"
    socket = next((obj for obj in bpy.context.scene.objects
                   if obj.parent == armature and obj.name.split(".")[0] == name), None)
    if socket is None:
        raise RuntimeError(
            f"Character is missing {name}; refusing to guess bra height from torso bones"
        )
    point = socket.matrix_world.translation.copy()
    return point


def cup_centres(selected):
    """Find authored left/right cup centroids from the cup material vertices."""
    points = []
    for obj, indices in selected.items():
        for polygon in obj.data.polygons:
            if material_names(obj, polygon) != "Halter fishnet bra cups":
                continue
            for index in polygon.vertices:
                points.append(obj.matrix_world @ obj.data.vertices[index].co)
    if len(points) < 4:
        raise RuntimeError("Could not identify enough vertices in the authored bra cups")
    midpoint_x = sorted(p.x for p in points)[len(points) // 2]
    left = [p for p in points if p.x >= midpoint_x]
    right = [p for p in points if p.x < midpoint_x]
    if not left or not right:
        raise RuntimeError("Could not separate the two authored bra cups")
    return (
        sum(left, Vector()) / len(left),
        sum(right, Vector()) / len(right),
    )


def align_garment_to_character(selected, reference_path):
    """Place this one bra from bilateral surface-derived nipple reference sockets.

    The socket generator is a bounded surface-vertex heuristic, not semantic
    breast recognition. We use it as an explicit placement reference only.
    The authored cup centroids are mapped to the corresponding left/right
    sockets; the complete garment follows that translation and horizontal
    spacing adjustment. No body vertices or anatomy profiles are changed.
    """
    target_armature = next(
        (obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"),
        None,
    )
    if target_armature is None:
        raise RuntimeError("Target companion GLB has no armature")

    target_points = {
        "L": nipple_socket_world(target_armature, "L"),
        "R": nipple_socket_world(target_armature, "R"),
    }
    existing = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(reference_path))
    imported = [obj for obj in bpy.context.scene.objects if obj not in existing]
    source_armature = next((obj for obj in imported if obj.type == "ARMATURE"), None)
    if source_armature is None:
        raise RuntimeError("Reference Ara garment GLB has no armature")
    try:
        source_points = {
            "L": nipple_socket_world(source_armature, "L"),
            "R": nipple_socket_world(source_armature, "R"),
        }
        source_cups = cup_centres(selected)
        source_mid = (source_points["L"] + source_points["R"]) * 0.5
        target_mid = (target_points["L"] + target_points["R"]) * 0.5
        source_span = (source_points["L"] - source_points["R"]).length
        target_span = (target_points["L"] - target_points["R"]).length
        if min(source_span, target_span) < 1e-4:
            raise RuntimeError("Bilateral breast reference sockets are coincident")
        horizontal_scale = target_span / source_span

        moved = 0
        for obj, indices in selected.items():
            inverse = obj.matrix_world.inverted()
            for index in indices:
                world = obj.matrix_world @ obj.data.vertices[index].co
                relative = world - source_mid
                adapted = target_mid + Vector((
                    relative.x * horizontal_scale,
                    relative.y,
                    relative.z,
                ))
                obj.data.vertices[index].co = inverse @ adapted
                moved += 1
            obj.data.update()

        report = {
            "method": "bilateral_surface_socket_bra_placement",
            "reference": os.path.abspath(reference_path),
            "source_socket_L_world": [round(float(v), 6) for v in source_points["L"]],
            "source_socket_R_world": [round(float(v), 6) for v in source_points["R"]],
            "target_socket_L_world": [round(float(v), 6) for v in target_points["L"]],
            "target_socket_R_world": [round(float(v), 6) for v in target_points["R"]],
            "source_authored_cup_centres_world": [
                [round(float(v), 6) for v in p] for p in source_cups
            ],
            "horizontal_spacing_scale": round(horizontal_scale, 6),
            "garment_vertices_warped": moved,
            "body_geometry_modified": False,
            "anatomy_detection": "uses existing bilateral surface-derived nipple sockets; these are heuristic surface anchors, not breast-volume recognition",
            "scope": "fishnet halter bra cups and straps only",
        }
        print("BRA BREAST-REFERENCE PLACEMENT", json.dumps(report, indent=2), flush=True)
        return report
    finally:
        for obj in imported:
            bpy.data.objects.remove(obj, do_unlink=True)


def main():
    args = parse_args()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if armature is None:
        raise RuntimeError("Could not identify the target companion armature")
    skin = max((o for o in meshes if any(
        s.material and "skin" in s.material.name.lower() for s in o.material_slots
    )), key=lambda o: len(o.data.polygons), default=None)
    if skin is None:
        raise RuntimeError("Could not identify the companion skin mesh")

    selected = {}
    for obj in meshes:
        for poly in obj.data.polygons:
            name = material_names(obj, poly)
            if name in MATERIALS:
                selected.setdefault(obj, set()).update(poly.vertices)
    if not selected:
        raise RuntimeError("Fishnet halter bra material regions were not found")

    anchor_report = align_garment_to_character(selected, args.reference_rig)
    tree = make_skin_bvh(skin)
    totals = {
        "vertices": 0, "penetrating": 0, "small_gaps": 0,
        "large_gaps": 0, "moved_outward": 0, "moved_inward": 0,
        "rejected_far": 0, "max_correction_m": 0.0,
        "max_edge_strain_estimate": 0.0,
    }
    material_vertex_sets = {}
    for obj, indices in selected.items():
        inv = obj.matrix_world.inverted()
        before = {i: obj.matrix_world @ obj.data.vertices[i].co for i in indices}
        corrections = {}
        for i in sorted(indices):
            point = before[i]
            nearest = tree.find_nearest(point)
            if not nearest or nearest[0] is None or nearest[1] is None:
                totals["rejected_far"] += 1
                continue
            surface, normal, _face, distance = nearest
            normal = normal.normalized()
            signed = (point - surface).dot(normal)
            correction = Vector((0.0, 0.0, 0.0))
            if signed < 0.0:
                totals["penetrating"] += 1
                amount = min(args.clearance - signed, args.max_correction)
                correction = normal * amount
                totals["moved_outward"] += 1
            elif signed > args.clearance:
                gap = signed - args.clearance
                if gap <= args.max_gap:
                    # Elastic contraction test: draw a nearby floating point
                    # toward the body. Large gaps are not silently stretched.
                    amount = min(gap, args.max_correction)
                    correction = -normal * amount
                    totals["small_gaps"] += 1
                    totals["moved_inward"] += 1
                else:
                    totals["large_gaps"] += 1
            if correction.length > 0:
                obj.data.vertices[i].co = inv @ (point + correction)
                corrections[i] = correction
                totals["max_correction_m"] = max(totals["max_correction_m"], correction.length)
            totals["vertices"] += 1

        # A simple edge-based differential-correction estimate flags places
        # where neighbouring vertices would need substantially different
        # deformation. It is diagnostic, not a cloth strain tensor.
        edge_count = 0
        max_strain = 0.0
        for edge in obj.data.edges:
            a, b = edge.vertices
            if a not in corrections or b not in corrections:
                continue
            length = (before[a] - before[b]).length
            if length <= 1e-8:
                continue
            strain = (corrections[a] - corrections[b]).length / length
            max_strain = max(max_strain, strain)
            edge_count += 1
        totals["max_edge_strain_estimate"] = max(totals["max_edge_strain_estimate"], max_strain)
        material_vertex_sets[obj.name] = len(indices)
        obj.data.update()

    # Preserve the body exactly: only selected bra vertices were written.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False)
    report = {
        "experiment": "fishnet_halter_bra_bidirectional_surface_fit",
        "input": args.input,
        "output": args.output,
        "modified_materials": sorted(MATERIALS),
        "starting_position": "authored Ara placement mapped to target bilateral surface-derived nipple reference sockets",
        "anchor_adaptation": anchor_report,
        "correction_policy": {
            "clearance_m": args.clearance,
            "small_gap_limit_m": args.max_gap,
            "maximum_vertex_correction_m": args.max_correction,
            "penetration": "bounded outward correction",
            "small_gap": "bounded inward elastic-contraction test",
            "large_gap": "left unchanged and reported",
        },
        "body_geometry_modified": False,
        "garment_vertex_counts_by_object": material_vertex_sets,
        "metrics": totals,
        "limitations": [
            "No full cloth simulation",
            "Nipple sockets are heuristic front-surface anchors, not semantic breast-volume detection",
            "Cup placement does not yet infer underbust contours or perform garment-specific cup shaping",
            "Large placement errors require authored landmark repositioning or re-patterning",
            "Edge strain is a diagnostic approximation",
        ],
    }
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(json.dumps(report, indent=2))
    print("FISHNET BRA FIT REPORT", json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    main()
