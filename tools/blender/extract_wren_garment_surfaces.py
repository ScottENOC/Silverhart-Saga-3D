"""Split Ara bikini material surfaces into skinned garment objects for cloth fitting.

The accepted Wren GLB remains the source. This pass separates only material
surfaces already present on the integrated skinned mesh; it does not alter
their vertices, move the body, hide piercings, or claim a cloth simulation.
"""
import argparse
import json
import os
import re
import sys

import bpy
from mathutils import Vector


GARMENT_RE = re.compile(r"(bikini|bra|brief|underwear|panty)", re.IGNORECASE)


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-blend", required=True)
    parser.add_argument("--output-blend", required=True)
    parser.add_argument("--report", required=True)
    return parser.parse_args(raw)


def material_names(obj):
    return [
        slot.material.name
        for slot in obj.material_slots
        if slot.material is not None
    ]


def used_material_names(obj):
    used = sorted({polygon.material_index for polygon in obj.data.polygons})
    return [
        obj.material_slots[index].material.name
        for index in used
        if index < len(obj.material_slots) and obj.material_slots[index].material is not None
    ]


def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return {
        "min": [min(point[i] for point in points) for i in range(3)],
        "max": [max(point[i] for point in points) for i in range(3)],
    }


def main():
    args = arguments()
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(args.input_blend))

    candidates = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH"
        and any(name.lower().startswith("skin") for name in used_material_names(obj))
        and any(GARMENT_RE.search(name) for name in used_material_names(obj))
    ]
    if len(candidates) != 1:
        raise RuntimeError(
            "Expected exactly one integrated Wren mesh containing skin and "
            f"bikini material surfaces; found {[obj.name for obj in candidates]}"
        )
    source = candidates[0]
    source_shape_keys = (
        len(source.data.shape_keys.key_blocks)
        if source.data.shape_keys else 0
    )
    armatures = [
        modifier.object.name
        for modifier in source.modifiers
        if modifier.type == "ARMATURE" and modifier.object is not None
    ]
    if not armatures:
        raise RuntimeError("Integrated Wren mesh has no armature modifier")

    bpy.ops.object.select_all(action="DESELECT")
    source.select_set(True)
    bpy.context.view_layer.objects.active = source
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")

    garment_objects = []
    for obj in [item for item in bpy.context.scene.objects if item.type == "MESH"]:
        names = used_material_names(obj)
        selected = [name for name in names if GARMENT_RE.search(name)]
        if not selected:
            continue
        if len(selected) != len(names):
            raise RuntimeError(
                f"Material separation left mixed garment/body object: {obj.name}: {names}"
            )
        if not any(
            modifier.type == "ARMATURE" and modifier.object is not None
            for modifier in obj.modifiers
        ):
            raise RuntimeError(f"Separated garment lost its armature modifier: {obj.name}")
        shape_key_count = (
            len(obj.data.shape_keys.key_blocks)
            if obj.data.shape_keys else 0
        )
        if source_shape_keys and shape_key_count != source_shape_keys:
            raise RuntimeError(
                f"{obj.name} lost shape keys: {shape_key_count} != {source_shape_keys}"
            )
        obj.name = "Garment_" + re.sub(r"[^A-Za-z0-9_]+", "_", selected[0]).strip("_")
        obj["cloth_role"] = "garment_surface"
        obj["cloth_source_materials"] = selected
        garment_objects.append({
            "object": obj.name,
            "materials": selected,
            "vertices": len(obj.data.vertices),
            "faces": len(obj.data.polygons),
            "shape_key_count": shape_key_count,
            "vertex_group_count": len(obj.vertex_groups),
            "armature_modifiers": [
                modifier.object.name
                for modifier in obj.modifiers
                if modifier.type == "ARMATURE" and modifier.object is not None
            ],
            "bounds_world": world_bounds(obj),
        })

    names = [name for row in garment_objects for name in row["materials"]]
    has_top = any(re.search(r"top", name, re.IGNORECASE) for name in names)
    has_bottom = any(re.search(r"bottom", name, re.IGNORECASE) for name in names)
    if not has_top or not has_bottom:
        raise RuntimeError(f"Expected bikini top and bottom surfaces; found {names}")
    if not garment_objects:
        raise RuntimeError("No garment surfaces were extracted")

    report = {
        "stage": "skinned_garment_surface_extraction",
        "source_object": source.name,
        "source_shape_key_count": source_shape_keys,
        "source_armature_modifiers": armatures,
        "garment_object_count": len(garment_objects),
        "garments": garment_objects,
        "body_geometry_deformed": False,
        "piercings_hidden_or_moved": False,
        "cloth_simulation_run": False,
        "notes": [
            "Garment polygons were separated by their existing material assignments.",
            "Garment objects retain their source armature modifier, vertex groups, and shape keys.",
            "This extraction is preparation for the subsequent contact-first cloth solve, not a fitted simulation.",
        ],
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.output_blend)), exist_ok=True)
    os.makedirs(os.path.dirname(os.path.abspath(args.report)), exist_ok=True)
    with open(args.report, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.output_blend))
    print("WREN_GARMENT_SURFACES_EXTRACTED " + json.dumps({
        "garment_objects": len(garment_objects),
        "materials": names,
        "shape_keys": source_shape_keys,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
