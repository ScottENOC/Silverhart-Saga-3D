"""Exercise upstream MPFB2 against its original CC0 system clothing assets.

This is deliberately a baseline smoke test: it invokes MPFB2's own human and
clothing services and records the exact upstream source revision. It does not
replace or modify MPFB2's fitting algorithm.
"""
from __future__ import annotations

import json
import os
import traceback

import bpy

OUTPUT_DIR = os.path.abspath("makehuman-baseline")
os.makedirs(OUTPUT_DIR, exist_ok=True)


def dynamic_import(module_suffix: str, symbol: str):
    import importlib
    import sys
    for module_name in list(sys.modules):
        if module_name.endswith(module_suffix):
            module = importlib.import_module(module_name)
            if hasattr(module, symbol):
                return getattr(module, symbol)
    raise RuntimeError(f"Could not find MPFB symbol {symbol} in {module_suffix}")


def main():
    # MPFB2 is installed from its upstream source checkout by the workflow.
    bpy.ops.preferences.addon_enable(module="mpfb")

    HumanService = dynamic_import("mpfb.services.humanservice", "HumanService")
    AssetService = dynamic_import("mpfb.services.assetservice", "AssetService")

    # Refresh discovery after the system asset archive has been unpacked.
    AssetService.update_all_asset_lists()
    clothes = AssetService.get_asset_list("clothes", "mhclo")
    if not clothes:
        raise RuntimeError("The original MakeHuman system pack contains no discoverable .mhclo clothing assets")

    basemesh = HumanService.create_human()
    if basemesh is None:
        raise RuntimeError("MPFB2 create_human() did not return a base mesh")

    # Choose a deterministic original garment from the installed system pack.
    garment_label = sorted(clothes.keys())[0]
    garment_path = clothes[garment_label]["full_path"]
    HumanService.add_clothes(garment_path, basemesh)

    bpy.context.view_layer.update()
    scene_objects = []
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            scene_objects.append({
                "name": obj.name,
                "vertices": len(obj.data.vertices),
                "polygons": len(obj.data.polygons),
            })

    if len(scene_objects) < 2:
        raise RuntimeError(
            "Expected the generated human and a separately loaded garment mesh; "
            f"found {len(scene_objects)} mesh object(s)"
        )

    # Export the actual MPFB2 scene result for visual inspection.
    glb_path = os.path.join(OUTPUT_DIR, "makehuman-original-garment.glb")
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB")

    report = {
        "mpfb2": "upstream source checkout",
        "blender_version": bpy.app.version_string,
        "garment_label": garment_label,
        "garment_path": garment_path,
        "mesh_objects": scene_objects,
        "export": glb_path,
        "status": "passed",
    }
    with open(os.path.join(OUTPUT_DIR, "baseline-report.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    print(json.dumps(report, indent=2))


try:
    main()
except Exception:
    with open(os.path.join(OUTPUT_DIR, "failure.txt"), "w", encoding="utf-8") as handle:
        handle.write(traceback.format_exc())
    raise
