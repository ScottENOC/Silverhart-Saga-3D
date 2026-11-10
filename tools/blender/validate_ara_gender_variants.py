#!/usr/bin/env python3
"""Compare raw Ara gender exports with their anatomy-processed runtime bodies.

Run by Blender in background mode. This is diagnostic: it never edits or exports
any source asset. Geometry deltas are compared by vertex index only when the
two selected skin meshes have matching topology.
"""
import argparse
import json
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--female-raw", required=True)
    parser.add_argument("--male-raw", required=True)
    parser.add_argument("--female-final", required=True)
    parser.add_argument("--male-final", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(raw)


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_glb(path):
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")
    return meshes


def material_names(obj):
    return [slot.material.name for slot in obj.material_slots if slot.material]


def choose_skin(meshes):
    candidates = [
        obj for obj in meshes
        if any("skin" in name.lower() for name in material_names(obj))
    ]
    if not candidates:
        raise RuntimeError("Could not identify a skin mesh by material name")
    return max(candidates, key=lambda obj: len(obj.data.polygons))


def mesh_summary(obj):
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    minimum = [min(point[i] for point in points) for i in range(3)]
    maximum = [max(point[i] for point in points) for i in range(3)]
    dimensions = [maximum[i] - minimum[i] for i in range(3)]
    return {
        "object": obj.name,
        "vertices": len(obj.data.vertices),
        "polygons": len(obj.data.polygons),
        "materials": material_names(obj),
        "bounds_min_xyz": [round(v, 6) for v in minimum],
        "bounds_max_xyz": [round(v, 6) for v in maximum],
        "dimensions_xyz": [round(v, 6) for v in dimensions],
        "world_matrix": [[round(v, 8) for v in row] for row in obj.matrix_world],
    }


def compare_meshes(a, b):
    result = {
        "same_vertex_count": len(a.data.vertices) == len(b.data.vertices),
        "same_polygon_count": len(a.data.polygons) == len(b.data.polygons),
    }
    if not result["same_vertex_count"]:
        result["comparable_by_vertex_index"] = False
        return result
    pa = [a.matrix_world @ vertex.co for vertex in a.data.vertices]
    pb = [b.matrix_world @ vertex.co for vertex in b.data.vertices]
    deltas = [(x - y).length for x, y in zip(pa, pb)]
    result.update({
        "comparable_by_vertex_index": True,
        "rms_vertex_displacement_metres": round(
            (sum(delta * delta for delta in deltas) / max(1, len(deltas))) ** 0.5, 8
        ),
        "max_vertex_displacement_metres": round(max(deltas, default=0.0), 8),
        "vertices_moved_over_0_1mm": sum(delta > 0.0001 for delta in deltas),
        "vertices_moved_over_1mm": sum(delta > 0.001 for delta in deltas),
        "vertices_moved_over_5mm": sum(delta > 0.005 for delta in deltas),
    })
    return result


def inspect(label, path):
    meshes = import_glb(path)
    skin = choose_skin(meshes)
    anatomy_objects = [
        {"object": obj.name, "anatomy_profile": obj.get("anatomy_profile")}
        for obj in meshes if obj.get("anatomy_profile")
    ]
    return {
        "path": str(path),
        "skin": mesh_summary(skin),
        "mesh_count": len(meshes),
        "all_meshes": [
            {"object": obj.name, "vertices": len(obj.data.vertices),
             "polygons": len(obj.data.polygons), "materials": material_names(obj)}
            for obj in meshes
        ],
        "anatomy_tagged_objects": anatomy_objects,
        "_skin_object": skin,
    }


def main():
    args = parse_args()
    paths = {
        "female_raw": args.female_raw,
        "male_raw": args.male_raw,
        "female_final": args.female_final,
        "male_final": args.male_final,
    }
    records = {}
    skin_objects = {}
    for label, path in paths.items():
        record = inspect(label, path)
        skin_objects[label] = record.pop("_skin_object")
        records[label] = record
    report = {
        "schema_version": 1,
        "purpose": "diagnose Ara gender morph output and anatomy integration",
        "models": records,
        "comparisons": {
            "raw_female_vs_raw_male": compare_meshes(
                skin_objects["female_raw"], skin_objects["male_raw"]),
            "female_raw_vs_female_final": compare_meshes(
                skin_objects["female_raw"], skin_objects["female_final"]),
            "male_raw_vs_male_final": compare_meshes(
                skin_objects["male_raw"], skin_objects["male_final"]),
        },
        "interpretation_notes": [
            "Raw female/male geometry is the decisive test of Ara gender morphing.",
            "A nonzero male anatomy mesh does not prove the underlying torso is male.",
            "Female anatomy is currently a skin-surface deformation, not a separate mesh.",
            "Vertex-index deltas are meaningful only when topology counts match.",
        ],
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
