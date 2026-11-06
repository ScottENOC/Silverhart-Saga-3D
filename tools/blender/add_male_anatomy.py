"""Build a separate, skin-matched male external anatomy component for an adult Ara GLB.

The penis and scrotum are one continuous remeshed body-part object, independently
skinned to the canonical Hips bone. The root is buried slightly into the pelvis.
This is a reviewable blockout; proportions and deformation require visual review.
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


def make_shaft(cx, cy, cz, length, radius, segments=32):
    verts, faces = [], []
    # Flaccid resting axis: predominantly downward (-Z), with only a slight
    # forward (-Y) component. The proximal rings sit inside the pelvis so the
    # join is not a flat cap at the skin. Avoid an erect, forward-projecting pose.
    profile = [
        (-0.025, 0.50), (-0.010, 0.78), (0.012, 0.92),
        (0.035, 1.00), (0.58, 0.94), (0.78, 1.00),
        (0.88, 1.08), (0.94, 0.94), (1.00, 0.55),
    ]
    for t, r in profile:
        y = cy - length * t * 0.22
        z = cz - length * t * 0.88
        for j in range(segments):
            a = 2.0 * math.pi * j / segments
            verts.append((cx + math.cos(a) * radius * r,
                          y,
                          z + math.sin(a) * radius * r * 0.88))
    for ring in range(len(profile) - 1):
        for j in range(segments):
            a = ring * segments + j
            b = ring * segments + (j + 1) % segments
            c = (ring + 1) * segments + (j + 1) % segments
            d = (ring + 1) * segments + j
            faces.append((a, b, c, d))
    faces.append(tuple(range(segments - 1, -1, -1)))
    start = (len(profile) - 1) * segments
    faces.append(tuple(start + j for j in range(segments)))
    mesh = bpy.data.meshes.new("Male anatomy shaft source")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Male anatomy shaft source", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def add_ellipsoid(name, location, scale):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=28, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def build_component(armature, skin, skin_material, anatomy_z, front_y, height, voxel_size):
    length = max(0.080, min(0.105, height * 0.058))
    radius = max(0.012, min(0.015, height * 0.0085))
    cx, cy, cz = 0.0, front_y + 0.010, anatomy_z + height * 0.012

    parts = [make_shaft(cx, cy, cz, length, radius)]
    # Scrotal sac hangs below the penile root, independent of the shaft's
    # slight forward angle. Two subtle lobes are fused into
    # one continuous silhouette by voxel remeshing rather than left as spheres.
    sac_y = front_y - 0.010
    sac_z = anatomy_z - height * 0.010
    parts.append(add_ellipsoid("Scrotum left source", (-radius * 0.72, sac_y, sac_z),
                               (radius * 0.90, radius * 1.00, height * 0.027)))
    parts.append(add_ellipsoid("Scrotum right source", (radius * 0.72, sac_y, sac_z),
                               (radius * 0.90, radius * 1.00, height * 0.027)))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    anatomy = bpy.context.object
    anatomy.name = "Body_Genital_Male"
    anatomy.data.name = "Body_Genital_Male_Mesh"
    anatomy.data.remesh_voxel_size = voxel_size
    bpy.ops.object.voxel_remesh()
    smooth = anatomy.modifiers.new("Anatomy surface relax", "SMOOTH")
    smooth.factor = 0.65
    smooth.iterations = 4
    bpy.context.view_layer.objects.active = anatomy
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    for poly in anatomy.data.polygons:
        poly.use_smooth = True

    # Geometry was authored in world coordinates from the evaluated skin surface.
    # Store it in the same object space/transform as Ara skin before skinning.
    inverse_skin = skin.matrix_world.inverted()
    for vertex in anatomy.data.vertices:
        vertex.co = inverse_skin @ vertex.co
    anatomy.matrix_world = skin.matrix_world.copy()

    anatomy.data.materials.clear()
    anatomy.data.materials.append(skin_material)
    hips = next((b for b in armature.data.bones if b.name.lower() in ("hips", "hip", "pelvis")), None)
    if hips is None:
        raise RuntimeError("Ara male rig has no Hips/Hip/Pelvis bone")
    group = anatomy.vertex_groups.new(name=hips.name)
    group.add(list(range(len(anatomy.data.vertices))), 1.0, "REPLACE")
    modifier = anatomy.modifiers.new("Canonical character rig", "ARMATURE")
    modifier.object = armature
    anatomy["anatomy_component"] = "male_external_genitalia"
    anatomy["anatomy_parts"] = "penis_and_scrotum"
    anatomy["anatomy_method"] = "separate_continuous_voxel_remeshed_skinned_body_part"
    anatomy["review_status"] = "adult_anatomy_blockout_for_art_review"
    anatomy["skin_material_source"] = skin_material.name
    return anatomy


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
    build_component(armature, skin, skin_material, anatomy_z, hit.y, height, args.voxel_size)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False, export_animations=True)
    print("Exported separate skinned male anatomy component; inspect front, side and three-quarter views.")


if __name__ == "__main__":
    main()
