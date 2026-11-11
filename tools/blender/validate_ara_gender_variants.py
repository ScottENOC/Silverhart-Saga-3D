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


def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--female-raw", required=True)
    parser.add_argument("--male-raw", required=True)
    parser.add_argument("--female-final", required=True)
    parser.add_argument("--male-final", required=True)
    parser.add_argument("--female-test-raw")
    parser.add_argument("--male-test-raw")
    parser.add_argument("--female-test-final")
    parser.add_argument("--male-test-final")
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


def compare_vertices(pa, pb, polygon_count_a, polygon_count_b):
    result = {
        "same_vertex_count": len(pa) == len(pb),
        "same_polygon_count": polygon_count_a == polygon_count_b,
    }
    if not result["same_vertex_count"]:
        result["comparable_by_vertex_index"] = False
        return result
    deltas = [
        sum((pa[i][axis] - pb[i][axis]) ** 2 for axis in range(3)) ** 0.5
        for i in range(len(pa))
    ]
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


def cross_section_profile(points):
    if not points:
        return {}
    minimum = [min(point[i] for point in points) for i in range(3)]
    maximum = [max(point[i] for point in points) for i in range(3)]
    height = maximum[2] - minimum[2]
    width = maximum[0] - minimum[0]
    bands = {
        "shoulders": 0.795,
        "chest": 0.685,
        "waist": 0.595,
        "pelvis": 0.485,
    }
    result = {}
    for label, ratio in bands.items():
        z = minimum[2] + height * ratio
        band = [point for point in points if abs(point[2] - z) <= height * 0.012]
        if len(band) < 8:
            band = sorted(points, key=lambda point: abs(point[2] - z))[:max(8, len(points) // 100)]
        result[label] = {
            "z_ratio": ratio,
            "sample_vertices": len(band),
            "width_metres": round(max(point[0] for point in band) - min(point[0] for point in band), 6),
        }
    chest_z = minimum[2] + height * bands["chest"]
    chest = [point for point in points
             if abs(point[2] - chest_z) <= height * 0.055
             and abs(point[0]) <= width * 0.22]
    result["chest_depth"] = {
        "sample_vertices": len(chest),
        "front_to_back_metres": round(max(point[1] for point in chest) - min(point[1] for point in chest), 6) if chest else None,
        "frontmost_y": round(min(point[1] for point in chest), 6) if chest else None,
    }
    return result


def inspect(label, path):
    meshes = import_glb(path)
    skin = choose_skin(meshes)
    anatomy_objects = [
        {"object": obj.name, "anatomy_profile": obj.get("anatomy_profile")}
        for obj in meshes if obj.get("anatomy_profile")
    ]
    world_vertices = [
        tuple((skin.matrix_world @ vertex.co))
        for vertex in skin.data.vertices
    ]
    return {
        "path": str(path),
        "skin": mesh_summary(skin),
        "_world_vertices": world_vertices,
        "cross_section_profile": cross_section_profile(world_vertices),
        "mesh_count": len(meshes),
        "all_meshes": [
            {"object": obj.name, "vertices": len(obj.data.vertices),
             "polygons": len(obj.data.polygons), "materials": material_names(obj)}
            for obj in meshes
        ],
        "anatomy_tagged_objects": anatomy_objects,
    }


def main():
    args = parse_args()
    paths = {
        "female_raw": args.female_raw,
        "male_raw": args.male_raw,
        "female_final": args.female_final,
        "male_final": args.male_final,
    }
    optional_paths = {
        "female_test_raw": args.female_test_raw,
        "male_test_raw": args.male_test_raw,
        "female_test_final": args.female_test_final,
        "male_test_final": args.male_test_final,
    }
    paths.update({key: value for key, value in optional_paths.items() if value})
    records = {}
    vertex_sets = {}
    for label, path in paths.items():
        record = inspect(label, path)
        vertex_sets[label] = record.pop("_world_vertices")
        records[label] = record
    report = {
        "schema_version": 1,
        "purpose": "diagnose Ara gender morph output and anatomy integration",
        "models": records,
        "comparisons": {
            "raw_female_vs_raw_male": compare_vertices(
                vertex_sets["female_raw"], vertex_sets["male_raw"],
                records["female_raw"]["skin"]["polygons"], records["male_raw"]["skin"]["polygons"]),
            "female_raw_vs_female_final": compare_vertices(
                vertex_sets["female_raw"], vertex_sets["female_final"],
                records["female_raw"]["skin"]["polygons"], records["female_final"]["skin"]["polygons"]),
            "male_raw_vs_male_final": compare_vertices(
                vertex_sets["male_raw"], vertex_sets["male_final"],
                records["male_raw"]["skin"]["polygons"], records["male_final"]["skin"]["polygons"]),
            "female_final_vs_male_final_cross_sections": {
                "female": records["female_final"]["cross_section_profile"],
                "male": records["male_final"]["cross_section_profile"],
            },
            "diagnostic_pair_cross_sections": {
                "female_max_breast": records.get("female_test_final", {}).get("cross_section_profile"),
                "male_min_breast_broad_upper_body": records.get("male_test_final", {}).get("cross_section_profile"),
            },
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
