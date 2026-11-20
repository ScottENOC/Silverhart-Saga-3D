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


def main():
    args = parse_args()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
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
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = skin
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False)
    report = {
        "experiment": "fishnet_halter_bra_bidirectional_surface_fit",
        "input": args.input,
        "output": args.output,
        "modified_materials": sorted(MATERIALS),
        "starting_position": "authored Ara rest placement; no global repositioning",
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
            "Nearest-surface mapping is not yet anatomically region-constrained",
            "Large placement errors require authored landmark repositioning or re-patterning",
            "Edge strain is a diagnostic approximation",
        ],
    }
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(json.dumps(report, indent=2))
    print("FISHNET BRA FIT REPORT", json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    main()
