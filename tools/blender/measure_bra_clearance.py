#!/usr/bin/env python3
"""Measure bra vertex clearance against the Ara skin surface in a GLB.

Run with Blender:
  blender --background --python tools/blender/measure_bra_clearance.py -- --input model.glb --output report.json

Reports nearest-skin distance, signed normal offset, chest-region coverage and
outlier vertices. Ara GLB coordinates are Z-up and face -Y.
"""
import argparse
import json
import math
import os
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    return p.parse_args(raw)


def bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return (Vector(tuple(min(v[i] for v in pts) for i in range(3))),
            Vector(tuple(max(v[i] for v in pts) for i in range(3))))


def material_names(obj):
    return [s.material.name.lower() for s in obj.material_slots if s.material]


def main():
    opt = args()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(opt.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    skin = max((o for o in meshes if any("skin" in n for n in material_names(o))),
               key=lambda o: len(o.data.polygons), default=None)
    if skin is None:
        raise RuntimeError("No skin mesh/material found for bra clearance analysis")
    garment = []
    for obj in meshes:
        selected = set()
        for poly in obj.data.polygons:
            if poly.material_index >= len(obj.material_slots):
                continue
            slot = obj.material_slots[poly.material_index]
            label = slot.material.name.lower() if slot.material else ""
            if "halter lace" in label or "bikini strings" in label:
                selected.update(poly.vertices)
        if selected:
            garment.append((obj, selected))
    if not garment:
        raise RuntimeError("No Halter lace or Bikini strings vertices found")

    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = skin.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    skin_world = [skin.matrix_world @ v.co for v in mesh.vertices]
    faces = [list(poly.vertices) for poly in mesh.polygons]
    tree = BVHTree.FromPolygons(skin_world, faces, all_triangles=False)
    evaluated.to_mesh_clear()
    lo, hi = bounds(skin)
    height = hi.z - lo.z
    width = hi.x - lo.x
    chest_lo, chest_hi = lo.z + height * 0.54, lo.z + height * 0.86

    distances, signed_offsets, chest_distances = [], [], []
    samples, outliers = [], []
    for obj, indices in garment:
        for index in sorted(indices):
            point = obj.matrix_world @ obj.data.vertices[index].co
            nearest = tree.find_nearest(point)
            if nearest is None or nearest[0] is None:
                continue
            location, normal, face_index, distance = nearest
            signed = (point - location).dot(normal.normalized())
            distances.append(float(distance))
            signed_offsets.append(float(signed))
            is_chest = chest_lo <= point.z <= chest_hi and abs(point.x) <= width * 0.43
            if is_chest:
                chest_distances.append(float(distance))
            if len(samples) < 12 or distance > 0.015 or distance < 0.001:
                item = {"object": obj.name, "vertex": int(index),
                        "position": [round(float(v), 5) for v in point],
                        "nearest_skin": [round(float(v), 5) for v in location],
                        "distance_m": round(float(distance), 6),
                        "signed_normal_offset_m": round(float(signed), 6),
                        "chest_band": bool(is_chest)}
                if len(samples) < 12:
                    samples.append(item)
                if distance > 0.015 or distance < 0.001:
                    outliers.append(item)

    def stats(values):
        if not values:
            return {"count": 0}
        ordered = sorted(values)
        def pct(q):
            return round(ordered[min(len(ordered)-1, int((len(ordered)-1)*q))], 6)
        return {"count": len(ordered), "min_m": round(ordered[0], 6),
                "median_m": pct(0.50), "p95_m": pct(0.95),
                "max_m": round(ordered[-1], 6),
                "within_2mm": sum(v <= 0.002 for v in ordered),
                "within_5mm": sum(v <= 0.005 for v in ordered),
                "over_15mm": sum(v > 0.015 for v in ordered)}

    report = {
        "input": os.path.basename(opt.input),
        "coordinate_note": "Ara GLB: Z up, character faces -Y; distances are to nearest skin triangle.",
        "skin_object": skin.name,
        "skin_bounds_m": {"min": [round(float(v), 5) for v in lo],
                          "max": [round(float(v), 5) for v in hi]},
        "chest_band_z_m": [round(float(chest_lo), 5), round(float(chest_hi), 5)],
        "garment_vertex_count": len(distances),
        "nearest_skin_distance": stats(distances),
        "chest_band_distance": stats(chest_distances),
        "signed_normal_offset_m": {
            "count": len(signed_offsets),
            "min_m": round(min(signed_offsets), 6) if signed_offsets else None,
            "median_m": round(sorted(signed_offsets)[(len(signed_offsets)-1)//2], 6) if signed_offsets else None,
            "max_m": round(max(signed_offsets), 6) if signed_offsets else None,
        },
        "absolute_normal_offset_m": stats([abs(v) for v in signed_offsets]),
        "outlier_thresholds": "distance > 15 mm or < 1 mm",
        "outlier_examples": outliers[:100],
        "sample_vertices": samples,
    }
    os.makedirs(os.path.dirname(os.path.abspath(opt.output)), exist_ok=True)
    with open(opt.output, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print("BRA_CLEARANCE_REPORT " + json.dumps({
        "vertices": len(distances),
        "nearest_skin": report["nearest_skin_distance"],
        "chest_band": report["chest_band_distance"],
        "signed_offset": report["signed_normal_offset_m"],
        "absolute_offset": report["absolute_normal_offset_m"],
        "outliers": len(outliers),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
