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


def matching_material_polygons(obj, tokens):
    return [
        list(poly.vertices)
        for poly in obj.data.polygons
        if (material := material_for_polygon(obj, poly)) is not None
        and material.name in tokens
    ]


def matching_material_vertices(obj, tokens):
    selected = set()
    for polygon in obj.data.polygons:
        material = material_for_polygon(obj, polygon)
        if material and material.name in tokens:
            selected.update(polygon.vertices)
    return selected


def build_world_surface_tree(skin, skin_tokens):
    """Build the BVH from evaluated shape keys in the neutral, unposed body."""
    armature_modifiers = [
        modifier for modifier in skin.modifiers
        if modifier.type == "ARMATURE" and modifier.show_viewport
    ]
    try:
        for modifier in armature_modifiers:
            modifier.show_viewport = False
        bpy.context.view_layer.update()
        depsgraph = bpy.context.evaluated_depsgraph_get()
        evaluated = skin.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh(preserve_all_data_layers=True, depsgraph=depsgraph)
        try:
            world_vertices = [skin.matrix_world @ vertex.co for vertex in mesh.vertices]
            polygons = [
                list(poly.vertices) for poly in mesh.polygons
                if poly.material_index < len(skin.material_slots)
                and skin.material_slots[poly.material_index].material is not None
                and skin.material_slots[poly.material_index].material.name in skin_tokens
            ]
            if not world_vertices or not polygons:
                raise RuntimeError(
                    f"Evaluated skin mesh {skin.name} has no faces matching {sorted(skin_tokens)}"
                )
            tree = BVHTree.FromPolygons(world_vertices, polygons, all_triangles=False)
            if tree is None:
                raise RuntimeError("Could not build BVH from evaluated skin-only surface")
            shape_keys = skin.data.shape_keys.key_blocks if skin.data.shape_keys else []
            diagnostics = {
                "evaluated_vertex_count": len(mesh.vertices),
                "evaluated_polygon_count": len(mesh.polygons),
                "shape_keys": [{"name": key.name, "value": float(key.value)} for key in shape_keys],
                "armature_pose_excluded": bool(armature_modifiers),
            }
            return tree, diagnostics
        finally:
            evaluated.to_mesh_clear()
    finally:
        for modifier in armature_modifiers:
            modifier.show_viewport = True
        bpy.context.view_layer.update()


def apply_world_offsets(obj, indices, before, after):
    """Apply identical positional offsets to Basis and all garment shape keys."""
    inverse = obj.matrix_world.inverted()
    offsets = {
        index: inverse.to_3x3() @ (Vector(fitted) - Vector(source))
        for index, source, fitted in zip(indices, before, after)
    }
    if obj.data.shape_keys and obj.data.shape_keys.key_blocks:
        for key_block in obj.data.shape_keys.key_blocks:
            for index, offset in offsets.items():
                key_block.data[index].co += offset
    else:
        for index, offset in offsets.items():
            obj.data.vertices[index].co += offset
    obj.data.update()


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
    tree, surface_diagnostics = build_world_surface_tree(skin, skin_tokens)
    query = query_factory(tree)
    presets = {
        "existing": {"clearance_mm": 1.0, "max_displacement_mm": 10.0,
                     "max_step_mm": 1.0, "smoothing": 0.08, "iterations": 15},
        "new": {"clearance_mm": 4.0, "max_displacement_mm": 50.0,
                "max_step_mm": 3.0, "smoothing": 0.2, "iterations": 25},
    }
    preset = presets[args.fit_mode]
    config = FitConfig(
        target_clearance=(args.clearance_mm if args.clearance_mm is not None else preset["clearance_mm"]) / 1000.0,
        max_vertex_displacement=(args.max_displacement_mm if args.max_displacement_mm is not None else preset["max_displacement_mm"]) / 1000.0,
        max_step=(args.max_step_mm if args.max_step_mm is not None else preset["max_step_mm"]) / 1000.0,
        smoothing=args.smoothing if args.smoothing is not None else preset["smoothing"],
        max_iterations=args.iterations if args.iterations is not None else preset["iterations"],
        floating_tolerance=args.floating_tolerance_mm / 1000.0,
    )

    object_reports = []
    total_selected = 0
    total_moved = 0
    body_vertex_indices = matching_material_vertices(skin, skin_tokens)
    for obj in meshes:
        selected, found_materials = matching_material_faces(obj, garment_tokens)
        if not selected:
            continue
        if obj == skin:
            overlap = selected.intersection(body_vertex_indices)
            if overlap:
                raise RuntimeError(
                    "Garment and skin material faces share vertex indices; refusing "
                    f"to modify the body mesh ({len(overlap)} shared vertices)"
                )
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
        apply_world_offsets(obj, indices, source_world, fitted_world)

        moved = sum(
            1 for before, after in zip(source_world, fitted_world)
            if (Vector(after) - Vector(before)).length > 1e-7
        )
        vertex_diagnostics = []
        for local_index, (vertex_index, before, after) in enumerate(
            zip(indices, source_world, fitted_world)
        ):
            hit = query(after)
            if hit is None:
                nearest_point = None
                surface_normal = None
                signed_clearance = None
                nearest_distance = None
                issue = "surface_query_miss"
            else:
                nearest_point, surface_normal = hit
                delta = Vector(after) - Vector(nearest_point)
                signed_clearance = float(delta.dot(Vector(surface_normal)))
                nearest_distance = float(delta.length)
                displacement = float((Vector(after) - Vector(before)).length)
                if signed_clearance < 0.0:
                    issue = "penetrating"
                elif signed_clearance < config.target_clearance - 0.00025:
                    issue = "below_target_clearance"
                elif signed_clearance > config.floating_tolerance:
                    issue = "floating"
                elif displacement >= config.max_vertex_displacement - 1e-7:
                    issue = "at_displacement_limit"
                else:
                    issue = "ok"
            displacement = float((Vector(after) - Vector(before)).length)
            vertex_diagnostics.append({
                "vertex_index": int(vertex_index),
                "original_world_m": [float(value) for value in before],
                "fitted_world_m": [float(value) for value in after],
                "displacement_m": displacement,
                "nearest_surface_point_world_m": (
                    [float(value) for value in nearest_point]
                    if nearest_point is not None else None
                ),
                "surface_normal_world": (
                    [float(value) for value in surface_normal]
                    if surface_normal is not None else None
                ),
                "signed_clearance_m": signed_clearance,
                "nearest_distance_m": nearest_distance,
                "issue": issue,
            })
        total_selected += len(indices)
        total_moved += moved
        object_reports.append({
            "object": obj.name,
            "materials": found_materials,
            "selected_vertices": len(indices),
            "selected_edges": len(selected_edges),
            "moved_vertices": moved,
            "vertex_diagnostics": vertex_diagnostics,
            **report,
        })

    if not object_reports:
        diagnostics = []
        for obj in meshes:
            slots = [
                slot.material.name if slot.material else None
                for slot in obj.material_slots
            ]
            used_indices = sorted({poly.material_index for poly in obj.data.polygons})
            diagnostics.append({
                "object": obj.name,
                "is_skin_object": obj == skin,
                "data_materials": [
                    material.name if material else None
                    for material in obj.data.materials
                ],
                "slot_materials": slots,
                "used_polygon_material_indices": used_indices,
                "polygon_count": len(obj.data.polygons),
            })
        raise RuntimeError(
            f"No garment faces matched explicit materials {sorted(garment_tokens)}; "
            f"imported mesh material diagnostics={diagnostics}"
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
        "solver": "iterative_clearance_projection_v2",
        "fit_mode": args.fit_mode,
        "surface_evaluation": surface_diagnostics,
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
        "objects": object_reports,
    }, sort_keys=True))
    if not overall_pass:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
