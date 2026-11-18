"""Create a reusable pointed-elf-ear shape key on an Ara GLB.

Ara's exported GLB is Y-up and faces +Z (verified against the exported skin
mesh and the body-hair UV pass). Ear selection therefore uses Y for height,
X for left/right and -Z for the rearward sweep.
"""
import argparse
import os
import sys
import math

import bpy
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--length", type=float, default=0.105)
    parser.add_argument("--rise", type=float, default=0.025)
    parser.add_argument("--sweep", type=float, default=0.055,
                        help="Rearward tip sweep in metres")
    parser.add_argument("--strength", type=float, default=1.0)
    parser.add_argument("--ear-height", type=float, default=0.875)
    parser.add_argument("--ear-band", type=float, default=0.035, help="Half-height of strict ear selection band")
    parser.add_argument("--key-name", default="ElfEars")
    return parser.parse_args(raw)


def material_name(obj):
    return " ".join(slot.material.name.lower() for slot in obj.material_slots if slot.material)


def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (Vector(tuple(min(p[i] for p in points) for i in range(3))),
            Vector(tuple(max(p[i] for p in points) for i in range(3))))


def smoothstep(a, b, x):
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    t = (x - a) / (b - a)
    return t * t * (3.0 - 2.0 * t)


def main():
    args = arguments()
    if args.length <= 0 or args.strength < 0:
        raise ValueError("Ear length must be positive and strength non-negative")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    skin = max((o for o in meshes if "skin" in material_name(o)),
               key=lambda o: len(o.data.polygons), default=None)
    if skin is None:
        raise RuntimeError("Could not identify Ara skin mesh")

    lo, hi = world_bounds(skin)
    height, width = hi.y - lo.y, hi.x - lo.x
    if height <= 0 or width <= 0:
        raise RuntimeError("Invalid skin mesh bounds")
    ear_y = lo.y + height * args.ear_height
    # Hard spatial gate: only the upper head/ear band can be modified.
    # The previous broad mask also caught side-facing shoulders and limbs.
    y_min = lo.y + height * 0.855
    y_max = lo.y + height * 0.915
    inner_x, outer_x = width * 0.105, width * 0.205
    centre_y = ear_y
    vertical_sigma = height * 0.018

    world_matrix = skin.matrix_world
    original = [v.co.copy() for v in skin.data.vertices]
    world_positions = [world_matrix @ co for co in original]
    world_normals = [(world_matrix.to_3x3() @ v.normal).normalized() for v in skin.data.vertices]

    side_candidates = {}
    for side in (-1.0, 1.0):
        indices = []
        for i, (p, n) in enumerate(zip(world_positions, world_normals)):
            lateral = side * p.x
            if not (inner_x <= lateral <= outer_x):
                continue
            # Absolute limits prevent shoulders, torso, buttocks and legs
            # from ever entering this shape key, regardless of normal.
            if not (y_min <= p.y <= y_max):
                continue
            if abs(p.y - ear_y) > height * args.ear_band:
                continue
            if side * n.x < 0.42:
                continue
            indices.append(i)
        side_candidates[side] = indices

    counts = {("L" if s > 0 else "R"): len(v) for s, v in side_candidates.items()}
    print(f"Elf-ear candidate vertex counts: {counts}")
    if min(counts.values()) < 8:
        raise RuntimeError(f"Could not confidently locate both Ara ears: {counts}; no output exported")

    if skin.data.shape_keys is None:
        skin.shape_key_add(name="Basis", from_mix=False)
    elif args.key_name in skin.data.shape_keys.key_blocks:
        raise RuntimeError(f"Shape key {args.key_name!r} already exists")
    key = skin.shape_key_add(name=args.key_name, from_mix=False)
    key.slider_min, key.slider_max = 0.0, 1.0
    key.value = max(0.0, min(1.0, args.strength))

    inv = world_matrix.inverted()
    moved = {("L" if s > 0 else "R"): 0 for s in side_candidates}
    for side, indices in side_candidates.items():
        for i in indices:
            p = world_positions[i]
            u = (side * p.x - inner_x) / max(outer_x - inner_x, 1e-8)
            influence = smoothstep(0.0, 0.45, u) * math.exp(-0.5 * ((p.y - centre_y) / vertical_sigma) ** 2)
            if influence < 0.001:
                continue
            q = p.copy()
            q.x += side * args.length * influence
            q.y += args.rise * influence
            q.z -= args.sweep * influence
            key.data[i].co = inv @ q
            moved["L" if side > 0 else "R"] += 1
    if min(moved.values()) < 4:
        raise RuntimeError(f"Too few vertices deformed on both ears: {moved}")
    skin.data.update()
    skin["elf_ears_shape_key"] = args.key_name
    skin["elf_ears_length_m"] = args.length
    skin["elf_ears_rise_m"] = args.rise
    skin["elf_ears_sweep_m"] = args.sweep
    skin["elf_ears_strength"] = key.value
    print(f"Created {args.key_name}: Y-up mask, moved={moved}, length={args.length:.3f}m")
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    if armature:
        bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False, export_animations=True)
    print("Exported Y-up elf-ear variant.")


if __name__ == "__main__":
    main()
