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
    parser.add_argument(
        "--anatomy-state", choices=("flaccid", "erect-reference"), default="flaccid",
        help="Compact resting form by default; preserve the previous projection as an optional reference asset.",
    )
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


def create_finger_derived_phallus(skin, material, armature, pelvis_bone,
                                  body_height, anatomy_z, anchor_y, anatomy_state):
    """Reuse Ara's own middle-finger surface as the phallus modelling template.

    Extracts only the skin-material faces weighted to the right middle finger,
    then transforms that existing organic surface from the finger bone axis to
    the pelvic attachment axis. This preserves Ara's native surface character
    and avoids synthetic cylinders, UV spheres, torus seams and voxel remeshing.
    """
    import bmesh

    chain_names = (
        "RightHandMiddle1", "RightHandMiddle2", "RightHandMiddle3"
    )
    bones = []
    for name in chain_names:
        bone = armature.data.bones.get(name)
        if bone is None:
            raise RuntimeError(f"Ara finger-template bone is missing: {name}")
        bones.append(bone)

    source_base = armature.matrix_world @ bones[0].head_local
    source_tip = armature.matrix_world @ bones[-1].tail_local
    source_axis = source_tip - source_base
    source_length = source_axis.length
    if source_length < 0.025:
        raise RuntimeError(f"Ara middle-finger template is unexpectedly short: {source_length:.4f} m")
    source_axis.normalize()

    group_indices = {
        group.name: group.index for group in skin.vertex_groups
        if group.name in chain_names
    }
    if len(group_indices) != len(chain_names):
        raise RuntimeError(
            "Ara skin mesh is missing middle-finger vertex groups: "
            + ", ".join(sorted(set(chain_names) - set(group_indices)))
        )

    group_weights = [dict() for _ in skin.data.vertices]
    for vertex in skin.data.vertices:
        for assignment in vertex.groups:
            if assignment.group in group_indices.values():
                group_weights[vertex.index][assignment.group] = assignment.weight

    selected_faces = []
    for polygon in skin.data.polygons:
        if polygon.material_index >= len(skin.material_slots):
            continue
        face_material = skin.material_slots[polygon.material_index].material
        if face_material is None or "skin" not in face_material.name.lower():
            continue
        weighted_vertices = sum(
            1 for index in polygon.vertices
            if any(group_weights[index].get(group_index, 0.0) > 0.08
                   for group_index in group_indices.values())
        )
        if weighted_vertices < 2:
            continue
        centre_local = sum((skin.data.vertices[index].co for index in polygon.vertices),
                           Vector()) / len(polygon.vertices)
        centre_world = skin.matrix_world @ centre_local
        relative = centre_world - source_base
        along = relative.dot(source_axis)
        radial = (relative - source_axis * along).length
        if -0.006 <= along <= source_length * 1.08 and radial <= 0.030:
            selected_faces.append(polygon)

    if len(selected_faces) < 500:
        raise RuntimeError(
            f"Could only extract {len(selected_faces)} Ara middle-finger skin faces; "
            "refusing to fall back to synthetic anatomy"
        )

    used_indices = sorted({index for polygon in selected_faces for index in polygon.vertices})
    remap = {old: new for new, old in enumerate(used_indices)}
    source_vertices = [
        skin.matrix_world @ skin.data.vertices[index].co for index in used_indices
    ]
    faces = [
        tuple(remap[index] for index in polygon.vertices) for polygon in selected_faces
    ]

    # Keep the previous projection as a separately generated reference. The
    # default flaccid form is shorter, narrower, angled down and tucked closer
    # to the pubic surface so it does not read as an erect presentation.
    if anatomy_state == "erect-reference":
        target_axis = Vector((0.0, -0.94, -0.34)).normalized()
        target_length = body_height * 0.074
        radial_factor = 1.16
        base_depth_offset = body_height * 0.006
    else:
        target_axis = Vector((0.0, -0.56, -0.83)).normalized()
        target_length = body_height * 0.040
        radial_factor = 0.88
        base_depth_offset = body_height * 0.002
    rotation = source_axis.rotation_difference(target_axis)
    length_scale = target_length / source_length
    radial_scale = length_scale * radial_factor
    target_base = Vector((
        0.0,
        anchor_y + base_depth_offset,
        anatomy_z + body_height * 0.004,
    ))

    vertices = []
    for point in source_vertices:
        relative = point - source_base
        along = relative.dot(source_axis)
        radial = relative - source_axis * along
        transformed = (
            source_axis * (along * length_scale) + radial * radial_scale
        )
        vertices.append(tuple(target_base + rotation @ transformed))

    mesh = bpy.data.meshes.new("AraFingerDerivedPhallusMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    mesh.update()
    phallus = bpy.data.objects.new("Male anatomy · Ara finger-derived surface", mesh)
    bpy.context.collection.objects.link(phallus)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    group = phallus.vertex_groups.new(name=pelvis_bone)
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    phallus.parent = armature
    phallus.matrix_parent_inverse = armature.matrix_world.inverted()
    modifier = phallus.modifiers.new("Ara pelvis skinning", "ARMATURE")
    modifier.object = armature
    phallus["anatomy_state"] = anatomy_state
    phallus["anatomy_parts"] = "finger_derived_root,shaft,rounded_distal_tip"
    phallus["source_template"] = "Ara_RightHandMiddleFinger_skin_surface"
    phallus["source_face_count"] = len(selected_faces)
    phallus["source_length_m"] = source_length
    phallus["target_length_m"] = target_length
    phallus["anatomy_method"] = "native_Ara_finger_surface_transformed_and_pelvis_weighted"
    print(
        "Ara finger-derived anatomy: "
        f"faces={len(selected_faces)}, source_length={source_length:.4f} m, "
        f"target_length={target_length:.4f} m, radial_scale={radial_scale:.3f}"
    )
    return phallus


def create_scrotum(tree, material, armature, pelvis_bone, width, height, anatomy_z, anchor_y, anatomy_state):
    centre_z = anatomy_z - height * 0.046
    surface_y = anchor_y
    if anatomy_state == "erect-reference":
        width_factor, depth_factor, height_factor = 0.067, 0.020, 0.044
    else:
        # Reduce the current oversized scrotal silhouette by roughly one third.
        width_factor, depth_factor, height_factor = 0.045, 0.014, 0.030
    depth = height * depth_factor
    centre = Vector((0.0, surface_y - depth * 0.40, centre_z))
    sac = create_uv_surface(
        "Male anatomy · scrotum with paired contours", centre,
        Vector((width * width_factor, depth, height * height_factor)),
        material, armature, pelvis_bone, segments=72, rings=48, front_lobes=True
    )
    sac["anatomy_state"] = anatomy_state
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



def join_male_anatomy_parts(parts, armature, pelvis_bone):
    """Join the finger-derived shaft and scrotal form without voxel remeshing."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        for modifier in list(obj.modifiers):
            obj.modifiers.remove(modifier)
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
        obj.select_set(True)
    combined = parts[0]
    bpy.context.view_layer.objects.active = combined
    bpy.ops.object.join()
    combined.name = "Male anatomy · Ara-derived unified surface"
    combined.data.name = "AraDerivedMaleAnatomyMesh"
    group = combined.vertex_groups.get(pelvis_bone)
    if group is None:
        group = combined.vertex_groups.new(name=pelvis_bone)
    group.add(list(range(len(combined.data.vertices))), 1.0, "REPLACE")
    combined.parent = armature
    combined.matrix_parent_inverse = armature.matrix_world.inverted()
    modifier = combined.modifiers.new("Ara pelvis skinning", "ARMATURE")
    modifier.object = armature
    combined["anatomy_profile"] = "adult_male"
    combined["anatomy_method"] = "Ara_middle_finger_surface_plus_contoured_scrotum_no_voxel_remesh"
    combined["anatomy_parts"] = "integrated_root,shaft,rounded_tip,scrotal_sac"
    combined["review_status"] = "native_Ara_geometry_requires_multi_angle_visual_acceptance"
    return combined


def merge_anatomy_into_skin(skin, anatomy, armature, pelvis_bone):
    """Attach the fused anatomy geometry to the original full-rig body mesh.

    Keeping it as a separate pelvis-only skinned mesh can make glTF emit a
    reduced joint palette for that component. Joining it into the original
    Ara skin mesh makes the body and anatomy share the body's complete rig
    and existing skin modifier.
    """
    # The anatomy vertices are already in character/world space. Blender's
    # join operation converts the selected object's geometry into the
    # active skin object's local space.
    for modifier in list(anatomy.modifiers):
        anatomy.modifiers.remove(modifier)
    if skin.vertex_groups.get(pelvis_bone) is None:
        skin.vertex_groups.new(name=pelvis_bone)

    bpy.ops.object.select_all(action="DESELECT")
    skin.select_set(True)
    anatomy.select_set(True)
    bpy.context.view_layer.objects.active = skin
    bpy.ops.object.join()

    skin["male_anatomy_geometry"] = "joined_into_original_ara_skin_mesh"
    skin["male_anatomy_rig"] = "shares_full_original_ara_skeleton"
    skin["male_anatomy_parts"] = "integrated_root,shaft,glans,corona,scrotal_sac"
    return skin

def masculinise_body_mesh(skin):
    """Apply a restrained male torso/pelvis silhouette to the shared Ara rig.

    Ara's gender=1 export currently produces the exact same skin vertices as
    gender=0. This pass therefore changes the actual skinned body surface before
    adding male anatomy. It preserves topology, UVs, vertex groups, modifiers
    and applies the same spatial transform to every existing shape-key block.
    """
    lo, hi = bounds(skin)
    height = hi.z - lo.z
    width = hi.x - lo.x
    if height <= 0.0 or width <= 0.0:
        raise RuntimeError("Cannot masculinise Ara body with invalid bounds")

    inverse_world = skin.matrix_world.inverted()
    shape_keys = skin.data.shape_keys
    blocks = list(shape_keys.key_blocks) if shape_keys else [None]
    moved = 0
    max_displacement = 0.0
    squared_displacement = 0.0
    for block in blocks:
        coordinates = block.data if block is not None else skin.data.vertices
        for vertex in coordinates:
            original_local = vertex.co.copy()
            point = skin.matrix_world @ original_local
            ratio = (point.z - lo.z) / height
            shoulder = math.exp(-0.5 * ((ratio - 0.795) / 0.095) ** 2)
            ribcage = math.exp(-0.5 * ((ratio - 0.685) / 0.085) ** 2)
            waist = math.exp(-0.5 * ((ratio - 0.595) / 0.075) ** 2)
            pelvis = math.exp(-0.5 * ((ratio - 0.485) / 0.085) ** 2)

            # Broader shoulder/ribcage line and a narrower waist/hip silhouette.
            lateral_scale = 1.0 + 0.115 * shoulder + 0.035 * ribcage - 0.105 * waist - 0.085 * pelvis
            point.x *= lateral_scale

            # Reduce the Ara female breast projection into a flatter male chest.
            # Ara faces -Y; only the front-facing chest surface is moved.
            chest_band = math.exp(-0.5 * ((ratio - 0.705) / 0.075) ** 2)
            chest_side = math.exp(-0.5 * ((abs(point.x) - width * 0.105) / (width * 0.075)) ** 2)
            front_surface = max(0.0, min(1.0, (-point.y - width * 0.015) / (width * 0.16)))
            point.y += height * 0.018 * chest_band * chest_side * front_surface

            new_local = inverse_world @ point
            displacement = (new_local - original_local).length
            if displacement > 1e-8:
                moved += 1
                max_displacement = max(max_displacement, displacement)
                squared_displacement += displacement * displacement
            vertex.co = new_local

    total = sum(len(block.data) if block is not None else len(skin.data.vertices) for block in blocks)
    rms = math.sqrt(squared_displacement / max(moved, 1))
    skin["male_body_shape"] = "masculinised_torso_shoulders_waist_pelvis"
    skin["male_body_shape_vertices_moved"] = moved
    skin["male_body_shape_max_displacement_m"] = max_displacement
    skin["male_body_shape_rms_displacement_m"] = rms
    print(
        "Ara male body silhouette: "
        f"moved={moved}/{total} shape-key vertices, "
        f"RMS={rms:.6f} m, max={max_displacement:.6f} m"
    )
    if moved < 100:
        raise RuntimeError("Male silhouette pass changed too few vertices; refusing a female-shaped male base")


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
    masculinise_body_mesh(skin)
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
    phallus = create_finger_derived_phallus(
        skin, skin_material, armature, pelvis_bone, height, anatomy_z, pelvic_surface_y,
        args.anatomy_state
    )
    scrotum = create_scrotum(
        surface_tree, skin_material, armature, pelvis_bone, width, height, anatomy_z,
        pelvic_surface_y, args.anatomy_state
    )

    anatomy = join_male_anatomy_parts(
        [phallus, scrotum], armature, pelvis_bone
    )
    anatomy["profile_name"] = args.profile_name
    anatomy["anatomy_state"] = args.anatomy_state
    # Join into the original Ara body mesh so the exported GLB retains one
    # full-rig skin rather than a separate pelvis-only skeleton palette.
    skin = merge_anatomy_into_skin(skin, anatomy, armature, pelvis_bone)

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
        f"Exported Ara-derived adult male anatomy ({args.anatomy_state}) "
        "with paired scrotal contours, integrated into the original full-rig skin mesh."
    )


if __name__ == "__main__":
    main()
