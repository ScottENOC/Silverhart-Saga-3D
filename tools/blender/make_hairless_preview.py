"""Create a temporary hairless inspection GLB without changing the deployed character.

Ara combines the body and hair cards into one mesh with multiple material slots.
For this inspection export, remove only faces assigned to hair materials. The
source GLB and the normal deployment GLB remain untouched.
"""
import argparse
import os
import re
import sys
import bpy


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(raw)


def is_hair_material(name):
    value = name.lower()
    if any(token in value for token in ("eyebrow", "eyelash", "lash", "beard", "mustache")):
        return False
    return bool(re.search(r"hair", value))


def main():
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    removed_faces = 0
    matched_materials = []
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        hair_slots = {
            index for index, slot in enumerate(obj.material_slots)
            if slot.material and is_hair_material(slot.material.name)
        }
        print(
            "HAIRLESS_MATERIAL_SCAN",
            obj.name,
            [(i, slot.material.name if slot.material else None)
             for i, slot in enumerate(obj.material_slots)],
        )
        if not hair_slots:
            continue

        for index in sorted(hair_slots):
            material = obj.material_slots[index].material
            matched_materials.append(material.name if material else str(index))

        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.context.tool_settings.mesh_select_mode = (False, False, True)
        for polygon in obj.data.polygons:
            polygon.select = polygon.material_index in hair_slots
        face_count = sum(1 for polygon in obj.data.polygons if polygon.select)
        if face_count:
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.delete(type="ONLY_FACE")
            bpy.ops.object.mode_set(mode="OBJECT")
            removed_faces += face_count

    print(
        f"HAIRLESS_PREVIEW_REMOVED_FACES {removed_faces}; "
        f"materials={matched_materials}"
    )
    if removed_faces == 0:
        raise RuntimeError(
            "No hair-material faces were found. Refusing to export an unchanged "
            "or misleading inspection model."
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
    if not os.path.isfile(args.output) or os.path.getsize(args.output) < 1000000:
        raise RuntimeError(
            "Hairless inspection GLB is missing or unexpectedly small; "
            "the body mesh may have been removed."
        )
    print("EXPORTED_HAIRLESS_EAR_INSPECTION_GLB " + args.output)


if __name__ == "__main__":
    main()
