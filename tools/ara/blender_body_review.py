"""Create a Blender turntable review file and four orthographic renders for an Ara GLB.
Run: blender --background --python tools/ara/blender_body_review.py -- --input body.glb --out review/
"""
import argparse
import os
import sys
from pathlib import Path
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument("--input", required=True)
parser.add_argument("--out", required=True)
args = parser.parse_args(argv)
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=args.input)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise RuntimeError("GLB import contained no mesh objects")
points = []
for obj in meshes:
    points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
center = (minimum + maximum) * 0.5
height = maximum.z - minimum.z
span = max(maximum.x - minimum.x, maximum.y - minimum.y, height) * 1.55
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 900
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.world.color = (0.12, 0.12, 0.12)
scene.view_settings.view_transform = "AgX"
light_data = bpy.data.lights.new("Large soft key", "AREA")
light_data.energy = 1800
light_data.shape = "DISK"
light_data.size = 5.0
light = bpy.data.objects.new("Large soft key", light_data)
scene.collection.objects.link(light)
light.location = center + Vector((3.0, -4.0, height * 0.8))
light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()
camera_data = bpy.data.cameras.new("Review camera")
camera = bpy.data.objects.new("Review camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera.data.type = "ORTHO"
camera.data.ortho_scale = span
views = {
    "front": Vector((0, -1, 0.08)),
    "back": Vector((0, 1, 0.08)),
    "left": Vector((-1, 0, 0.08)),
    "right": Vector((1, 0, 0.08)),
    "front_three_quarter": Vector((0.65, -0.76, 0.08)),
}
for name, direction in views.items():
    camera.location = center + direction.normalized() * span * 2.4
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(out / (name + ".png"))
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out / "body_review.blend"))
print("Wrote multi-angle Blender review to", out)
