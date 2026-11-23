#!/usr/bin/env python3
"""Derive Ara's standard briefs coverage field from the native Ara rig.

Ara's catalog predicate is:
  (trunk region and trunk t < 0.12) or (upper-leg region and leg t < 0.1)
This adapter reconstructs those regions from the native Ara skinning weights
and the Hips/Neck/UpLeg rig landmarks in the exported Wren GLB.
"""
import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", default="")
    parser.add_argument("--body-object", default="")
    parser.add_argument("--trunk-limit", type=float, default=0.12)
    parser.add_argument("--upperleg-limit", type=float, default=0.10)
    parser.add_argument("--minimum-region-weight", type=float, default=0.15)
    return parser.parse_args(raw)


def import_glb(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(path))


def find_body(name=""):
    candidates = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or (name and obj.name != name):
            continue
        if not any(m.type == "ARMATURE" and m.object for m in obj.modifiers):
            continue
        materials = [m.name.lower() for m in obj.data.materials if m]
        score = 2 if any("skin" in material for material in materials) else 0
        candidates.append((score, obj))
    if not candidates:
        raise RuntimeError("No skinned Ara body mesh found")
    candidates.sort(key=lambda item: item[0], reverse=True)
    if not name and len(candidates) > 1 and candidates[0][0] == candidates[1][0]:
        raise RuntimeError("Multiple possible body meshes; specify --body-object")
    return candidates[0][1]


def main():
    options = args()
    import_glb(options.input)
    body = find_body(options.body_object)
    armature_modifier = next(m for m in body.modifiers if m.type == "ARMATURE" and m.object)
    armature = armature_modifier.object
    bones = armature.data.bones
    required = ("Hips", "Neck", "LeftUpLeg", "RightUpLeg")
    missing = [name for name in required if bones.get(name) is None]
    if missing:
        raise RuntimeError("Ara rig is missing required landmarks: " + ", ".join(missing))

    to_body = body.matrix_world.inverted() @ armature.matrix_world
    hips_y = (to_body @ bones["LeftUpLeg"].head_local).y
    hips_y += (to_body @ bones["RightUpLeg"].head_local).y
    hips_y *= 0.5
    neck_y = (to_body @ bones["Neck"].head_local).y
    if neck_y <= hips_y:
        raise RuntimeError(f"Expected Ara body-local Y-up coordinates; neck_y={neck_y:.5f}, hips_y={hips_y:.5f}")

    leg_axes = {}
    for side, bone_name in (("left", "LeftUpLeg"), ("right", "RightUpLeg")):
        bone = bones[bone_name]
        head = to_body @ bone.head_local
        tail = to_body @ bone.tail_local
        axis = tail - head
        length_sq = axis.length_squared
        if length_sq <= 1e-8:
            raise RuntimeError(f"Degenerate Ara upper-leg axis: {bone_name}")
        leg_axes[side] = (head, axis, length_sq)

    group_names = {group.index: group.name for group in body.vertex_groups}
    trunk_names = {"Hips", "Spine", "Spine1", "Spine2"}
    leg_names = {"LeftUpLeg", "RightUpLeg"}
    trunk_groups = {i for i, name in group_names.items() if name in trunk_names}
    left_group = next((i for i, name in group_names.items() if name == "LeftUpLeg"), None)
    right_group = next((i for i, name in group_names.items() if name == "RightUpLeg"), None)
    if not trunk_groups or left_group is None or right_group is None:
        raise RuntimeError("Body vertex groups do not expose the expected Ara trunk and upper-leg weights")

    field = []
    classifications = {"trunk": 0, "left_upperleg": 0, "right_upperleg": 0, "outside": 0}
    for vertex in body.data.vertices:
        weights = {entry.group: entry.weight for entry in vertex.groups}
        trunk_weight = sum(weights.get(index, 0.0) for index in trunk_groups)
        left_weight = weights.get(left_group, 0.0)
        right_weight = weights.get(right_group, 0.0)
        leg_weight = max(left_weight, right_weight)
        point = vertex.co

        if trunk_weight >= leg_weight and trunk_weight >= options.minimum_region_weight:
            trunk_t = (point.y - hips_y) / (neck_y - hips_y)
            field.append(options.trunk_limit - trunk_t)
            classifications["trunk"] += 1
        elif leg_weight >= options.minimum_region_weight:
            side = "left" if left_weight >= right_weight else "right"
            head, axis, length_sq = leg_axes[side]
            leg_t = (point - head).dot(axis) / length_sq
            field.append(options.upperleg_limit - leg_t)
            classifications[side + "_upperleg"] += 1
        else:
            field.append(-1.0)
            classifications["outside"] += 1

    if not any(value >= 0 for value in field):
        raise RuntimeError("Ara briefs coverage selected no body vertices")
    result = {"field_values": field}
    output = Path(options.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, separators=(",", ":")) + "\n")
    report = {
        "preset": "ara_standard_briefs",
        "body_object": body.name,
        "body_vertices": len(body.data.vertices),
        "hip_y_m": hips_y,
        "neck_y_m": neck_y,
        "trunk_limit": options.trunk_limit,
        "upperleg_limit": options.upperleg_limit,
        "minimum_region_weight": options.minimum_region_weight,
        "classifications": classifications,
        "covered_vertices": sum(value >= 0 for value in field),
        "field_min": min(field),
        "field_max": max(field),
        "field_json": str(output),
    }
    report_path = Path(options.report) if options.report else output.with_suffix(".report.json")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print("ARA_BRIEFS_COVERAGE " + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()
