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


def paired_bone_point(armature, aliases):
    wanted = {name.lower().replace(" ", "").replace("-", "_") for name in aliases}
    bone = next((b for b in armature.data.bones
                 if b.name.lower().replace(" ", "").replace("-", "_") in wanted), None)
    return armature.matrix_world @ bone.head_local if bone else None


def paired_leg_root_height(armature):
    left = paired_bone_point(armature, {
        "LeftUpLeg", "LeftUpperLeg", "UpperLeg_L", "thigh_l", "LeftThigh", "thigh.L"
    })
    right = paired_bone_point(armature, {
        "RightUpLeg", "RightUpperLeg", "UpperLeg_R", "thigh_r", "RightThigh", "thigh.R"
    })
    if left is None or right is None:
        raise RuntimeError("Cannot establish torso lower boundary from paired upper-leg roots")
    return (left.z + right.z) * 0.5


def detect_breast_surface_anchors(skin, armature):
    """Find bilateral breast-surface prominence peaks from the evaluated skin mesh.

    This is a geometry-based landmark estimate, not a nipple locator. It uses
    the paired shoulder/leg-root rig landmarks only to delimit the torso, then
    searches for two front-surface protrusions relative to the sternum and
    lateral ribcage at matching heights. It fails closed when the surface does
    not contain two sufficiently distinct peaks.
    """
    left_shoulder = paired_bone_point(armature, {
        "LeftShoulder", "Shoulder_L", "clavicle_l", "LeftClavicle"
    })
    right_shoulder = paired_bone_point(armature, {
        "RightShoulder", "Shoulder_R", "clavicle_r", "RightClavicle"
    })
    if left_shoulder is None or right_shoulder is None:
        raise RuntimeError("Cannot establish torso upper boundary from paired shoulder bones")

    pelvis_z = paired_leg_root_height(armature)
    shoulder_z = (left_shoulder.z + right_shoulder.z) * 0.5
    torso_span = shoulder_z - pelvis_z
    if torso_span <= 0.05:
        raise RuntimeError("Invalid torso landmark span for breast-surface detection")

    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = skin.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    skin_bounds = [skin.matrix_world @ Vector(corner) for corner in skin.bound_box]
    width = max(point.x for point in skin_bounds) - min(point.x for point in skin_bounds)
    # Delimit the upper torso relative to the actual rig, not whole-body height.
    z_low = pelvis_z + torso_span * 0.36
    z_high = shoulder_z - torso_span * 0.10
    bin_size = max(0.006, torso_span * 0.018)
    bins = {}

    for vertex in mesh.vertices:
        p = skin.matrix_world @ vertex.co
        n = (skin.matrix_world.to_3x3() @ vertex.normal).normalized()
        if n.y > -0.25 or not (z_low <= p.z <= z_high):
            continue
        side = "L" if p.x > 0 else "R"
        ax = abs(p.x)
        if ax < width * 0.035 or ax > width * 0.43:
            continue
        zbin = round((p.z - z_low) / bin_size)
        bins.setdefault(zbin, {"centre": [], "outer": [], "left": [], "right": []})
        bucket = bins[zbin]
        if ax <= width * 0.055:
            bucket["centre"].append(p.y)
        elif ax >= width * 0.31:
            bucket["outer"].append(p.y)
        elif side == "L":
            bucket["left"].append((p.copy(), n.copy()))
        else:
            bucket["right"].append((p.copy(), n.copy()))

    evaluated.to_mesh_clear()
    candidates = {"L": [], "R": []}
    for zbin, bucket in bins.items():
        if not bucket["centre"] or not bucket["outer"]:
            continue
        # Ara faces -Y: a more prominent breast surface has a lower Y value
        # than both the sternum and the lateral ribcage at the same height.
        centre_y = sorted(bucket["centre"])[len(bucket["centre"]) // 2]
        outer_y = sorted(bucket["outer"])[len(bucket["outer"]) // 2]
        baseline_y = (centre_y + outer_y) * 0.5
        for side in ("L", "R"):
            points = bucket["left" if side == "L" else "right"]
            if not points:
                continue
            point, normal = min(points, key=lambda item: item[0].y)
            prominence = baseline_y - point.y
            candidates[side].append((prominence, point, normal, zbin))

    anchors = {}
    diagnostics = {}
    for side in ("L", "R"):
        if not candidates[side]:
            raise RuntimeError(f"No front-surface breast candidates found on {side} side")
        prominence, point, normal, zbin = max(candidates[side], key=lambda item: item[0])
        diagnostics[side] = {
            "prominence_m": round(float(prominence), 5),
            "surface_point_world": [round(float(v), 6) for v in point],
            "surface_normal_world": [round(float(v), 5) for v in normal],
            "z_bin": int(zbin),
        }
        if prominence < 0.004:
            raise RuntimeError(
                f"Breast-surface prominence on {side} side is too weak "
                f"({prominence:.4f}m); refusing to guess a cup location"
            )
        anchors[side] = point.copy()

    if abs(anchors["L"].z - anchors["R"].z) > torso_span * 0.12:
        raise RuntimeError("Detected breast-surface peaks are vertically asymmetric; refusing fit")
    return anchors, {
        "method": "bilateral_surface_prominence",
        "torso_landmarks": {
            "pelvis_z": round(float(pelvis_z), 6),
            "shoulder_z": round(float(shoulder_z), 6),
            "torso_span": round(float(torso_span), 6),
        },
        "candidate_diagnostics": diagnostics,
        "note": "Surface prominence relative to sternum and lateral ribcage; not nipple detection or a cloth simulation.",
    }


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


def align_garment_to_character(selected, reference_path, skin, target_armature):
    """Place this one bra using bilateral prominence peaks on the target skin.

    The authored cup centroids map to the left/right surface peaks. This is
    geometric placement only: it does not infer underbust contours or simulate
    fabric. No body vertices or anatomy profiles are changed.
    """
    if target_armature is None:
        raise RuntimeError("Target companion GLB has no armature")
    target_points, anatomy_report = detect_breast_surface_anchors(skin, target_armature)
    existing = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(reference_path))
    imported = [obj for obj in bpy.context.scene.objects if obj not in existing]
    source_armature = next((obj for obj in imported if obj.type == "ARMATURE"), None)
    if source_armature is None:
        raise RuntimeError("Reference Ara garment GLB has no armature")
    try:
        # The authored garment asset has no nipple sockets. Its cup centroids
        # provide the source references; only the target character supplies
        # anatomical surface sockets.
        source_cups = cup_centres(selected)
        source_mid = (source_cups[0] + source_cups[1]) * 0.5
        target_mid = (target_points["L"] + target_points["R"]) * 0.5
        source_span = (source_cups[0] - source_cups[1]).length
        target_span = (target_points["L"] - target_points["R"]).length
        if min(source_span, target_span) < 1e-4:
            raise RuntimeError("Authored cup centres or target breast sockets are coincident")
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
            "method": "bilateral_surface_prominence_bra_placement",
            "reference": os.path.abspath(reference_path),
            "source_cup_centres_world": [
                [round(float(v), 6) for v in p] for p in source_cups
            ],
            "target_socket_L_world": [round(float(v), 6) for v in target_points["L"]],
            "target_socket_R_world": [round(float(v), 6) for v in target_points["R"]],
            
            "horizontal_spacing_scale": round(horizontal_scale, 6),
            "garment_vertices_warped": moved,
            "body_geometry_modified": False,
            "anatomy_detection": "bilateral front-surface prominence relative to sternum and lateral ribcage; heuristic geometry landmarks, not semantic anatomical segmentation",
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

    anchor_report = align_garment_to_character(selected, args.reference_rig, skin, armature)
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
            "Breast anchors are geometric prominence estimates, not semantic anatomical segmentation",
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
