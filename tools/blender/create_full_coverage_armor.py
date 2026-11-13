"""Replace Ara's small leather accessory with a skinned, full-coverage leather armour shell.

The shell is derived from the Ara body surface, so it follows the same silhouette and
inherits the original vertex weights. It covers torso front/back, shoulders/upper arms,
and both legs. This is a first-pass armour base for later plate segmentation and detailing.
"""
import argparse
import os
import sys

import bpy
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(raw)


def find_material_faces(obj, token):
    found = []
    for poly in obj.data.polygons:
        if poly.material_index < len(obj.material_slots):
            mat = obj.material_slots[poly.material_index].material
            if mat and token in mat.name.lower():
                found.append(poly)
    return found


def main():
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    skin = max((o for o in meshes if any(s.material and "skin" in s.material.name.lower()
                                         for s in o.material_slots)),
               key=lambda o: len(o.data.polygons), default=None)
    if skin is None or armature is None:
        raise RuntimeError("Full-coverage armour requires Ara's skinned body and armature")

    # Remove the original small Ara accessory; it is not the coverage requested.
    removed_old = 0
    for obj in meshes:
        bm = __import__("bmesh").new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        doomed = []
        for face in bm.faces:
            if face.material_index < len(obj.data.materials):
                mat = obj.data.materials[face.material_index]
                if mat and "leather armor" in mat.name.lower():
                    doomed.append(face)
        removed_old += len(doomed)
        if doomed:
            __import__("bmesh").ops.delete(bm, geom=doomed, context="FACES")
            bm.to_mesh(obj.data)
            obj.data.update()
        bm.free()

    world_points = [skin.matrix_world @ v.co for v in skin.data.vertices]
    lo = Vector(tuple(min(p[i] for p in world_points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in world_points) for i in range(3)))
    height = hi.z - lo.z
    width = hi.x - lo.x
    centre_x = (hi.x + lo.x) * 0.5
    if height <= 0.5 or width <= 0.1:
        raise RuntimeError("Ara body bounds are implausible; refusing to generate armour")

    # Select surface panels by anatomical region. All faces are taken from the
    # outer skin surface, offset slightly and given a real shell thickness.
    selected_faces = []
    for poly in skin.data.polygons:
        centre_local = sum((skin.data.vertices[i].co for i in poly.vertices), Vector()) / len(poly.vertices)
        centre = skin.matrix_world @ centre_local
        x = abs(centre.x - centre_x)
        z = (centre.z - lo.z) / height
        torso = 0.50 <= z <= 0.80 and x <= width * 0.205
        upper_arm = 0.53 <= z <= 0.79 and width * 0.145 <= x <= width * 0.335
        legs = 0.075 <= z <= 0.515 and width * 0.055 <= x <= width * 0.235
        if torso or upper_arm or legs:
            selected_faces.append(poly)

    if len(selected_faces) < 1200:
        raise RuntimeError(f"Only {len(selected_faces)} Ara surface faces selected for armour; expected broad body coverage")

    used = sorted({i for poly in selected_faces for i in poly.vertices})
    remap = {old: new for new, old in enumerate(used)}
    vertices = []
    for old in used:
        vertex = skin.data.vertices[old]
        world = skin.matrix_world @ vertex.co
        normal = (skin.matrix_world.to_3x3() @ vertex.normal).normalized()
        vertices.append(tuple(world + normal * 0.006))
    faces = [tuple(remap[i] for i in poly.vertices) for poly in selected_faces]

    mesh = bpy.data.meshes.new("FullCoverageLeatherArmourMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    armour = bpy.data.objects.new("Full coverage leather armour", mesh)
    bpy.context.collection.objects.link(armour)

    material = bpy.data.materials.get("Leather armor")
    if material is None:
        material = bpy.data.materials.new("Leather armor")
    material.diffuse_color = (0.105, 0.055, 0.028, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled:
        principled.inputs["Base Color"].default_value = (0.105, 0.055, 0.028, 1.0)
        principled.inputs["Roughness"].default_value = 0.72
        principled.inputs["Metallic"].default_value = 0.08
    mesh.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = True

    # Copy Ara's exact skinning weights to each copied surface vertex.
    source_groups = {g.index: g.name for g in skin.vertex_groups}
    target_groups = {name: armour.vertex_groups.new(name=name) for name in source_groups.values()}
    for old, new in remap.items():
        for assignment in skin.data.vertices[old].groups:
            name = source_groups.get(assignment.group)
            if name:
                target_groups[name].add([new], assignment.weight, "REPLACE")

    armour.parent = armature
    armour.matrix_parent_inverse = armature.matrix_world.inverted()
    modifier = armour.modifiers.new("Ara armour skinning", "ARMATURE")
    modifier.object = armature
    solidify = armour.modifiers.new("Leather shell thickness", "SOLIDIFY")
    solidify.thickness = 0.007
    solidify.offset = -0.25
    bevel = armour.modifiers.new("Soft armour edges", "BEVEL")
    bevel.width = 0.0025
    bevel.segments = 2
    armour["coverage"] = "chest,back,shoulders,upper_arms,thighs,lower_legs"
    armour["source"] = "Ara body surface with original skin weights"
    armour["selected_surface_faces"] = len(selected_faces)
    armour["review_status"] = "first_pass_full_coverage_armour_requires_visual_review"
    print(f"Generated full-coverage leather armour from {len(selected_faces)} Ara body faces; removed {removed_old} faces from old accessory")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False, export_animations=True)
    print("Exported full-coverage leather armour")


if __name__ == "__main__":
    main()
