"""Create a reusable pointed-elf-ear shape key on an Ara GLB.

Run AFTER add_adult_anatomy.py when the character also needs that pass.
Only the largest skin mesh is modified; the ear selection is spatially limited
to the lateral head band and outward-facing skin vertices. The body mesh,
armature, materials and existing facial shape keys are retained.

Ara GLB convention used by this project: Z up, character facing -Y.
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
    parser.add_argument("--length", type=float, default=0.050,
                        help="Maximum outward ear-tip extension in metres")
    parser.add_argument("--rise", type=float, default=0.012,
                        help="Additional upward tip angle in metres")
    parser.add_argument("--sweep", type=float, default=0.012,
                        help="Sweep the tip backwards (+Y) in metres")
    parser.add_argument("--strength", type=float, default=1.0)
    parser.add_argument("--ear-height", type=float, default=0.875,
                        help="Ear centre as a fraction of whole-character height")
    parser.add_argument("--key-name", default="ElfEars")
    return parser.parse_args(raw)


def material_name(obj):
    return " ".join(
        slot.material.name.lower()
        for slot in obj.material_slots if slot.material
    )


def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector(tuple(min(p[i] for p in points) for i in range(3))),
        Vector(tuple(max(p[i] for p in points) for i in range(3))),
    )


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
    skin = max(
        (o for o in meshes if "skin" in material_name(o)),
        key=lambda o: len(o.data.polygons),
        default=None,
    )
    if skin is None:
        raise RuntimeError(
            "Could not identify Ara skin mesh. Meshes/materials: " +
            " | ".join(f"{o.name}: {material_name(o)}" for o in meshes)
        )

    lo, hi = world_bounds(skin)
    height = hi.z - lo.z
    width = hi.x - lo.x
    if height <= 0 or width <= 0:
        raise RuntimeError("Invalid skin mesh bounds")

    ear_z = lo.z + height * args.ear_height
    # Match the ear band already used by the project's earring-socket finder.
    z_half_band = height * 0.055
    inner_x = width * 0.100
    outer_x = width * 0.350
    centre_z = ear_z + height * 0.003
    vertical_sigma = height * 0.050

    world_matrix = skin.matrix_world
    normal_matrix = world_matrix.to_3x3()
    original = [v.co.copy() for v in skin.data.vertices]
    world_positions = [world_matrix @ co for co in original]
    world_normals = [
        (normal_matrix @ v.normal).normalized() for v in skin.data.vertices
    ]

    # Candidate vertices must lie in the ear band and face outwards. This
    # excludes most of the front-facing cheek and the rear of the skull.
    side_candidates = {}
    for side in (-1.0, 1.0):
        indices = []
        for i, (p, n) in enumerate(zip(world_positions, world_normals)):
            lateral = side * p.x
            if not (inner_x <= lateral <= outer_x):
                continue
            if abs(p.z - ear_z) > z_half_band:
                continue
            if side * n.x < 0.28:
                continue
            indices.append(i)
        side_candidates[side] = indices

    # Require a reasonable sample on both sides; silently deforming one ear
    # would be worse than failing the build with useful diagnostics.
    counts = {("L" if s > 0 else "R"): len(v) for s, v in side_candidates.items()}
    print(f"Elf-ear candidate vertex counts: {counts}")
    if min(counts.values()) < 8:
        raise RuntimeError(
            "Could not confidently locate both Ara ears. "
            f"Candidate counts={counts}; refusing a partial/face deformation. "
            "Inspect skin bounds and adjust --ear-height or selection limits."
        )

    # A shape key keeps this reusable and adjustable in the exported GLB.
    if skin.data.shape_keys is None:
        skin.shape_key_add(name="Basis", from_mix=False)
    elif args.key_name in skin.data.shape_keys.key_blocks:
        raise RuntimeError(
            f"Shape key {args.key_name!r} already exists; refusing to stack it"
        )
    key = skin.shape_key_add(name=args.key_name, from_mix=False)
    key.slider_min = 0.0
    key.slider_max = 1.0
    key.value = max(0.0, min(1.0, args.strength))

    # Extend only the outer portion of the ear. A narrow vertical influence
    # band makes the extension converge to a point rather than scaling the
    # whole side of the head. The slight upward component gives a natural,
    # swept-back fantasy-ear silhouette without changing the ear root.
    inv = world_matrix.inverted()
    moved = {("L" if s > 0 else "R"): 0 for s in side_candidates}\n    max_influence = 0.0
    for side, indices in side_candidates.items():
        for i in indices:
            p = world_positions[i]
            lateral = side * p.x
            u = (lateral - inner_x) / max(outer_x - inner_x, 1e-8)
            outer_falloff = smoothstep(0.00, 0.30, u)
            vertical = math.exp(
                -0.5 * ((p.z - centre_z) / vertical_sigma) ** 2
            )
            influence = outer_falloff * vertical
            if influence < 0.001:
                continue
            q = p.copy()
            q.x += side * args.length * influence
            q.y += args.sweep * influence
            q.z += args.rise * influence
            key.data[i].co = inv @ q
            moved["L" if side > 0 else "R"] += 1

    if min(moved.values()) < 4:
        raise RuntimeError(
            f"Too few vertices were deformed on both ears: {moved}. "
            "No output exported."
        )

    skin.data.update()
    skin["elf_ears_shape_key"] = args.key_name
    skin["elf_ears_length_m"] = args.length
    skin["elf_ears_rise_m"] = args.rise
    skin["elf_ears_sweep_m"] = args.sweep
    skin["elf_ears_strength"] = key.value
    print(
        f"Created {args.key_name}: length={args.length:.3f}m, "
        f"rise={args.rise:.3f}m, sweep={args.sweep:.3f}m, "
        f"strength={key.value:.2f}, moved={moved}, max_influence={max_influence:.3f}"
    )

    armature = next(
        (o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None
    )
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    if armature:
        bpy.context.view_layer.objects.active = armature

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(args.output),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
    )
    print("Exported elf-ear variant. Review front, side and three-quarter views.")


if __name__ == "__main__":
    main()
