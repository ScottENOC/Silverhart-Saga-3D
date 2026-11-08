"""Build a proportion-scaled, rigged adult male anatomy model for Ara.

This replaces the former broad surface-displacement blockout with explicit,
smooth anatomical geometry: a tapered flaccid shaft, defined glans/corona,
subtle meatus, and a scrotal form with paired testicular lobes. All geometry
uses the Ara skin material and is skinned to the pelvis bone. It is scaled from
the imported body's measured bounds and pelvis landmark, not fixed world units.

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
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--adult", action="store_true")
    parser.add_argument("--profile-name", default="adult_male")
    return parser.parse_args(raw)


def material_name(obj):
    return " ".join(slot.material.name.lower() for slot in obj.material_slots if slot.material)


def bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector(tuple(min(p[i] for p in points) for i in range(3))),
        Vector(tuple(max(p[i] for p in points) for i in range(3))),
    )


def find_skin(meshes):
    candidates = [obj for obj in meshes if "skin" in material_name(obj)]
    if not candidates:
        raise RuntimeError("Could not identify Ara skin mesh/material")
    skin = max(candidates, key=lambda obj: len(obj.data.polygons))
    material = next(
        (slot.material for slot in skin.material_slots
         if slot.material and "skin" in slot.material.name.lower()), None
    )
    if material is None:
        raise RuntimeError("Ara skin material is missing")
    return skin, material


def find_pelvis_bone(armature):
    aliases = {
        "hips", "hip", "pelvis", "pelvisroot", "rootpelvis",
        "mixamorig:hips", "mixamorig_hips",
    }
    for bone in armature.data.bones:
        key = bone.name.lower().replace(" ", "").replace("-", "_")
        if key in aliases:
            return bone.name
    # Ara rigs may name the pelvis through a numbered spine chain.
    for bone in armature.data.bones:
        key = bone.name.lower()
        if "hip" in key or "pelvis" in key:
            return bone.name
    raise RuntimeError("Could not find a pelvis/Hips bone for male anatomy weighting")


def pelvis_landmark_from_leg_roots(armature, height):
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
        "Male pelvic landmark: "
        f"left={found['left'].z:.4f}, right={found['right'].z:.4f}, "
        f"centre={z:.4f}, character height={height:.4f}"
    )
    return z


def build_surface_tree(skin):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = skin.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    vertices = [skin.matrix_world @ vertex.co for vertex in mesh.vertices]
    faces = [list(poly.vertices) for poly in mesh.polygons]
    tree = BVHTree.FromPolygons(vertices, faces, all_triangles=False)
    evaluated.to_mesh_clear()
    return tree


def front_surface_y(tree, x, z):
    hit, _normal, _index, _distance = tree.ray_cast(
        Vector((x, -3.0, z)), Vector((0.0, 1.0, 0.0)), 6.0
    )
    if hit is None:
        raise RuntimeError(f"Could not sample front skin surface at x={x:.4f}, z={z:.4f}")
    return hit.y


def create_mesh_object(name, vertices, faces, material, armature, pelvis_bone, smooth=True):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = smooth
    group = obj.vertex_groups.new(name=pelvis_bone)
    if vertices:
        group.add(list(range(len(vertices))), 1.0, "REPLACE")
    obj.parent = armature
    obj.matrix_parent_inverse = armature.matrix_world.inverted()
    modifier = obj.modifiers.new("Ara pelvis skinning", "ARMATURE")
    modifier.object = armature
    obj["anatomy_profile"] = "adult_male"
    obj["deformation"] = "pelvis_weighted_and_body_proportion_scaled"
    return obj


def create_uv_surface(name, centre, scale, material, armature, pelvis_bone,
                      segments=64, rings=40, front_lobes=False):
    vertices = []
    faces = []
    for ring in range(rings + 1):
        phi = math.pi * ring / rings
        for segment in range(segments):
            theta = 2.0 * math.pi * segment / segments
            nx = math.sin(phi) * math.cos(theta)
            ny = math.sin(phi) * math.sin(theta)
            nz = math.cos(phi)
            x = centre.x + scale.x * nx
            y = centre.y + scale.y * ny
            z = centre.z + scale.z * nz
            if front_lobes and ny < -0.12:
                # Paired soft lobes with a shallow median raphe/groove.
                left = math.exp(-0.5 * ((x + scale.x * 0.36) / (scale.x * 0.23)) ** 2
                                -0.5 * (nz / 0.72) ** 2)
                right = math.exp(-0.5 * ((x - scale.x * 0.36) / (scale.x * 0.23)) ** 2
                                 -0.5 * (nz / 0.72) ** 2)
                groove = math.exp(-0.5 * (x / (scale.x * 0.12)) ** 2
                                  -0.5 * (nz / 0.8) ** 2)
                y -= scale.y * (0.17 * (left + right) - 0.075 * groove) * min(1.0, -ny * 1.8)
            vertices.append((x, y, z))
    for ring in range(rings):
        for segment in range(segments):
            a = ring * segments + segment
            b = ring * segments + (segment + 1) % segments
            c = (ring + 1) * segments + (segment + 1) % segments
            d = (ring + 1) * segments + segment
            faces.append((a, d, c, b))  # outward-facing winding for the UV surface
    return create_mesh_object(name, vertices, faces, material, armature, pelvis_bone)


def create_shaft(tree, material, armature, pelvis_bone, width, height, anatomy_z, anchor_y):
    # The shaft is a swept, tapered surface, angled naturally down from its root.
    length = height * 0.078
    radius = width * 0.022
    top_z = anatomy_z + height * 0.012
    ring_count, sides = 40, 48
    vertices, faces = [], []
    profile = [
        (0.00, 0.30), (0.07, 0.62), (0.18, 0.82), (0.48, 0.92),
        (0.70, 0.94), (0.78, 0.98), (0.84, 1.04), (0.90, 1.00),
        (0.96, 0.80), (1.00, 0.48),
    ]

    def interpolate(t):
        for i in range(len(profile) - 1):
            if profile[i][0] <= t <= profile[i + 1][0]:
                a, va = profile[i]
                b, vb = profile[i + 1]
                f = (t - a) / (b - a)
                f = f * f * (3.0 - 2.0 * f)
                return va + (vb - va) * f
        return profile[-1][1]

    for ring in range(ring_count + 1):
        t = ring / ring_count
        z = top_z - length * t
        centre_x = width * 0.004 * math.sin(t * math.pi * 0.8)
        # The centreline can pass between the upper legs, where no skin ray hit exists.
        # Keep the shaft rooted to the sampled pubic surface instead of sampling the gap.
        r = radius * interpolate(t)
        depth_radius = r * 0.88
        embed = depth_radius * 0.48
        for side in range(sides):
            angle = 2.0 * math.pi * side / sides
            x = centre_x + r * math.cos(angle)
            y = anchor_y - embed - depth_radius * math.sin(angle)
            vertices.append((x, y, z))
    for ring in range(ring_count):
        for side in range(sides):
            a = ring * sides + side
            b = ring * sides + (side + 1) % sides
            c = (ring + 1) * sides + (side + 1) % sides
            d = (ring + 1) * sides + side
            faces.append((a, b, c, d))
    obj = create_mesh_object("Male anatomy · tapered shaft and root",
                             vertices, faces, material, armature, pelvis_bone)
    obj["anatomy_parts"] = "root,shaft,corona_transition"
    return obj, top_z - length, radius


def create_glans(tree, material, armature, pelvis_bone, width, height, tip_z, shaft_radius, anchor_y):
    glans_z = tip_z + height * 0.006
    surface_y = anchor_y
    depth = shaft_radius * 0.92
    centre = Vector((0.0, surface_y - depth * 0.52, glans_z))
    glans = create_uv_surface(
        "Male anatomy · distinct glans", centre,
        Vector((shaft_radius * 1.13, depth, height * 0.0105)),
        material, armature, pelvis_bone, segments=64, rings=40
    )
    glans["anatomy_parts"] = "glans,corona"
    # A narrow raised corona follows the glans base as a continuous toroidal ridge.
    major = shaft_radius * 1.07
    minor = shaft_radius * 0.13
    bpy.ops.mesh.primitive_torus_add(
        major_segments=64, minor_segments=12, location=(0.0, surface_y - depth * 0.88, glans_z + height * 0.004)
    )
    corona = bpy.context.object
    corona.name = "Male anatomy · corona ridge"
    corona.scale = (major, major * 0.78, minor)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    corona.data.materials.append(material)
    for polygon in corona.data.polygons:
        polygon.use_smooth = True
    group = corona.vertex_groups.new(name=pelvis_bone)
    group.add(list(range(len(corona.data.vertices))), 1.0, "REPLACE")
    corona.parent = armature
    corona.matrix_parent_inverse = armature.matrix_world.inverted()
    modifier = corona.modifiers.new("Ara pelvis skinning", "ARMATURE")
    modifier.object = armature
    corona["anatomy_parts"] = "corona"
    return glans, corona


def create_scrotum(tree, material, armature, pelvis_bone, width, height, anatomy_z, anchor_y):
    centre_z = anatomy_z - height * 0.046
    surface_y = anchor_y
    depth = height * 0.020
    centre = Vector((0.0, surface_y - depth * 0.48, centre_z))
    sac = create_uv_surface(
        "Male anatomy · scrotum with paired contours", centre,
        Vector((width * 0.067, depth, height * 0.044)),
        material, armature, pelvis_bone, segments=72, rings=48, front_lobes=True
    )
    sac["anatomy_parts"] = "scrotal_sac,left_testis_contour,right_testis_contour,median_raphe"
    return sac


def add_meatus_detail(tree, skin_material, armature, pelvis_bone, height, tip_z, shaft_radius, anchor_y):
    # A very small recessed-looking, darker oval at the distal glans surface.
    glans_z = tip_z + height * 0.006
    surface_y = anchor_y - shaft_radius * 1.42
    detail_material = skin_material.copy()
    detail_material.name = "Anatomy detail · subtle meatus"
    if detail_material.use_nodes:
        shader = next((node for node in detail_material.node_tree.nodes
                       if node.type == "BSDF_PRINCIPLED"), None)
        if shader:
            shader.inputs["Base Color"].default_value = (0.22, 0.105, 0.085, 1.0)
            shader.inputs["Roughness"].default_value = 0.72
    obj = create_uv_surface(
        "Male anatomy · meatus detail",
        Vector((0.0, surface_y, glans_z - height * 0.001)),
        Vector((shaft_radius * 0.19, height * 0.0009, height * 0.0014)),
        detail_material, armature, pelvis_bone, segments=32, rings=20
    )
    obj["anatomy_parts"] = "external_meatus_detail"
    return obj


def main():
    args = arguments()
    if not args.adult:
        raise SystemExit("Refusing to add external genital anatomy without explicit --adult confirmation")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if not meshes or armature is None:
        raise RuntimeError("Expected Ara male meshes and game armature")
    skin, skin_material = find_skin(meshes)
    pelvis_bone = find_pelvis_bone(armature)
    lo, hi = bounds(skin)
    height = hi.z - lo.z
    width = hi.x - lo.x
    if height <= 0 or width <= 0:
        raise RuntimeError("Ara skin mesh has invalid dimensions")
    hipline_z = pelvis_landmark_from_leg_roots(armature, height)
    anatomy_z = hipline_z - height * 0.035
    surface_tree = build_surface_tree(skin)

    # Fail early if the front pelvis surface cannot be sampled.
    pelvic_surface_y = front_surface_y(surface_tree, 0.0, anatomy_z)
    shaft, tip_z, shaft_radius = create_shaft(
        surface_tree, skin_material, armature, pelvis_bone, width, height, anatomy_z, pelvic_surface_y
    )
    glans, corona = create_glans(
        surface_tree, skin_material, armature, pelvis_bone, width, height, tip_z, shaft_radius, pelvic_surface_y
    )
    scrotum = create_scrotum(
        surface_tree, skin_material, armature, pelvis_bone, width, height, anatomy_z, pelvic_surface_y
    )
    meatus = add_meatus_detail(
        surface_tree, skin_material, armature, pelvis_bone, height, tip_z, shaft_radius, pelvic_surface_y
    )

    for obj in (shaft, glans, corona, scrotum, meatus):
        obj["review_status"] = "geometry_pass_requires_visual_acceptance"
        obj["profile_name"] = args.profile_name

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(args.output), export_format="GLB",
        use_selection=True, export_apply=False, export_animations=True
    )
    print(
        "Exported explicit adult male anatomy geometry: shaft, glans, corona, "
        "meatus and paired scrotal contours; all parts pelvis-weighted and "
        f"scaled to body width={width:.4f}, height={height:.4f}."
    )


if __name__ == "__main__":
    main()
