#!/usr/bin/env python3
"""Apply the iterative clearance solver to explicitly named garment materials.

Example:
  blender --background --python tools/blender/garment_fit/fit_glb.py -- \
    --input character.glb --output fitted.glb --report fit-report.json \
    --skin-material Skin --garment-material "Tank Top"

The script refuses ambiguous skin selection and never modifies the body mesh.
It is a one-way clearance fitter; it does not generate missing garment panels,
simulate fabric, or deform soft tissue.
"""
import argparse
import json
import os
import sys

# Blender does not consistently add the --python script directory to sys.path.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from solver_core import FitConfig, fit_clearance


def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--skin-material", action="append", required=True)
    parser.add_argument("--garment-material", action="append", required=True)
    parser.add_argument("--clearance-mm", type=float, default=4.0)
    parser.add_argument("--max-displacement-mm", type=float, default=25.0)
    parser.add_argument("--max-step-mm", type=float, default=3.0)
    parser.add_argument("--smoothing", type=float, default=0.2)
    parser.add_argument("--iterations", type=int, default=20)
    parser.add_argument("--floating-tolerance-mm", type=float, default=15.0)
    return parser.parse_args(raw)


def material_for_polygon(obj, polygon):
    if polygon.material_index >= len(obj.material_slots):
        return None
    return obj.material_slots[polygon.material_index].material


def matching_material_faces(obj, tokens):
    selected = set()
    names = set()
    for polygon in obj.data.polygons:
        material = material_for_polygon(obj, polygon)
        if material and material.name in tokens:
            selected.update(polygon.vertices)
            names.add(material.name)
    return selected, sorted(names)


def build_world_surface_tree(skin):
    world_vertices = [skin.matrix_world @ vertex.co for vertex in skin.data.vertices]
    polygons = [list(poly.vertices) for poly in skin.data.polygons]
    if not world_vertices or not polygons:
        raise RuntimeError("Skin mesh has no usable vertices or faces")
    tree = BVHTree.FromPolygons(world_vertices, polygons, all_triangles=False)
    if tree is None:
        raise RuntimeError("Could not build BVH from skin-only surface")
    return tree


def query_factory(tree):
    def query(point):
        hit = tree.find_nearest(Vector(point))
        if hit is None or hit[0] is None or hit[1] is None:
            return None
        location, normal, _face_index, _distance = hit
        return (tuple(location), tuple(normal.normalized()))
    return query


def main():
    args = parse_args()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    skin_tokens = set(args.skin_material)
    garment_tokens = set(args.garment_material)
    skin_matches = []
    for obj in meshes:
        names = {
            material.name
            for material in obj.data.materials
            if material is not None and material.name in skin_tokens
        }
        if names:
            skin_matches.append((obj, names))
    if len(skin_matches) != 1:
        detail = [f"{obj.name}:{sorted(names)}" for obj, names in skin_matches]
        raise RuntimeError(
            f"Expected exactly one skin mesh matching {sorted(skin_tokens)}; "
            f"found {len(skin_matches)}: {detail}"
        )

    skin, found_skin_materials = skin_matches[0]
    tree = build_world_surface_tree(skin)
    query = query_factory(tree)
    config = FitConfig(
        target_clearance=args.clearance_mm / 1000.0,
        max_vertex_displacement=args.max_displacement_mm / 1000.0,
        max_step=args.max_step_mm / 1000.0,
        smoothing=args.smoothing,
        max_iterations=args.iterations,
        floating_tolerance=args.floating_tolerance_mm / 1000.0,
    )

    object_reports = []
    total_selected = 0
    total_moved = 0
    for obj in meshes:
        if obj == skin:
            continue
        selected, found_materials = matching_material_faces(obj, garment_tokens)
        if not selected:
            continue
        indices = sorted(selected)
        remap = {old: new for new, old in enumerate(indices)}
        source_world = [tuple(obj.matrix_world @ obj.data.vertices[i].co) for i in indices]
        selected_edges = []
        for edge in obj.data.edges:
            left, right = edge.vertices
            if left in remap and right in remap:
                selected_edges.append((remap[left], remap[right]))

        fitted_world, report = fit_clearance(
            source_world, selected_edges, query, config
        )
        inverse = obj.matrix_world.inverted()
        for old_index, world_position in zip(indices, fitted_world):
            obj.data.vertices[old_index].co = inverse @ Vector(world_position)
        obj.data.update()

        moved = sum(
            1 for before, after in zip(source_world, fitted_world)
            if (Vector(after) - Vector(before)).length > 1e-7
        )
        total_selected += len(indices)
        total_moved += moved
        object_reports.append({
            "object": obj.name,
            "materials": found_materials,
            "selected_vertices": len(indices),
            "selected_edges": len(selected_edges),
            "moved_vertices": moved,
            **report,
        })

    if not object_reports:
        raise RuntimeError(
            f"No garment faces matched explicit materials {sorted(garment_tokens)}"
        )

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    active_armature = next(
        (obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None
    )
    bpy.context.view_layer.objects.active = active_armature or skin
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(args.output),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
    )

    overall_pass = all(item["status"] == "PASS" for item in object_reports)
    report = {
        "status": "PASS" if overall_pass else "FAIL",
        "solver": "iterative_clearance_projection_v1",
        "input": os.path.basename(args.input),
        "output": os.path.basename(args.output),
        "blender_version": bpy.app.version_string,
        "body_mesh": skin.name,
        "body_materials": sorted(found_skin_materials),
        "body_modified": False,
        "configuration": {
            "target_clearance_m": config.target_clearance,
            "max_vertex_displacement_m": config.max_vertex_displacement,
            "max_step_m": config.max_step,
            "smoothing": config.smoothing,
            "max_iterations": config.max_iterations,
            "floating_tolerance_m": config.floating_tolerance,
        },
        "garment_vertices_selected": total_selected,
        "garment_vertices_moved": total_moved,
        "objects": object_reports,
    }
    report_path = os.path.abspath(args.report)
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    print("GARMENT_FIT_REPORT " + json.dumps({
        "status": report["status"],
        "selected_vertices": total_selected,
        "moved_vertices": total_moved,
        "objects": len(object_reports),
    }, sort_keys=True))
    if not overall_pass:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
