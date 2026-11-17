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


def topology_signature(mesh):
    return (
        len(mesh.vertices),
        tuple(tuple(poly.vertices) for poly in mesh.polygons),
    )


def add_relative_key(base_obj, variant_obj, name, epsilon=1e-8):
    if topology_signature(base_obj.data) != topology_signature(variant_obj.data):
        raise RuntimeError(
            f"Topology mismatch for {base_obj.name} / {variant_obj.name}: "
            f"base vertices={len(base_obj.data.vertices)}, "
            f"variant vertices={len(variant_obj.data.vertices)}, "
            f"base faces={len(base_obj.data.polygons)}, "
            f"variant faces={len(variant_obj.data.polygons)}"
        )
    if base_obj.data.shape_keys is None:
        base_obj.shape_key_add(name="Basis", from_mix=False)
    key = base_obj.shape_key_add(name=name, from_mix=False)
    base_inverse = base_obj.matrix_world.inverted()
    moved = 0
    maximum = 0.0
    for index, base_vertex in enumerate(base_obj.data.vertices):
        base_world = base_obj.matrix_world @ base_vertex.co
        variant_world = variant_obj.matrix_world @ variant_obj.data.vertices[index].co
        delta = variant_world - base_world
        distance = delta.length
        if distance > epsilon:
            moved += 1
        maximum = max(maximum, distance)
        key.data[index].co = base_inverse @ variant_world
    return {"name": name, "vertices": len(base_obj.data.vertices),
            "moved_vertices": moved, "max_delta_metres": maximum}


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
