#!/usr/bin/env python3
"""Render native Wren together with a body-derived Ara briefs shell."""
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_glb(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [obj for obj in bpy.context.scene.objects if obj not in before]


def setup_scene(scene):
    engines = {item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items}
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    # These are fit-review images, not final marketing renders. Lower sample counts
    # keep the three-view CI review quick while retaining enough detail for clipping checks.
    if hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
        scene.eevee.taa_render_samples = 16
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("BriefsShellReviewWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.035, 0.04, 0.05, 1)
        bg.inputs["Strength"].default_value = 0.35


def render_view(scene, target, direction, scale, radius, output):
    camera_data = bpy.data.cameras.new("BriefsReviewCamera")
    camera = bpy.data.objects.new("BriefsReviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = target + direction.normalized() * radius * 4
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = scale
    scene.camera = camera
    lights = []
    for name, offset, energy, size in (
        ("Key", Vector((-0.8, -1.0, 0.8)), 450, 1.0),
        ("Fill", Vector((0.9, -0.6, 0.3)), 240, 1.2),
        ("Rim", Vector((0.1, 1.0, 0.8)), 350, 1.0),
    ):
        data = bpy.data.lights.new(name, "AREA")
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = target + offset * radius
        data.energy = energy
        data.shape = "DISK"
        data.size = size * radius
        lights.append(obj)
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    for light in lights:
        bpy.data.objects.remove(light, do_unlink=True)


def main():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(raw) != 3:
        raise SystemExit("usage: blender --background --python render_wren_briefs_shell.py -- BODY.glb BRIEFS.glb OUTPUT_DIR")
    body_path, garment_path, output = map(Path, raw)
    output.mkdir(parents=True, exist_ok=True)
    clear_scene()
    body_objects = import_glb(body_path)
    garment_objects = import_glb(garment_path)
    body = next((o for o in body_objects if o.type == "MESH" and any(
        m and "skin" in m.name.lower() for m in o.data.materials)), None)
    # Blender's glTF importer can combine several glTF primitives into one
    # object. In that case the imported object has both Skin and Bra material
    # slots, and rendering the whole object makes the body occlude the garment.
    # Isolate faces assigned to the dedicated garment material before review.
    garment_material_names = {"bra", "briefs"}
    candidates = []
    for obj in garment_objects:
        if obj.type != "MESH":
            continue
        for index, material in enumerate(obj.data.materials):
            if material and material.name.strip().lower() in garment_material_names:
                candidates.append((obj, index, material))
    if len(candidates) != 1:
        details = [(o.name, i, m.name) for o, i, m in candidates]
        raise RuntimeError(f"Expected one dedicated Bra/Briefs material slot, got {details}")

    source_garment, material_index, garment_material = candidates[0]
    garment_mesh = source_garment.data.copy()
    bm = bmesh.new()
    bm.from_mesh(garment_mesh)
    bmesh.ops.delete(
        bm,
        geom=[face for face in bm.faces if face.material_index != material_index],
        context="FACES",
    )
    loose = [vertex for vertex in bm.verts if not vertex.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(garment_mesh)
    bm.free()
    garment_mesh.materials.clear()
    garment_mesh.materials.append(garment_material)
    for polygon in garment_mesh.polygons:
        polygon.material_index = 0
    garment = source_garment.copy()
    garment.data = garment_mesh
    garment.name = f"{source_garment.name}_{garment_material.name}_isolated"
    bpy.context.collection.objects.link(garment)

    if body is None:
        raise RuntimeError("Could not identify canonical body skin mesh")
    # Hide all meshes imported from the transfer GLB. The isolated garment
    # above is the only geometry retained from it; the canonical body is
    # rendered from body_path so there is no duplicate/occluding source body.
    for obj in garment_objects:
        if obj.type == "MESH":
            obj.hide_render = True
    garment.hide_render = False
    armature_mod = next((m for m in body.modifiers if m.type == "ARMATURE" and m.object), None)
    if armature_mod is None or armature_mod.object.data.bones.get("LeftUpLeg") is None:
        raise RuntimeError("Wren rig is missing the LeftUpLeg landmark")
    armature = armature_mod.object
    left = armature.matrix_world @ armature.data.bones["LeftUpLeg"].head_local
    right = armature.matrix_world @ armature.data.bones["RightUpLeg"].head_local
    hip_z = (left.z + right.z) * 0.5

    deps = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in (body, garment):
        evaluated = obj.evaluated_get(deps)
        points.extend(evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    # Frame the garment itself. A pelvis-centred camera made the bra comparison\n    # show the wrong part of the body and could not support a fit judgement.\n    garment_eval = garment.evaluated_get(deps)\n    garment_points = [garment_eval.matrix_world @ Vector(corner) for corner in garment_eval.bound_box]\n    garment_lo = Vector(tuple(min(p[i] for p in garment_points) for i in range(3)))\n    garment_hi = Vector(tuple(max(p[i] for p in garment_points) for i in range(3)))\n    target = (garment_lo + garment_hi) * 0.5\n    garment_width = max(garment_hi.x - garment_lo.x, garment_hi.y - garment_lo.y, 0.12)\n    review_scale = max(0.42, garment_width * 2.2)
    scene = bpy.context.scene
    setup_scene(scene)
    views = {
        "front": Vector((0, -1, 0)),
        "side": Vector((1, 0, 0)),
        "rear": Vector((0, 1, 0)),
    }
    for name, direction in views.items():
        render_view(scene, target, direction, review_scale, 0.6, output / f"{name}.png")

    report = {
        "body": body.name,
        "garment": garment.name,\n        "source_mesh": source_garment.name,\n        "garment_material": garment_material.name,\n        "garment_bounds_world": [garment_lo[:], garment_hi[:]],\n        "review_scale": review_scale,
        "body_vertices": len(body.data.vertices),
        "garment_vertices": len(garment.data.vertices),
        "garment_faces": len(garment.data.polygons),
        "garment_materials": [m.name if m else None for m in garment.data.materials],
        "hip_z_m": hip_z,
        "views": list(views),
    }
    (output / "review-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("WREN_BRIEFS_SHELL_REVIEW " + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()
