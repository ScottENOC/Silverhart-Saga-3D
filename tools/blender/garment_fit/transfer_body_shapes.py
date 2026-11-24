#!/usr/bin/env python3
"""Transfer body shape-key deformation to fitted garments by surface correspondence.

This is the static MakeHuman-style shape adaptation stage: each garment vertex
is associated with a nearby triangle on the undeformed body, then every body
shape-key delta is barycentrically interpolated onto that garment vertex.
Garment Basis geometry, panels, thickness, UVs, weights and material construction
are retained. Only shape-key deltas are added; the body is never modified.

Run inside Blender:
  blender --background --python tools/blender/garment_fit/transfer_body_shapes.py -- \\
    --input fitted-character.glb --output shape-fitted-character.glb \\
    --body-material Skin_Anatomy --garment-material Briefs --garment-material Bra
"""
import argparse
import json
import os
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", default="")
    parser.add_argument("--body-material", action="append", required=True)
    parser.add_argument("--garment-material", action="append", required=True)
    parser.add_argument("--max-surface-distance-mm", type=float, default=35.0)
    parser.add_argument("--minimum-mapped-fraction", type=float, default=0.995)
    return parser.parse_args(raw)


def material_face_indices(obj, names):
    wanted = set(names)
    return [
        polygon.index for polygon in obj.data.polygons
        if polygon.material_index < len(obj.material_slots)
        and obj.material_slots[polygon.material_index].material is not None
        and obj.material_slots[polygon.material_index].material.name in wanted
    ]


def material_vertex_indices(obj, names):
    selected_faces = set(material_face_indices(obj, names))
    return sorted({
        vertex
        for polygon in obj.data.polygons
        if polygon.index in selected_faces
        for vertex in polygon.vertices
    })


def closest_triangle_weights(point, a, b, c):
    """Barycentric coordinates of the closest point on triangle ABC."""
    ab = b - a
    ac = c - a
    ap = point - a
    d1, d2 = ab.dot(ap), ac.dot(ap)
    if d1 <= 0.0 and d2 <= 0.0:
        return (1.0, 0.0, 0.0)

    bp = point - b
    d3, d4 = ab.dot(bp), ac.dot(bp)
    if d3 >= 0.0 and d4 <= d3:
        return (0.0, 1.0, 0.0)

    vc = d1 * d4 - d3 * d2
    if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
        v = d1 / (d1 - d3)
        return (1.0 - v, v, 0.0)

    cp = point - c
    d5, d6 = ab.dot(cp), ac.dot(cp)
    if d6 >= 0.0 and d5 <= d6:
        return (0.0, 0.0, 1.0)

    vb = d5 * d2 - d1 * d6
    if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
        w = d2 / (d2 - d6)
        return (1.0 - w, 0.0, w)

    va = d3 * d6 - d5 * d4
    if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
        w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return (0.0, 1.0 - w, w)

    denominator = 1.0 / max(va + vb + vc, 1e-20)
    v = vb * denominator
    w = vc * denominator
    return (1.0 - v - w, v, w)


def build_body_surface(body, body_materials):
    mesh = body.data
    mesh.calc_loop_triangles()
    body_faces = set(material_face_indices(body, body_materials))
    # A glTF import may combine body and garments into one Blender mesh. Never
    # include garment triangles in the query surface: otherwise each garment
    # vertex can map to itself and receive no useful body deformation.
    triangles = [
        tuple(triangle.vertices)
        for triangle in mesh.loop_triangles
        if triangle.polygon_index in body_faces
    ]
    vertices_world = [body.matrix_world @ vertex.co for vertex in mesh.vertices]
    if not triangles:
        raise RuntimeError("Body material selection produced no surface triangles")
    tree = BVHTree.FromPolygons(vertices_world, triangles, all_triangles=True)
    if tree is None:
        raise RuntimeError("Could not build body surface BVH")
    return vertices_world, triangles, tree


def find_body_and_garments(meshes, body_names, garment_names):
    body_hits = [obj for obj in meshes if material_face_indices(obj, body_names)]
    if len(body_hits) != 1:
        raise RuntimeError(
            f"Expected exactly one body mesh using {sorted(body_names)}; "
            f"found {[obj.name for obj in body_hits]}"
        )
    body = body_hits[0]
    garments = [
        obj for obj in meshes
        if obj != body and material_face_indices(obj, garment_names)
    ]
    if not garments:
        # Some glTF imports combine body and clothing primitives into one mesh.
        if material_face_indices(body, garment_names):
            garments = [body]
    if not garments:
        raise RuntimeError(
            f"No mesh contains garment materials {sorted(garment_names)}"
        )
    return body, garments


def transfer_shape_keys(body, garment, garment_indices, body_vertices,
                        body_triangles, tree, max_distance, minimum_mapped_fraction):
    body_keys = body.data.shape_keys
    if body_keys is None or len(body_keys.key_blocks) <= 1:
        raise RuntimeError(f"{body.name} has no body shape keys to transfer")
    basis = body_keys.key_blocks[0]
    source_keys = list(body_keys.key_blocks)[1:]

    if garment.data.shape_keys is None:
        garment.shape_key_add(name="Basis", from_mix=False)
    garment_keys = garment.data.shape_keys
    existing = {key.name: key for key in garment_keys.key_blocks}
    garment_basis = garment_keys.key_blocks[0]
    if len(garment_basis.data) != len(garment.data.vertices):
        raise RuntimeError(f"{garment.name} has an invalid garment Basis")

    # Build stable surface correspondences once, against the undeformed body.
    correspondences = []
    distances = []
    inverse_garment = garment.matrix_world.inverted()
    body_to_world = body.matrix_world.to_3x3()
    world_to_garment = inverse_garment.to_3x3()
    for vertex_index in garment_indices:
        garment_world = garment.matrix_world @ garment.data.vertices[vertex_index].co
        hit = tree.find_nearest(garment_world)
        if hit is None or hit[0] is None or hit[2] is None:
            raise RuntimeError(f"No body surface correspondence for {garment.name} vertex {vertex_index}")
        nearest, _normal, triangle_index, distance = hit
        if distance > max_distance:
            raise RuntimeError(
                f"{garment.name} vertex {vertex_index} is {distance * 1000:.1f} mm "
                f"from the body (limit {max_distance * 1000:.1f} mm); refusing "
                "to transfer a potentially unrelated surface deformation"
            )
        tri = body_triangles[triangle_index]
        weights = closest_triangle_weights(
            nearest, body_vertices[tri[0]], body_vertices[tri[1]], body_vertices[tri[2]]
        )
        correspondences.append((vertex_index, tri, weights))
        distances.append(float(distance))

    mapped_fraction = len(correspondences) / max(1, len(garment_indices))
    if mapped_fraction < minimum_mapped_fraction:
        raise RuntimeError(
            f"Only {mapped_fraction:.3%} garment vertices were mapped; "
            f"required {minimum_mapped_fraction:.3%}"
        )

    transferred = []
    for source_key in source_keys:
        if source_key.relative_key != basis:
            raise RuntimeError(
                f"Body key {source_key.name!r} is relative to "
                f"{source_key.relative_key.name!r}, not Basis; explicit conversion is required"
            )
        target_key = existing.get(source_key.name)
        if target_key is None:
            target_key = garment.shape_key_add(name=source_key.name, from_mix=False)
            existing[source_key.name] = target_key
        # Calculate all offsets before writing. This also supports a combined
        # body+garment mesh where source_key and target_key are the same block.
        updates = []
        for vertex_index, triangle, weights in correspondences:
            delta_world = Vector((0.0, 0.0, 0.0))
            for body_index, weight in zip(triangle, weights):
                delta_local = source_key.data[body_index].co - basis.data[body_index].co
                delta_world += (body_to_world @ delta_local) * weight
            updates.append((vertex_index, world_to_garment @ delta_world))
        for vertex_index, delta_local in updates:
            target_key.data[vertex_index].co += delta_local
        transferred.append(source_key.name)

    return {
        "garment": garment.name,
        "garment_vertices": len(garment_indices),
        "body_shape_keys_transferred": transferred,
        "mapped_fraction": mapped_fraction,
        "surface_distance_mm": {
            "max": max(distances) * 1000.0 if distances else None,
            "median": sorted(distances)[len(distances) // 2] * 1000.0 if distances else None,
        },
    }


def main():
    args = parse_args()
    if args.max_surface_distance_mm <= 0:
        raise SystemExit("--max-surface-distance-mm must be positive")
    if not 0.0 < args.minimum_mapped_fraction <= 1.0:
        raise SystemExit("--minimum-mapped-fraction must be in (0, 1]")

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    body, garments = find_body_and_garments(
        meshes, set(args.body_material), set(args.garment_material)
    )
    body_vertices, body_triangles, tree = build_body_surface(body, set(args.body_material))
    max_distance = args.max_surface_distance_mm / 1000.0

    results = []
    for garment in garments:
        indices = material_vertex_indices(garment, set(args.garment_material))
        if not indices:
            continue
        result = transfer_shape_keys(
            body, garment, indices, body_vertices, body_triangles, tree,
            max_distance, args.minimum_mapped_fraction
        )
        if result["mapped_fraction"] < args.minimum_mapped_fraction:
            raise RuntimeError(
                f"{garment.name} mapped {result['mapped_fraction']:.3%}; "
                f"required {args.minimum_mapped_fraction:.3%}"
            )
        results.append(result)

    if not results:
        raise RuntimeError("No garment vertices were processed")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    active_armature = next(
        (obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None
    )
    bpy.context.view_layer.objects.active = active_armature or body
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(args.output),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
    )

    report = {
        "status": "PASS",
        "method": "barycentric_body_surface_shape_delta_transfer_v1",
        "input": os.path.basename(args.input),
        "output": os.path.basename(args.output),
        "body_mesh": body.name,
        "body_materials": args.body_material,
        "garment_materials": args.garment_material,
        "body_shape_key_count": len(body.data.shape_keys.key_blocks) - 1,
        "garments": results,
        "body_geometry_modified": False,
        "garment_basis_modified": False,
    }
    report_path = args.report or (args.output + ".shape-transfer.json")
    os.makedirs(os.path.dirname(os.path.abspath(report_path)), exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    print("GARMENT_SHAPE_TRANSFER_REPORT " + json.dumps(report, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
