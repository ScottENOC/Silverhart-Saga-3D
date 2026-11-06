import argparse
import json
import os
import sys

import bpy
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default=os.environ.get("REVIEW_INPUT"), required=not bool(os.environ.get("REVIEW_INPUT")))
    parser.add_argument("--output-dir", default=os.environ.get("REVIEW_OUTPUT_DIR"), required=not bool(os.environ.get("REVIEW_OUTPUT_DIR")))
    return parser.parse_args(raw)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_model(path):
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))


def mesh_report():
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    materials = {m.name for o in meshes for m in o.data.materials if m}
    vertices = sum(len(o.data.vertices) for o in meshes)
    polygons = sum(len(o.data.polygons) for o in meshes)
    return {
        "mesh_objects": len(meshes),
        "vertices": vertices,
        "polygons": polygons,
        "materials": sorted(materials),
        "armatures": [{"name": a.name, "bones": len(a.data.bones)} for a in armatures]
    }


def camera_for_view(name, centre, radius):
    camera_data = bpy.data.cameras.new("ReviewCamera_" + name)
    camera = bpy.data.objects.new("ReviewCamera_" + name, camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = centre + {
        "front": Vector((0, -radius * 2.8, radius * 0.15)),
        "side": Vector((radius * 2.8, 0, radius * 0.15)),
        "rear": Vector((0, radius * 2.8, radius * 0.15)),
        "three_quarter": Vector((radius * 2.2, -radius * 2.2, radius * 0.2))
    }[name]
    direction = centre - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 55
    return camera


def main():
    args = arguments()
    os.makedirs(args.output_dir, exist_ok=True)
    clear_scene()
    import_model(args.input)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("GLB contained no mesh objects")
    points = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    minimum = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    maximum = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    centre = (minimum + maximum) * 0.5
    radius = max((maximum - minimum).length * 0.5, 0.5)

    scene = bpy.context.scene
    available_engines = {item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items}
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        if engine in available_engines:
            scene.render.engine = engine
            break
    else:
        raise RuntimeError(f"No supported review render engine found: {sorted(available_engines)}")
    scene.render.resolution_x = 720
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    if scene.render.engine in {'BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'}:
        scene.eevee.taa_render_samples = 16
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (0.18, 0.18, 0.18)
    scene.render.film_transparent = False
    light_data = bpy.data.lights.new("ReviewKey", "AREA")
    light = bpy.data.objects.new("ReviewKey", light_data)
    bpy.context.collection.objects.link(light)
    light.location = centre + Vector((-radius, -radius * 1.5, radius * 1.5))
    light.data.energy = 1800
    light.data.shape = "DISK"
    light.data.size = radius * 1.2

    report = mesh_report()
    report["bounds_min"] = list(minimum)
    report["bounds_max"] = list(maximum)
    with open(os.path.join(args.output_dir, "model_report.json"), "w") as f:
        json.dump(report, f, indent=2)

    for view in ("front", "side", "rear", "three_quarter"):
        camera = camera_for_view(view, centre, radius)
        scene.camera = camera
        scene.render.filepath = os.path.join(args.output_dir, view + ".png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(camera, do_unlink=True)


if __name__ == "__main__":
    main()
