"""Create a temporary hairless inspection GLB without changing the deployed character.

The source GLB is retained. This output is solely for inspecting the elf ears.
"""
import argparse
import os
import sys
import bpy


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

    removed = []
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        names = [obj.name.lower()]
        names.extend(
            slot.material.name.lower()
            for slot in obj.material_slots if slot.material
        )
        if any("hair" in name for name in names):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)

    print("HAIRLESS_PREVIEW_REMOVED " + repr(removed))
    if not removed:
        raise RuntimeError(
            "No separate hair mesh/material was found. Refusing to produce "
            "a misleading bald preview; inspect the Ara GLB mesh/material layout."
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
    if not os.path.isfile(args.output) or os.path.getsize(args.output) < 100000:
        raise RuntimeError("Hairless inspection GLB is missing or unexpectedly small")
    print("EXPORTED_HAIRLESS_EAR_INSPECTION_GLb " + args.output)


if __name__ == "__main__":
    main()
