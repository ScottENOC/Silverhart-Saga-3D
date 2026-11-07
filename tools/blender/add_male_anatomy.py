"""Sculpt adult male external anatomy directly into the existing Ara skin mesh.

The penis, glans and scrotum are integrated surface forms, not attached objects.
Ara GLB axes after Blender import: Z up, character facing -Y.
"""
import argparse
import os
import sys
import math
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--adult", action="store_true")
    p.add_argument("--voxel-size", type=float, default=0.0025)
    return p.parse_args(raw)


def material_name(obj):
    return " ".join(s.material.name.lower() for s in obj.material_slots if s.material)


def bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return Vector(tuple(min(p[i] for p in pts) for i in range(3))), Vector(tuple(max(p[i] for p in pts) for i in range(3)))


def find_skin(meshes):
    candidates = [o for o in meshes if "skin" in material_name(o)]
    if not candidates:
        raise RuntimeError("Could not identify Ara skin mesh/material")
    skin = max(candidates, key=lambda o: len(o.data.polygons))
    mat = next((s.material for s in skin.material_slots if s.material and "skin" in s.material.name.lower()), None)
    if mat is None:
        raise RuntimeError("Ara skin material is missing")
    return skin, mat


def pelvis_landmark_from_leg_roots(armature, height):
    """Find the hip-joint line from paired femur roots, not the Hips bone midpoint."""
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
        if bone is not None:
            found[side] = armature.matrix_world @ bone.head_local
    if len(found) != 2:
        relevant = ", ".join(b.name for b in armature.data.bones
                             if any(token in b.name.lower() for token in ("leg", "thigh", "upleg")))
        raise RuntimeError(
            "Cannot locate paired upper-leg roots for male anatomy placement. "
            f"Found {sorted(found)}; relevant rig bones: {relevant or 'none'}"
        )
    z = (found["left"].z + found["right"].z) * 0.5
    print(
        "Male pelvic landmark from paired upper-leg roots: "
        f"left={found['left'].z:.4f}, right={found['right'].z:.4f}, "
        f"centre={z:.4f}, character height={height:.4f}"
    )
    return z



def integrate_male_anatomy_into_skin(skin, anatomy_z, width, height):
    """Shape the existing Ara skin surface into flaccid male anatomy.

    The shaft, glans, scrotum and raphe are surface deformations of the body
    mesh, retaining its material, UVs, vertex groups and armature modifier.
    No separate genital object is created or attached.
    """
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    bm.normal_update()
    inv = skin.matrix_world.inverted()
    local_edges = []
    for edge in bm.edges:
        mid = (edge.verts[0].co + edge.verts[1].co) * 0.5
        world = skin.matrix_world @ mid
        normal = skin.matrix_world.to_3x3() @ (edge.verts[0].normal + edge.verts[1].normal)
        if normal.length:
            normal.normalize()
        if (normal.y < -0.12 and abs(world.x) < width * 0.20
                and abs(world.z - anatomy_z) < height * 0.12):
            local_edges.append(edge)
    if local_edges:
        bmesh.ops.subdivide_edges(bm, edges=local_edges, cuts=4, use_grid_fill=True)
        bm.normal_update()

    def g(x, z, cx, cz, sx, sz):
        return math.exp(-0.5 * (((x-cx)/sx)**2 + ((z-cz)/sz)**2))

    # Scale every dimension to the actual character, not a fixed-world-size prop.
    shaft_len = height * 0.075
    shaft_radius = width * 0.027
    shaft_top = anatomy_z + height * 0.010
    shaft_mid = shaft_top - shaft_len * 0.46
    shaft_tip = shaft_top - shaft_len * 0.88
    for v in bm.verts:
        p = skin.matrix_world @ v.co
        n = skin.matrix_world.to_3x3() @ v.normal
        if n.length:
            n.normalize()
        if n.y > -0.10 or abs(p.x) > width * 0.22 or abs(p.z-anatomy_z) > height*0.15:
            continue
        # The flaccid shaft rests downwards, close to the body, with a gentle
        # forward curve. Its proximal root fades smoothly into the pubic mound.
        root = g(p.x,p.z,0.0,shaft_top,width*0.040,height*0.020)
        shaft = g(p.x,p.z,0.0,shaft_mid,shaft_radius,height*0.043)
        distal = g(p.x,p.z,0.0,shaft_tip,shaft_radius*1.06,height*0.014)
        glans = g(p.x,p.z,0.0,shaft_tip-height*0.010,shaft_radius*1.12,height*0.012)
        corona = g(p.x,p.z,0.0,shaft_tip-height*0.021,shaft_radius*1.18,height*0.005)
        meatus = g(p.x,p.z,0.0,shaft_tip-height*0.010,shaft_radius*0.18,height*0.0025)
        scrotum = g(p.x,p.z,0.0,anatomy_z-height*0.052,width*0.075,height*0.030)
        testis_l = g(p.x,p.z,-width*0.026,anatomy_z-height*0.050,width*0.026,height*0.024)
        testis_r = g(p.x,p.z, width*0.026,anatomy_z-height*0.050,width*0.026,height*0.024)
        raphe = g(p.x,p.z,0.0,anatomy_z-height*0.052,width*0.004,height*0.026)
        # Continuous surface relief: no exposed sphere pair and no breadstick forms.
        outward = (0.010*root + 0.017*shaft + 0.020*distal
                   + 0.012*glans + 0.003*corona
                   + 0.013*scrotum + 0.003*(testis_l+testis_r))
        inward = 0.004*meatus + 0.002*raphe
        p.y -= outward
        p.y += inward
        v.co = inv @ p
    bm.normal_update()
    bm.to_mesh(skin.data)
    bm.free()
    skin.data.update()
    for poly in skin.data.polygons:
        poly.use_smooth = True
    skin["anatomy_profile"] = "adult_male_integrated_skin"
    skin["anatomy_method"] = "local_subdivision_and_surface_displacement"
    skin["anatomy_parts"] = "root,flaccid_shaft,glans,corona,meatus,scrotum,paired_testes,raphe"
    skin["review_status"] = "integrated_mesh_blockout_for_art_review"
    return skin


def main():
    args = arguments()
    if not args.adult:
        raise SystemExit("Refusing to add external genital anatomy without explicit --adult confirmation")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if not meshes or armature is None:
        raise RuntimeError("Expected Ara male meshes and game armature")
    skin, skin_material = find_skin(meshes)
    lo, hi = bounds(skin)
    height = hi.z - lo.z
    hipline_z = pelvis_landmark_from_leg_roots(armature, height)
    anatomy_z = hipline_z - height * 0.035
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = skin.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    verts = [skin.matrix_world @ v.co for v in mesh.vertices]
    faces = [list(p.vertices) for p in mesh.polygons]
    tree = BVHTree.FromPolygons(verts, faces, all_triangles=False)
    evaluated.to_mesh_clear()
    hit, _normal, _index, _distance = tree.ray_cast(
        Vector((0.0, -2.0, anatomy_z)), Vector((0.0, 1.0, 0.0)), 4.0)
    if hit is None:
        raise RuntimeError("Could not locate front pelvis surface on Ara male body")
    integrate_male_anatomy_into_skin(skin, anatomy_z, hi.x - lo.x, height)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False, export_animations=True)
    print("Exported integrated male skin sculpt; inspect front, side and three-quarter views.")


if __name__ == "__main__":
    main()
