"""Add named reusable accessory/tattoo sockets to a rigged adult GLB.

Assumes Blender Z-up and character facing -Y. Socket placement is estimated from
mesh bounds and must be reviewed against the actual character and rig.
"""
import argparse
import os
import sys

import bpy
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(raw)


def main():
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("Input GLB contains no meshes")
    points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    size = hi - lo
    centre = (lo + hi) * 0.5
    front = centre.y - size.y * 0.20
    sockets = {
        "SOCKET_Necklace": (centre.x, front, lo.z + size.z * 0.805),
        "SOCKET_Earring_L": (centre.x - size.x * 0.185, centre.y, lo.z + size.z * 0.875),
        "SOCKET_Earring_R": (centre.x + size.x * 0.185, centre.y, lo.z + size.z * 0.875),
        "SOCKET_NoseRing": (centre.x, front - size.y * 0.025, lo.z + size.z * 0.895),
        "SOCKET_Forearm_L": (centre.x - size.x * 0.32, centre.y, lo.z + size.z * 0.48),
        "SOCKET_Forearm_R": (centre.x + size.x * 0.32, centre.y, lo.z + size.z * 0.48),
        "SOCKET_Tattoo_UpperArm_L": (centre.x - size.x * 0.22, centre.y, lo.z + size.z * 0.68),
        "SOCKET_Tattoo_UpperArm_R": (centre.x + size.x * 0.22, centre.y, lo.z + size.z * 0.68)
    }
    for name, location in sockets.items():
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_type = "SPHERE"
        empty.empty_display_size = max(size.x * 0.012, 0.008)
        empty.location = location
        empty["socket_type"] = name.replace("SOCKET_", "").split("_")[0].lower()
        bpy.context.collection.objects.link(empty)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False)
    print("Exported named sockets. Align them to the rig before production use.")


if __name__ == "__main__":
    main()
