#!/usr/bin/env python3
"""Generate and render a diagnostic torso-clearance shell on Wren.

This is deliberately NOT a production garment. It extracts a torso surface
patch from Wren's own body mesh, offsets it, runs the clearance solver, and
renders the result so the solver can be validated before real garment panels
are introduced.
"""
import argparse
import csv
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
    body.data.calc_loop_triangles()
    surface_triangles = [tuple(triangle.vertices) for triangle in body.data.loop_triangles]
    tree = BVHTree.FromPolygons(world_vertices, [list(t) for t in surface_triangles], all_triangles=True)
    if tree is None:
        raise RuntimeError("Could not build triangulated body BVH")

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

    normal_matrix = body.matrix_world.to_3x3().inverted().transposed()

    # Start 5 mm outside the body along correctly transformed smooth normals.
    start_world = []
    for old in used:
        vertex = body.data.vertices[old]
        normal = (normal_matrix @ vertex.normal).normalized()
        start_world.append(tuple(world_vertices[old] + normal * 0.005))

    def interpolated_smooth_normal(triangle_index, location):
        # BVH face indices map directly to the triangulated surface list.
        indices = surface_triangles[triangle_index]
        a, b, c = (world_vertices[index] for index in indices)
        p = Vector(location)
        ab, ac, ap = b - a, c - a, p - a
        d00, d01, d11 = ab.dot(ab), ab.dot(ac), ac.dot(ac)
        d20, d21 = ap.dot(ab), ap.dot(ac)
        denom = d00 * d11 - d01 * d01
        if abs(denom) <= 1e-18:
            raise RuntimeError(f"Degenerate body triangle {triangle_index}")
        v = (d11 * d20 - d01 * d21) / denom
        w = (d00 * d21 - d01 * d20) / denom
        u = 1.0 - v - w
        local_normal = (
            body.data.vertices[indices[0]].normal * u
            + body.data.vertices[indices[1]].normal * v
            + body.data.vertices[indices[2]].normal * w
        )
        if local_normal.length_squared <= 1e-16:
            raise RuntimeError(f"Degenerate interpolated normal on triangle {triangle_index}")
        return (normal_matrix @ local_normal.normalized()).normalized()

    def query(point):
        hit = tree.find_nearest(Vector(point))
        if hit is None or hit[0] is None or hit[1] is None or hit[2] is None:
            return None
        location, _face_normal, triangle_index, _distance = hit
        return tuple(location), tuple(interpolated_smooth_normal(triangle_index, location))

    # Diagnose whether nearest-point queries jump to a different nearby body
    # region. A shell point derived from a body vertex should normally hit the
    # same vertex's local one-ring, not an unrelated surface across a fold.
    body_neighbours = [set() for _ in body.data.vertices]
    for edge in body.data.edges:
        left, right = edge.vertices
        body_neighbours[left].add(right)
        body_neighbours[right].add(left)

    initial_signed = []
    initial_distances = []
    normal_alignment = []
    source_normal_alignment = []
    hit_topology = {"same_vertex": 0, "one_ring": 0, "nonlocal": 0}
    diagnostic_rows = []
    for old, point in zip(used, start_world):
        raw_hit = tree.find_nearest(Vector(point))
        hit = query(point)
        if hit is None or raw_hit is None:
            continue
        nearest, query_normal = hit
        delta = Vector(point) - Vector(nearest)
        triangle_index = raw_hit[2]
        hit_vertices = set(surface_triangles[triangle_index])
        if old in hit_vertices:
            topology = "same_vertex"
        elif hit_vertices.intersection(body_neighbours[old]):
            topology = "one_ring"
        else:
            topology = "nonlocal"
        hit_topology[topology] += 1
        raw_face_normal = raw_hit[1].normalized()
        source_normal = (normal_matrix @ body.data.vertices[old].normal).normalized()
        signed = delta.dot(Vector(query_normal))
        initial_signed.append(signed)
        initial_distances.append(delta.length)
        normal_alignment.append(Vector(query_normal).dot(Vector(raw_face_normal)))
        source_dot = Vector(query_normal).dot(source_normal)
        source_normal_alignment.append(source_dot)
        diagnostic_rows.append({
            "source_vertex": old,
            "hit_triangle": triangle_index,
            "hit_vertices": ",".join(str(i) for i in surface_triangles[triangle_index]),
            "topology": topology,
            "signed_clearance_m": float(signed),
            "nearest_distance_m": float(delta.length),
            "source_to_hit_distance_m": float((Vector(world_vertices[old]) - Vector(nearest)).length),
            "query_vs_source_normal_dot": float(source_dot),
            "delta_vs_source_normal_dot": float(delta.normalized().dot(source_normal)) if delta.length > 1e-12 else 0.0,
            "source_x": float(world_vertices[old].x),
            "source_y": float(world_vertices[old].y),
            "source_z": float(world_vertices[old].z),
        })

    diagnostic_rows.sort(key=lambda row: row["signed_clearance_m"])
    csv_path = os.path.join(a.output_dir, "initial-clearance-diagnostics.csv")
    with open(csv_path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(diagnostic_rows[0].keys()))
        writer.writeheader()
        writer.writerows(diagnostic_rows)

    def metric_summary(values):
        ordered = sorted(values)
        if not ordered:
            return {"min": None, "median": None, "p95": None, "max": None}
        return {
            "min": ordered[0],
            "median": ordered[len(ordered) // 2],
            "p95": ordered[min(len(ordered) - 1, int(round((len(ordered) - 1) * 0.95)))],
            "max": ordered[-1],
        }

    initial_diagnostics = {
        "signed_clearance_m": metric_summary(initial_signed),
        "nearest_distance_m": metric_summary(initial_distances),
        "raw_face_vs_smooth_query_normal_dot": metric_summary(normal_alignment),
        "raw_face_normals_opposed_to_smooth": sum(value < 0.0 for value in normal_alignment),
        "raw_face_normals_oblique_to_smooth": sum(value < 0.5 for value in normal_alignment),
        "query_vs_source_normal_dot": metric_summary(source_normal_alignment),
        "nearest_hit_topology": hit_topology,
        "nonlocal_nearest_hits": hit_topology["nonlocal"],
        "measured_vertices": len(initial_signed),
        "per_vertex_csv": "initial-clearance-diagnostics.csv",
    }

    fitted, report = fit_clearance(
        start_world, edges, query,
        FitConfig(target_clearance=a.clearance_mm / 1000.0,
                  max_vertex_displacement=0.025, max_step=0.003,
                  smoothing=0.2, max_iterations=20,
                  floating_tolerance=0.015)
    )
    # Always render the fitted geometry, including failed fits. The report keeps
    # the solver status so a diagnostic image can be inspected without implying
    # that clearance validation passed.

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
    scene.render.engine = "BLENDER_EEVEE"
    if hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
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
        "initial_diagnostics": initial_diagnostics,
        "solver_report": report,
        "views": ["front.png", "side.png", "threequarter.png"],
    }
    with open(os.path.join(a.output_dir, "fit-report.json"), "w", encoding="utf-8") as f:
        json.dump(report_out, f, indent=2)
    print("GARMENT_PREVIEW " + json.dumps({"status": report["status"], "vertices": len(fitted), "faces": len(faces)}))


if __name__ == "__main__":
    main()
