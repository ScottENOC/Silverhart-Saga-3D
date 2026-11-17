#!/usr/bin/env python3
"""Render the final native-Ara Wren GLB for visual review."""
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(raw) != 2:
        raise SystemExit("usage: blender --background --python render_wren_native.py -- MODEL.glb OUTPUT_DIR")
    return Path(raw[0]), Path(raw[1])


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_model(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [obj for obj in bpy.context.scene.objects if obj not in before]
    for obj in objects:
        if obj.type == "ARMATURE" and obj.animation_data:
            obj.animation_data_clear()
    return objects


def bounds_for(objects):
    deps = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(deps)
        points.extend(evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
    if not points:
        raise RuntimeError("Imported Wren GLB contains no mesh geometry")
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return lo, hi


def setup_world(scene):
    engines = {item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items}
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    looks = {item.identifier for item in scene.view_settings.bl_rna.properties["look"].enum_items}
    for candidate in ("AgX - Medium High Contrast", "Medium High Contrast"):
        if candidate in looks:
            scene.view_settings.look = candidate
            break
    scene.view_settings.exposure = -0.35
    scene.view_settings.gamma = 1.0
    if scene.world is None:
        scene.world = bpy.data.worlds.new("WrenReviewWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    if background:
        background.inputs["Color"].default_value = (0.045, 0.052, 0.068, 1)
        background.inputs["Strength"].default_value = 0.35


def render_view(scene, target, direction, ortho_scale, radius, path):
    cam_data = bpy.data.cameras.new("WrenReviewCamera")
    cam = bpy.data.objects.new("WrenReviewCamera", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = target + direction.normalized() * radius * 4.0
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    scene.camera = cam

    lights = []
    specs = [
        ("Key", Vector((-radius * 1.0, -radius * 1.3, radius * 1.2)), 520, radius * 1.2),
        ("Fill", Vector((radius * 1.1, -radius * 0.8, radius * 0.45)), 260, radius * 1.4),
        ("Rim", Vector((radius * 0.15, radius * 1.1, radius * 1.0)), 420, radius * 1.1),
    ]
    for name, offset, power, size in specs:
        data = bpy.data.lights.new(name, "AREA")
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = target + offset
        data.energy = power
        data.shape = "DISK"
        data.size = size
        lights.append(obj)

    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)

    bpy.data.objects.remove(cam, do_unlink=True)
    for light in lights:
        bpy.data.objects.remove(light, do_unlink=True)


def main():
    model_path, output = arguments()
    if not model_path.is_file():
        raise FileNotFoundError(model_path)
    output.mkdir(parents=True, exist_ok=True)
    clear_scene()
    objects = import_model(model_path)
    meshes = [obj for obj in objects if obj.type == "MESH"]
    lo, hi = bounds_for(objects)
    centre = (lo + hi) * 0.5
    height = hi.z - lo.z
    width = hi.x - lo.x
    radius = max(height, width, 0.5)
    scene = bpy.context.scene
    setup_world(scene)

    full_scale = height * 1.18
    views = {
        "front": (centre, Vector((0, -1, 0)), full_scale, radius),
        "side": (centre, Vector((1, 0, 0)), full_scale, radius),
        "threequarter": (centre, Vector((1, -1, 0)), full_scale, radius),
        "face": (Vector((centre.x, centre.y, lo.z + height * 0.915)),
                 Vector((0, -1, 0)), height * 0.37, height * 0.22),
    }
    for name, (target, direction, scale, light_radius) in views.items():
        render_view(scene, target, direction, scale, light_radius, output / (name + ".png"))

    mesh_report = []
    for obj in meshes:
        keys = []
        if obj.data.shape_keys:
            keys = [block.name for block in obj.data.shape_keys.key_blocks if block.name != "Basis"]
        mesh_report.append({
            "name": obj.name,
            "vertices": len(obj.data.vertices),
            "triangles": sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons),
            "materials": [mat.name if mat else None for mat in obj.data.materials],
            "shape_keys": keys,
        })
    report = {
        "model": str(model_path),
        "height_m": round(height, 4),
        "width_m": round(width, 4),
        "mesh_count": len(meshes),
        "meshes": mesh_report,
        "views": list(views),
    }
    (output / "render-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("[Wren review] rendered front, side, three-quarter and face views", flush=True)


if __name__ == "__main__":
    main()
