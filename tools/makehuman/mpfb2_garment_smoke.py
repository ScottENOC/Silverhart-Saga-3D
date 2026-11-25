"""Run a visibly useful MakeHuman MPFB2 garment-fitting baseline.

Uses MPFB2's upstream MHCLO loader/fitter and original CC0 system assets.
This is an integration diagnostic, not a replacement fitting implementation.
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


def choose_garments(clothes: dict) -> list[tuple[str, str]]:
    """Prefer a recognisable upper and lower garment, never hats/accessories."""
    excluded = ("hat", "fedora", "cap", "helmet", "shoe", "boot", "sandal",
                "glove", "sock", "scarf", "necklace", "earring", "bracelet",
                "bag", "backpack", "hair", "eyebrow", "eyelash")
    entries = sorted(
        ((str(label), str(item["full_path"])) for label, item in clothes.items()),
        key=lambda entry: (entry[0].casefold(), entry[1].casefold()),
    )

    def eligible(entry):
        haystack = (entry[0] + " " + entry[1]).casefold()
        return not any(word in haystack for word in excluded)

    usable = [entry for entry in entries if eligible(entry)]
    if not usable:
        raise RuntimeError(
            "No wearable garments remained after excluding accessories. "
            "Discovered assets: " + json.dumps([label for label, _ in entries])
        )

    upper_words = ("shirt", "top", "tshirt", "t-shirt", "blouse", "jacket", "hoodie", "sweater", "vest", "tunic")
    lower_words = ("trouser", "pants", "jeans", "shorts", "skirt", "leggings")
    upper = next((entry for entry in usable
                  if any(word in (entry[0] + " " + entry[1]).casefold() for word in upper_words)), None)
    lower = next((entry for entry in usable
                  if any(word in (entry[0] + " " + entry[1]).casefold() for word in lower_words)), None)

    selected = []
    if upper:
        selected.append(upper)
    if lower and lower not in selected:
        selected.append(lower)

    # If the system pack uses less obvious naming, still demonstrate a real
    # wearable mesh rather than silently choosing a hat or reporting success
    # with no clothing.
    if not selected:
        selected = [usable[0]]
    return selected


def material_diagnostics(obj):
    result = []
    for slot in obj.material_slots:
        material = slot.material
        if not material:
            continue
        images = []
        if material.node_tree:
            for node in material.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image:
                    images.append({
                        "name": node.image.name,
                        "filepath": node.image.filepath,
                        "packed": bool(node.image.packed_file),
                    })
        result.append({
            "name": material.name,
            "use_nodes": material.use_nodes,
            "image_textures": images,
        })
    return result


def main():
    bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mpfb")

    HumanService = dynamic_import("mpfb.services.humanservice", "HumanService")
    AssetService = dynamic_import("mpfb.services.assetservice", "AssetService")

    AssetService.update_all_asset_lists()
    clothes = AssetService.get_asset_list("clothes", "mhclo")
    skins = AssetService.get_asset_list("skins", "mhmat")
    if not clothes:
        raise RuntimeError("No original MakeHuman .mhclo clothing assets were discovered")
    if not skins:
        raise RuntimeError("No original MakeHuman .mhmat skin assets were discovered")

    basemesh = HumanService.create_human()
    if basemesh is None:
        raise RuntimeError("MPFB2 create_human() did not return a base mesh")

    # Use MPFB2's own skin setup rather than a generic Blender colour.
    skin_entries = sorted(
        ((str(label), str(item["full_path"])) for label, item in skins.items()),
        key=lambda entry: (0 if os.path.basename(entry[1]).casefold() == "brown.mhmat" else 1,
                           entry[0].casefold()),
    )
    skin_label, skin_path = skin_entries[0]
    HumanService.set_character_skin(skin_path, basemesh, skin_type="MAKESKIN")

    selected_garments = choose_garments(clothes)
    loaded_garments = []
    for garment_label, garment_path in selected_garments:
        garment = HumanService.add_mhclo_asset(
            garment_path,
            basemesh,
            asset_type="Clothes",
            material_type="MAKESKIN",
            set_up_rigging=False,
            interpolate_weights=False,
            import_subrig=False,
            import_weights=False,
        )
        if garment is None or garment.type != "MESH":
            raise RuntimeError(f"MPFB2 failed to create garment mesh for {garment_label}: {garment_path}")
        loaded_garments.append({
            "label": garment_label,
            "path": garment_path,
            "object": garment,
        })

    # Remove Blender's startup cube; it is not part of the MakeHuman character.
    startup_objects_removed = []
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj != basemesh and obj not in [g["object"] for g in loaded_garments]:
            startup_objects_removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.context.view_layer.update()

    mesh_objects = []
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            mesh_objects.append({
                "name": obj.name,
                "vertices": len(obj.data.vertices),
                "polygons": len(obj.data.polygons),
                "materials": material_diagnostics(obj),
            })

    skin_materials = material_diagnostics(basemesh)
    if not skin_materials:
        raise RuntimeError("MPFB2 skin setup completed without assigning a material to the human")
    if len(loaded_garments) < 1:
        raise RuntimeError("No wearable garment meshes were loaded")

    glb_path = os.path.join(OUTPUT_DIR, "makehuman-original-garments.glb")
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB")

    report = {
        "mpfb2": "upstream source checkout",
        "blender_version": bpy.app.version_string,
        "skin_asset_label": skin_label,
        "skin_asset_path": skin_path,
        "skin_materials": skin_materials,
        "garments": [
            {"label": garment["label"], "path": garment["path"], "object": garment["object"].name}
            for garment in loaded_garments
        ],
        "discovered_garment_count": len(clothes),
        "discovered_garment_labels": sorted(str(label) for label in clothes.keys()),
        "removed_startup_meshes": startup_objects_removed,
        "mesh_objects": mesh_objects,
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
