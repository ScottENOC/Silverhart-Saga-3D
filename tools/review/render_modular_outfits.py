#!/usr/bin/env python3
"""Render isolated modular outfit variants from the exact assembled Wren GLB."""
import json
import os
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

GARMENTS = {
    "Fatigue pants", "Fatigue pants.001",
    "Backless slit dress", "Pencil skirt",
    "Halter lace bra cups", "Halter lace bra straps",
    "Shoes", "Boot shafts", "Fatigue shirt", "Lace shirt", "Lace pants", "Lace briefs", "Lace briefs ties", "Bra", "Briefs",
    "Tank top", "Triangle bikini top", "Triangle bikini strings",
    "String bikini bottom", "String bikini strings", "Leather armor",
}
OUTFITS = {
    "skin": set(),
    "halter": {"Halter lace bra cups", "Halter lace bra straps"},
    "dress": {"Backless slit dress", "Pencil skirt"},
    "pants": {"Fatigue pants", "Fatigue pants.001"},
    "halter_pants": {
        "Halter lace bra cups", "Halter lace bra straps",
        "Fatigue pants", "Fatigue pants.001",
    },
    "lace_briefs": {"Lace briefs", "Lace briefs ties"},
    "lace_shirt": {"Lace shirt"},
    "lace_pants": {"Lace pants"},
}

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def import_model(path):
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))

def material_names():
    names = set()
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            names.update(m.name for m in obj.data.materials if m)
    return sorted(names)

def isolate_outfit(keep):
    removed = {}
    kept_faces = {}
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        mesh = obj.data
        bm = bmesh.new()
        bm.from_mesh(mesh)
        faces = []
        for face in bm.faces:
            idx = face.material_index
            name = mesh.materials[idx].name if idx < len(mesh.materials) and mesh.materials[idx] else ""
            if name in keep:
                kept_faces[name] = kept_faces.get(name, 0) + 1
            if name in GARMENTS and name not in keep:
                faces.append(face)
                removed[name] = removed.get(name, 0) + 1
        if faces:
            bmesh.ops.delete(bm, geom=faces, context="FACES")
            loose = [v for v in bm.verts if not v.link_faces]
            if loose:
                bmesh.ops.delete(bm, geom=loose, context="VERTS")
            bm.to_mesh(mesh)
            mesh.update()
        bm.free()
    missing = sorted(name for name in keep if kept_faces.get(name, 0) == 0)
    if missing:
        raise RuntimeError("Requested garment material(s) absent or empty: " + ", ".join(missing))
    return removed, kept_faces

def bounds():
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    points = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    if not points:
        raise RuntimeError("No mesh geometry remains after outfit isolation")
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return (lo + hi) * 0.5, max((hi - lo).length * 0.5, 0.5)

def camera_for_view(name, centre, radius):
    data = bpy.data.cameras.new("OutfitReview_" + name)
    camera = bpy.data.objects.new("OutfitReview_" + name, data)
    bpy.context.collection.objects.link(camera)
    direction = {
        "front": Vector((0, -1, 0.08)),
        "side": Vector((1, 0, 0.08)),
        "rear": Vector((0, 1, 0.08)),
    }[name]
    camera.location = centre + direction.normalized() * radius * 2.9
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    data.lens = 55
    return camera

def render_outfit(input_path, output_root, outfit, keep):
    clear_scene()
    import_model(input_path)
    available = material_names()
    unknown = sorted(name for name in available if any(k in name.lower() for k in ("pants", "dress", "skirt", "halter", "bra", "brief", "shirt", "bikini", "shoes", "boot", "armor")) and name not in GARMENTS)
    if unknown:
        raise RuntimeError("Unclassified garment material(s): " + ", ".join(unknown))
    removed, kept_faces = isolate_outfit(keep)
    centre, radius = bounds()
    scene = bpy.context.scene
    engines = {item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items}
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        if engine in engines:
            scene.render.engine = engine
            break
    else:
        raise RuntimeError("No supported Blender render engine")
    scene.render.resolution_x = 720
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    if scene.render.engine in {"BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"}:
        scene.eevee.taa_render_samples = 16
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.18, 0.18, 0.18)
    light_data = bpy.data.lights.new("OutfitReviewKey", "AREA")
    light = bpy.data.objects.new("OutfitReviewKey", light_data)
    bpy.context.collection.objects.link(light)
    light.location = centre + Vector((-radius, -radius * 1.5, radius * 1.5))
    light.data.energy = 1800
    light.data.shape = "DISK"
    light.data.size = radius * 1.2

    output = Path(output_root) / outfit
    output.mkdir(parents=True, exist_ok=True)
    report = {
        "outfit": outfit,
        "kept_materials": sorted(keep),
        "kept_face_counts": kept_faces,
        "removed_face_counts": removed,
        "available_materials": available,
        "unrecognised_garment_materials": unknown,
        "mesh_objects": sum(o.type == "MESH" for o in scene.objects),
        "remaining_polygons": sum(len(o.data.polygons) for o in scene.objects if o.type == "MESH"),
    }
    (output / "report.json").write_text(json.dumps(report, indent=2))
    for view in ("front", "side", "rear"):
        camera = camera_for_view(view, centre, radius)
        scene.camera = camera
        scene.render.filepath = str(output / (view + ".png"))
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(camera, do_unlink=True)

def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: blender --background --python render_modular_outfits.py -- INPUT.glb OUTPUT_DIR")
    args = sys.argv[sys.argv.index("--") + 1:]
    input_path, output_root = args[0], args[1]
    if not Path(input_path).is_file():
        raise FileNotFoundError(input_path)
    for outfit, keep in OUTFITS.items():
        print("Rendering isolated outfit:", outfit, "keep:", sorted(keep), flush=True)
        render_outfit(input_path, output_root, outfit, keep)

if __name__ == "__main__":
    main()
