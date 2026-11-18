#!/usr/bin/env python3
"""Create real Ara-derived relative shape keys from topology-matched GLB exports.

The base, low and high inputs must be generated from the same Ara dataset,
detail level and anatomy pipeline. This script refuses to guess vertex
correspondence: it verifies each skin mesh's vertex and polygon layout.
"""
import argparse
import json
import os
import sys
from pathlib import Path

import bpy


def args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--low", required=True)
    parser.add_argument("--high", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    return [obj for obj in bpy.data.objects if obj not in before]


def is_skin_mesh(obj):
    if obj.type != "MESH" or len(obj.data.vertices) < 100:
        return False
    return any(slot.material and "skin" in slot.material.name.lower()
               for slot in obj.material_slots)


def skin_meshes(objects):
    return sorted((obj for obj in objects if is_skin_mesh(obj)), key=lambda o: o.name)


def vertex_uv_signatures(mesh):
    """Stable per-vertex UV identity, including seam duplicates."""
    if not mesh.uv_layers:
        raise RuntimeError(f"Mesh {mesh.name} has no UV layer for correspondence")
    uv_layer = mesh.uv_layers.active
    per_vertex = [[] for _ in mesh.vertices]
    for loop in mesh.loops:
        uv = uv_layer.data[loop.index].uv
        per_vertex[loop.vertex_index].append((round(float(uv.x), 7), round(float(uv.y), 7)))
    return [tuple(sorted(values)) for values in per_vertex]


def map_variant_vertices(base_obj, variant_obj, max_distance=0.15):
    """Map GLB-reimported vertices by UV identity, then prove face connectivity.

    The exporter can reorder vertices, and UV seams can contain coincident
    positions. A per-vertex UV signature distinguishes those seam copies;
    spatial distance selects among any remaining duplicate signatures.
    """
    base_vertices = base_obj.data.vertices
    variant_vertices = variant_obj.data.vertices
    if len(base_vertices) != len(variant_vertices):
        raise RuntimeError(
            f"Vertex count mismatch for {base_obj.name} / {variant_obj.name}: "
            f"base={len(base_vertices)}, variant={len(variant_vertices)}"
        )

    base_uv = vertex_uv_signatures(base_obj.data)
    variant_uv = vertex_uv_signatures(variant_obj.data)
    variant_by_uv = {}
    for index, signature in enumerate(variant_uv):
        variant_by_uv.setdefault(signature, []).append(index)

    variant_world = [
        variant_obj.matrix_world @ vertex.co for vertex in variant_vertices
    ]
    mapping = []
    used = set()
    distances = []
    spatial_fallbacks = []
    for base_index, base_vertex in enumerate(base_vertices):
        signature = base_uv[base_index]
        candidates = [
            index for index in variant_by_uv.get(signature, [])
            if index not in used
        ]
        point = base_obj.matrix_world @ base_vertex.co

        # Ara's GLB exporter can alter UV-loop grouping for a small number of
        # vertices between otherwise topology-equivalent body profiles. Keep
        # UV identity as the primary key, but for a missing signature use a
        # one-to-one spatial match. The full face-connectivity proof below is
        # still mandatory, so this cannot silently accept a bad correspondence.
        if not candidates:
            candidates = [
                index for index in range(len(variant_vertices))
                if index not in used
            ]
            spatial_fallbacks.append(base_index)

        variant_index = min(
            candidates,
            key=lambda index: (variant_world[index] - point).length_squared,
        )
        distance = (variant_world[variant_index] - point).length
        if distance > max_distance:
            raise RuntimeError(
                f"Matched vertex too far apart for base vertex {base_index}: "
                f"{distance:.4f}m (limit {max_distance:.4f}m)"
            )
        mapping.append(variant_index)
        used.add(variant_index)
        distances.append(distance)

    if spatial_fallbacks:
        print(
            f"Spatial fallback used for {len(spatial_fallbacks)} vertices: "
            f"{spatial_fallbacks[:20]}"
        )

    inverse = [-1] * len(mapping)
    for base_index, variant_index in enumerate(mapping):
        inverse[variant_index] = base_index

    base_faces = {
        tuple(sorted(int(index) for index in polygon.vertices))
        for polygon in base_obj.data.polygons
    }
    mapped_variant_faces = {
        tuple(sorted(inverse[int(index)] for index in polygon.vertices))
        for polygon in variant_obj.data.polygons
    }
    if base_faces != mapped_variant_faces:
        missing = len(base_faces - mapped_variant_faces)
        extra = len(mapped_variant_faces - base_faces)
        raise RuntimeError(
            "UV vertex map failed face-connectivity validation: "
            f"{missing} base faces unmatched, {extra} variant faces unmatched"
        )
    return mapping, max(distances, default=0.0), sum(distances) / max(len(distances), 1)


def add_relative_key(base_obj, variant_obj, name):
    mapping, max_distance, mean_distance = map_variant_vertices(base_obj, variant_obj)
    if base_obj.data.shape_keys is None:
        base_obj.shape_key_add(name="Basis", from_mix=False)
    key = base_obj.shape_key_add(name=name, from_mix=False)
    base_inverse = base_obj.matrix_world.inverted()
    variant_world = [
        variant_obj.matrix_world @ vertex.co for vertex in variant_obj.data.vertices
    ]
    moved = 0
    maximum = 0.0
    for index, base_vertex in enumerate(base_obj.data.vertices):
        base_world = base_obj.matrix_world @ base_vertex.co
        target_world = variant_world[mapping[index]]
        delta = target_world - base_world
        distance = delta.length
        if distance > 1e-8:
            moved += 1
        maximum = max(maximum, distance)
        key.data[index].co = base_inverse @ target_world
    return {
        "name": name,
        "vertices": len(base_obj.data.vertices),
        "moved_vertices": moved,
        "max_delta_metres": maximum,
        "mapping_max_distance_metres": max_distance,
        "mapping_mean_distance_metres": mean_distance,
    }


def main():
    options = args()
    clear_scene()
    base_objects = import_glb(options.base)
    base_skin = skin_meshes(base_objects)
    if not base_skin:
        raise RuntimeError("Base GLB contains no identifiable Ara skin mesh")

    report = {"base": options.base, "morphs": [], "skin_meshes": []}
    for label, path, morph_name in (
        ("low", options.low, "body_muscle_low"),
        ("high", options.high, "body_muscle_high"),
    ):
        variant_objects = import_glb(path)
        variant_skin = skin_meshes(variant_objects)
        if len(variant_skin) != len(base_skin):
            raise RuntimeError(
                f"{label} export has {len(variant_skin)} skin meshes; "
                f"base has {len(base_skin)}"
            )
        for mesh_index, (base_obj, variant_obj) in enumerate(zip(base_skin, variant_skin)):
            result = add_relative_key(base_obj, variant_obj, morph_name)
            result.update({"variant": label, "mesh_index": mesh_index,
                           "base_mesh": base_obj.name, "variant_mesh": variant_obj.name})
            report["morphs"].append(result)
        for obj in variant_objects:
            bpy.data.objects.remove(obj, do_unlink=True)

    for obj in base_skin:
        report["skin_meshes"].append({
            "name": obj.name,
            "vertices": len(obj.data.vertices),
            "shape_keys": list(obj.data.shape_keys.key_blocks.keys())
                if obj.data.shape_keys else [],
        })

    output = Path(options.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if armature:
        bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_skins=True,
        export_morph=True,
        export_animations=False,
        export_apply=False,
        use_selection=True,
    )
    report["output"] = str(output)
    report["output_bytes"] = output.stat().st_size
    report_path = Path(options.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"Wrote Ara body morph GLB: {output} ({output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
