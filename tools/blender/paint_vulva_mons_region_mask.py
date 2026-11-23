#!/usr/bin/env python3
"""Paint the combined Ara vulva + mons pubis region into TEXCOORD_1.y.

This is a review-pipeline adapter for an already anatomy-integrated Wren GLB.
It reuses the exact surface-coordinate helpers and anatomical parameters from
add_female_anatomy_surface.py. TEXCOORD_1.x (CorrespondenceID) is preserved.
"""
import argparse
import json
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from add_female_anatomy_surface import (
    build_vulva_mons_region_weights,
    material_name,
    mesh_world_bounds,
    pelvis_landmark_from_leg_roots,
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def find_skin_and_rig():
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    skin = max(
        (obj for obj in meshes if "skin" in material_name(obj)),
        key=lambda obj: len(obj.data.polygons),
        default=None,
    )
    if skin is None or armature is None:
        raise RuntimeError("Wren GLB is missing its skin mesh or armature")
    return meshes, skin, armature


def export_scene(path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if armature:
        bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(path),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_morph=True,
        export_animations=True,
        export_apply=False,
    )


def read_mask_from_uv2(mesh):
    # Resolve the semantic layer by name, not Blender collection position.
    layer = mesh.uv_layers.get("CorrespondenceID")
    if layer is None:
        names = [item.name for item in mesh.uv_layers]
        raise RuntimeError("CorrespondenceID UV layer missing; available layers: " + repr(names))
    if len(mesh.uv_layers) < 2:
        raise RuntimeError(
            f"Expected TEXCOORD_1/CorrespondenceID; found {len(mesh.uv_layers)} UV channels"
        )
    values = [None] * len(mesh.vertices)
    for loop in mesh.loops:
        vertex_index = loop.vertex_index
        uv = layer.data[loop.index].uv
        pair = (round(float(uv.x), 7), round(float(uv.y), 6))
        if values[vertex_index] is not None and values[vertex_index] != pair:
            raise RuntimeError(
                f"Vertex {vertex_index} has inconsistent TEXCOORD_1 identity/mask values"
            )
        values[vertex_index] = pair
    if any(value is None for value in values):
        raise RuntimeError("TEXCOORD_1 does not identify every skin vertex")
    return values


def main():
    args = parse_args()
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes, skin, armature = find_skin_and_rig()
    if len(skin.data.uv_layers) < 2:
        raise RuntimeError("Ara anatomy GLB has no TEXCOORD_1 CorrespondenceID channel")

    bounds = [mesh_world_bounds(obj) for obj in meshes]
    minimum = Vector(tuple(min(bound[0][axis] for bound in bounds) for axis in range(3)))
    maximum = Vector(tuple(max(bound[1][axis] for bound in bounds) for axis in range(3)))
    height = maximum.z - minimum.z
    if height <= 0:
        raise RuntimeError(f"Invalid Wren character height: {height}")
    hipline_z = pelvis_landmark_from_leg_roots(armature, height)
    weights = build_vulva_mons_region_weights(skin, hipline_z, height)
    if len(weights) != len(skin.data.vertices):
        raise RuntimeError("Ara surface-coordinate mask does not match the Wren skin vertex count")

    layer = skin.data.uv_layers.get("CorrespondenceID")
    if layer is None:
        raise RuntimeError("Wren GLB has no named CorrespondenceID UV layer")
    # The glTF exporter emits the active-render UV map as TEXCOORD_0.
    # Explicitly make the ordinary texture UV first and CorrespondenceID second.
    base_layers = [item for item in skin.data.uv_layers if item.name != "CorrespondenceID"]
    if not base_layers:
        raise RuntimeError("Cannot export TEXCOORD_1 without an ordinary base UV map")
    base_layers[0].active_render = True
    layer.active_render = False
    export_order = [item.name for item in skin.data.uv_layers]
    if export_order.index("CorrespondenceID") != 1:
        raise RuntimeError("CorrespondenceID must be second in UV layer order: " + repr(export_order))
    for loop in skin.data.loops:
        uv = layer.data[loop.index].uv.copy()
        uv.y = float(weights[loop.vertex_index])
        layer.data[loop.index].uv = uv
    skin.data.update()
    skin["anatomy_region_mask"] = "vulva_external_including_mons_pubis"
    skin["anatomy_region_mask_channel"] = "TEXCOORD_1.y"

    source_values = read_mask_from_uv2(skin.data)

    def canonical_by_correspondence(values):
        canonical = {}
        for correspondence_id, weight in values:
            previous = canonical.get(correspondence_id)
            if previous is not None and abs(previous - weight) > 1e-5:
                raise RuntimeError(
                    f"CorrespondenceID {correspondence_id} carries inconsistent region weights"
                )
            canonical[correspondence_id] = weight
        return canonical

    # glTF may split vertices at material/UV seams. TEXCOORD_1.x is the
    # stable original vertex ID, so compare canonical IDs rather than raw
    # imported vertex counts.
    source_by_id = canonical_by_correspondence(source_values)
    weighted_vertices = sum(weight >= 0.15 for weight in source_by_id.values())
    nonzero_vertices = sum(weight > 0.0 for weight in source_by_id.values())
    if weighted_vertices == 0:
        raise RuntimeError("Combined vulva/mons pubis mask contains no weighted vertices")

    export_scene(args.output)

    # Re-import the GLB to verify that TEXCOORD_1.y survived export and that
    # the existing correspondence IDs in TEXCOORD_1.x were not changed.
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.output))
    _meshes, exported_skin, _armature = find_skin_and_rig()
    exported_values = read_mask_from_uv2(exported_skin.data)
    exported_by_id = canonical_by_correspondence(exported_values)
    if set(exported_by_id) != set(source_by_id):
        missing = len(set(source_by_id) - set(exported_by_id))
        extra = len(set(exported_by_id) - set(source_by_id))
        raise RuntimeError(
            "Export/re-import changed CorrespondenceID coverage: "
            f"{missing} IDs missing, {extra} unexpected IDs"
        )
    for correspondence_id, before_weight in source_by_id.items():
        after_weight = exported_by_id[correspondence_id]
        if abs(before_weight - after_weight) > 1e-5:
            raise RuntimeError(
                f"Export/re-import changed mask weight for CorrespondenceID {correspondence_id}"
            )
    exported_weighted = sum(weight >= 0.15 for weight in exported_by_id.values())

    report = {
        "status": "REVIEW_MASK_PAINTED_NOT_PRODUCTION_APPROVED",
        "region_id": "vulva_external",
        "region_label": "External vulva including mons pubis",
        "source_method": "Ara add_female_anatomy_surface.py surface-following midline coordinates",
        "mask_channel": "TEXCOORD_1.y (Godot Mesh ARRAY_TEX_UV2.y)",
        "correspondence_channel": "TEXCOORD_1.x preserved unchanged",
        "blender_uv_layer_order": [item.name for item in exported_skin.data.uv_layers],
        "correspondence_uv_layer_index_after_reimport": next(
            i for i, item in enumerate(exported_skin.data.uv_layers)
            if item.name == "CorrespondenceID"
        ),
        "skin_mesh": exported_skin.name,
        "source_correspondence_vertex_count": len(source_by_id),
        "exported_mesh_vertex_count": len(exported_values),
        "weighted_vertices_at_0_15": exported_weighted,
        "nonzero_vertices": sum(weight > 0.0 for weight in exported_by_id.values()),
        "maximum_weight": max(value[1] for value in exported_values),
        "height_metres": height,
        "hipline_z": hipline_z,
        "output": os.path.abspath(args.output),
        "output_bytes": os.path.getsize(args.output),
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.report)), exist_ok=True)
    with open(args.report, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
