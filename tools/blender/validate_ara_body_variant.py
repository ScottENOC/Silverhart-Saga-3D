#!/usr/bin/env python3
"""Compare same-profile Ara exports and retain full diagnostics on failure.

Reports both armature-space bone matrices and parent-relative bone transforms.
This distinguishes a genuine change in a bone's local rig definition from a
character-origin offset (for example, a different footwear ground reference).
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
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
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
    return armatures[0], meshes


def matrix_delta(a, b):
    return max(abs(a[r][c] - b[r][c]) for r in range(4) for c in range(4))


def relative_matrix(bone):
    return bone.parent.matrix_local.inverted_safe() @ bone.matrix_local if bone.parent else bone.matrix_local.copy()


def shape_names(meshes):
    return sorted({
        key.name
        for obj in meshes if obj.data.shape_keys
        for key in list(obj.data.shape_keys.key_blocks)[1:]
    })


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

    ref_armature, ref_meshes = import_asset(args.reference)
    candidate_armature, candidate_meshes = import_asset(args.candidate)

    armature_delta = matrix_delta(ref_armature.matrix_world, candidate_armature.matrix_world)
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
    max_absolute_delta = 0.0
    max_relative_delta = 0.0
    for ref_bone, candidate_bone in zip(ref_bones, candidate_bones):
        absolute_delta = matrix_delta(ref_bone.matrix_local, candidate_bone.matrix_local)
        relative_delta = matrix_delta(relative_matrix(ref_bone), relative_matrix(candidate_bone))
        max_absolute_delta = max(max_absolute_delta, absolute_delta)
        max_relative_delta = max(max_relative_delta, relative_delta)
        if absolute_delta > 1e-5 or relative_delta > 1e-5:
            differences.append({
                "bone": ref_bone.name,
                "parent": ref_bone.parent.name if ref_bone.parent else None,
                "armature_space_matrix_delta": absolute_delta,
                "parent_relative_matrix_delta": relative_delta,
                "reference_head": [round(v, 7) for v in ref_bone.head_local],
                "candidate_head": [round(v, 7) for v in candidate_bone.head_local],
            })

    ref_shapes = shape_names(ref_meshes)
    candidate_shapes = shape_names(candidate_meshes)
    shape_match = ref_shapes == candidate_shapes and len(ref_shapes) >= 20

    report = {
        "schema_version": 2,
        "reference": str(args.reference),
        "candidate": str(args.candidate),
        "bone_count": len(ref_bones),
        "bone_names_and_order_match": ref_names == candidate_names,
        "armature_object_matrix_delta": armature_delta,
        "maximum_armature_space_bone_matrix_delta": max_absolute_delta,
        "maximum_parent_relative_bone_matrix_delta": max_relative_delta,
        "armature_space_differing_bone_count": sum(
            item["armature_space_matrix_delta"] > 1e-5 for item in differences
        ),
        "parent_relative_differing_bone_count": sum(
            item["parent_relative_matrix_delta"] > 1e-5 for item in differences
        ),
        "bone_differences": sorted(
            differences,
            key=lambda item: max(item["armature_space_matrix_delta"], item["parent_relative_matrix_delta"]),
            reverse=True,
        ),
        "facial_morphs_match": shape_match,
        "bare_facial_morph_target_count": len(ref_shapes),
        "dressed_facial_morph_target_count": len(candidate_shapes),
        "bare_facial_morph_target_names": ref_shapes,
        "dressed_facial_morph_target_names": candidate_shapes,
        "dressed_material_names": material_names(candidate_meshes),
        "validation": "passed" if (
            armature_delta <= 1e-5 and max_absolute_delta <= 1e-5 and shape_match
        ) else "failed",
        "note": (
            "Armature-space differences with matching parent-relative transforms indicate "
            "a root/origin offset, not changed finger or limb articulation. Ara places bones "
            "from morphed body joints; footwear can affect the character ground origin."
        ),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print(
        "[Ara body validation] "
        f"bones={len(ref_bones)} "
        f"armature_delta={armature_delta:.8g} "
        f"max_armature_space_delta={max_absolute_delta:.8g} "
        f"max_parent_relative_delta={max_relative_delta:.8g} "
        f"armature_space_differences={report['armature_space_differing_bone_count']} "
        f"parent_relative_differences={report['parent_relative_differing_bone_count']} "
        f"facial_morphs={len(ref_shapes)} match={shape_match}"
    )
    print(f"[Ara body validation] Full report: {args.output}")

    if report["validation"] != "passed":
        raise RuntimeError(
            "Ara export validation failed. See the full JSON report for every bone's "
            "armature-space and parent-relative differences."
        )


if __name__ == "__main__":
    main()
