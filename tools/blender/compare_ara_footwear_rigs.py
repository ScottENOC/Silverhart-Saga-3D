#!/usr/bin/env python3
"""Read-only comparison of bare, dressed/no-shoes and dressed/booted Ara rigs.

No bones, meshes, modifiers or transforms are changed. The report isolates
whether Ara footwear is responsible for the Wren garment-source rig offset.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy


EPSILON = 1e-5


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--no-shoes", type=Path, required=True)
    parser.add_argument("--with-shoes", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    return parser.parse_args(raw)


def import_rig(path: Path):
    if not path.is_file():
        raise FileNotFoundError(path)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = list(set(bpy.data.objects) - before)
    armatures = [obj for obj in imported if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"{path.name}: expected one armature, found {len(armatures)}")
    return imported, armatures[0]


def matrix_delta(a, b):
    return max(abs(a[r][c] - b[r][c]) for r in range(4) for c in range(4))


def relative_matrix(bone):
    return bone.parent.matrix_local.inverted_safe() @ bone.matrix_local if bone.parent else bone.matrix_local.copy()


def compare(reference, candidate):
    ref_bones = {bone.name: bone for bone in reference.data.bones}
    candidate_bones = {bone.name: bone for bone in candidate.data.bones}
    same_order = list(ref_bones) == list(candidate_bones)
    same_hierarchy = same_order and all(
        (ref_bones[name].parent.name if ref_bones[name].parent else None)
        == (candidate_bones[name].parent.name if candidate_bones[name].parent else None)
        for name in ref_bones
    )
    result = {
        "armature_world_matrix_delta": matrix_delta(reference.matrix_world, candidate.matrix_world),
        "bone_names_and_order_match": same_order,
        "bone_hierarchy_match": same_hierarchy,
        "reference_bone_count": len(ref_bones),
        "candidate_bone_count": len(candidate_bones),
    }
    if not same_order:
        result["missing_from_candidate"] = sorted(set(ref_bones) - set(candidate_bones))
        result["extra_in_candidate"] = sorted(set(candidate_bones) - set(ref_bones))
        return result

    root_delta = ref_bones["Hips"].head_local - candidate_bones["Hips"].head_local
    absolute = {}
    relative = {}
    translated = {}
    for name in ref_bones:
        absolute[name] = matrix_delta(ref_bones[name].matrix_local, candidate_bones[name].matrix_local)
        relative[name] = matrix_delta(relative_matrix(ref_bones[name]), relative_matrix(candidate_bones[name]))
        shifted = candidate_bones[name].matrix_local.copy()
        shifted.translation += root_delta
        translated[name] = matrix_delta(ref_bones[name].matrix_local, shifted)

    def maximum(values):
        return max(values.values(), default=0.0)

    result.update({
        "hips_head_delta_candidate_to_reference_metres": [round(v, 9) for v in -root_delta],
        "hips_head_delta_length_metres": root_delta.length,
        "max_absolute_rest_matrix_delta": maximum(absolute),
        "max_parent_relative_rest_matrix_delta": maximum(relative),
        "max_residual_after_common_hips_translation": maximum(translated),
        "absolute_bones_over_1e-5": [name for name, value in absolute.items() if value > EPSILON],
        "parent_relative_bones_over_1e-5": [name for name, value in relative.items() if value > EPSILON],
        "translation_residuals_over_1e-5": {
            name: value for name, value in translated.items()
            if value > EPSILON and name != "WeaponR"
        },
        "weaponr_translation_residual": translated.get("WeaponR"),
    })
    return result


def main():
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    _, reference = import_rig(args.reference)
    _, no_shoes = import_rig(args.no_shoes)
    _, with_shoes = import_rig(args.with_shoes)

    report = {
        "schema_version": 1,
        "test": "Does Ara footwear cause the Wren dressed-source rig offset?",
        "inputs": {
            "bare_body": str(args.reference),
            "dressed_without_shoes": str(args.no_shoes),
            "dressed_with_profile_shoes": str(args.with_shoes),
        },
        "comparisons_against_bare_body": {
            "dressed_without_shoes": compare(reference, no_shoes),
            "dressed_with_profile_shoes": compare(reference, with_shoes),
        },
        "comparison_between_dressed_variants": compare(no_shoes, with_shoes),
        "read_only": True,
        "epsilon_metres": EPSILON,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("[Ara footwear rig comparison] Report: " + str(args.report), flush=True)
    for label, item in report["comparisons_against_bare_body"].items():
        print(
            f"[Ara footwear rig comparison] {label}: "
            f"hips_delta={item.get('hips_head_delta_length_metres')}m "
            f"max_parent_relative={item.get('max_parent_relative_rest_matrix_delta')} "
            f"max_translation_residual={item.get('max_residual_after_common_hips_translation')}",
            flush=True,
        )


if __name__ == "__main__":
    main()
