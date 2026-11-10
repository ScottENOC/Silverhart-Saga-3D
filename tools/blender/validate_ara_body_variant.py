#!/usr/bin/env python3
"""Validate that a bare Ara body and its same-profile dressed export share one rig.

Ara places bones from the generated body's joints. Different body profiles can
therefore have different rest transforms without anyone editing the rig. The
important garment contract is that the bare body and its matching dressed
export were generated from the same parameters, rig and rest pose.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, required=True, help="Bare Ara body GLB")
    parser.add_argument("--candidate", type=Path, required=True, help="Same-profile dressed Ara GLB")
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(raw)


def import_asset(path: Path):
    if not path.is_file():
        raise FileNotFoundError(path)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = list(set(bpy.data.objects) - before)
    armatures = [obj for obj in imported if obj.type == "ARMATURE"]
    meshes = [obj for obj in imported if obj.type == "MESH"]
    if len(armatures) != 1:
        raise RuntimeError(f"{path.name}: expected exactly one armature, found {len(armatures)}")
    if not meshes:
        raise RuntimeError(f"{path.name}: no mesh objects imported")
    return imported, armatures[0], meshes


def shape_names(meshes):
    names = []
    for obj in meshes:
        keys = obj.data.shape_keys
        if keys:
            names.extend(key.name for key in list(keys.key_blocks)[1:])
    return sorted(set(names))


def material_names(meshes):
    return sorted({
        slot.material.name
        for obj in meshes
        for slot in obj.material_slots
        if slot.material is not None
    })


def main():
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    _ref_objects, ref_armature, ref_meshes = import_asset(args.reference)
    _candidate_objects, candidate_armature, candidate_meshes = import_asset(args.candidate)

    ref_bones = list(ref_armature.data.bones)
    candidate_bones = list(candidate_armature.data.bones)
    ref_names = [bone.name for bone in ref_bones]
    candidate_names = [bone.name for bone in candidate_bones]
    if ref_names != candidate_names:
        missing = sorted(set(ref_names) - set(candidate_names))
        extra = sorted(set(candidate_names) - set(ref_names))
        raise RuntimeError(
            "Same-profile Ara exports have different bone names/order: "
            f"missing={missing[:12]}, extra={extra[:12]}, "
            f"reference_count={len(ref_names)}, candidate_count={len(candidate_names)}"
        )

    differences = []
    max_delta = 0.0
    for ref_bone, candidate_bone in zip(ref_bones, candidate_bones):
        delta = max(
            abs(ref_bone.matrix_local[row][column] - candidate_bone.matrix_local[row][column])
            for row in range(4) for column in range(4)
        )
        max_delta = max(max_delta, delta)
        if delta > 1e-5:
            differences.append({"bone": ref_bone.name, "max_matrix_element_delta": delta})
    if differences:
        differences.sort(key=lambda item: item["max_matrix_element_delta"], reverse=True)
        raise RuntimeError(
            "Bare and dressed Wren exports do not share the same rest transforms: "
            + json.dumps(differences[:12])
        )

    ref_shapes = shape_names(ref_meshes)
    candidate_shapes = shape_names(candidate_meshes)
    if len(ref_shapes) < 20 or len(candidate_shapes) < 20:
        raise RuntimeError(
            "Expected Ara facial morph targets in both exports; "
            f"bare={len(ref_shapes)}, dressed={len(candidate_shapes)}"
        )

    report = {
        "schema_version": 1,
        "reference": str(args.reference),
        "candidate": str(args.candidate),
        "validation": "passed",
        "bone_count": len(ref_bones),
        "bone_names_and_order": "identical",
        "rest_transforms": "identical",
        "maximum_rest_matrix_delta": max_delta,
        "bare_mesh_objects": [obj.name for obj in ref_meshes],
        "dressed_mesh_objects": [obj.name for obj in candidate_meshes],
        "bare_facial_morph_target_count": len(ref_shapes),
        "dressed_facial_morph_target_count": len(candidate_shapes),
        "facial_morph_target_names": ref_shapes,
        "dressed_material_names": material_names(candidate_meshes),
        "note": "Ara body macro controls are baked into exported geometry; facial blend shapes remain available in GLB."
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        f"[Ara body validation] PASSED bones={len(ref_bones)} "
        f"rest_transform_delta={max_delta:.8g} "
        f"facial_morphs={len(ref_shapes)} "
        f"dressed_materials={', '.join(report['dressed_material_names'])}"
    )
    print(f"[Ara body validation] Report: {args.output}")


if __name__ == "__main__":
    main()
