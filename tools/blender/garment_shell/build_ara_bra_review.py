#!/usr/bin/env python3
"""Apply the opaque fit-review fabric to Ara's standard bra and export review GLBs."""
import argparse
import json
import traceback
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def parse_args():
    raw = __import__("sys").argv
    raw = raw[raw.index("--") + 1:] if "--" in raw else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Wren body plus extracted Ara bra GLB")
    parser.add_argument("--garment-output", required=True)
    parser.add_argument("--review-output", required=True)
    parser.add_argument("--clearance-m", type=float, default=0.0045)
    return parser.parse_args(raw)


def material_labels(obj):
    return [slot.material.name.lower() for slot in obj.material_slots if slot.material]


def find_body(objects):
    matches = [obj for obj in objects if obj.type == "MESH"
               and any("skin" in name for name in material_labels(obj))
               and any(mod.type == "ARMATURE" and mod.object for mod in obj.modifiers)]
    if not matches:
        raise RuntimeError("Could not find the skinned Wren skin mesh")
    return max(matches, key=lambda obj: len(obj.data.polygons))


def find_bra(objects):
    matches = [obj for obj in objects if obj.type == "MESH"
               and any("bra" in name for name in material_labels(obj))
               and any(mod.type == "ARMATURE" and mod.object for mod in obj.modifiers)]
    if not matches:
        raise RuntimeError("Could not find a skinned Ara Bra mesh/material in assembled GLB")
    return max(matches, key=lambda obj: len(obj.data.polygons))


def build_surface_tree(body):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = body.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    vertices = [body.matrix_world @ vertex.co for vertex in mesh.vertices]
    faces = [list(poly.vertices) for poly in mesh.polygons]
    tree = BVHTree.FromPolygons(vertices, faces, all_triangles=False)
    evaluated.to_mesh_clear()
    return tree


def make_material():
    material = bpy.data.materials.new("Black matte moderate-stretch fabric")
    material.diffuse_color = (0.008, 0.008, 0.010, 1.0)
    material.use_nodes = True
    shader = next((node for node in material.node_tree.nodes
                   if node.type == "BSDF_PRINCIPLED"), None)
    if shader:
        values = {
            "Base Color": (0.008, 0.008, 0.010, 1.0),
            "Roughness": 0.86, "Metallic": 0.0, "Alpha": 1.0,
            "Transmission Weight": 0.0, "Sheen Weight": 0.18,
            "Sheen Roughness": 0.72, "Coat Weight": 0.0,
        }
        for key, value in values.items():
            socket = shader.inputs.get(key)
            if socket is not None:
                socket.default_value = value
    if hasattr(material, "surface_render_method"):
        try:
            material.surface_render_method = "DITHERED"
        except (TypeError, ValueError):
            pass
    material["fabric_profile"] = "black_matte_moderate_stretch"
    material["opacity"] = "opaque"
    material["stretch"] = "moderate (construction intent; not simulated by static GLB)"
    return material


def fit_clearance(body, bra, clearance):
    tree = build_surface_tree(body)
    inverse = bra.matrix_world.inverted()
    moved = 0
    for vertex in bra.data.vertices:
        world = bra.matrix_world @ vertex.co
        nearest = tree.find_nearest(world)
        if not nearest or nearest[0] is None or nearest[1] is None:
            continue
        location, normal, _face, _distance = nearest
        normal = normal.normalized()
        signed = (world - location).dot(normal)
        if signed < clearance:
            world += normal * (clearance - signed)
            vertex.co = inverse @ world
            moved += 1
    bra.data.update()
    return moved


def export_selected(path, objects, active):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = active
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
                              use_selection=True, export_apply=False,
                              export_skins=True, export_morph=True)


def main():
    args = parse_args()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(Path(args.input)))
    objects = list(bpy.context.scene.objects)
    body = find_body(objects)
    bra = find_bra(objects)
    armatures = [mod.object for mod in bra.modifiers
                 if mod.type == "ARMATURE" and mod.object]
    if not armatures:
        raise RuntimeError("Ara bra has no armature modifier")
    material = make_material()
    bra.data.materials.clear()
    bra.data.materials.append(material)
    moved = fit_clearance(body, bra, args.clearance_m)
    export_selected(args.garment_output, [bra, *armatures], bra)
    export_selected(args.review_output, [body, bra, *armatures], body)
    report = {
        "source": str(args.input), "garment": bra.name, "body": body.name,
        "garment_vertices": len(bra.data.vertices), "clearance_m": args.clearance_m,
        "vertices_adjusted": moved, "fabric_profile": "black_matte_moderate_stretch",
        "opacity": "opaque",
        "stretch": "moderate (construction intent; not simulated by static GLB)",
        "garment_output": str(args.garment_output), "review_output": str(args.review_output),
    }
    report_path = Path(args.garment_output).with_suffix(".report.json")
    report_path.write_text(json.dumps(report, indent=2) + "\\n")
    print("ARA_BRA_FIT " + json.dumps(report), flush=True)


if __name__ == "__main__":
    try:
        main()
    except BaseException:
        traceback.print_exc()
        raise
