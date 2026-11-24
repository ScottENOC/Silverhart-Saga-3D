#!/usr/bin/env python3
"""Build a skinned garment shell from a body GLB and a signed coverage field.

Run inside Blender:
  blender --background --python build_shell_from_body.py -- \
    --input Wren.glb --field-json briefs-field.json --output briefs.glb
The JSON file is {"field_values": [one signed value per body vertex]}.
"""
import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from shell_core import build_shell


def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--field-json", required=True)
    parser.add_argument("--output", required=True, help="Garment-only GLB")
    parser.add_argument("--review-output", default="", help="Optional combined body + garment GLB for interactive inspection")
    parser.add_argument("--body-object", default="")
    parser.add_argument("--source-material", default="Skin_Anatomy")
    parser.add_argument("--material-name", default="GarmentShell")
    parser.add_argument("--offset-m", type=float, default=0.003)
    parser.add_argument("--hem-depth-m", type=float, default=0.0015)
    parser.add_argument("--colour", nargs=4, type=float, default=(0.008, 0.008, 0.010, 1.0), help="Linear RGBA fabric colour; defaults to near-black")
    parser.add_argument("--fabric-profile", default="black_matte_moderate_stretch")
    return parser.parse_args(raw)


def import_glb(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(path))


def find_body(name=""):
    candidates = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        if name and obj.name != name:
            continue
        armatures = [m for m in obj.modifiers if m.type == "ARMATURE" and m.object]
        if not armatures:
            continue
        materials = [m.name.lower() for m in obj.data.materials if m]
        score = 2 if any("skin" in m for m in materials) else 0
        candidates.append((score, obj))
    if not candidates:
        raise RuntimeError("No skinned body mesh with an armature modifier was found")
    candidates.sort(key=lambda item: item[0], reverse=True)
    if not name and len(candidates) > 1 and candidates[0][0] == candidates[1][0]:
        raise RuntimeError("Multiple possible body meshes; specify --body-object")
    return candidates[0][1]


def ref_delta(ref, source_key, basis_key):
    if ref[0] == "vertex":
        i = ref[1]
        return source_key.data[i].co - basis_key.data[i].co
    _, a, b, t = ref
    da = source_key.data[a].co - basis_key.data[a].co
    db = source_key.data[b].co - basis_key.data[b].co
    return da.lerp(db, t)


def copy_shape_keys(source, target, shell):
    source_keys = source.data.shape_keys
    if source_keys is None or len(source_keys.key_blocks) <= 1:
        return
    blocks = list(source_keys.key_blocks)
    basis = blocks[0]
    created = {}
    for block in blocks[1:]:
        new = target.shape_key_add(name=block.name, from_mix=False)
        new.slider_min = block.slider_min
        new.slider_max = block.slider_max
        new.value = 0.0
        new.mute = block.mute
        for index, ref in enumerate(shell.source_refs):
            new.data[index].co = Vector(shell.positions[index]) + ref_delta(ref, block, basis)
        created[block.name] = new
    for block in blocks[1:]:
        if block.relative_key.name in created:
            created[block.name].relative_key = created[block.relative_key.name]


def copy_skinning(source, target, shell):
    groups = [target.vertex_groups.new(name=group.name) for group in source.vertex_groups]
    source_weights = []
    for vertex in source.data.vertices:
        source_weights.append({entry.group: entry.weight for entry in vertex.groups})

    def weights_for(ref):
        if ref[0] == "vertex":
            return source_weights[ref[1]]
        _, a, b, t = ref
        wa, wb = source_weights[a], source_weights[b]
        result = {}
        for group in set(wa) | set(wb):
            value = wa.get(group, 0.0) * (1.0 - t) + wb.get(group, 0.0) * t
            if value > 1e-6:
                result[group] = value
        return result

    for vertex_index, ref in enumerate(shell.source_refs):
        for group_index, weight in weights_for(ref).items():
            groups[group_index].add([vertex_index], weight, "REPLACE")

    for modifier in source.modifiers:
        if modifier.type != "ARMATURE" or modifier.object is None:
            continue
        new = target.modifiers.new(modifier.name, "ARMATURE")
        new.object = modifier.object
        new.use_vertex_groups = modifier.use_vertex_groups
        new.use_bone_envelopes = modifier.use_bone_envelopes
        new.use_deform_preserve_volume = modifier.use_deform_preserve_volume
        new.show_viewport = modifier.show_viewport
        new.show_render = modifier.show_render


def make_material(name, colour, source):
    """Create a deliberately opaque, matte fabric material for fit review.

    Stretch is a garment construction property, not a static glTF shader
    parameter. It is recorded as profile metadata; the shell remains skinned
    to the rig so its fit can be evaluated under character poses.
    """
    material = bpy.data.materials.new(name)
    material.diffuse_color = tuple(colour)
    material.use_nodes = True
    shader = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if shader:
        values = {
            "Base Color": tuple(colour),
            "Roughness": 0.86,
            "Metallic": 0.0,
            "Alpha": 1.0,
            "Transmission Weight": 0.0,
            "Sheen Weight": 0.18,
            "Sheen Roughness": 0.72,
            "Coat Weight": 0.0,
        }
        for socket, value in values.items():
            target = shader.inputs.get(socket)
            if target is not None:
                target.default_value = value
    # Explicitly disable material-level transparency where supported.
    if hasattr(material, "surface_render_method"):
        try:
            material.surface_render_method = "DITHERED"
        except (TypeError, ValueError):
            pass
    material["fabric_profile"] = "black_matte_moderate_stretch"
    material["opacity"] = "opaque"
    material["stretch"] = "moderate (construction intent; not simulated by static GLB)"
    return material

