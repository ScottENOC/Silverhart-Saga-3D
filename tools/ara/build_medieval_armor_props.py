#!/usr/bin/env python3
"""Build standalone medieval shield and helmet props with Blender.

These are first-pass blockout assets, deliberately separate from Ara character
meshes. Origins are attachment pivots: shields at left-hand grip, helmets at
head centre. Dimensions are metre-scale approximations and require visual fit
review against the pinned male/female Ara exports before game integration.
"""
import argparse
from pathlib import Path
import bpy
from mathutils import Vector

STEEL = (0.34, 0.37, 0.40, 1.0)
DARK_STEEL = (0.16, 0.18, 0.20, 1.0)
WOOD = (0.25, 0.13, 0.065, 1.0)
BRASS = (0.55, 0.36, 0.12, 1.0)
LEATHER = (0.12, 0.065, 0.035, 1.0)

def material(name, colour, metallic=0.0, roughness=0.55):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = colour
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

MATS = {
    "steel": material("Steel", STEEL, 0.78, 0.32),
    "dark": material("Darkened steel", DARK_STEEL, 0.72, 0.38),
    "wood": material("Oak", WOOD, 0.0, 0.78),
    "brass": material("Brass", BRASS, 0.82, 0.3),
    "leather": material("Leather", LEATHER, 0.0, 0.8),
    "heraldry": material("HeraldryFace", (0.62, 0.08, 0.08, 1.0), 0.0, 0.78),
}

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def finish_object(obj, name, mat):
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(MATS[mat])
    bevel = obj.modifiers.new("Soft forged edges", "BEVEL")
    bevel.width = 0.008
    bevel.segments = 2
    obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj

def shield_mesh(name, outline, thickness=0.035, mat="wood"):
    verts = [(x, y, z) for z in (-thickness/2, thickness/2) for x, y in outline]
    n = len(outline)
    faces = [tuple(range(n-1, -1, -1)), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(MATS[mat])
    mesh.materials.append(MATS["heraldry"])
    # The +Z front is its own material surface for independent heraldry.
    mesh.polygons[1].material_index = 1
    uv_layer = mesh.uv_layers.new(name="ShieldFaceUV")
    min_x = min(point[0] for point in outline)
    max_x = max(point[0] for point in outline)
    min_y = min(point[1] for point in outline)
    max_y = max(point[1] for point in outline)
    width = max(max_x - min_x, 0.0001)
    height = max(max_y - min_y, 0.0001)
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            uv_layer.data[loop_index].uv = ((vertex.x - min_x) / width, (vertex.y - min_y) / height)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bevel = obj.modifiers.new("Bound rim", "BEVEL")
    bevel.width = 0.012
    bevel.segments = 3
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj

def uv_sphere(name, loc, scale, mat="steel", segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_object(obj, name, mat)

def cylinder(name, loc, radius, depth, mat="steel", vertices=24, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation or (0,0,0))
    return finish_object(bpy.context.object, name, mat)

def join_and_export(name, objects, output):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True)
    bpy.data.objects.remove(obj, do_unlink=True)

def build_shield(kind, out):
    clear_scene()
    if kind == "round":
        outline = [(0.16*__import__("math").cos(i*__import__("math").tau/48),
                    0.16*__import__("math").sin(i*__import__("math").tau/48)) for i in range(48)]
    elif kind == "kite":
        outline = [(-0.15,0.16),(0.15,0.16),(0.13,-0.03),(0,-0.29),(-0.13,-0.03)]
    else:
        outline = [(-0.15,0.17),(0.15,0.17),(0.14,-0.10),(0,-0.27),(-0.14,-0.10)]
    shield = shield_mesh(kind + "_shield", outline)
    boss = uv_sphere("Shield boss", (0,0,0.025), (0.055,0.055,0.025), "steel")
    rim = cylinder("Boss ring", (0,0,0.005), 0.073, 0.012, "brass", 32)
    join_and_export(kind + "_shield", [shield,boss,rim], out)

def build_helmet(kind, out):
    clear_scene()
    parts = []
    if kind == "nasal_helm":
        parts.append(uv_sphere("Nasal helm crown", (0,0,0.055), (0.115,0.13,0.135)))
        parts.append(cylinder("Nasal guard", (0,-0.125,0.015), 0.012, 0.13, "steel", 12, (1.5708,0,0)))
    elif kind == "kettle_hat":
        parts.append(uv_sphere("Kettle crown", (0,0,0.075), (0.11,0.12,0.105)))
        parts.append(cylinder("Kettle brim", (0,0,0.015), 0.19, 0.018, "steel", 48))
    elif kind == "great_helm":
        parts.append(cylinder("Great helm shell", (0,0,0.015), 0.125, 0.23, "steel", 32))
        parts.append(uv_sphere("Great helm top", (0,0,0.13), (0.125,0.125,0.07)))
        for z in (-0.025, 0.005, 0.035):
            parts.append(cylinder("Breathing slit", (0,-0.127,z), 0.004, 0.018, "dark", 8, (1.5708,0,0)))
    else:
        parts.append(uv_sphere("Bascinet bowl", (0,0,0.055), (0.12,0.13,0.14)))
        parts.append(uv_sphere("Bascinet visor", (0,-0.105,0.005), (0.105,0.035,0.085), "dark"))
        for z in (-0.02, 0.0, 0.02):
            parts.append(cylinder("Visor breathing hole", (0,-0.14,z), 0.0035, 0.01, "steel", 8, (1.5708,0,0)))
    join_and_export(kind, parts, out)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for kind in ("round", "kite", "heater"):
        build_shield(kind, args.output / f"{kind}_shield.glb")
    for kind in ("nasal_helm", "kettle_hat", "great_helm", "bascinet"):
        build_helmet(kind, args.output / f"{kind}.glb")
    print("Built 3 shields and 4 helmets; first-pass blockout geometry only.")

if __name__ == "__main__":
    main()
