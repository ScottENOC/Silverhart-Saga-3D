"""Cut a narrow high side slit into the Ara pencil-skirt layer of the backless dress.

The cut is made only in the Pencil skirt material, on the character's right side.
The rest of the skirt, the dress bodice and the underlying skin are untouched.
"""
import argparse
import os
import sys

import bpy
import bmesh
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(raw)


def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return lo, hi


def main():
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    skin = next((o for o in meshes if any(s.material and "skin" == s.material.name.lower()
                                          for s in o.material_slots)), None)
    if not meshes or armature is None or skin is None:
        raise RuntimeError("Expected skinned Ara model, armature and Skin material")

    skin_lo, skin_hi = world_bounds(skin)
    width = skin_hi.x - skin_lo.x
    height = skin_hi.z - skin_lo.z
    body_centre_x = (skin_lo.x + skin_hi.x) * 0.5
    hips = next((b for b in armature.data.bones
                 if b.name.lower() in ("hips", "hip", "pelvis")), None)
    if hips is None:
        raise RuntimeError("Ara rig has no Hips/Pelvis bone")
    pelvis_z = (armature.matrix_world @ ((hips.head_local + hips.tail_local) * 0.5)).z

    candidates = []
    for obj in meshes:
        slot_index = next((i for i, slot in enumerate(obj.material_slots)
                           if slot.material and slot.material.name.lower().startswith("pencil skirt")), None)
        if slot_index is None:
            continue
        print(f"Found skirt material on {obj.name}; bounds={world_bounds(obj)}", flush=True)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        remove = []
        for face in bm.faces:
            if face.material_index != slot_index:
                continue
            centre = obj.matrix_world @ face.calc_center_median()
            # A slim vertical cut on the character's right side, beginning high
            # on the thigh and continuing to the existing skirt hem.
            if (centre.x > body_centre_x + width * 0.12
                    and pelvis_z - height * 0.28 < centre.z < pelvis_z - 0.025):
                remove.append(face)
        candidates.append((obj, bm, remove))

    total = sum(len(item[2]) for item in candidates)
    print(f"Side-slit candidate faces: {total}; body centre X={body_centre_x:.4f}, width={width:.4f}, pelvis Z={pelvis_z:.4f}", flush=True)
    if total < 4:
        for _obj, bm, _faces in candidates:
            bm.free()
        raise RuntimeError(f"Could not find enough Pencil skirt faces for side slit ({total})")

    for obj, bm, faces in candidates:
        if faces:
            bmesh.ops.delete(bm, geom=faces, context="FACES")
            bm.to_mesh(obj.data)
            obj.data.update()
            print(f"Cut {len(faces)} skirt faces from {obj.name}")
        bm.free()

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False, export_animations=True)
    print(f"Exported backless dress with side slit ({total} faces removed)")


if __name__ == "__main__":
    main()
