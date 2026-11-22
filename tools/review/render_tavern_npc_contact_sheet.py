#!/usr/bin/env python3
"""Render a front-view review gallery for generated tavern NPC GLBs.

Run with Blender:
  blender --background --python render_tavern_npc_contact_sheet.py -- MANIFEST MODEL_DIR OUTPUT_DIR
"""
import json
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_glb(path: Path) -> None:
    bpy.ops.import_scene.gltf(filepath=str(path.resolve()))


def scene_bounds():
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    if not points:
        raise RuntimeError("Imported NPC has no mesh geometry")
    low = Vector(tuple(min(point[i] for point in points) for i in range(3)))
    high = Vector(tuple(max(point[i] for point in points) for i in range(3)))
    return (low + high) * 0.5, max((high - low).length * 0.5, 0.5)


def setup_camera(centre: Vector, radius: float):
    data = bpy.data.cameras.new("TavernNPCReviewCamera")
    camera = bpy.data.objects.new("TavernNPCReviewCamera", data)
    bpy.context.collection.objects.link(camera)
    direction = Vector((0, -1, 0.08)).normalized()
    camera.location = centre + direction * radius * 3.0
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    data.type = "ORTHO"
    data.ortho_scale = radius * 2.15
    bpy.context.scene.camera = camera
    return camera


def setup_lighting(centre: Vector, radius: float) -> None:
    world = bpy.context.scene.world
    if world is not None:
        world.color = (0.22, 0.22, 0.22)
    light_data = bpy.data.lights.new("TavernNPCReviewKey", "AREA")
    light = bpy.data.objects.new("TavernNPCReviewKey", light_data)
    bpy.context.collection.objects.link(light)
    light.location = centre + Vector((-radius, -radius * 1.4, radius * 1.2))
    light_data.energy = 1400
    light_data.shape = "DISK"
    light_data.size = radius


def render_one(model: Path, output: Path) -> None:
    clear_scene()
    import_glb(model)
    centre, radius = scene_bounds()
    camera = setup_camera(centre, radius)
    setup_lighting(centre, radius)
    scene = bpy.context.scene
    engines = {item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items}
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        if engine in engines:
            scene.render.engine = engine
            break
    scene.render.resolution_x = 320
    scene.render.resolution_y = 400
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = str(output)
    if scene.render.engine in {"BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"}:
        scene.eevee.taa_render_samples = 8
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    if len(args) != 3:
        raise SystemExit("Expected MANIFEST MODEL_DIR OUTPUT_DIR")
    manifest_path, model_dir, output_dir = map(Path, args)
    manifest = json.loads(manifest_path.read_text())
    output_dir.mkdir(parents=True, exist_ok=True)
    for character in manifest.get("characters", []):
        model = model_dir / str(character.get("model", f"{character['id']}.glb"))
        if not model.is_file():
            raise FileNotFoundError(model)
        output = output_dir / f"{character['id']}.png"
        print(f"Rendering NPC review: {character.get('name', character['id'])}", flush=True)
        render_one(model, output)
    print(f"Rendered {len(manifest.get('characters', []))} NPC review images.", flush=True)


if __name__ == "__main__":
    main()
