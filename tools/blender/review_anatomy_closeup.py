#!/usr/bin/env python3
"""Render close-up adult anatomy diagnostics with a temporary blue pelvic highlight.

This is a review-only tool. It never writes or modifies a source GLB. The blue
material marks the front-facing pelvic skin region so reviewers can locate and
inspect the generated anatomy under controlled lighting.
"""
import argparse
import os
import sys

import bpy
from mathutils import Vector


def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--label", default="anatomy")
    parser.add_argument("--natural-colour", action="store_true", help="Render actual anatomy colours without the blue diagnostic overlay")
    return parser.parse_args(raw)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def skin_mesh():
    candidates = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        names = [slot.material.name.lower() for slot in obj.material_slots if slot.material]
        if any("skin" in name for name in names):
            candidates.append(obj)
    if not candidates:
        raise RuntimeError("No Ara skin mesh/material found in anatomy diagnostic GLB")
    return max(candidates, key=lambda obj: len(obj.data.polygons))


def pelvic_landmark(armature, height):
    aliases = {
        "left": {"leftupleg", "leftupperleg", "upleg_l", "upperleg_l",
                 "thigh_l", "leftthigh", "lthigh", "thigh.l"},
        "right": {"rightupleg", "rightupperleg", "upleg_r", "upperleg_r",
                  "thigh_r", "rightthigh", "rthigh", "thigh.r"},
    }
    found = {}
    for side, names in aliases.items():
        bone = next((b for b in armature.data.bones
                     if b.name.lower().replace(" ", "").replace("-", "_") in names), None)
        if bone:
            found[side] = armature.matrix_world @ bone.head_local
    if len(found) != 2:
        raise RuntimeError("Could not find paired upper-leg roots for close-up camera")
    return (found["left"].z + found["right"].z) * 0.5


def highlight_pelvis(skin, pelvis_z, height, width):
    blue = bpy.data.materials.new("DIAGNOSTIC ONLY · electric blue pelvic region")
    blue.diffuse_color = (0.015, 0.12, 1.0, 1.0)
    blue.use_nodes = True
    shader = next((node for node in blue.node_tree.nodes
                   if node.type == "BSDF_PRINCIPLED"), None)
    if shader:
        shader.inputs["Base Color"].default_value = (0.005, 0.08, 1.0, 1.0)
        shader.inputs["Metallic"].default_value = 0.0
        shader.inputs["Roughness"].default_value = 0.48
    skin.data.materials.append(blue)
    blue_index = len(skin.data.materials) - 1
    highlighted = 0
    for polygon in skin.data.polygons:
        centre = sum((skin.data.vertices[i].co for i in polygon.vertices), Vector()) / len(polygon.vertices)
        world = skin.matrix_world @ centre
        normal = (skin.matrix_world.to_3x3() @ polygon.normal).normalized()
        if (normal.y < -0.12
                and abs(world.x) <= width * 0.075
                and pelvis_z - height * 0.125 <= world.z <= pelvis_z + height * 0.012):
            polygon.material_index = blue_index
            highlighted += 1
    if highlighted == 0:
        raise RuntimeError("No front-facing pelvic polygons found for blue diagnostic highlight")
    return highlighted


def camera_for_view(name, target, width, height):
    data = bpy.data.cameras.new("PelvisDiagnosticCamera_" + name)
    camera = bpy.data.objects.new("PelvisDiagnosticCamera_" + name, data)
    bpy.context.collection.objects.link(camera)
    if name == "front":
        camera.location = target + Vector((0.0, -1.5, 0.015))
    else:
        camera.location = target + Vector((0.9, -1.15, 0.015))
    direction = target - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    data.type = "ORTHO"
    data.ortho_scale = max(width * 0.52, 0.28)
    return camera


def main():
    args = parse_args()
    os.makedirs(args.output_dir, exist_ok=True)
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    skin = skin_mesh()
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if armature is None:
        raise RuntimeError("No Ara armature found")
    points = [skin.matrix_world @ Vector(corner) for corner in skin.bound_box]
    minimum = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    maximum = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    height = maximum.z - minimum.z
    width = maximum.x - minimum.x
    pelvis_z = pelvic_landmark(armature, height)
    highlighted = 0 if args.natural_colour else highlight_pelvis(skin, pelvis_z, height, width)

    scene = bpy.context.scene
    available = {item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items}
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in available else "BLENDER_WORKBENCH"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    if scene.render.engine == "BLENDER_EEVEE_NEXT":
        scene.eevee.taa_render_samples = 48
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (0.22, 0.22, 0.22)
    scene.render.film_transparent = False

    for index, (offset, energy, size) in enumerate((
        (Vector((-0.45, -0.75, 0.55)), 850, 0.65),
        (Vector((0.55, -0.35, 0.10)), 500, 0.45),
    )):
        data = bpy.data.lights.new("PelvisDiagnosticLight" + str(index), "AREA")
        light = bpy.data.objects.new(data.name, data)
        bpy.context.collection.objects.link(light)
        light.location = Vector((0.0, -0.12, pelvis_z)) + offset
        data.energy = energy
        data.shape = "DISK"
        data.size = size

    target = Vector((0.0, -0.02, pelvis_z - height * 0.045))
    for view in ("front", "three_quarter"):
        camera = camera_for_view(view, target, width, height)
        scene.camera = camera
        suffix = "natural" if args.natural_colour else "blue"
        scene.render.filepath = os.path.join(args.output_dir, f"{args.label}_{view}_{suffix}.png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(camera, do_unlink=True)

    report = {
        "input": os.path.abspath(args.input),
        "label": args.label,
        "skin_mesh": skin.name,
        "pelvis_z": pelvis_z,
        "body_height": height,
        "body_width": width,
        "blue_highlighted_front_polygons": highlighted,
        "blue_material_is_review_only": not args.natural_colour,
        "natural_colour_render": args.natural_colour,
    }
    import json
    with open(os.path.join(args.output_dir, f"{args.label}_anatomy_review.json"), "w") as stream:
        json.dump(report, stream, indent=2)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
