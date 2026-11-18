"""Add a reusable, adjustable rectus-abdominis definition shape key to an Ara GLB.

The sculpt is deliberately restrained: six rounded muscle bellies, a subtle
linea alba and two tendinous intersections. It is applied only to the front
abdominal skin surface and remains a morph target in the exported GLB.
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
    parser.add_argument("--strength", type=float, default=1.0,
                        help="Definition strength from 0 (off) to 1.5 (very pronounced)")
    parser.add_argument("--key-name", default="AbdominalDefinition")
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


def gaussian(value, sigma):
    return math.exp(-0.5 * (value / max(sigma, 1e-8)) ** 2)


def main():
    args = arguments()
    if not 0.0 <= args.strength <= 1.5:
        raise ValueError("--strength must be between 0 and 1.5")

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

    world_matrix = skin.matrix_world
    normal_matrix = world_matrix.to_3x3()
    inverse = world_matrix.inverted()
    positions = [world_matrix @ v.co for v in skin.data.vertices]
    normals = [
        (normal_matrix @ v.normal).normalized() for v in skin.data.vertices
    ]

    # Ara's humanoid is Z-up in Blender and faces -Y. The abdomen lies below
    # the ribcage and above the pelvis; the mask excludes chest, hips and back.
    centre_z = lo.z + height * 0.525
    row_spacing = height * 0.065
    row_centres = (centre_z + row_spacing, centre_z, centre_z - row_spacing)
    pad_x = width * 0.070
    sigma_x = width * 0.030
    sigma_z = height * 0.022
    front_limit = width * 0.16
    top_z = lo.z + height * 0.64
    bottom_z = lo.z + height * 0.42

    if skin.data.shape_keys is None:
        skin.shape_key_add(name="Basis", from_mix=False)
    elif args.key_name in skin.data.shape_keys.key_blocks:
        raise RuntimeError(
            f"Shape key {args.key_name!r} already exists; refusing to stack it"
        )

    key = skin.shape_key_add(name=args.key_name, from_mix=False)
    key.slider_min = 0.0
    key.slider_max = 1.0
    key.value = 1.0

    moved = 0
    max_bulge = 0.0
    for index, (p, normal) in enumerate(zip(positions, normals)):
        if p.z < bottom_z or p.z > top_z or abs(p.x) > front_limit:
            continue
        frontness = max(0.0, min(1.0, -normal.y))
        if frontness < 0.45:
            continue

        # Three paired rectus bellies. A slight taper at the top and bottom
        # keeps the sculpt integrated with the ribcage and lower abdomen.
        pads = 0.0
        for row_z in row_centres:
            vertical = gaussian(p.z - row_z, sigma_z)
            for side in (-1.0, 1.0):
                pads = max(
                    pads,
                    vertical * gaussian(p.x - side * pad_x, sigma_x),
                )

        # Narrow grooves: linea alba down the centre and two horizontal
        # tendinous intersections separating the three rows.
        central = gaussian(p.x, width * 0.006)
        central *= gaussian(p.z - centre_z, height * 0.095)
        horizontal = 0.0
        for groove_z in (centre_z + row_spacing * 0.5,
                         centre_z - row_spacing * 0.5):
            horizontal = max(
                horizontal,
                gaussian(p.z - groove_z, height * 0.0035)
                * gaussian(p.x, width * 0.14),
            )

        # A little lateral definition hints at the external obliques without
        # turning the waist into a hard-edged or bodybuilder caricature.
        oblique = 0.0
        for side in (-1.0, 1.0):
            oblique = max(
                oblique,
                gaussian(p.x - side * width * 0.125, width * 0.016)
                * gaussian(p.z - centre_z, height * 0.075),
            )

        displacement = (
            pads * 0.0140
            + oblique * 0.0035
            - central * 0.0040
            - horizontal * 0.0035
        ) * args.strength * frontness

        if abs(displacement) < 1e-6:
            continue
        q = p + normal * displacement
        key.data[index].co = inverse @ q
        moved += 1
        max_bulge = max(max_bulge, abs(displacement))

    if moved < 100:
        raise RuntimeError(
            f"Only {moved} abdominal vertices were selected; refusing a weak or misplaced sculpt. "
            "Check Ara's front orientation and abdomen height mask."
        )

    skin.data.update()
    skin["abdominal_definition_key"] = args.key_name
    skin["abdominal_definition_strength"] = args.strength
    print(
        f"Created {args.key_name}: strength={args.strength:.2f}, "
        f"moved_vertices={moved}, max_surface_offset={max_bulge:.4f}m"
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
    print("Exported abdominal-definition variant.")


if __name__ == "__main__":
    main()
