#!/usr/bin/env python3
"""Assemble a configured Ara character and export one standalone GLB."""
import json
import sys
from pathlib import Path
import bpy
import bmesh

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

def tint_material(material, hex_colour, mix_factor=0.35):
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
    multiply.blend_type = "MIX"
    multiply.inputs["Fac"].default_value = max(0.0, min(1.0, float(mix_factor)))
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
    body_objects = import_glb(body_path)
    imported = list(body_objects)
    hair_objects = []
    hair_path_value = profile.get("hair_asset", "")
    if hair_path_value:
        hair_path = root / hair_path_value
        if not hair_path.is_file():
            raise FileNotFoundError(hair_path)
        hair_objects = import_glb(hair_path)
        imported.extend(hair_objects)

    cleared_actions = []
    if profile.get("reset_armatures_to_rest", True):
        for obj in imported:
            if obj.type == "ARMATURE" and obj.animation_data:
                action = obj.animation_data.action
                cleared_actions.append({"armature": obj.name, "action": action.name if action else None})
                obj.animation_data_clear()

    # Remove the base model's short-hair cap when a separate hairstyle is supplied.
    hide_body_tokens = {value.casefold() for value in profile.get("hide_materials_on_body", [])}
    if hide_body_tokens:
        for obj in body_objects:
            if obj.type != "MESH":
                continue
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            faces = []
            for face in bm.faces:
                idx = face.material_index
                mat = obj.data.materials[idx] if idx < len(obj.data.materials) else None
                if mat and any(token in mat.name.casefold() for token in hide_body_tokens):
                    faces.append(face)
            if faces:
                bmesh.ops.delete(bm, geom=faces, context="FACES")
                loose = [vert for vert in bm.verts if not vert.link_faces]
                if loose:
                    bmesh.ops.delete(bm, geom=loose, context="VERTS")
                bm.to_mesh(obj.data)
                obj.data.update()
            bm.free()

    requested_keys = profile.get("shape_keys", {})
    key_results = []
    material_results = []
    tinted_materials = set()
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
            if material is None or material.as_pointer() in tinted_materials:
                continue
            tint_rules = profile.get("material_tints", {})
            is_hair_asset = obj in hair_objects
            for token, tint in tint_rules.items():
                if (is_hair_asset and token.casefold() == "hair") or (not is_hair_asset and token.casefold() in material.name.casefold()):
                    colour = tint.get("colour", tint.get("color")) if isinstance(tint, dict) else tint
                    mix_factor = tint.get("mix", 0.35) if isinstance(tint, dict) else 0.35
                    tint_material(material, colour, mix_factor)
                    tinted_materials.add(material.as_pointer())
                    material_results.append({
                        "mesh": obj.name, "material": material.name,
                        "tint_token": token, "colour": colour, "mix": mix_factor
                    })
                    break

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

    from mathutils import Vector
    def object_diagnostics(obj):
        corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box] if obj.type == "MESH" else []
        return {
            "name": obj.name, "type": obj.type,
            "world_location": [round(float(v), 5) for v in obj.matrix_world.translation],
            "world_bounds_min": [round(float(min(v[i] for v in corners)), 5) for i in range(3)] if corners else None,
            "world_bounds_max": [round(float(max(v[i] for v in corners)), 5) for i in range(3)] if corners else None,
            "materials": [slot.material.name if slot.material else None for slot in obj.material_slots] if obj.type == "MESH" else [],
            "armature_modifier_targets": [m.object.name for m in obj.modifiers if m.type == "ARMATURE" and m.object] if obj.type == "MESH" else []
        }
    rig_diagnostics = []
    for obj in armatures:
        head_bones = [b for b in obj.data.bones if any(k in b.name.casefold() for k in ("head", "neck"))]
        rig_diagnostics.append({
            "armature": obj.name,
            "head_bones": [{"name": b.name, "head_world": [round(float(v), 5) for v in (obj.matrix_world @ b.head)]} for b in head_bones]
        })
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
        "object_diagnostics": [object_diagnostics(obj) for obj in imported],
        "rig_diagnostics": rig_diagnostics,
        "output_bytes": output_path.stat().st_size,
        "notes": [
            "Standalone export assembled from existing Ara body and hair GLBs.",
            "Separate braid asset materials receive the configured Hair tint regardless of source material name.",
            "Object bounds and head/neck bone coordinates are included to support precise hairstyle alignment.",
            "Source GLBs and Godot game files are not modified.",
            "Clothing has not been added to this first Wren export."
        ]
    }
    output_path.with_name("Wren-export-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2), flush=True)

if __name__ == "__main__":
    main()
