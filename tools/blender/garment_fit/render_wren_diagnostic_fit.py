#!/usr/bin/env python3
"""Generate and render a diagnostic torso-clearance shell on Wren.

This is deliberately NOT a production garment. It extracts a torso surface
patch from Wren's own body mesh, offsets it, runs the clearance solver, and
renders the result so the solver can be validated before real garment panels
are introduced.
"""
import argparse
import json
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from solver_core import FitConfig, fit_clearance


def args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output-dir", required=True)
    p.add_argument("--clearance-mm", type=float, default=4.0)
    return p.parse_args(raw)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def make_camera(name, location, target, out_path):
    data = bpy.data.cameras.new(name)
    cam = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = location
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.0
    look_at(cam, target)
    bpy.context.scene.camera = cam
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)


def main():
    a = args()
    os.makedirs(a.output_dir, exist_ok=True)
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(a.input))
    body = bpy.data.objects.get("Wren")
    if body is None or body.type != "MESH":
        raise RuntimeError("Expected the Wren body mesh named 'Wren'")
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if armature is None or len(armature.data.bones) != 69:
        raise RuntimeError("Expected Wren's 69-bone armature")

    world_vertices = [body.matrix_world @ v.co for v in body.data.vertices]
    tree = BVHTree.FromPolygons(world_vertices, [list(p.vertices) for p in body.data.polygons], all_triangles=False)
    if tree is None:
        raise RuntimeError("Could not build body BVH")

    # Diagnostic region: central torso only, avoiding the head, limbs and legs.
    selected_faces = []
    for poly in body.data.polygons:
        c = body.matrix_world @ poly.center
        if 1.00 <= c.z <= 1.52 and abs(c.x) <= 0.285:
            selected_faces.append(poly)
    if len(selected_faces) < 100:
        raise RuntimeError(f"Torso selection unexpectedly small: {len(selected_faces)} faces")

    used = sorted({i for poly in selected_faces for i in poly.vertices})
    remap = {old: new for new, old in enumerate(used)}
    local_coords = [body.data.vertices[i].co.copy() for i in used]
    faces = [[remap[i] for i in poly.vertices] for poly in selected_faces]
    edges_set = set()
    for face in faces:
        for j, left in enumerate(face):
            right = face[(j + 1) % len(face)]
            edges_set.add(tuple(sorted((left, right))))
    edges = sorted(edges_set)

    # Start 5 mm outside the body, then solve to the requested 4 mm clearance.
    start_world = []
    for old in used:
        v = body.data.vertices[old]
        normal = (body.matrix_world.to_3x3() @ v.normal).normalized()
        start_world.append(tuple(world_vertices[old] + normal * 0.005))

    def query(point):
        hit = tree.find_nearest(Vector(point))
        if hit is None or hit[0] is None or hit[1] is None:
            return None
        return tuple(hit[0]), tuple(hit[1].normalized())

    fitted, report = fit_clearance(
        start_world, edges, query,
        FitConfig(target_clearance=a.clearance_mm / 1000.0,
                  max_vertex_displacement=0.025, max_step=0.003,
                  smoothing=0.2, max_iterations=20,
                  floating_tolerance=0.015)
    )
    # Render failed fits as diagnostic evidence; the report preserves FAIL.

    # Build fitted shell in world coordinates, retaining the extracted topology.
    mesh = bpy.data.meshes.new("Wren_Torso_Clearance_Test_Mesh")
    mesh.from_pydata(fitted, [], faces)
    mesh.update()
    shell = bpy.data.objects.new("DIAGNOSTIC_TORSO_CLEARANCE_SHELL", mesh)
    bpy.context.scene.collection.objects.link(shell)
    mat = bpy.data.materials.new("Diagnostic teal shell")
    mat.diffuse_color = (0.035, 0.32, 0.38, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.025, 0.30, 0.36, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.48
    shell.data.materials.append(mat)

    # Smooth the diagnostic shell for legible renders; do not alter its fit coordinates.
    for poly in shell.data.polygons:
        poly.use_smooth = True

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 32
    scene.render.resolution_x = 768
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.025, 0.025, 0.03)

    # Neutral studio lighting.
    for name, loc, energy, size in [
        ("Key", (3.5, -4.0, 4.0), 850, 4.0),
        ("Fill", (-3.0, -2.5, 2.5), 500, 3.0),
        ("Rim", (0.0, 3.0, 3.5), 900, 3.0),
    ]:
        ld = bpy.data.lights.new(name, "AREA")
        lo = bpy.data.objects.new(name, ld)
        bpy.context.scene.collection.objects.link(lo)
        lo.location = loc
        ld.energy = energy
        ld.shape = "DISK"
        ld.size = size
        look_at(lo, (0, -0.08, 1.0))

    target = (0, -0.08, 1.0)
    views = {
        "front": ((0, -4.0, 1.0), target),
        "side": ((4.0, -0.08, 1.0), target),
        "threequarter": ((2.8, -3.5, 1.05), target),
    }
    for name, (location, aim) in views.items():
        make_camera(name, location, aim, os.path.join(a.output_dir, name + ".png"))

    report_out = {
        "status": report["status"],
        "purpose": "diagnostic torso-shell clearance test; not a production garment",
        "source_body": "Wren",
        "armature_bones": len(armature.data.bones),
        "selected_body_faces": len(selected_faces),
        "shell_vertices": len(fitted),
        "shell_faces": len(faces),
        "body_modified": False,
        "solver_report": report,
        "views": ["front.png", "side.png", "threequarter.png"],
    }
    with open(os.path.join(a.output_dir, "fit-report.json"), "w", encoding="utf-8") as f:
        json.dump(report_out, f, indent=2)
    print("GARMENT_PREVIEW " + json.dumps({"status": report["status"], "vertices": len(fitted), "faces": len(faces)}))


if __name__ == "__main__":
    main()
