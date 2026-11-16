#!/usr/bin/env python3
"""Add reusable relative body shape keys to the shared Ara male/female GLBs.

The keys are deliberately moderate art-direction blockouts. They preserve the
existing armature and facial keys and are driven per-character in Godot.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


MORPH_NAMES = (
    "body_height",
    "body_muscle",
    "body_weight",
    "body_breasts",
    "body_legs",
    "body_proportions",
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def smoothstep(a, b, value):
    t = max(0.0, min(1.0, (value - a) / max(1e-6, b - a)))
    return t * t * (3.0 - 2.0 * t)


def gaussian(value, centre, spread):
    return math.exp(-0.5 * ((value - centre) / max(1e-6, spread)) ** 2)


def main():
    args = parse_args()
    source = Path(args.input)
    output = Path(args.output)
    if not source.is_file():
        raise FileNotFoundError(source)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source))

    skinned = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH"
        and any(mod.type == "ARMATURE" for mod in obj.modifiers)
        and len(obj.data.vertices) > 100
    ]
    if not skinned:
        raise RuntimeError(f"No skinned Ara meshes found in {source}")

    world_vertices = []
    for obj in skinned:
        matrix = obj.matrix_world
        world_vertices.extend(matrix @ vertex.co for vertex in obj.data.vertices)
    min_x = min(v.x for v in world_vertices)
    max_x = max(v.x for v in world_vertices)
    min_y = min(v.y for v in world_vertices)
    max_y = max(v.y for v in world_vertices)
    min_z = min(v.z for v in world_vertices)
    max_z = max(v.z for v in world_vertices)
    width = max(1e-5, max_x - min_x)
    height = max(1e-5, max_z - min_z)
    centre_x = (min_x + max_x) * 0.5
    centre_y = (min_y + max_y) * 0.5

    print(
        f"[Ara body morphs] {source.name}: meshes={len(skinned)} "
        f"bounds=({min_x:.4f},{min_y:.4f},{min_z:.4f})-"
        f"({max_x:.4f},{max_y:.4f},{max_z:.4f})"
    )

    for obj in skinned:
        if obj.data.shape_keys is None:
            obj.shape_key_add(name="Basis", from_mix=False)
        existing = obj.data.shape_keys.key_blocks
        for morph_name in MORPH_NAMES:
            if morph_name in existing:
                continue
            key = obj.shape_key_add(name=morph_name, from_mix=False)
            inverse = obj.matrix_world.inverted()
            normal_matrix = obj.matrix_world.to_3x3().inverted().transposed()
            for vertex in obj.data.vertices:
                world_pos = obj.matrix_world @ vertex.co
                normal = (normal_matrix @ vertex.normal).normalized()
                x = world_pos.x - centre_x
                z = (world_pos.z - min_z) / height
                x_abs = abs(x) / (width * 0.5)
                y_front = world_pos.y < centre_y

                delta = Vector((0.0, 0.0, 0.0))
                if morph_name == "body_height":
                    delta.z = (world_pos.z - min_z) * 0.18
                elif morph_name == "body_breasts":
                    chest = gaussian(z, 0.68, 0.075) * gaussian(x_abs, 0.22, 0.18)
                    front = max(0.0, -normal.y) if y_front else 0.0
                    delta.y = -0.045 * height * chest * front
                elif morph_name == "body_legs":
                    leg_zone = smoothstep(0.08, 0.18, z) * (1.0 - smoothstep(0.48, 0.60, z))
                    thigh_focus = 0.55 + 0.45 * gaussian(z, 0.34, 0.16)
                    side = 1.0 if x >= 0.0 else -1.0
                    delta.x = side * 0.028 * width * leg_zone * thigh_focus * min(1.0, x_abs * 3.0)
                elif morph_name == "body_muscle":
                    arm_zone = smoothstep(0.38, 0.52, z) * (1.0 - smoothstep(0.86, 0.96, z)) * smoothstep(0.12, 0.30, x_abs)
                    leg_zone = smoothstep(0.08, 0.18, z) * (1.0 - smoothstep(0.48, 0.60, z))
                    torso_zone = gaussian(z, 0.58, 0.20) * (1.0 - smoothstep(0.30, 0.48, x_abs))
                    amount = max(arm_zone, leg_zone * 0.75, torso_zone * 0.45)
                    delta = normal * (0.012 * height * amount)
                elif morph_name == "body_weight":
                    torso = gaussian(z, 0.48, 0.18) * (1.0 - smoothstep(0.22, 0.40, x_abs))
                    delta = normal * (0.020 * height * torso)
                elif morph_name == "body_proportions":
                    shoulder = gaussian(z, 0.78, 0.10)
                    hip = gaussian(z, 0.43, 0.09)
                    side = 1.0 if x >= 0.0 else -1.0
                    delta.x = side * 0.025 * width * max(shoulder, hip) * min(1.0, x_abs * 3.0)

                key.data[vertex.index].co = inverse @ (world_pos + delta)

        print(
            f"[Ara body morphs] mesh={obj.name} vertices={len(obj.data.vertices)} "
            f"keys={len(obj.data.shape_keys.key_blocks)}"
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".tmp.glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(temporary),
        export_format="GLB",
        export_skins=True,
        export_morph=True,
        export_animations=True,
        export_apply=False,
    )
    temporary.replace(output)
    print(f"[Ara body morphs] wrote {output} ({output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
