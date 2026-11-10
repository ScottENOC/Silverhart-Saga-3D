#!/usr/bin/env python3
"""Rebase a footwear-shifted Ara garment export onto the canonical bare-body rig.

This is deliberately conservative: it accepts only the known Wren case where
all rest-bone transforms become identical after one common translation, with
a sub-millimetre WeaponR socket discrepancy. It then copies the canonical
WeaponR rest transform and verifies evaluated mesh geometry is unchanged
before exporting a normalized GLB.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


EPSILON = 1e-5
MAX_ROOT_OFFSET = 0.05
MAX_WEAPON_SOCKET_DELTA = 0.001


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    return parser.parse_args(raw)


def import_asset(path: Path):
    if not path.is_file():
        raise FileNotFoundError(path)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = list(set(bpy.data.objects) - before)
    armatures = [obj for obj in imported if obj.type == "ARMATURE"]
    meshes = [obj for obj in imported if obj.type == "MESH"]
    if len(armatures) != 1 or not meshes:
        raise RuntimeError(
            f"{path.name}: expected one armature and at least one mesh; "
            f"found armatures={len(armatures)}, meshes={len(meshes)}"
        )
    return imported, armatures[0], meshes


def matrix_delta(a, b):
    return max(abs(a[r][c] - b[r][c]) for r in range(4) for c in range(4))


def relative_matrix(bone):
    return bone.parent.matrix_local.inverted_safe() @ bone.matrix_local if bone.parent else bone.matrix_local.copy()


def evaluated_mesh_snapshot(meshes):
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    snapshot = {}
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        try:
            snapshot[obj.name] = [
                tuple(evaluated.matrix_world @ vertex.co)
                for vertex in mesh.vertices
            ]
        finally:
            evaluated.to_mesh_clear()
    return snapshot


def max_geometry_delta(before, after):
    if before.keys() != after.keys():
        raise RuntimeError("Mesh object set changed during rig normalisation")
    maximum = 0.0
    for name in before:
        if len(before[name]) != len(after[name]):
            raise RuntimeError(f"{name}: evaluated vertex count changed during normalisation")
        for a, b in zip(before[name], after[name]):
            maximum = max(maximum, (Vector(a) - Vector(b)).length)
    return maximum


def main():
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    ref_objects, ref_armature, _ = import_asset(args.reference)
    candidate_objects, candidate_armature, candidate_meshes = import_asset(args.candidate)

    if matrix_delta(ref_armature.matrix_world, candidate_armature.matrix_world) > EPSILON:
        raise RuntimeError("Armature object transforms differ; refusing to normalise.")

    ref_bones = {bone.name: bone for bone in ref_armature.data.bones}
    candidate_bones = {bone.name: bone for bone in candidate_armature.data.bones}
    if list(ref_bones) != list(candidate_bones):
        raise RuntimeError("Bone names/order differ; refusing to normalise.")
    if any(
        (ref_bones[name].parent.name if ref_bones[name].parent else None)
        != (candidate_bones[name].parent.name if candidate_bones[name].parent else None)
        for name in ref_bones
    ):
        raise RuntimeError("Bone parent hierarchy differs; refusing to normalise.")
    if "Hips" not in ref_bones or "WeaponR" not in ref_bones:
        raise RuntimeError("Expected Hips and WeaponR bones are not present.")

    root_delta = ref_bones["Hips"].head_local - candidate_bones["Hips"].head_local
    if root_delta.length > MAX_ROOT_OFFSET:
        raise RuntimeError(
            f"Hips offset {root_delta.length:.6f}m exceeds the "
            f"{MAX_ROOT_OFFSET:.3f}m safety limit."
        )

    # Prove that one translation explains every rest-bone difference except
    # the already observed tiny WeaponR socket discrepancy.
    preflight = {}
    for name in ref_bones:
        shifted = candidate_bones[name].matrix_local.copy()
        shifted.translation += root_delta
        delta = matrix_delta(ref_bones[name].matrix_local, shifted)
        preflight[name] = delta
        if name == "WeaponR":
            if delta > MAX_WEAPON_SOCKET_DELTA:
                raise RuntimeError(
                    f"WeaponR residual {delta:.7g} exceeds the "
                    f"{MAX_WEAPON_SOCKET_DELTA:.4f}m safety limit."
                )
        elif delta > EPSILON:
            raise RuntimeError(
                f"{name} is not explained by the common Hips translation "
                f"(residual matrix delta {delta:.7g}); refusing to normalise."
            )

    geometry_before = evaluated_mesh_snapshot(candidate_meshes)

    # Shift every candidate rest bone by the same armature-space vector.
    # This removes the generated footwear ground-reference offset while
    # preserving all parent-relative transforms and bone lengths.
    bpy.context.view_layer.objects.active = candidate_armature
    candidate_armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = candidate_armature.data.edit_bones
    for bone in edit_bones:
        bone.head += root_delta
        bone.tail += root_delta

    # The weapon socket has a separately measured sub-millimetre residual.
    # Copy its canonical rest placement after applying the common translation.
    edit_bones["WeaponR"].matrix = ref_bones["WeaponR"].matrix_local.copy()
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    post_deltas = {
        name: matrix_delta(ref_bones[name].matrix_local, candidate_bones[name].matrix_local)
        for name in ref_bones
    }
    worst_bone = max(post_deltas, key=post_deltas.get)
    if post_deltas[worst_bone] > EPSILON:
        raise RuntimeError(
            f"Normalised skeleton still differs at {worst_bone}: "
            f"{post_deltas[worst_bone]:.7g}"
        )

    geometry_after = evaluated_mesh_snapshot(candidate_meshes)
    geometry_delta = max_geometry_delta(geometry_before, geometry_after)
    if geometry_delta > EPSILON:
        raise RuntimeError(
            f"Normalisation changed evaluated mesh geometry by up to "
            f"{geometry_delta:.7g}m; refusing to export."
        )

    # Remove the reference import; export only the candidate meshes and its
    # now-canonical skeleton.
    for obj in ref_objects:
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in candidate_objects:
        if obj.name in bpy.data.objects:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = candidate_armature

    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(args.output),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=False,
        export_apply=False,
    )

    report = {
        "schema_version": 1,
        "reference": str(args.reference),
        "candidate": str(args.candidate),
        "output": str(args.output),
        "root_translation_removed_metres": [round(v, 8) for v in root_delta],
        "root_translation_distance_metres": root_delta.length,
        "preflight_max_residual_by_bone": preflight,
        "post_normalisation_max_residual_by_bone": post_deltas,
        "evaluated_mesh_max_vertex_displacement_metres": geometry_delta,
        "validation": "passed",
        "method": "Common rest-bone translation plus canonical WeaponR rest transform; evaluated mesh vertices verified unchanged.",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        "[Ara rig normalisation] "
        f"root_offset={root_delta.length:.7g}m "
        f"weaponR_preflight={preflight['WeaponR']:.7g} "
        f"mesh_displacement={geometry_delta:.7g}m "
        "all_rest_bones_match=True"
    )
    print(f"[Ara rig normalisation] Report: {args.report}")


if __name__ == "__main__":
    main()
