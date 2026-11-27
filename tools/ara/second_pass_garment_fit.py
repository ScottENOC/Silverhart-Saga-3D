#!/usr/bin/env python3
"""Second-pass static garment correction for Ara's fitted bikini.

This pass edits only the Bikini bottom material's front-facing vertices. It
uses the body surface as a collision reference and a small lateral envelope
to keep the fabric from tracing narrow concavities. The skin mesh and its
material are never deleted, hidden, or modified.
"""
import argparse
import json
import os
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--clearance", type=float, default=0.012)
    parser.add_argument("--bridge-radius", type=float, default=0.035)
    parser.add_argument("--vertical-sample", type=float, default=0.010)
    return parser.parse_args()


def main():
    args = arguments()
    if args.clearance < 0.004 or args.clearance > 0.030:
        raise ValueError("--clearance must be between 4 and 30 mm")
    if args.bridge_radius < 0.010 or args.bridge_radius > 0.080:
        raise ValueError("--bridge-radius must be between 10 and 80 mm")

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    candidates = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        names = [m.name.lower() if m else "" for m in obj.data.materials]
        if any(name.startswith("skin") for name in names) and any("bikini bottom" in name for name in names):
            candidates.append(obj)
    if len(candidates) != 1:
        raise RuntimeError(f"Expected one skinned Ara mesh with skin and bikini-bottom materials; found {len(candidates)}")
    obj = candidates[0]
    mesh = obj.data
    materials = [m.name if m else "" for m in mesh.materials]
    skin_indices = {i for i, name in enumerate(materials) if name.lower().startswith("skin")}
    bottom_indices = {i for i, name in enumerate(materials) if "bikini bottom" in name.lower()}
    if not skin_indices or not bottom_indices:
        raise RuntimeError(f"Missing skin or bikini-bottom materials: {materials}")

    world_vertices = [obj.matrix_world @ vertex.co for vertex in mesh.vertices]
    skin_faces = [tuple(poly.vertices) for poly in mesh.polygons if poly.material_index in skin_indices and len(poly.vertices) >= 3]
    if not skin_faces:
        raise RuntimeError("No skin polygons available for garment collision")
    tree = BVHTree.FromPolygons(world_vertices, skin_faces)

    bottom_polygons = [poly for poly in mesh.polygons if poly.material_index in bottom_indices]
    bottom_vertices = sorted({index for poly in bottom_polygons for index in poly.vertices})
    if not bottom_vertices:
        raise RuntimeError("Ara's bikini bottom has no vertices")

    min_y = min(v.y for v in world_vertices)
    max_y = max(v.y for v in world_vertices)
    center_y = (min_y + max_y) * 0.5
    changed = 0
    skipped = 0
    max_push = 0.0
    radius = args.bridge_radius
    x_offsets = (-radius, -radius * 0.5, 0.0, radius * 0.5, radius)
    z_offsets = (-args.vertical_sample, 0.0, args.vertical_sample)

    for index in bottom_vertices:
        point = world_vertices[index]
        # Ara's character faces -Y. Leave the rear and lateral fabric alone.
        if point.y >= center_y:
            skipped += 1
            continue

        front_hits = []
        for dx in x_offsets:
            for dz in z_offsets:
                origin = Vector((point.x + dx, min_y - 0.25, point.z + dz))
                hit, normal, face_index, distance = tree.ray_cast(
                    origin, Vector((0.0, 1.0, 0.0)), max_y - min_y + 0.5
                )
                if hit is not None:
                    front_hits.append(hit.y)
        if not front_hits:
            skipped += 1
            continue

        # Taking the most anterior nearby body sample bridges small inward
        # contours instead of letting the briefs reproduce every concavity.
        envelope_y = min(front_hits)
        target_y = envelope_y - args.clearance
        if point.y > target_y:
            push = point.y - target_y
            world_target = Vector((point.x, target_y, point.z))
            mesh.vertices[index].co = obj.matrix_world.inverted() @ world_target
            changed += 1
            max_push = max(max_push, push)

    mesh.update()
    if changed == 0:
        raise RuntimeError("Second pass made no corrections; refusing to report a successful fit")

    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = obj
    output_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_morph=True,
        export_animations=True,
        export_apply=False,
    )

    report = {
        "input": os.path.abspath(args.input),
        "output": output_path,
        "method": "body-surface collision clearance with lateral front-envelope bridging",
        "garment_materials": [materials[i] for i in sorted(bottom_indices)],
        "skin_materials_retained": [materials[i] for i in sorted(skin_indices)],
        "skin_polygons_used_as_collision_surface": len(skin_faces),
        "bikini_bottom_polygons": len(bottom_polygons),
        "bikini_bottom_vertices": len(bottom_vertices),
        "vertices_corrected": changed,
        "vertices_skipped": skipped,
        "clearance_metres": args.clearance,
        "bridge_radius_metres": args.bridge_radius,
        "max_outward_correction_metres": max_push,
        "body_or_skin_hidden": False,
        "body_or_skin_deleted": False,
        "physics_simulation": "not run; this is a deterministic static second pass",
    }
    report_path = os.path.abspath(args.report)
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    Path(report_path).write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
