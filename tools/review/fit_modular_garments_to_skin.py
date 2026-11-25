#!/usr/bin/env python3
"""Refit modular underwear vertices to the accepted companion's skin surface.

The catalogue garments are independently skinned meshes, but their source-body
proportions do not perfectly match every companion. After the bind-pose scale
fit, this pass moves only garment vertices that are embedded in the target skin
to a small, consistent clearance outside the nearest skin surface. The body
mesh and its shape keys are never edited.
"""
import argparse
import json
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--clearance", type=float, default=0.004)
    parser.add_argument("--max-distance", type=float, default=0.090)
    parser.add_argument("--max-adjustment", type=float, default=0.090)
    return parser.parse_args(raw)


def main():
    args = parse_args()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    body = None
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and any(
            slot.material and slot.material.name.lower().startswith("skin")
            for slot in obj.material_slots
        ):
            body = obj
            break
    if body is None:
        raise RuntimeError("Could not find the imported skinned body mesh")

    mesh = body.data
    skin_indices = {
        index for index, slot in enumerate(body.material_slots)
        if slot.material and slot.material.name.lower().startswith("skin")
    }
    skin_faces = [
        tuple(poly.vertices) for poly in mesh.polygons
        if poly.material_index in skin_indices and len(poly.vertices) >= 3
    ]
    if not skin_faces:
        raise RuntimeError("No skin-material polygons found for garment fitting")

    matrix = body.matrix_world.copy()
    inverse = matrix.inverted()
    world_vertices = [matrix @ vertex.co for vertex in mesh.vertices]
    skin_vertex_ids = sorted({v for face in skin_faces for v in face})
    body_centre = sum((world_vertices[i] for i in skin_vertex_ids), Vector()) / len(skin_vertex_ids)
    tree = BVHTree.FromPolygons(world_vertices, skin_faces, all_triangles=False)

    garment_names = {"Triangle bikini top", "String bikini bottom", "Bra", "Briefs"}
    material_to_vertices = {name: set() for name in garment_names}
    for poly in mesh.polygons:
        if poly.material_index >= len(body.material_slots):
            continue
        slot = body.material_slots[poly.material_index]
        name = slot.material.name if slot.material else ""
        if name in material_to_vertices:
            material_to_vertices[name].update(poly.vertices)

    missing = sorted(name for name, ids in material_to_vertices.items() if not ids)
    if missing:
        raise RuntimeError("Garment surface(s) missing from assembled GLB: " + ", ".join(missing))

    report = {
        "input": args.input,
        "clearance_m": args.clearance,
        "max_distance_m": args.max_distance,
        "max_adjustment_m": args.max_adjustment,
        "garments": {},
    }
    adjustments = {}
    for name, vertex_ids in material_to_vertices.items():
        adjusted = 0
        skipped_far = 0
        max_delta = 0.0
        before_signed = []
        after_signed = []
        for vertex_id in sorted(vertex_ids):
            point = world_vertices[vertex_id]
            hit, normal, _face_index, distance = tree.find_nearest(point)
            if hit is None or normal is None or distance is None or distance > args.max_distance:
                skipped_far += 1
                continue
            normal = normal.normalized()
            if normal.dot(hit - body_centre) < 0:
                normal.negate()
            signed = (point - hit).dot(normal)
            before_signed.append(signed)
            required = args.clearance - signed
            if required > 0:
                if required > args.max_adjustment:
                    skipped_far += 1
                    continue
                adjustments[vertex_id] = max(adjustments.get(vertex_id, 0.0), required)
                max_delta = max(max_delta, required)
                adjusted += 1
                after_signed.append(args.clearance)
            else:
                after_signed.append(signed)
        report["garments"][name] = {
            "vertices": len(vertex_ids),
            "adjusted_vertices": adjusted,
            "skipped_far_vertices": skipped_far,
            "max_displacement_m": round(max_delta, 5),
            "median_signed_before_m": round(sorted(before_signed)[len(before_signed)//2], 5) if before_signed else None,
        }

    for vertex_id, displacement in adjustments.items():
        point = world_vertices[vertex_id]
        hit, normal, _face_index, _distance = tree.find_nearest(point)
        if hit is None or normal is None:
            continue
        normal = normal.normalized()
        if normal.dot(hit - body_centre) < 0:
            normal.negate()
        mesh.vertices[vertex_id].co = inverse @ (point + normal * displacement)

    mesh.update()
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(json.dumps(report, indent=2) + "\n")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(args.output),
        export_format="GLB",
        use_selection=False,
        export_apply=False,
        export_animations=True,
    )
    print(json.dumps(report, indent=2))
    print("Exported surface-fitted garment preview:", args.output)


if __name__ == "__main__":
    main()
