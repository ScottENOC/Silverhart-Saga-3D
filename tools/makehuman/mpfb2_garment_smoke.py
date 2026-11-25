"""Build and render a complete MPFB2 base-human diagnostic.

This deliberately validates the human/head assembly before garment fitting.
It uses MPFB2's own MHCLO loader for facial assets and CC0 system assets.
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


def choose_asset(entries: dict, preferred_terms: tuple[str, ...] = ()) -> tuple[str, str] | None:
    """Choose a deterministic, named asset; report the full inventory for review."""
    values = sorted(
        ((str(label), str(item["full_path"])) for label, item in entries.items()),
        key=lambda entry: (entry[0].casefold(), entry[1].casefold()),
    )
    if not values:
        return None
    for term in preferred_terms:
        match = next((entry for entry in values
                      if term.casefold() in (entry[0] + " " + entry[1]).casefold()), None)
        if match:
            return match
    return values[0]


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


def point_camera(camera, location, target):
    from mathutils import Vector
    camera.location = location
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_view(name: str, location: tuple[float, float, float], target: tuple[float, float, float]):
    scene = bpy.context.scene
    camera_data = bpy.data.cameras.new(name + "Camera")
    camera = bpy.data.objects.new(name + "Camera", camera_data)
    scene.collection.objects.link(camera)
    point_camera(camera, location, target)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.0
    scene.camera = camera

    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.12, 0.12, 0.12)

    # Neutral studio lighting, with no texture or colour grading intended to
    # conceal geometry problems.
    for obj in list(bpy.data.objects):
        if obj.type == "LIGHT":
            bpy.data.objects.remove(obj, do_unlink=True)
    light_data = bpy.data.lights.new(name + "Key", type="AREA")
    light = bpy.data.objects.new(name + "Key", light_data)
    scene.collection.objects.link(light)
    light.location = ( -3.0, -4.0, 4.5)
    light.data.energy = 450
    light.data.shape = "DISK"
    light.data.size = 4.0
    fill_data = bpy.data.lights.new(name + "Fill", type="AREA")
    fill = bpy.data.objects.new(name + "Fill", fill_data)
    scene.collection.objects.link(fill)
    fill.location = (3.0, -2.0, 2.5)
    fill.data.energy = 220
    fill.data.size = 3.0

    scene.render.filepath = os.path.join(OUTPUT_DIR, name + ".png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.data.objects.remove(light, do_unlink=True)
    bpy.data.objects.remove(fill, do_unlink=True)


def main():
    bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mpfb")

    HumanService = dynamic_import("mpfb.services.humanservice", "HumanService")
    AssetService = dynamic_import("mpfb.services.assetservice", "AssetService")

    AssetService.update_all_asset_lists()
    categories = {
        "skins": ("skins", "mhmat"),
        "eyes": ("eyes", "mhclo"),
        "eyebrows": ("eyebrows", "mhclo"),
        "eyelashes": ("eyelashes", "mhclo"),
        "hair": ("hair", "mhclo"),
        "teeth": ("teeth", "mhclo"),
        "tongue": ("tongue", "mhclo"),
    }
    inventories = {}
    for key, (subdir, extension) in categories.items():
        inventories[key] = AssetService.get_asset_list(subdir, extension)

    basemesh = HumanService.create_human()
    if basemesh is None:
        raise RuntimeError("MPFB2 create_human() did not return a base mesh")

    # A deliberate female skin asset is selected when available; the report
    # records the exact choice rather than silently using alphabetical order.
    skin_choice = choose_asset(
        inventories["skins"],
        ("young caucasian female", "young female", "caucasian female", "female"),
    )
    if skin_choice is None:
        raise RuntimeError("No original MakeHuman skin material was discovered")
    skin_label, skin_path = skin_choice
    HumanService.set_character_skin(skin_path, basemesh, skin_type="MAKESKIN")

    # MPFB2 defines separate system-asset libraries for the face components.
    # Loading each via its native MHCLO path lets the upstream fitter place it
    # against this exact base mesh; no guessed offsets or manual eye placement.
    component_preferences = {
        "eyes": ("eyeball", "eyes"),
        "eyebrows": ("eyebrow",),
        "eyelashes": ("eyelash",),
        "hair": ("short", "bob", "ponytail", "hair"),
        "teeth": ("teeth",),
        "tongue": ("tongue",),
    }
    loaded_components = []
    for category, terms in component_preferences.items():
        choice = choose_asset(inventories[category], terms)
        if choice is None:
            continue
        label, asset_path = choice
        obj = HumanService.add_mhclo_asset(
            asset_path,
            basemesh,
            asset_type=category.capitalize(),
            material_type="MAKESKIN",
            set_up_rigging=False,
            interpolate_weights=False,
            import_subrig=False,
            import_weights=False,
        )
        if obj is None or obj.type != "MESH":
            raise RuntimeError(f"MPFB2 failed to load {category} asset {label}: {asset_path}")
        loaded_components.append({
            "category": category,
            "label": label,
            "path": asset_path,
            "object": obj.name,
        })

    # Remove Blender's startup cube and any unrelated default meshes.
    startup_objects_removed = []
    keep = {basemesh.name} | {item["object"] for item in loaded_components}
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.name not in keep:
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

    if not material_diagnostics(basemesh):
        raise RuntimeError("MPFB2 skin setup completed without assigning a material to the human")
    if not any(item["category"] == "eyes" for item in loaded_components):
        raise RuntimeError("No eye asset was loaded; cannot validate complete head assembly")

    # Front and side renders are the primary diagnostic deliverables.
    render_view("base-human-front", (0.0, -5.0, 1.0), (0.0, 0.0, 0.9))
    render_view("base-human-side", (5.0, 0.0, 1.0), (0.0, 0.0, 0.9))

    glb_path = os.path.join(OUTPUT_DIR, "makehuman-base-human.glb")
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB")

    report = {
        "mpfb2": "upstream source checkout",
        "blender_version": bpy.app.version_string,
        "skin_asset_label": skin_label,
        "skin_asset_path": skin_path,
        "asset_inventory": {
            key: sorted(str(label) for label in values.keys())
            for key, values in inventories.items()
        },
        "asset_counts": {key: len(values) for key, values in inventories.items()},
        "loaded_face_components": loaded_components,
        "removed_startup_meshes": startup_objects_removed,
        "mesh_objects": mesh_objects,
        "renders": [
            os.path.join(OUTPUT_DIR, "base-human-front.png"),
            os.path.join(OUTPUT_DIR, "base-human-side.png"),
        ],
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
