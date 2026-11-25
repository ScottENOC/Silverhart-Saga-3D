"""Add a defined, anatomically placed rectus-abdominis shape key to an Ara GLB.

Six distinct muscle bellies are created with a narrow linea alba and two
horizontal tendinous intersections. The mask is shifted upward and fades
before the pelvis so the lower abdomen remains smooth. Strength is a separate
Blender sculpt parameter (0..1.5), not Ara's 0..1 stomach-tone slider.
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
    parser.add_argument("--strength", type=float, default=0.55)
    parser.add_argument("--key-name", default="AbdominalDefinition")
    return parser.parse_args(raw)


def material_name(obj):
    return " ".join(slot.material.name.lower() for slot in obj.material_slots if slot.material)


def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (Vector(tuple(min(p[i] for p in points) for i in range(3))),
            Vector(tuple(max(p[i] for p in points) for i in range(3))))


def gaussian(value, sigma):
    return math.exp(-0.5 * (value / max(sigma, 1e-8)) ** 2)


def smoothstep(edge0, edge1, value):
    t = max(0.0, min(1.0, (value - edge0) / max(edge1 - edge0, 1e-8)))
    return t * t * (3.0 - 2.0 * t)


def main():
    args = arguments()
    if not 0.0 <= args.strength <= 1.5:
        raise ValueError("--strength must be between 0 and 1.5")
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
    world_matrix = skin.matrix_world
    normal_matrix = world_matrix.to_3x3().inverted().transposed()
    inverse = world_matrix.inverted()
    positions = [world_matrix @ v.co for v in skin.data.vertices]
    normals = [(normal_matrix @ v.normal).normalized() for v in skin.data.vertices]

    # Raise the six-pack centre and tighten its vertical footprint. The lowest
    # muscle belly is now above the hip/pelvis transition.
    centre_y = lo.y + height * 0.555
    row_spacing = height * 0.052
    row_centres = (centre_y + row_spacing, centre_y, centre_y - row_spacing)
    pad_x = width * 0.066
    sigma_x = width * 0.024
    sigma_y = height * 0.017
    front_limit = width * 0.155
    top_y = lo.y + height * 0.655
    bottom_y = lo.y + height * 0.455

    if skin.data.shape_keys is None:
        skin.shape_key_add(name="Basis", from_mix=False)
    elif args.key_name in skin.data.shape_keys.key_blocks:
        raise RuntimeError(f"Shape key {args.key_name!r} already exists")
    key = skin.shape_key_add(name=args.key_name, from_mix=False)
    key.slider_min, key.slider_max, key.value = 0.0, 1.0, 1.0

    moved, max_offset = 0, 0.0
    for index, (p, normal) in enumerate(zip(positions, normals)):
        if p.y < bottom_y or p.y > top_y or abs(p.x) > front_limit:
            continue
        frontness = max(0.0, min(1.0, normal.z))
        if frontness < 0.45:
            continue

        vertical_gate = smoothstep(bottom_y, bottom_y + height * 0.025, p.y)
        vertical_gate *= 1.0 - smoothstep(top_y - height * 0.025, top_y, p.y)
        lateral_gate = 1.0 - smoothstep(front_limit * 0.82, front_limit, abs(p.x))
        mask = vertical_gate * lateral_gate * frontness

        pads = 0.0
        for row_y in row_centres:
            vertical = gaussian(p.y - row_y, sigma_y)
            for side in (-1.0, 1.0):
                pads = max(pads, vertical * gaussian(p.x - side * pad_x, sigma_x))

        central = gaussian(p.x, width * 0.0045) * gaussian(p.y - centre_y, height * 0.088)
        horizontal = 0.0
        for groove_y in (centre_y + row_spacing * 0.5, centre_y - row_spacing * 0.5):
            horizontal = max(horizontal,
                             gaussian(p.y - groove_y, height * 0.0027)
                             * gaussian(p.x, width * 0.135))

        oblique = 0.0
        for side in (-1.0, 1.0):
            oblique = max(oblique,
                          gaussian(p.x - side * width * 0.124, width * 0.016)
                          * gaussian(p.y - centre_y, height * 0.070))

        displacement = (pads * 0.0200 + oblique * 0.0032
                        - central * 0.0080 - horizontal * 0.0070) * args.strength * mask
        if abs(displacement) < 1e-6:
            continue
        key.data[index].co = inverse @ (p + normal * displacement)
        moved += 1
        max_offset = max(max_offset, abs(displacement))

    if moved < 100:
        raise RuntimeError(f"Only {moved} abdominal vertices selected; check Y-up front-facing mask")
    skin.data.update()
    skin["abdominal_definition_key"] = args.key_name
    skin["abdominal_definition_strength"] = args.strength
    skin["abdominal_definition_region"] = "Y 45.5%-65.5%; six-pack centre 55.5%"
    print(f"Created {args.key_name}: Y-up strength={args.strength:.2f}, moved={moved}, "
          f"max_offset={max_offset:.4f}m, region=45.5%-65.5%")

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
    print("Exported refined abdominal-definition variant.")


if __name__ == "__main__":
    main()
