#!/usr/bin/env python3
"""Read-only inventory of a GLB before garment fitting.

Run with:
  blender --background --python tools/blender/garment_fit/inspect_fit_inputs.py -- \
    --input character.glb --output fit-input-inventory.json

This intentionally does not deform or export the model. It establishes whether
body/garment materials, mesh objects, transforms and rig data are identifiable
before a fitting solver is allowed to touch the asset.
"""
import argparse
import json
import os
import sys

import bpy
from mathutils import Vector


def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--skin-token", action="append", default=["skin"])
    parser.add_argument(
        "--garment-token",
        action="append",
        default=["bra", "halter", "lace", "bikini", "brief", "underwear", "shirt", "dress", "pants"],
    )
    return parser.parse_args(raw)


def material_label(material):
    return material.name if material else ""


def world_bounds(obj):
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    if not points:
        return None
    return {
        "min": [round(float(min(p[i] for p in points)), 6) for i in range(3)],
        "max": [round(float(max(p[i] for p in points)), 6) for i in range(3)],
    }


def mesh_inventory(obj, skin_tokens, garment_tokens):
    face_counts = {}
    for polygon in obj.data.polygons:
        material = None
        if polygon.material_index < len(obj.material_slots):
            material = obj.material_slots[polygon.material_index].material
        name = material_label(material)
        face_counts[name] = face_counts.get(name, 0) + 1

    materials = [name for name in face_counts if name]
    skin_faces = 0
    garment_faces = 0
    garment_groups = {}
    for name, count in face_counts.items():
        lower = name.lower()
        if any(token in lower for token in skin_tokens):
            skin_faces += count
        if any(token in lower for token in garment_tokens) and not any(
            token in lower for token in skin_tokens
        ):
            garment_faces += count
            garment_groups[name] = count

    matrix = obj.matrix_world
    return {
        "name": obj.name,
        "vertices": len(obj.data.vertices),
        "edges": len(obj.data.edges),
        "faces": len(obj.data.polygons),
        "world_bounds_m": world_bounds(obj),
        "world_matrix": [[round(float(matrix[r][c]), 8) for c in range(4)] for r in range(4)],
        "materials": materials,
        "faces_by_material": face_counts,
        "skin_material_face_count": skin_faces,
        "garment_material_face_count": garment_faces,
        "garment_material_groups": garment_groups,
    }


def main():
    args = parse_args()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    mesh_data = [
        mesh_inventory(obj, tuple(t.lower() for t in args.skin_token),
                       tuple(t.lower() for t in args.garment_token))
        for obj in meshes
    ]
    skin_candidates = [
        item for item in mesh_data if item["skin_material_face_count"] > 0
    ]
    garment_candidates = [
        item for item in mesh_data if item["garment_material_face_count"] > 0
    ]

    rig_data = []
    for armature in armatures:
        rig_data.append({
            "name": armature.name,
            "bone_count": len(armature.data.bones),
            "bone_names": [bone.name for bone in armature.data.bones],
            "world_matrix": [
                [round(float(armature.matrix_world[r][c]), 8) for c in range(4)]
                for r in range(4)
            ],
        })

    result = {
        "input": os.path.basename(args.input),
        "blender_version": bpy.app.version_string,
        "coordinate_note": "World-space values are Blender GLB import coordinates; expected Ara convention is Z-up, character facing -Y.",
        "mesh_count": len(meshes),
        "armature_count": len(armatures),
        "meshes": mesh_data,
        "skin_candidates": [item["name"] for item in skin_candidates],
        "garment_candidates": [item["name"] for item in garment_candidates],
        "rigs": rig_data,
        "validation": {
            "has_mesh": bool(meshes),
            "has_skin_material_faces": bool(skin_candidates),
            "has_garment_material_faces": bool(garment_candidates),
            "has_armature": bool(armatures),
            "ambiguous_skin_mesh_candidates": len(skin_candidates) > 1,
        },
    }

    output = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(output), exist_ok=True)
    with open(output, "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)

    print("GARMENT_FIT_INPUT_INVENTORY " + json.dumps(result["validation"], sort_keys=True))
    if not result["validation"]["has_mesh"]:
        raise RuntimeError("Input GLB contains no mesh objects")
    if not result["validation"]["has_skin_material_faces"]:
        raise RuntimeError("No faces assigned to a material matching --skin-token")
    if not result["validation"]["has_armature"]:
        raise RuntimeError("No armature found; cannot validate skinned garment compatibility")


if __name__ == "__main__":
    main()
