"""Run controlled MPFB2 body-morph and native MHCLO garment-fit comparisons.

Each phenotype is generated from the same upstream MakeHuman basemesh and the
same original CC0 MHCLO outfit. MPFB2's HumanService loads and fits the outfit
against that phenotype. The report records mesh bounds, topology, shape keys,
and per-vertex garment displacement relative to the neutral build.
"""
from __future__ import annotations

import json
import math
import os
import traceback

import bpy

OUTPUT_DIR = os.path.abspath("makehuman-morph-fit")
os.makedirs(OUTPUT_DIR, exist_ok=True)


def choose_asset(entries, terms):
    values = sorted(
        ((str(label), str(item["full_path"])) for label, item in entries.items()),
        key=lambda item: (item[0].casefold(), item[1].casefold()),
    )
    for term in terms:
        match = next((item for item in values if term.casefold() in (item[0] + " " + item[1]).casefold()), None)
        if match:
            return match
    return values[0] if values else None


def bounds(obj):
    coords = [obj.matrix_world @ v.co for v in obj.data.vertices]
    return {
        "min": [min(v[i] for v in coords) for i in range(3)],
        "max": [max(v[i] for v in coords) for i in range(3)],
        "dimensions": [max(v[i] for v in coords) - min(v[i] for v in coords) for i in range(3)],
    }


def render_character(label):
    scene = bpy.context.scene
    camera_data = bpy.data.cameras.new(label + "_CameraData")
    camera = bpy.data.objects.new(label + "_Camera", camera_data)
    scene.collection.objects.link(camera)
    from mathutils import Vector
    camera.location = (0.0, -5.0, 1.0)
    camera.rotation_euler = (Vector((0.0, 0.0, 0.9)) - camera.location).to_track_quat("-Z", "Y").to_euler()
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

    lights = []
    for name, location, energy, size in (
        ("Key", (-3.0, -4.0, 4.5), 450, 4.0),
        ("Fill", (3.0, -2.0, 2.5), 220, 3.0),
    ):
        data = bpy.data.lights.new(label + "_" + name, type="AREA")
        obj = bpy.data.objects.new(label + "_" + name, data)
        scene.collection.objects.link(obj)
        obj.location = location
        data.energy = energy
        data.size = size
        lights.append(obj)

    scene.render.filepath = os.path.join(OUTPUT_DIR, label + ".png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    for light in lights:
        bpy.data.objects.remove(light, do_unlink=True)


def remove_scene_objects():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def main():
    bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mpfb")
    # Blender 4.2 installs MPFB2 as an extension package, so its import
    # namespace is bl_ext.user_default.mpfb rather than top-level "mpfb".
    # Resolve the already-loaded extension modules the same way as the
    # upstream base-human smoke test.
    def dynamic_import(module_suffix, symbol):
        import importlib
        import sys
        for module_name in list(sys.modules):
            if module_name.endswith(module_suffix):
                module = importlib.import_module(module_name)
                if hasattr(module, symbol):
                    return getattr(module, symbol)
        raise RuntimeError(f"Could not find MPFB symbol {symbol} in {module_suffix}")

    HumanService = dynamic_import("mpfb.services.humanservice", "HumanService")
    AssetService = dynamic_import("mpfb.services.assetservice", "AssetService")
    TargetService = dynamic_import("mpfb.services.targetservice", "TargetService")

    AssetService.update_all_asset_lists()
    skins = AssetService.get_asset_list("skins", "mhmat")
    clothes = AssetService.get_asset_list("clothes", "mhclo")
    skin = choose_asset(skins, ("young caucasian female", "young female", "caucasian female", "female"))
    outfit = choose_asset(clothes, ("female casualsuit01", "female casualsuit"))
    if not skin:
        raise RuntimeError("No original MakeHuman skin asset found")
    if not outfit:
        raise RuntimeError("No original MakeHuman female MHCLO outfit found")

    # Macro values are MPFB/MakeHuman's native 0..1 phenotype controls.
    # Keep sex, age, and race fixed; vary only weight and muscle so the
    # clothing-fit comparison isolates body-shape response.
    phenotypes = [
        {"id": "neutral", "weight": 0.50, "muscle": 0.50},
        {"id": "lean_muscular", "weight": 0.20, "muscle": 0.85},
        {"id": "heavier_less_muscular", "weight": 0.85, "muscle": 0.20},
    ]

    results = []
    garment_vertices = {}
    for phenotype in phenotypes:
        label = phenotype["id"]
        macro = TargetService.get_default_macro_info_dict()
        macro.update({
            "gender": 1.0,
            "age": 0.5,
            "muscle": phenotype["muscle"],
            "weight": phenotype["weight"],
            "proportions": 0.5,
            "height": 0.5,
            "cupsize": 0.5,
            "firmness": 0.5,
            "race": {"asian": 0.0, "caucasian": 1.0, "african": 0.0},
        })

        remove_scene_objects()
        human = HumanService.create_human(
            mask_helpers=True,
            detailed_helpers=True,
            extra_vertex_groups=True,
            feet_on_ground=True,
            scale=0.1,
            macro_detail_dict=macro,
        )
        if human is None:
            raise RuntimeError("MPFB2 failed to create human for " + label)
        HumanService.set_character_skin(skin[1], human, skin_type="MAKESKIN")

        garment = HumanService.add_mhclo_asset(
            outfit[1],
            human,
            asset_type="Clothes",
            subdiv_levels=0,
            material_type="MAKESKIN",
            set_up_rigging=False,
            interpolate_weights=False,
            import_subrig=False,
            import_weights=False,
        )
        if garment is None or garment.type != "MESH":
            raise RuntimeError("MPFB2 failed to fit MHCLO outfit for " + label)

        bpy.context.view_layer.update()
        shape_keys = human.data.shape_keys.key_blocks if human.data.shape_keys else []
        vertices = [tuple(float(c) for c in v.co) for v in garment.data.vertices]
        garment_vertices[label] = vertices
        result = {
            "id": label,
            "phenotype": macro,
            "skin_asset": skin[0],
            "outfit_asset": outfit[0],
            "body": {
                "vertices": len(human.data.vertices),
                "polygons": len(human.data.polygons),
                "bounds": bounds(human),
                "shape_key_count": len(shape_keys),
                "active_shape_keys": [
                    {"name": key.name, "value": float(key.value)}
                    for key in shape_keys if key.name != "Basis" and abs(key.value) > 0.0001
                ],
            },
            "garment": {
                "name": garment.name,
                "vertices": len(garment.data.vertices),
                "polygons": len(garment.data.polygons),
                "bounds": bounds(garment),
                "fitted_by": "MPFB2 HumanService.add_mhclo_asset / ClothesService MHCLO mapping",
            },
            "render": os.path.join(OUTPUT_DIR, label + ".png"),
            "glb": os.path.join(OUTPUT_DIR, label + ".glb"),
        }
        render_character(label)
        bpy.ops.export_scene.gltf(filepath=result["glb"], export_format="GLB")
        results.append(result)

    baseline = garment_vertices["neutral"]
    comparisons = {}
    for label, vertices in garment_vertices.items():
        if len(vertices) != len(baseline):
            raise RuntimeError("Garment topology changed between phenotypes")
        deltas = [
            math.sqrt(sum((vertices[i][axis] - baseline[i][axis]) ** 2 for axis in range(3)))
            for i in range(len(baseline))
        ]
        comparisons[label] = {
            "vertex_count": len(vertices),
            "mean_vertex_displacement_from_neutral": sum(deltas) / max(1, len(deltas)),
            "max_vertex_displacement_from_neutral": max(deltas, default=0.0),
            "vertices_moved_over_0_1mm": sum(value > 0.001 for value in deltas),
        }

    for label in ("lean_muscular", "heavier_less_muscular"):
        if comparisons[label]["mean_vertex_displacement_from_neutral"] <= 0.00001:
            raise RuntimeError("MHCLO garment did not measurably respond to " + label + " body morph")

    report = {
        "status": "passed",
        "blender_version": bpy.app.version_string,
        "mpfb2_method": "HumanService.create_human(macro_detail_dict=...) + HumanService.add_mhclo_asset(...)",
        "fixed_variables": ["gender=female", "age=0.5", "race=caucasian", "height=0.5", "proportions=0.5"],
        "varied_variables": ["weight", "muscle"],
        "phenotypes": results,
        "garment_displacement_comparison": comparisons,
        "interpretation": "A measurable garment vertex displacement confirms that the same original MHCLO mapping is re-fitted to each changed body. This is not a collision, cloth-simulation, or visual-quality certification.",
    }
    with open(os.path.join(OUTPUT_DIR, "morph-fit-report.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    print(json.dumps(report, indent=2))


try:
    main()
except Exception:
    with open(os.path.join(OUTPUT_DIR, "failure.txt"), "w", encoding="utf-8") as handle:
        handle.write(traceback.format_exc())
    raise
