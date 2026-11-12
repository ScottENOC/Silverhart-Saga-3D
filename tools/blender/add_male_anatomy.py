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
        "--anatomy-state", choices=("erect", "flaccid"), default="erect",
        help="Compact resting form by default; preserve the previous projection as an optional reference asset.",
    )
    return parser.parse_args(raw)



def wire_vertex_colour_to_skin_material(material, attribute_name="Color"):
    """Multiply the skin texture by anatomy vertex colours for Blender and glTF."""
    if material is None or not material.use_nodes:
        raise RuntimeError("Skin material must use nodes to display anatomy vertex colours")
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
    if shader is None:
        raise RuntimeError("Skin material has no Principled BSDF")
    base = shader.inputs.get("Base Color")
    if base is None:
        raise RuntimeError("Skin shader has no Base Color input")
    if any(node.get("anatomy_vertex_colour_layer") == attribute_name for node in nodes):
        return
    vertex_colour = nodes.new("ShaderNodeVertexColor")
    vertex_colour.layer_name = attribute_name
    vertex_colour.label = "Anatomy skin-tone variation"
    vertex_colour.name = "AnatomyVertexColour"
    vertex_colour.location = (shader.location.x - 420, shader.location.y - 180)
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MULTIPLY"
    multiply.inputs["Fac"].default_value = 1.0
    multiply.label = "Preserve skin texture; apply anatomy tint"
    multiply.name = "AnatomyColourMultiply"
    multiply.location = (shader.location.x - 190, shader.location.y - 100)
    multiply["anatomy_vertex_colour_layer"] = attribute_name
    existing_links = list(base.links)
    if existing_links:
        original_socket = existing_links[0].from_socket
        for link in existing_links:
            links.remove(link)
        links.new(original_socket, multiply.inputs["Color1"])
    else:
        multiply.inputs["Color1"].default_value = (1.0, 1.0, 1.0, 1.0)
    links.new(vertex_colour.outputs["Color"], multiply.inputs["Color2"])
    links.new(multiply.outputs["Color"], base)
    print(f"Skin shader now multiplies its base texture by vertex colour layer {attribute_name!r}")


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
    x = (found["left"].x + found["right"].x) * 0.5
    z = (found["left"].z + found["right"].z) * 0.5
    print(
        "Male pelvic landmark: "
        f"left={found['left'].z:.4f}, right={found['right'].z:.4f}, "
        f"centre={z:.4f}, character height={height:.4f}"
    )
    return x, z


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


def create_flaccid_phallus(material, armature, pelvis_bone, body_height, anatomy_z, anchor_y, centre_x=0.0):
    """Create a new compact, downward-resting flaccid form (not the old finger mesh)."""
    axis = Vector((0.0, -0.43, -0.90)).normalized()
    right = Vector((1.0, 0.0, 0.0))
    side = axis.cross(right).normalized()
    length = body_height * 0.038
    radius = body_height * 0.0085  # fuller relaxed shaft, +42% radius
    base = Vector((centre_x, anchor_y + body_height * 0.003, anatomy_z + body_height * 0.003))

    # Longitudinal silhouette: narrow attachment, fuller shaft, a restrained
    # distal glans transition, then a softly rounded tip. Values are relative
    # to body height and deliberately much smaller than the preserved reference.
    profile = [
        (0.00, 0.28), (0.08, 0.58), (0.20, 0.78), (0.38, 0.88),
        (0.58, 0.91), (0.70, 0.94), (0.76, 0.86), (0.82, 1.00),
        (0.89, 1.08), (0.95, 0.90), (0.985, 0.58), (1.00, 0.18),
    ]
    segments = 48
    vertices = []
    faces = []
    for t, width_factor in profile:
        # A slight natural curve back toward the body as the form descends.
        centre = base + axis * (length * t) + Vector((0.0, body_height * 0.0015 * math.sin(math.pi * t), 0.0))
        ring_radius = radius * width_factor
        for segment in range(segments):
            angle = 2.0 * math.pi * segment / segments
            radial = right * math.cos(angle) + side * math.sin(angle)
            point = centre + radial * ring_radius
            vertices.append(tuple(point))
    for ring in range(len(profile) - 1):
        for segment in range(segments):
            a = ring * segments + segment
            b = ring * segments + (segment + 1) % segments
            c = (ring + 1) * segments + (segment + 1) % segments
            d = (ring + 1) * segments + segment
            faces.append((a, b, c, d))
    # Close both ends with small caps to avoid an open surface.
    start_index = len(vertices)
    vertices.append(tuple(base))
    end_index = len(vertices)
    vertices.append(tuple(base + axis * length))
    last_ring = (len(profile) - 1) * segments
    for segment in range(segments):
        nxt = (segment + 1) % segments
        faces.append((start_index, nxt, segment))
        faces.append((end_index, last_ring + segment, last_ring + nxt))

    obj = create_mesh_object(
        "Male anatomy · new flaccid resting form", vertices, faces,
        material, armature, pelvis_bone
    )
    obj["anatomy_state"] = "flaccid"
    obj["anatomy_method"] = "new_parametric_resting_form_not_finger_template"
    obj["target_length_m"] = length
    obj["maximum_radius_m"] = radius * max(value for _t, value in profile)
    return obj


def add_anatomy_bones(armature, pelvis_bone, base_world, axis_world, length):
    """Create a pelvis-parented root/mid/tip chain for the shared shaft mesh."""
    inverse = armature.matrix_world.inverted()
    base = inverse @ base_world
    axis = (inverse.to_3x3() @ axis_world).normalized()
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    edit = armature.data.edit_bones
    pelvis = edit.get(pelvis_bone)
    if pelvis is None:
        bpy.ops.object.mode_set(mode="OBJECT")
        raise RuntimeError("Pelvis bone missing while creating male anatomy rig")
    for name in ("AnatomyRoot", "AnatomyMid", "AnatomyTip"):
        old = edit.get(name)
        if old:
            edit.remove(old)
    previous = None
    cursor = base.copy()
    for name, fraction in (("AnatomyRoot", 0.42), ("AnatomyMid", 0.34), ("AnatomyTip", 0.24)):
        bone = edit.new(name)
        bone.head = cursor
        cursor = cursor + axis * (length * fraction)
        bone.tail = cursor
        bone.parent = previous if previous else pelvis
        bone.use_connect = False
        previous = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    armature["male_anatomy_rig"] = "AnatomyRoot>AnatomyMid>AnatomyTip"


def key_anatomy_pose_transition(armature, state):
    """Author an erect-to-resting transition on the dedicated anatomy chain."""
    import math
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 24
    armature.animation_data_create()
    action = bpy.data.actions.new("MaleAnatomy_ErectToFlaccid")
    armature.animation_data.action = action
    bones = [armature.pose.bones.get(name) for name in
             ("AnatomyRoot", "AnatomyMid", "AnatomyTip")]
    if any(bone is None for bone in bones):
        raise RuntimeError("Dedicated male anatomy bones missing before animation")
    for frame, root_angle, mid_angle, tip_angle in (
        (1, 0.0, 0.0, 0.0),
        (24, math.radians(55.0), math.radians(5.0), math.radians(3.0)),
    ):
        bpy.context.scene.frame_set(frame)
        for bone, angle in zip(bones, (root_angle, mid_angle, tip_angle)):
            bone.rotation_mode = "XYZ"
            bone.rotation_euler.x = angle
            bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone.name)
    bpy.context.scene.frame_set(24 if state == "flaccid" else 1)
    armature["male_anatomy_animation"] = "MaleAnatomy_ErectToFlaccid"
    armature["male_anatomy_pose"] = state


def create_finger_derived_phallus(skin, material, armature, pelvis_bone,
                                  body_height, anatomy_z, anchor_y, anatomy_state, centre_x=0.0):
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

    # Use the former erect surface as the shared starting geometry.
    # A dedicated deform rig will control the resting/erect transition.
    if anatomy_state == "flaccid":
        # Resting pose hangs down with a slight forward cant; use the same
        # transformed Ara surface and cross-section profile as the erect form.
        target_axis = Vector((0.0, -0.43, -0.90)).normalized()
        target_length = body_height * 0.038
        base_depth_offset = body_height * 0.003
    else:
        target_axis = Vector((0.0, -0.985, -0.17)).normalized()
        target_length = body_height * 0.074
        base_depth_offset = body_height * 0.016
    radial_factor = 1.16
    rotation = source_axis.rotation_difference(target_axis)
    length_scale = target_length / source_length
    radial_scale = length_scale * radial_factor
    target_base = Vector((
        centre_x,
        anchor_y + base_depth_offset,
        anatomy_z + body_height * 0.004,
    ))
    add_anatomy_bones(armature, pelvis_bone, target_base, target_axis, target_length)

    vertices = []
    for point in source_vertices:
        relative = point - source_base
        along = relative.dot(source_axis)
        radial = relative - source_axis * along
        t = max(0.0, min(1.0, along / source_length))
        glans = math.exp(-0.5 * ((t - 0.875) / 0.075) ** 2)
        corona_groove = math.exp(-0.5 * ((t - 0.785) / 0.026) ** 2)
        root_taper = 0.82 + 0.18 * min(1.0, t / 0.18)
        profile_scale = root_taper + 0.24 * glans - 0.13 * corona_groove
        transformed = (
            source_axis * (along * length_scale) + radial * radial_scale * profile_scale
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
    phallus.parent = armature
    shaft_groups = [phallus.vertex_groups.new(name=name) for name in
                    ("AnatomyRoot", "AnatomyMid", "AnatomyTip")]
    for vertex in mesh.vertices:
        t = max(0.0, min(1.0, (Vector(vertex.co) - target_base).dot(target_axis) / target_length))
        weights = (
            max(0.0, min(1.0, (0.62 - t) / 0.42)),
            max(0.0, 1.0 - abs(t - 0.52) / 0.42),
            max(0.0, min(1.0, (t - 0.38) / 0.42)),
        )
        total = sum(weights)
        for group, weight in zip(shaft_groups, weights):
            if weight > 0.001 and total > 0.0:
                group.add([vertex.index], weight / total, "REPLACE")
    phallus.matrix_parent_inverse = armature.matrix_world.inverted()
    modifier = phallus.modifiers.new("Ara pelvis skinning", "ARMATURE")
    modifier.object = armature
    phallus["anatomy_state"] = anatomy_state
    phallus["anatomy_parts"] = "integrated_root,tapered_shaft,defined_corona,rounded_glans"
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


def create_scrotum(tree, material, armature, pelvis_bone, width, height, anatomy_z, anchor_y, anatomy_state, centre_x=0.0):
    # Scale from clinical adult dimensions rather than body-width heuristics.
    # A typical adult testis is roughly 4.5 x 2.6 x 2.5 cm; the external
    # scrotal envelope should accommodate the pair without reading as a
    # single oversized hanging sphere. For a 179 cm body these radii produce
    # an envelope about 6.1 cm wide x 4.3 cm deep x 6.4 cm tall.
    centre_z = anatomy_z - height * 0.024
    surface_y = anchor_y
    # A more compact, vertically restrained envelope avoids a spherical
    # silhouette and leaves the relaxed shaft visually distinct.
    width_radius = height * 0.0155
    depth_radius = height * 0.0105
    height_radius = height * 0.0145
    depth = depth_radius
    centre = Vector((centre_x, surface_y + depth * 0.30, centre_z))
    sac = create_uv_surface(
        "Male anatomy · scrotum with paired contours", centre,
        Vector((width_radius, depth_radius, height_radius)),
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



def paint_male_anatomy_detail(obj, centre_x, anatomy_z, height, anchor_y, state, part):
    mesh = obj.data
    old = mesh.color_attributes.get('Color')
    if old: mesh.color_attributes.remove(old)
    colour = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
    if part == 'phallus':
        axis = Vector((0.0, -0.43, -0.90)).normalized() if state == 'flaccid' else Vector((0.0, -0.985, -0.17)).normalized()
        length = height * (0.038 if state == 'flaccid' else 0.074)
        base = Vector((centre_x, anchor_y + height * (0.003 if state == 'flaccid' else 0.016), anatomy_z + height * 0.004))
        for vertex in mesh.vertices:
            point = obj.matrix_world @ vertex.co
            relative = point - base
            along = relative.dot(axis)
            t = max(0.0, min(1.0, along / length))
            radial = (relative - axis * along).length
            radius = height * (0.0085 if state == 'flaccid' else 0.010)
            glans = math.exp(-0.5 * ((t - 0.88) / 0.085) ** 2) * max(0.0, 1.0 - radial / (radius * 1.8))
            groove = math.exp(-0.5 * ((t - 0.785) / 0.028) ** 2) * max(0.0, 1.0 - radial / (radius * 1.5))
            strength = min(1.0, 0.58 * glans + 0.20 * groove)
            colour.data[vertex.index].color = (1.0 + 0.035*strength, 1.0 - 0.16*strength, 1.0 - 0.13*strength, 1.0)
    else:
        centre = Vector((centre_x, anchor_y + height * 0.0036, anatomy_z - height * 0.024))
        for vertex in mesh.vertices:
            point = obj.matrix_world @ vertex.co
            x = (point.x-centre.x) / max(height*0.017, 1e-5)
            z = (point.z-centre.z) / max(height*0.018, 1e-5)
            front = max(0.0, min(1.0, (centre.y-point.y) / max(height*0.008, 1e-5)))
            median = math.exp(-0.5*(x/0.14)**2 - 0.5*(z/0.68)**2) * front
            lobes = max(math.exp(-0.5*((x-0.36)/0.24)**2), math.exp(-0.5*((x+0.36)/0.24)**2)) * math.exp(-0.5*(z/0.85)**2) * front
            strength = min(1.0, 0.65*median + 0.18*lobes)
            colour.data[vertex.index].color = (1.0 + 0.025*strength, 1.0 - 0.11*strength, 1.0 - 0.09*strength, 1.0)
    mesh.color_attributes.active_color = colour
    obj['anatomy_colour_detail'] = 'skin_relative_gradient_glans_corona_and_median_raphe'


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
    if combined.vertex_groups.get(pelvis_bone) is None:
        combined.vertex_groups.new(name=pelvis_bone)
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
    centre_x, hipline_z = pelvis_landmark_from_leg_roots(armature, height)
    anatomy_z = hipline_z - height * 0.035
    surface_tree = build_surface_tree(skin)

    # Fail early if the front pelvis surface cannot be sampled.
    pelvic_surface_y = front_surface_y(surface_tree, centre_x, anatomy_z)
    # Both states use Ara's same native finger-derived surface, so the
    # flaccid form retains the erect form's shaft/glans character rather than
    # switching to an unrelated parametric capsule. Only scale and pose differ.
    if args.anatomy_state == "flaccid":
        # Use the dedicated fuller resting profile. The finger-derived template
        # remains the unchanged source for the accepted erect reference.
        phallus = create_flaccid_phallus(
            skin_material, armature, pelvis_bone, height, anatomy_z,
            pelvic_surface_y, centre_x
        )
    else:
        phallus = create_finger_derived_phallus(
            skin, skin_material, armature, pelvis_bone, height, anatomy_z,
            pelvic_surface_y, args.anatomy_state, centre_x
        )
    scrotum = create_scrotum(
        surface_tree, skin_material, armature, pelvis_bone, width, height, anatomy_z,
        pelvic_surface_y, args.anatomy_state, centre_x
    )

    paint_male_anatomy_detail(phallus, centre_x, anatomy_z, height, pelvic_surface_y, args.anatomy_state, "phallus")
    paint_male_anatomy_detail(scrotum, centre_x, anatomy_z, height, pelvic_surface_y, args.anatomy_state, "scrotum")
    anatomy = join_male_anatomy_parts(
        [phallus, scrotum], armature, pelvis_bone
    )
    anatomy["profile_name"] = args.profile_name
    anatomy["anatomy_state"] = args.anatomy_state
    if args.anatomy_state == "erect":
        key_anatomy_pose_transition(armature, args.anatomy_state)
    # Join into the original Ara body mesh so the exported GLB retains one
    # full-rig skin rather than a separate pelvis-only skeleton palette.
    skin = merge_anatomy_into_skin(skin, anatomy, armature, pelvis_bone)
    if skin.data.color_attributes.get("Color") is None:
        raise RuntimeError("Male anatomy vertex colours were lost while joining anatomy into the Ara skin")
    skin.data.color_attributes.active_color = skin.data.color_attributes.get("Color")
    skin_material = next((m for m in skin.data.materials if m and "skin" in m.name.lower()), None)
    wire_vertex_colour_to_skin_material(skin_material, "Color")
    skin["anatomy_colour_export_validation"] = "Color attribute present and connected to Principled Base Color"

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
