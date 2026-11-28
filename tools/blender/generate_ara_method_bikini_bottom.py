#!/usr/bin/env python3
"""Independent, single-pass reconstruction of Ara's string-bikini bottom.

This ports the construction method (front/back projected panels, underside
gusset, normal lift, edge piping and hip cords) into Blender Python. It does
not import, call, or copy Ara's implementation at runtime.

Input is a body-only Ara GLB so the reference proportions and coordinate
system match the original design. Blender's glTF importer maps Ara +Y-up/+Z-
front to Z-up/-Y-front; this script works in Blender world coordinates.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree


def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True, help="Body-only Ara GLB")
    p.add_argument("--output-glb", required=True)
    p.add_argument("--report", required=True)
    p.add_argument("--clearance-mm", type=float, default=3.0)
    return p.parse_args(raw)


def cm(value):
    # Ara's cm() returns decimetres; exported GLB coordinates are metres.
    return value * 0.001


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def find_body():
    candidates = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not candidates:
        raise RuntimeError("Input GLB contains no mesh")
    return max(candidates, key=lambda o: len(o.data.polygons))


def hip_height(body):
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if armature:
        names = ("upperleg01.L", "upperleg01.R", "upperleg01_L", "upperleg01_R")
        values = []
        for name in names:
            bone = armature.data.bones.get(name)
            if bone:
                values.append((armature.matrix_world @ bone.head_local).z)
        if len(values) >= 2:
            return sum(values) / len(values)
    # Fallback for exports without an armature: use the lower torso landmark.
    zs = sorted((body.matrix_world @ v.co).z for v in body.data.vertices)
    return zs[int(len(zs) * 0.54)]


def body_surface(body, hip_z):
    verts = [body.matrix_world @ v.co for v in body.data.vertices]
    # Ara's keep() selects trunk and the proximal 15% of upper legs. The
    # body-only GLB has no exported semantic REGION array, so reproduce that
    # mask geometrically around the hip/crotch region, not by using all skin.
    midline = [
        p.z for p in verts
        if abs(p.x) <= 0.015 and hip_z - 0.38 <= p.z <= hip_z + 0.04
    ]
    if not midline:
        raise RuntimeError("Could not identify the central crotch landmark")
    crotch_z = min(midline)
    low_z = crotch_z - 0.025
    high_z = hip_z + 0.17
    selected = []
    for poly in body.data.polygons:
        c = body.matrix_world @ poly.center
        if low_z <= c.z <= high_z and abs(c.x) <= 0.20:
            selected.append(list(poly.vertices))
    if len(selected) < 100:
        raise RuntimeError("Pelvic ray-cast region is unexpectedly small: %d faces" % len(selected))
    # Keep original vertex indices so nearest-skin projection and normals can
    # use the full source surface. The BVH itself contains only the selected
    # trunk/proximal-thigh region.
    bvh = BVHTree.FromPolygons(verts, selected, all_triangles=True)
    if bvh is None:
        raise RuntimeError("Could not build pelvic surface ray caster")
    normals = [(body.matrix_world.to_3x3() @ body.data.vertices[i].normal).normalized() for i in range(len(verts))]
    tree = KDTree(len(verts))
    for i, p in enumerate(verts):
        tree.insert(p, i)
    tree.balance()
    return verts, normals, selected, bvh, tree, crotch_z


def cast_axis(bvh, x, z, direction):
    # Front/back rays travel along depth (Y); underside rays travel upward (Z).
    if direction == "front":
        origin, ray = Vector((x, 1.5, z)), Vector((0, -1, 0))
    elif direction == "back":
        origin, ray = Vector((x, -1.5, z)), Vector((0, 1, 0))
    elif direction == "below":
        origin, ray = Vector((x, 0.0, -0.5)), Vector((0, 0, 1))
    else:
        raise ValueError(direction)
    hit, normal, face, distance = bvh.ray_cast(origin, ray, 3.0)
    return tuple(hit) if hit is not None else None


def grid_panel(bvh, hip_z, crotch_z, side):
    rows, cols = 16, 15
    low = crotch_z + cm(3.0)
    top = hip_z + (cm(7.5) if side == "front" else cm(9.5))

    def half_width(v):
        return cm(1.8) + cm(9.5) * v ** 1.25 if side == "front" else cm(2.0) + cm(11.0) * v ** 0.7

    def top_edge(u):
        return top + (cm(1.2) if side == "front" else cm(1.8)) * u * u

    grid = []
    for i in range(rows):
        v = i / (rows - 1)
        row = []
        for j in range(cols):
            u = (j / (cols - 1)) * 2.0 - 1.0
            x = u * half_width(v)
            z = low + (top_edge(u) - low) * v
            hit = cast_axis(bvh, x, z, side)
            if hit is None:
                raise RuntimeError("%s panel ray missed body at row=%d col=%d" % (side, i, j))
            row.append(hit)
        grid.append(row)
    return grid


def lift_grid(grid, offset, outward, smooth=2):
    g = [[Vector(p) for p in row] for row in grid]
    rows, cols = len(g), len(g[0])
    # Ara first relaxes the outline, preserving its four corners.
    loop = [(0, j) for j in range(cols)]
    loop += [(i, cols - 1) for i in range(1, rows)]
    loop += [(rows - 1, j) for j in range(cols - 2, -1, -1)]
    loop += [(i, 0) for i in range(rows - 2, 0, -1)]
    corners = {(0, 0), (0, cols - 1), (rows - 1, cols - 1), (rows - 1, 0)}
    for _ in range(6):
        old = {(i, j): g[i][j].copy() for i, j in loop}
        for k, (i, j) in enumerate(loop):
            if (i, j) in corners:
                continue
            a = old[loop[(k - 1) % len(loop)]]
            b = old[loop[(k + 1) % len(loop)]]
            g[i][j] = old[(i, j)] * 0.5 + (a + b) * 0.25
    # Interior Laplacian smoothing. Keep the surface on/outside the original
    # ray-cast surface along the panel's outward axis.
    for _ in range(smooth):
        old = [[p.copy() for p in row] for row in g]
        for i in range(1, rows - 1):
            for j in range(1, cols - 1):
                q = old[i][j] * 0.5 + (
                    old[i - 1][j] + old[i + 1][j] + old[i][j - 1] + old[i][j + 1]
                ) * 0.125
                original = Vector(grid[i][j])
                under = (original - q).dot(outward)
                g[i][j] = q + outward * under if under > 0 else q
    # Offset along the generated garment normal, oriented outward.
    result = []
    for i in range(rows):
        row = []
        for j in range(cols):
            du = g[i][min(cols - 1, j + 1)] - g[i][max(0, j - 1)]
            dv = g[min(rows - 1, i + 1)][j] - g[max(0, i - 1)][j]
            n = du.cross(dv)
            if n.length < 1e-9:
                n = outward.copy()
            else:
                n.normalize()
                if n.dot(outward) < 0:
                    n.negate()
                if n.dot(outward) < 0.25:
                    n = (n + outward).normalized()
            row.append(g[i][j] + n * offset)
        result.append(row)
    return result


def grid_outline(grid):
    rows, cols = len(grid), len(grid[0])
    return ([p for p in grid[0]]
            + [grid[i][-1] for i in range(1, rows)]
            + [grid[-1][j] for j in range(cols - 2, -1, -1)]
            + [grid[i][0] for i in range(rows - 2, 0, -1)])


def make_grid_object(name, grid, material):
    rows, cols = len(grid), len(grid[0])
    verts = [tuple(p) for row in grid for p in row]
    faces = []
    for i in range(rows - 1):
        for j in range(cols - 1):
            a = i * cols + j
            faces.append((a, a + 1, a + cols + 1, a + cols))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def spline(keys, per_span=10):
    out = []
    for i in range(len(keys) - 1):
        p0, p1 = Vector(keys[max(0, i - 1)]), Vector(keys[i])
        p2, p3 = Vector(keys[i + 1]), Vector(keys[min(len(keys) - 1, i + 2)])
        for k in range(per_span):
            t = k / per_span
            t2, t3 = t * t, t * t * t
            p = 0.5 * (2 * p1 + (-p0 + p2) * t + (2*p0 - 5*p1 + 4*p2 - p3) * t2 + (-p0 + 3*p1 - 3*p2 + p3) * t3)
            out.append(p)
    out.append(Vector(keys[-1]))
    return out


def nearest_laid_line(points, verts, normals, tree, offset, passes=6):
    line = [Vector(p) for p in points]
    sides = []
    for p in line:
        co, index, dist = tree.find(p)
        ny = normals[index].y
        sides.append(0 if abs(ny) < 0.15 else (1 if ny > 0 else -1))

    def snap(p, side):
        co, index, dist = tree.find(p)
        if side and abs(normals[index].y) > 0.15 and (1 if normals[index].y > 0 else -1) != side:
            # Search the closest same-facing surface vertex rather than snapping
            # a cord through the body to the opposite side.
            candidates = []
            for i, q in enumerate(verts):
                ny = normals[i].y
                if abs(ny) > 0.15 and (1 if ny > 0 else -1) == side:
                    candidates.append((p - q).length_squared, i)
            if candidates:
                _, index = min(candidates)
                co = verts[index]
        n = normals[index].normalized()
        return p + n * (offset - (p - co).dot(n))

    for _ in range(passes):
        old = [p.copy() for p in line]
        for i in range(1, len(line) - 1):
            smooth = (old[i - 1] + old[i] * 2 + old[i + 1]) * 0.25
            line[i] = snap(smooth, sides[i])
    return line


def make_cord(name, points, radius, material, cyclic=False):
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    spline_data = curve.splines.new("POLY")
    spline_data.points.add(len(points) - 1)
    for p, co in zip(spline_data.points, points):
        p.co = (co[0], co[1], co[2], 1)
    spline_data.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def make_bow(prefix, centre, outward, radius, material):
    p = Vector(centre)
    out = Vector(outward).normalized()
    up = Vector((0, 0, 1))
    x = up.cross(out).normalized()
    y = out.cross(x).normalized()
    made = []
    for sign in (1, -1):
        loop = []
        for i in range(33):
            a = i / 32 * math.tau
            q = p + x * (sign * (radius * 1.1 + math.cos(a) * radius * 1.1)) + y * (math.sin(a) * radius * 0.55) + out * 0.0015
            loop.append(q)
        made.append(make_cord(prefix + "Loop" + str(sign), loop, cm(0.11), material, True))
        tail = [p + x * (sign * radius * 0.6) - y * radius * 2.6 + out * 0.001,
                p + x * (sign * radius * 0.9) - y * radius * 4.5]
        made.append(make_cord(prefix + "Tail" + str(sign), spline([p, *tail], 6), cm(0.1), material))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1, location=p + out * 0.0015)
    knot = bpy.context.object
    knot.name = prefix + "Knot"
    knot.scale = (radius * 0.35, radius * 0.3, radius * 0.2)
    knot.data.materials.append(material)
    made.append(knot)
    return made


def make_material():
    mat = bpy.data.materials.new("Bikini bottom - Ara default gold foil")
    mat.diffuse_color = (0.78, 0.48, 0.12, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.78, 0.48, 0.12, 1)
    bsdf.inputs["Metallic"].default_value = 0.7
    bsdf.inputs["Roughness"].default_value = 0.32
    return mat


def main():
    args = parse_args()
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    body = find_body()
    hip_z = hip_height(body)
    verts, normals, selected, bvh, tree, crotch_z = body_surface(body, hip_z)
    front = grid_panel(bvh, hip_z, crotch_z, "front")
    back = grid_panel(bvh, hip_z, crotch_z, "back")

    # Ara's gusset joins the bottom rows by casting upward from below.
    gusset = []
    for k in range(9):
        t = k / 8
        row = []
        for fp, bp in zip(front[0], back[0]):
            x = fp[0] + (bp[0] - fp[0]) * t
            y = fp[1] + (bp[1] - fp[1]) * t
            hit = cast_axis(bvh, x, 0, "below")
            # The below caster's second coordinate is depth; cast_axis's
            # ordinary z parameter is adapted here to retain each interpolated
            # depth coordinate as its ray's cross-plane coordinate.
            origin = Vector((x, y, -0.5))
            hitp, normal, face, distance = bvh.ray_cast(origin, Vector((0, 0, 1)), 3.0)
            row.append(tuple(hitp) if hitp is not None else (x, y, fp[2] + (bp[2] - fp[2]) * t))
        gusset.append(row)

    clearance = args.clearance_mm / 1000.0
    lf = lift_grid(front, clearance, Vector((0, -1, 0)), 2)
    lb = lift_grid(back, clearance, Vector((0, 1, 0)), 2)
    lg = lift_grid(gusset, clearance, Vector((0, 0, -1)), 1)
    material = make_material()
    make_grid_object("AraMethod_BikiniBottom_FrontPanel", lf, material)
    make_grid_object("AraMethod_BikiniBottom_BackPanel", lb, material)
    make_grid_object("AraMethod_BikiniBottom_Gusset", lg, material)

    # Panel piping follows the lifted panel outlines, just as Ara's cord().
    cord_mat = material
    make_cord("AraMethod_BikiniBottom_FrontPiping", grid_outline(lf), cm(0.1), cord_mat, True)
    make_cord("AraMethod_BikiniBottom_BackPiping", grid_outline(lb), cm(0.1), cord_mat, True)

    # Hip strings: convex side extent of the body at hip + 13 cm, with 3 mm
    # stand-off; the two paths are smoothed and laid back onto the matching side.
    y_side = hip_z + cm(13.0)
    slab_points = [p for p in verts if abs(p.z - y_side) <= cm(1.5)]
    if len(slab_points) < 3:
        raise RuntimeError("Could not find the hip-level cross-section for side ties")
    for sign in (1, -1):
        fc = Vector(front[-1][-1 if sign > 0 else 0])
        bc = Vector(back[-1][-1 if sign > 0 else 0])
        side_v = max(slab_points, key=lambda p: p.x * sign)
        side = side_v + Vector((sign * cm(0.3), 0, 0))
        keys = [fc, fc.lerp(side, 0.55), side, bc.lerp(side, 0.55), bc]
        path = nearest_laid_line(spline(keys, 10), verts, normals, tree, cm(0.3))
        make_cord("AraMethod_BikiniBottom_HipTie_" + str(sign), path, cm(0.14), cord_mat)
        make_bow("AraMethod_BikiniBottom_Bow_" + str(sign), side, (sign, 0, 0.15), cm(1.5), cord_mat)

    # Render the pelvis and garment from front, back and side for visual comparison.
    preview_dir = os.path.join(os.path.dirname(os.path.abspath(args.output_glb)), "preview")
    os.makedirs(preview_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    target = Vector((0.0, 0.0, hip_z + 0.035))
    for view, location in (
        ("front", (0.0, -2.5, hip_z + 0.035)),
        ("back", (0.0, 2.5, hip_z + 0.035)),
        ("side", (2.5, 0.0, hip_z + 0.035)),
    ):
        camera_data = bpy.data.cameras.new("AraMethodReview_" + view)
        camera = bpy.data.objects.new("AraMethodReview_" + view, camera_data)
        scene.collection.objects.link(camera)
        camera.location = location
        camera.data.type = "ORTHO"
        camera.data.ortho_scale = 0.78
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.camera = camera
        scene.render.filepath = os.path.join(preview_dir, view + ".png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(camera, do_unlink=True)
        bpy.data.cameras.remove(camera_data)

    # Keep the source body intact. Garment pieces are independent objects.
    os.makedirs(os.path.dirname(os.path.abspath(args.output_glb)), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output_glb),
                              export_format="GLB", use_selection=False,
                              export_apply=True)

    report = {
        "method": "independent single-pass Ara swimwear construction port",
        "source_body": body.name,
        "body_geometry_modified": False,
        "body_hidden_or_deleted": False,
        "solver_or_simulation_used": False,
        "front_panel_grid": [16, 15],
        "back_panel_grid": [16, 15],
        "gusset_grid": [9, 15],
        "surface_lift_mm": args.clearance_mm,
        "selected_pelvic_faces": len(selected),
        "region_mask": "geometric approximation of Ara trunk plus proximal upper-leg REGION filter; semantic region labels are not present in the GLB",
        "hip_ring": "lateral cross-section extreme approximation of Ara convex hull ring",
        "hip_height_m": hip_z,
        "crotch_height_m": crotch_z,
        "garment_objects": sorted(o.name for o in bpy.context.scene.objects
                                  if o.name.startswith("AraMethod_BikiniBottom_")),
        "preview_images": ["preview/front.png", "preview/back.png", "preview/side.png"],
        "output_glb": os.path.abspath(args.output_glb),
    }
    with open(args.report, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print("ARA_METHOD_BIKINI_BOTTOM_OK " + json.dumps(report))


if __name__ == "__main__":
    main()
