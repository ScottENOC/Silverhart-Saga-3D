#!/usr/bin/env python3
"""Assemble a configured Ara character and export one standalone GLB."""
import json
import sys
from pathlib import Path
import bpy

def arguments():
    values = sys.argv[sys.argv.index("--") + 1:]
    if len(values) != 3:
        raise SystemExit("usage: blender --background --python export_character_glb.py -- PROFILE OUTPUT_GLB ROOT")
    return Path(values[0]), Path(values[1]), Path(values[2])

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def import_glb(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [obj for obj in bpy.context.scene.objects if obj not in before]

def tint_material(material, hex_colour):
    """Tint without discarding an existing base-colour texture."""
    colour = hex_colour.lstrip("#")
    rgba = tuple(int(colour[i:i + 2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)
    material.diffuse_color = rgba
    if not material.use_nodes or not material.node_tree:
        return
    nodes = material.node_tree.nodes
    bsdf = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return
    base = bsdf.inputs.get("Base Color")
    if base is None:
        return
    links = list(base.links)
    if not links:
        base.default_value = rgba
        return
    source_socket = links[0].from_socket
    for link in links:
        material.node_tree.links.remove(link)
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.name = "Character Tint"
    multiply.label = "Character Tint"
    multiply.blend_type = "MULTIPLY"
    multiply.inputs["Fac"].default_value = 1.0
    multiply.inputs["Color2"].default_value = rgba
    material.node_tree.links.new(source_socket, multiply.inputs["Color1"])
    material.node_tree.links.new(multiply.outputs["Color"], base)

def main():
    profile_path, output_path, root = arguments()
    profile = json.loads(profile_path.read_text(encoding="utf-8"))
    body_path = root / profile["model"]
    if not body_path.is_file():
        raise FileNotFoundError(body_path)
    clear_scene()
    imported = import_glb(body_path)
    hair_path_value = profile.get("hair_asset", "")
    if hair_path_value:
        hair_path = root / hair_path_value
        if not hair_path.is_file():
            raise FileNotFoundError(hair_path)
        imported.extend(import_glb(hair_path))

    cleared_actions = []
    if profile.get("reset_armatures_to_rest", True):
        for obj in imported:
            if obj.type == "ARMATURE" and obj.animation_data:
                action = obj.animation_data.action
                cleared_actions.append({"armature": obj.name, "action": action.name if action else None})
                obj.animation_data_clear()

    requested_keys = profile.get("shape_keys", {})
    key_results = []
    material_results = []
    for obj in imported:
        if obj.type != "MESH":
            continue
        shape_keys = obj.data.shape_keys
        if shape_keys:
            for key_name, value in requested_keys.items():
                block = shape_keys.key_blocks.get(key_name)
                if block is not None:
                    block.value = float(value)
                    key_results.append({
                        "mesh": obj.name, "key": key_name, "value": float(block.value),
                        "slider_min": float(block.slider_min), "slider_max": float(block.slider_max)
                    })
        for slot in obj.material_slots:
            material = slot.material
            if material is None:
                continue
            for token, colour in profile.get("material_tints", {}).items():
                if token.casefold() in material.name.casefold():
                    tint_material(material, colour)
                    material_results.append({
                        "mesh": obj.name, "material": material.name,
                        "tint_token": token, "colour": colour
                    })

    meshes = [obj for obj in imported if obj.type == "MESH"]
    armatures = [obj for obj in imported if obj.type == "ARMATURE"]
    if not meshes:
        raise RuntimeError("No mesh objects were imported")
    if not armatures:
        raise RuntimeError("No armatures were imported; refusing to export an unrigged character")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in imported:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next((obj for obj in imported if obj.type == "ARMATURE"), imported[0])
    result = bpy.ops.export_scene.gltf(
        filepath=str(output_path), export_format="GLB", use_selection=True,
        export_apply=False, export_animations=True, export_skins=True, export_morph=True
    )
    if "FINISHED" not in result or not output_path.is_file() or output_path.stat().st_size < 100_000:
        raise RuntimeError("Blender GLB export did not produce a valid-sized output file")

    report = {
        "name": profile.get("name", "Ara character"),
        "output": output_path.name,
        "source_model": profile["model"],
        "hair_asset": hair_path_value,
        "shape_keys_requested": requested_keys,
        "shape_keys_applied": key_results,
        "material_tints_applied": material_results,
        "armatures": [{"name": obj.name, "bones": len(obj.data.bones)} for obj in armatures],
        "cleared_actions": cleared_actions,
        "mesh_count": len(meshes),
        "mesh_objects": [obj.name for obj in meshes],
        "output_bytes": output_path.stat().st_size,
        "notes": [
            "Standalone export assembled from existing Ara body and hair GLBs.",
            "Source GLBs and Godot game files are not modified.",
            "Clothing has not been added to this first Wren export."
        ]
    }
    output_path.with_name("Wren-export-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2), flush=True)

if __name__ == "__main__":
    main()
