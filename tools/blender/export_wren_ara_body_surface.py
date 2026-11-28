#!/usr/bin/env python3
"""Export the accepted Wren GLB as an Ara-compatible body surface.

The export contains the accepted skin surfaces plus all body-piercing meshes.
Piercings remain independent scene objects in the source/final GLB; their
triangles are additionally included in Ara's fitting/collision surface.
Coordinates are converted from Blender's imported glTF frame to Ara's
(+X lateral, +Y up, +Z front) frame and MakeHuman decimetres.
"""
import argparse
import gzip
import hashlib
import json
import os
import sys

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

REGION = {
    "head": 0, "neck": 1, "torso": 2, "hips": 3, "upperarm": 4,
    "lowerarm": 5, "hand": 6, "upperleg": 7, "lowerleg": 8, "foot": 9,
}
def args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input-glb", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--report", required=True)
    return p.parse_args(raw)

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def ara_point(p):
    # Blender importer frame: X lateral, Y depth (front is negative), Z up.
    # Ara frame: X lateral, Y up, Z front. Convert metres -> decimetres.
    return [float(p.x) * 10.0, float(p.z) * 10.0, float(-p.y) * 10.0]

def ara_normal(n):
    q = Vector((n.x, n.z, -n.y))
    if q.length:
        q.normalize()
    return [float(q.x), float(q.y), float(q.z)]

def region_for_bone(name):
    n = name.lower().replace("_", "")
    if n in ("hips", "pelvis", "root"): return REGION["hips"]
    if n.startswith(("spine", "chest", "breast", "clavicle")): return REGION["torso"]
    if n.startswith("neck"): return REGION["neck"]
    if n.startswith(("head", "jaw", "eye")): return REGION["head"]
    if "forearm" in n: return REGION["lowerarm"]
    if "shoulder" in n or n.endswith("arm"): return REGION["upperarm"]
    if "hand" in n or any(x in n for x in ("thumb", "index", "middle", "ring", "pinky")): return REGION["hand"]
    if "upleg" in n or "thigh" in n: return REGION["upperleg"]
    if n.endswith("leg"): return REGION["lowerleg"]
    if "foot" in n or "toe" in n: return REGION["foot"]
    return 255

def vertex_regions(obj):
    group_names = {g.index: g.name for g in obj.vertex_groups}
    out = []
    for vertex in obj.data.vertices:
        best_weight, best_region = 0.0, 255
        for membership in vertex.groups:
            region = region_for_bone(group_names.get(membership.group, ""))
            if region != 255 and membership.weight > best_weight:
                best_weight, best_region = membership.weight, region
        out.append(best_region)
    return out

def has_material(obj, wanted):
    return any(slot.material and slot.material.name.lower() in wanted for slot in obj.material_slots)

def add_mesh(obj, coords, normals, regions, face_sizes, face_verts, forced_region=None, nearest_tree=None, nearest_regions=None):
    mesh = obj.data
    mesh.update()
    offset = len(coords) // 3
    local_regions = vertex_regions(obj)
    for i, vertex in enumerate(mesh.vertices):
        world = obj.matrix_world @ vertex.co
        coords.extend(ara_point(world))
        normal = obj.matrix_world.to_3x3() @ vertex.normal
        normals.extend(ara_normal(normal))
        region = forced_region if forced_region is not None else local_regions[i]
        if region == 255 and nearest_tree is not None:
            q = Vector(ara_point(world))
            _co, nearest, _dist = nearest_tree.find(q)
            if nearest is not None:
                region = nearest_regions[nearest]
        regions.append(region)
    for poly in mesh.polygons:
        if len(poly.vertices) < 3 or len(poly.vertices) > 255:
            raise RuntimeError("Unsupported polygon size %d in %s" % (len(poly.vertices), obj.name))
        face_sizes.append(len(poly.vertices))
        face_verts.extend(offset + int(v) for v in poly.vertices)

def bone_world(armature, bone_name, tail=False):
    bone = armature.data.bones.get(bone_name)
    if bone is None:
        raise RuntimeError("Required Wren rig bone is missing: " + bone_name)
    local = bone.tail_local if tail else bone.head_local
    return ara_point(armature.matrix_world @ local)

def main():
    opt = args()
    source_path = os.path.abspath(opt.input_glb)
    bpy.ops.import_scene.gltf(filepath=source_path)
    objects = list(bpy.context.scene.objects)
    armatures = [o for o in objects if o.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError("Expected exactly one Wren armature, found %d" % len(armatures))
    armature = armatures[0]

    skin_objects = [
        o for o in objects if o.type == "MESH"
        and has_material(o, {"skin_anatomy", "skin details"})
    ]
    anatomy_objects = [o for o in skin_objects if has_material(o, {"skin_anatomy"})]
    if not anatomy_objects:
        raise RuntimeError("Accepted Wren GLB has no Skin_Anatomy surface")
    piercing_objects = [
        o for o in objects if o.type == "MESH"
        and (o.name.lower().startswith("piercing")
             or has_material(o, {"ara_piercing_silver", "piercing"}))
    ]
    if not piercing_objects:
        raise RuntimeError("No independent body-piercing meshes found in accepted Wren GLB")

    coords, normals, regions, face_sizes, face_verts = [], [], [], [], []
    skin_names = []
    for obj in anatomy_objects:
        add_mesh(obj, coords, normals, regions, face_sizes, face_verts)
        skin_names.append(obj.name)
    anatomy_count = len(coords) // 3
    if anatomy_count == 0:
        raise RuntimeError("Accepted Wren anatomical skin mesh is empty")

    # Use the weighted anatomical skin as the nearest-region reference for
    # detail meshes and accessories which do not carry reliable skin weights.
    tree = KDTree(anatomy_count)
    for i in range(anatomy_count):
        tree.insert(Vector((coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2])), i)
    tree.balance()
    anatomy_regions = list(regions)
    detail_objects = [o for o in skin_objects if o not in anatomy_objects]
    for obj in detail_objects:
        add_mesh(obj, coords, normals, regions, face_sizes, face_verts,
                 nearest_tree=tree, nearest_regions=anatomy_regions)
        skin_names.append(obj.name)
    skin_count = len(coords) // 3
    skin_regions = list(regions)

    piercing_names = []
    nipple_left_points = []
    nipple_right_points = []
    for obj in piercing_objects:
        name = obj.name.lower()
        is_nipple = "nipple" in name
        forced = REGION["torso"] if is_nipple else None
        start = len(coords) // 3
        add_mesh(obj, coords, normals, regions, face_sizes, face_verts,
                 forced_region=forced, nearest_tree=tree, nearest_regions=skin_regions)
        piercing_names.append(obj.name)
        if is_nipple and ("_l_" in name or "left" in name):
            if "bar" in name:
                nipple_left_points.extend(
                    ara_point(obj.matrix_world @ v.co) for v in obj.data.vertices
                )
        if is_nipple and ("_r_" in name or "right" in name):
            if "bar" in name:
                nipple_right_points.extend(
                    ara_point(obj.matrix_world @ v.co) for v in obj.data.vertices
                )
        if len(coords) // 3 <= start:
            raise RuntimeError("Piercing mesh contributed no surface vertices: " + obj.name)

    if not nipple_left_points and not nipple_right_points:
        raise RuntimeError("No nipple piercing landmark found; cannot anchor Ara's breast cup construction")
    mean = lambda pts: [sum(p[i] for p in pts) / len(pts) for i in range(3)]
    left_nipple = mean(nipple_left_points) if nipple_left_points else None
    right_nipple = mean(nipple_right_points) if nipple_right_points else None
    if left_nipple is None:
        left_nipple = [-right_nipple[0], right_nipple[1], right_nipple[2]]
    if right_nipple is None:
        right_nipple = [-left_nipple[0], left_nipple[1], left_nipple[2]]

    joint_map = {
        "upperleg01.L____head": ("LeftUpLeg", False),
        "upperleg01.R____head": ("RightUpLeg", False),
        "lowerleg01.L____head": ("LeftLeg", False),
        "lowerleg01.R____head": ("RightLeg", False),
        "foot.L____head": ("LeftFoot", False),
        "foot.R____head": ("RightFoot", False),
        "toe3-1.L____head": ("LeftToeBase", False),
        "toe3-1.R____head": ("RightToeBase", False),
        "upperarm01.L____head": ("LeftArm", False),
        "upperarm01.R____head": ("RightArm", False),
        "lowerarm01.L____head": ("LeftForeArm", False),
        "lowerarm01.R____head": ("RightForeArm", False),
        "wrist.L____head": ("LeftHand", False),
        "wrist.R____head": ("RightHand", False),
        "finger3-3.L____head": ("LeftHandMiddle3", False),
        "finger3-3.R____head": ("RightHandMiddle3", False),
        "neck01____head": ("Neck", False),
    }
    joints = {key: bone_world(armature, bone, tail) for key, (bone, tail) in joint_map.items()}
    joints["breast.L____tail"] = left_nipple
    joints["breast.R____tail"] = right_nipple

    unknown = sum(1 for r in regions[:skin_count] if r == 255)
    if unknown / max(1, skin_count) > 0.08:
        raise RuntimeError("Too many accepted skin vertices lack semantic bone regions: %d/%d" % (unknown, skin_count))

    surface = {
        "schema": 1,
        "source_glb": source_path,
        "source_sha256": sha256(source_path),
        "coordinate_system": "Ara XYZ, decimetres",
        "coords": coords,
        "normals": normals,
        "regions": regions,
        "faceSizes": face_sizes,
        "faceVerts": face_verts,
        "jointPositions": joints,
        "skinObjects": skin_names,
        "piercingObjects": piercing_names,
        "piercingLandmarks": {"leftNipple": left_nipple, "rightNipple": right_nipple},
        "skinVertexCount": skin_count,
        "totalSurfaceVertexCount": len(coords) // 3,
        "faceCount": len(face_sizes),
        "unknownSkinRegionVertexCount": unknown,
    }
    os.makedirs(os.path.dirname(os.path.abspath(opt.output)), exist_ok=True)
    with gzip.open(opt.output, "wt", encoding="utf-8", compresslevel=9) as f:
        json.dump(surface, f, separators=(",", ":"))
    report = {k: v for k, v in surface.items() if k not in ("coords", "normals", "regions", "faceSizes", "faceVerts", "jointPositions")}
    report["jointPositions"] = joints
    report["surface_gzip_bytes"] = os.path.getsize(opt.output)
    os.makedirs(os.path.dirname(os.path.abspath(opt.report)), exist_ok=True)
    with open(opt.report, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print("WREN_ARA_BODY_SURFACE_OK", json.dumps({
        "skin_objects": skin_names,
        "piercing_objects": piercing_names,
        "skin_vertices": skin_count,
        "surface_vertices": len(coords) // 3,
        "faces": len(face_sizes),
        "unknown_skin_regions": unknown,
        "nipple_landmarks": {"left": left_nipple, "right": right_nipple},
        "source_sha256": surface["source_sha256"],
        "surface_gzip_bytes": os.path.getsize(opt.output),
    }))

if __name__ == "__main__":
    main()
