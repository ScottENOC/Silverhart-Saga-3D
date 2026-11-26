"""Build a proportion-scaled, rigged adult male anatomy model for Ara.

This replaces the former broad surface-displacement blockout with explicit,
smooth anatomical geometry: a tapered flaccid shaft, defined glans/corona,
subtle meatus, and a scrotal form with paired testicular lobes. All geometry
uses the Ara skin material and is skinned to the pelvis bone. Placement is derived
from measured body bounds and pelvis landmarks; genital dimensions use absolute
clinical measurements rather than height scaling.

Size: defaults to the published population mean (13.12 cm erect length, 11.66 cm erect circumference).
Use --length-scale / --girth-scale (independent) and, for per-character variation, --variation-seed.

Ara GLB axes after Blender import: Z up, character facing -Y.
"""
import argparse
import os
import sys
import math
import random

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
        help="Initial morph weight only: flaccid = 0, erect = 1. Both forms are always in the file (Anatomy_Erect morph target).",
    )
    parser.add_argument(
        "--penis-style", choices=("circumcised", "uncircumcised"), default="uncircumcised",
        help="uncircumcised: foreskin retracted into a collar when erect, covering the glans when flaccid. "
             "circumcised: exposed glans in both states.",
    )
    parser.add_argument(
        "--author-transition-clip", action="store_true",
        help="Also author a 24-frame MaleAnatomy_Erection clip (weight 0 -> 1). The Anatomy_Erect morph target "
             "is always written and is the primary interface; drive its weight directly in the engine.",
    )
    parser.add_argument(
        "--length-scale", type=float, default=1.0,
        help="Erect length relative to the population mean (1.0 = 13.12 cm). Absolute measurement, "
             "independent of character height and of --girth-scale.",
    )
    parser.add_argument(
        "--girth-scale", type=float, default=1.0,
        help="Erect circumference relative to the population mean (1.0 = 11.66 cm). "
             "Absolute measurement, independent of character height and of --length-scale.",
    )
    parser.add_argument(
        "--variation-seed", default=None,
        help="Per-character size variation. Any string or number (e.g. the character id): the same seed always "
             "gives the same size. Omit it to get the exact population mean.",
    )
    parser.add_argument(
        "--variation-strength", type=float, default=1.0,
        help="Multiplier on the population standard deviations used by --variation-seed "
             "(0 = none, 1 = realistic spread, clipped at +/-SIZE['variation_clip_sd']).",
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
    axis = Vector((0.38, -0.34, -0.86)).normalized()
    right = Vector((1.0, 0.0, 0.0))
    side = axis.cross(right).normalized()
    length = body_height * 0.044
    radius = body_height * 0.0090  # fuller relaxed shaft, with a less rigid resting silhouette
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
        centre = (base + axis * (length * t)
                  + Vector((body_height * 0.0035 * math.sin(math.pi * t),
                            body_height * 0.0010 * math.sin(math.pi * t), 0.0)))
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
    obj["anatomy_method"] = "curved_downward_resting_profile_not_finger_template"
    obj["resting_pose"] = "angled_and_gently_curved"
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
        target_length = SIZE["reference_height_m"] * SIZE["mesh_length_fraction"] * MALE_TRANSITION["erect_length_scale"]
        base_depth_offset = body_height * 0.016
    radial_factor = 1.16
    rotation = source_axis.rotation_difference(target_axis)
    length_scale = target_length / source_length
    radial_scale = length_scale * radial_factor * (MALE_TRANSITION["erect_girth_scale"] if anatomy_state != "flaccid" else 1.0)
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
        glans = math.exp(-0.5 * ((t - 0.92) / 0.07) ** 2)
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
    phallus["target_base"] = [float(v) for v in target_base]
    phallus["target_axis"] = [float(v) for v in target_axis]
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


# ---------------------------------------------------------------------------
# Phallus: symmetric parametric loft, fitted to the accepted erect.
#
# Replaces the finger-derived surface. The erect radius profile below was measured from
# the accepted erect mesh (radius per slice along its length), then cleaned: the finger's
# knuckle bumps and its 3-7 mm off-axis wobble are removed, so the form is exactly
# symmetric about the midline. The flaccid pose is generated from the SAME rings, so both
# states share one topology and form the phallus half of the `Anatomy_Erect` morph target.
#
# Radii are millimetres calibrated to the measured 1.676 m reference body.
# They remain absolute across body heights; edit this block only to fine-tune shape.
# ---------------------------------------------------------------------------
PHALLUS = {
    # (t along the erect length, radius mm). t < 0.2 is the buried root and flares into the body.
    "profile_mm": [
        (0.00, 16.5), (0.10, 16.0), (0.20, 15.6), (0.30, 15.3), (0.40, 15.0), (0.50, 14.8),
        (0.60, 14.6), (0.70, 14.4), (0.755, 14.2), (0.78, 13.95),             # soft coronal sulcus
        (0.80, 14.25), (0.82, 14.75), (0.835, 15.1), (0.847, 14.95), (0.858, 14.6),  # gentle corona
    ],
    # the glans is one smooth dome: a quarter-ellipse from the corona peak (tip_start) to the apex (tip_end)
    "tip_start": 0.858, "tip_end": 1.008,
    "fillet_mm": 0.0,                       # concave fillet where the shaft leaves the body (0 = off; still experimental: it flares into wings) ...
    "fillet_lead_mm": 6.0,                  # ... which starts this far outside the skin
    "style": "uncircumcised",               # "circumcised" or "uncircumcised" (CLI: --penis-style)
    # Uncircumcised: ERECT = foreskin retracted, bunched into a rolled collar behind the corona.
    # FLACCID = the shaft skin continues over the glans, which shows only as a slight swelling,
    # then narrows into a puckered opening. Both are the same rings, so the skin glides on the morph.
    "foreskin": {
        "coverage": 0.30,          # covered pose: 0 = short sleeve, glans tip clearly showing .. 1 = fully covered
        "collar_mm": 1.7, "collar_t": 0.745, "collar_sigma": 0.021, "collar_wrinkle_mm": 0.3,
        "overhang_mm": 9.0,        # covered pose: skin extends this far beyond the glans apex
        "glans_bulge": 0.06,       # the glans shows as a swelling under the skin (more when less covered)
        "tip_radius": 0.38,        # radius of the blunt snout relative to the shaft, before it closes
        "pucker_mm": 0.6, "pucker_lobes": 8,    # radial folds around the opening (even, to stay symmetric)
        "opening_mm": 1.2,         # depth of the dimple at the opening
        "droop_mm": 1.5,           # the opening hangs slightly ventral
        "rim_tilt_mm": 2.5,        # the foreskin edge is oblique: longer dorsally, shorter ventrally
        "taper": 0.05,             # the sleeve narrows slightly before the head, then swells over the glans
        "asymmetry_mm": 0.8,       # natural irregularity (side-to-side drift and uneven pleats); 0 = exactly symmetric
    },
    "section_ratio": 1.04,                  # shaft cross-section depth / width (the accepted erect measured ~1.04)
    "head_section_ratio": 0.90,             # the head is flatter: ~10% less deep than wide (blends in over t 0.66..0.84)                  # cross-section depth / width (the erect measured ~1.04)
    "axis_offset_mm": 3.5,                  # the accepted erect sits this far above its base axis
    "glans_start": 0.78,
    "rings_shaft": 44, "rings_glans": 36, "rings_cap": 28, "segments": 96,
    # Glans anatomy. The glans is NOT symmetric top to bottom: dorsal (top) fuller with a longer
    # slope, ventral (underside) flatter and steeper, apex slightly ventral, with the frenulum
    # running along the underside and the meatus a vertical slit at the tip.
    "glans": {
        "start": 0.76, "end": 0.86,        # where the dorsal/ventral difference fades in
        "dorsal_gain": 0.07,               # dorsal radius +7%, ventral -7% (flatter underside)
        "droop_mm": 2.5,                   # apex sits this far toward the ventral side
        "notch_mm": 1.5,                   # frenular notch (delta) in the corona, ventral midline
        "frenulum_mm": 0.6,                # raised central frenular band running to the meatus
        "groove_mm": 0.7,                  # the two grooves flanking the band
        "ridge_mm": 0.8,                   # frenulum root behind the sulcus
        "raphe_mm": 0.35,                  # faint median raphe down the underside of the shaft
        "sulcus_ventral_mm": 0.5,          # coronal sulcus is deeper on the underside
        "rim_lateral": 0.035,              # corona rim slightly more prominent at the sides
        "meatus_mm": 0.7,                  # depth of the vertical meatal slit
    },
}


def _phallus_radius(t, k):
    P = PHALLUS
    if t <= P["tip_start"]:
        return _catmull(P["profile_mm"], t) * 0.001 * k
    return 0.0


def create_symmetric_phallus(skin, material, armature, pelvis_bone,
                             body_height, anatomy_z, anchor_y, anatomy_state, centre_x=0.0, tree=None):
    """Symmetric loft for BOTH states. The mesh is the erect form; the flaccid pose is stored
    as `flaccid_positions` (same vertex order) for the morph target."""
    P, T = PHALLUS, MALE_TRANSITION
    F = P["foreskin"]
    unc = P["style"] == "uncircumcised"
    cov = max(0.0, min(1.0, F["coverage"]))
    ov_mm = F["overhang_mm"] * cov                                 # skin beyond the glans apex
    tip_r = 0.72 - (0.72 - F["tip_radius"]) * cov                  # blunt snout radius (relative)
    open_mm = 3.0 - (3.0 - F["opening_mm"]) * cov                  # opening dimple depth
    open_sig = (2.2 - (2.2 - 1.3) * cov) * 0.001                   # opening dimple radius
    bulge_eff = 0.14 - (0.14 - F["glans_bulge"]) * cov             # glans swelling under the skin
    pucker_eff = F["pucker_mm"] * (0.5 + 0.5 * cov)
    peek = max(0.0, min(1.0, (0.7 - cov) / 0.7))                    # below ~0.7 coverage the glans tip shows through
    H = body_height
    # Clinical averages are measured in centimetres, not height-normalised.
    # Keep the mesh dimensions absolute across tall/short body variants.
    k = 1.0
    length = SIZE["reference_height_m"] * SIZE["mesh_length_fraction"] * T["erect_length_scale"]
    girth = T["erect_girth_scale"]               # radius multiplier; independent of the length scale
    axis = Vector((0.0, -0.985, -0.17)).normalized()
    base = Vector((centre_x, anchor_y + H * 0.016, anatomy_z + H * 0.004))
    x_axis = Vector((1.0, 0.0, 0.0))
    right_e = (x_axis - axis * x_axis.dot(axis)).normalized()
    side_e = axis.cross(right_e).normalized()
    base = base + side_e * (P["axis_offset_mm"] * 0.001 * k)
    add_anatomy_bones(armature, pelvis_bone, base, axis, length)

    # ring parameters (erect arc fraction): shaft, glans, then a rounded cap
    ts = [P["glans_start"] * i / P["rings_shaft"] for i in range(P["rings_shaft"])]
    g0, g1 = P["glans_start"], P["tip_start"]
    ts += [g0 + (g1 - g0) * i / P["rings_glans"] for i in range(P["rings_glans"] + 1)]
    cap = []
    for i in range(P["rings_cap"]):
        phi = (i + 1) / (P["rings_cap"] + 1) * (math.pi / 2.0)
        cap.append((P["tip_start"] + (P["tip_end"] - P["tip_start"]) * math.sin(phi), math.cos(phi)))
    ring_t = ts + [c[0] for c in cap]
    ring_cap = [1.0] * len(ts) + [c[1] for c in cap]
    r_tip = _catmull(P["profile_mm"], P["tip_start"]) * 0.001 * girth
    segs = int(P["segments"])
    def section(t):
        ratio = P["section_ratio"] + (P["head_section_ratio"] - P["section_ratio"]) * _smooth01(0.66, 0.84, t)
        return 1.0 / math.sqrt(ratio), math.sqrt(ratio)


    def outside_skin(p):
        if tree is None:
            return True
        loc, nrm, _i, _d = tree.find_nearest(p)
        return (p - loc).dot(nrm) > 0.0005

    # where the erect centre line leaves the body, and the concave fillet that blends it in
    exit_e = length * 0.2
    if tree is not None:
        a_ = 0.0
        while a_ < length and not outside_skin(base + axis * a_):
            a_ += 0.001
        exit_e = a_
    fil = P["fillet_mm"] * 0.001 * k
    lead = P["fillet_lead_mm"] * 0.001 * k

    def signed_gap(p):
        if tree is None:
            return -1.0
        loc, nrm, _i, _d = tree.find_nearest(p)
        return (p - loc).dot(nrm)

    tol = 0.0015 * k          # the fillet may stand at most this far off the skin

    def hugging(make, extra):
        """Largest fillet extra (<= extra) whose vertex stays within `tol` of the skin."""
        if extra <= 1e-6 or tree is None:
            return make(extra)
        if signed_gap(make(extra)) <= tol:
            return make(extra)
        lo, hi = 0.0, extra
        for _ in range(7):
            mid = 0.5 * (lo + hi)
            if signed_gap(make(mid)) <= tol:
                lo = mid
            else:
                hi = mid
        return make(lo)

    def fillet(arc, exit_arc):
        d = exit_arc + lead - arc
        if d <= 0.0 or fil <= 0.0:
            return 0.0
        d = min(d, fil)
        return fil - math.sqrt(max(fil * fil - d * d, 0.0))

    def radius_erect(t, cap_f):
        r0 = r_tip if t > P["tip_start"] else _catmull(P["profile_mm"], t) * 0.001 * girth
        return (r0 + fillet(t * length, exit_e)) * cap_f

    # flaccid pose: shortened shaft, thinner, flared root, curved down under gravity
    comp, gls, g_start = T["shaft_compress"], T["glans_length_scale"], T["glans_start"]

    dome_len_f = (P["tip_end"] - P["tip_start"]) * length * gls
    stretch = 1.0 + (ov_mm * 0.001 * girth / dome_len_f) if unc else 1.0

    def _s_basic(a):
        a_g = g_start * length
        return a * comp if a <= a_g else comp * a_g + (a - a_g) * gls

    def to_s(t):
        if unc and t > P["tip_start"]:      # covered pose: the dome rings become the foreskin overhang
            return _s_basic(P["tip_start"] * length) + (t - P["tip_start"]) * length * gls * stretch
        return _s_basic(t * length)

    s_total = to_s(P["tip_end"])
    steps = 400
    ds = s_total / steps
    path, tang = [base.copy()], []
    pos = base.copy()
    for i in range(steps):
        u = (i + 0.5) / steps
        phi = math.radians(T["angle_root_deg"] + (T["angle_tip_deg"] - T["angle_root_deg"]) * (u ** 1.3))
        tv = Vector((T["lateral"], -math.cos(phi), -math.sin(phi))).normalized()
        pos = pos + tv * ds
        tang.append(tv); path.append(pos.copy())
    tang.append(tang[-1])

    def sample(s):
        if s >= s_total:
            return path[-1], tang[-1]
        f = s / ds
        i = int(f); kk = f - i
        return path[i].lerp(path[i + 1], kk), tang[i].lerp(tang[i + 1], kk).normalized()

    exit_f = s_total * 0.2
    if tree is not None:
        s_ = 0.0
        while s_ < s_total and not outside_skin(sample(s_)[0]):
            s_ += 0.001
        exit_f = s_

    def flaccid_scale(t):
        return (T["shaft_girth"] + (T["glans_girth"] - T["shaft_girth"]) * _smooth01(0.74, 0.82, t)) \
            * (1.0 + T["root_flare"] * (1.0 - _smooth01(0.0, 0.18, t)))

    G = P["glans"]

    def glans_mod(t, a):
        """(relative radius factor, absolute radius offset in metres at k=1) for ring parameter t, angle a."""
        sa, ca = math.sin(a), math.cos(a)
        bump = lambda c, sg: math.exp(-0.5 * ((t - c) / sg) ** 2)
        rel = 1.0 + G["dorsal_gain"] * sa * _smooth01(G["start"], G["end"], t) \
            + G["rim_lateral"] * ca * ca * bump(0.835, 0.014)
        phiv = math.atan2(abs(ca), -sa)                      # angle away from the ventral midline
        gv = lambda sg: math.exp(-0.5 * (phiv / sg) ** 2)
        flank = math.exp(-0.5 * ((phiv - 0.20) / 0.07) ** 2)
        glans_env = _smooth01(0.865, 0.895, t) * (1.0 - _smooth01(0.985, 1.005, t))
        absd = (-G["notch_mm"] * gv(0.28) * bump(0.835, 0.026)
                + (G["frenulum_mm"] * gv(0.07) - G["groove_mm"] * flank) * glans_env
                + G["ridge_mm"] * gv(0.10) * bump(0.765, 0.03)
                + G["raphe_mm"] * gv(0.05) * _smooth01(0.18, 0.30, t) * (1.0 - _smooth01(0.70, 0.76, t))
                - G["sulcus_ventral_mm"] * max(0.0, -sa) * bump(0.775, 0.02)) * 0.001
        return rel, absd

    def cover_radius(t):
        """Covered (flaccid) form: shaft skin over the glans, then narrowing into the foreskin opening."""
        r_base = _catmull(P["profile_mm"], min(t, 0.70)) * 0.001 * girth
        sc = flaccid_scale(t) * (1.0 - F["taper"] * _smooth01(0.45, 0.74, t))
        bulge = 1.0 + bulge_eff * _smooth01(0.74, 0.84, t)
        if t <= P["tip_start"]:
            return r_base * sc * bulge
        u = (t - P["tip_start"]) / (P["tip_end"] - P["tip_start"])
        if u < 0.85:                                         # skin narrows into a blunt snout ...
            f = 1.0 - (1.0 - tip_r) * _smooth01(0.40, 0.85, u)
        else:                                                # ... which closes in a short rounded end
            f = tip_r * math.sqrt(max(0.0, 1.0 - ((u - 0.85) / 0.15) ** 2))
        if peek > 0.0:                                       # less covered: skin ends in a rim, glans dome shows
            u_r = 0.62
            f_r = 1.0 - (1.0 - tip_r) * _smooth01(0.40, 0.85, u_r)
            if u < u_r:
                f_peek = 1.0 - (1.0 - tip_r) * _smooth01(0.40, 0.85, u)
            else:
                groove = 1.0 - 0.16 * _smooth01(u_r, u_r + 0.05, u)
                v = (u - (u_r + 0.06)) / (1.0 - (u_r + 0.06))
                dome = math.sqrt(max(0.0, 1.0 - v * v)) if v > 0.0 else 1.0
                f_peek = f_r * groove * dome
            f = (1.0 - peek) * f + peek * f_peek
        return r_base * sc * bulge * f

    def collar(t, a):
        """Retracted (erect) form: the foreskin bunched into a rolled collar behind the corona."""
        sa = math.sin(a)
        bump = math.exp(-0.5 * ((t - F["collar_t"]) / F["collar_sigma"]) ** 2)
        ripple = math.sin(2.0 * math.pi * (t - F["collar_t"]) / 0.016) * math.exp(-0.5 * ((t - F["collar_t"]) / 0.02) ** 2)
        ca2 = math.cos(2.0 * a)
        irregular = 1.0 + 0.15 * sa + 0.22 * ca2 + 0.10 * math.cos(4.0 * a)   # thicker at the sides: mirror-symmetric
        return (F["collar_mm"] * bump * irregular + F["collar_wrinkle_mm"] * ripple * (0.6 + 0.4 * math.cos(4.0 * a))) * 0.001

    erect_v, flaccid_v, cols = [], [], []
    for t, cap_f in zip(ring_t, ring_cap):
        fe, ff = fillet(t * length, exit_e) * cap_f, fillet(to_s(t), exit_f) * cap_f
        r_prof = (r_tip if t > P["tip_start"] else _catmull(P["profile_mm"], t) * 0.001 * girth) * cap_f
        r_flac = cover_radius(t) if unc else r_prof * flaccid_scale(t)
        centre_e = base + axis * (t * length)
        droop = G["droop_mm"] * 0.001 * _smooth01(0.80, 1.0, t) ** 2
        droop_f = (F["droop_mm"] if unc else G["droop_mm"]) * 0.001 * _smooth01(0.80, 1.0, t) ** 2
        centre_f, tv = sample(to_s(t))
        right_f = (x_axis - tv * x_axis.dot(tv)).normalized()
        side_f = tv.cross(right_f).normalized()
        centre_e = centre_e - side_e * (droop * girth)
        centre_f = centre_f - side_f * (droop_f * girth * flaccid_scale(t))
        u_cap = 1.0 - cap_f
        if unc:        # glans tone only; the skin collar and sleeve keep the skin colour
            strength = min(1.0, 0.5 * math.exp(-0.5 * ((t - 0.93) / 0.05) ** 2))
        else:
            glans = math.exp(-0.5 * ((t - 0.92) / 0.07) ** 2)
            groove = math.exp(-0.5 * ((t - 0.785) / 0.026) ** 2)
            strength = min(1.0, 0.62 * glans + 0.22 * groove)
        col = (1.0 + 0.04 * strength, 1.0 - 0.19 * strength, 1.0 - 0.15 * strength, 1.0)
        for j in range(segs):
            a = 2.0 * math.pi * j / segs
            wid, dep = section(t)
            cw, sd = math.cos(a) * wid, math.sin(a) * dep
            rel, absd = glans_mod(t, a)
            if unc:
                re_ = r_prof * rel + (absd + collar(t, a)) * girth * cap_f
                u_f = max(0.0, (t - P["tip_start"]) / (P["tip_end"] - P["tip_start"]))
                w_sleeve = _smooth01(0.55, 0.95, u_f)
                w_rim = _smooth01(0.45, 0.60, u_f) * (1.0 - _smooth01(0.64, 0.70, u_f))
                pucker = pucker_eff * 0.001 * math.cos(F["pucker_lobes"] * a) * ((1.0 - peek) * w_sleeve + peek * w_rim) \
                    * (1.0 if t > P["tip_start"] else 0.0)
                rf_ = r_flac + pucker * girth
            else:
                re_ = r_prof * rel + absd * girth * cap_f
                rf_ = r_flac * rel + absd * girth * flaccid_scale(t) * cap_f
            pe = hugging(lambda x: centre_e + right_e * ((re_ + x) * cw) + side_e * ((re_ + x) * sd), fe)
            pf = hugging(lambda x: centre_f + right_f * ((rf_ + x) * cw) + side_f * ((rf_ + x) * sd), ff)
            if u_cap > 0.0:                                   # meatus: elongated dimple (long axis dorsoventral)
                lat_e, dv_e = re_ * cw, re_ * sd
                lat_f, dv_f = rf_ * cw, rf_ * sd
                s_lat, s_dv = 0.0007 * k, 0.0016 * k
                dm = G["meatus_mm"] * 0.001 * girth
                pe = pe - axis * (dm * math.exp(-0.5 * ((lat_e / s_lat) ** 2 + (dv_e / s_dv) ** 2)))
                if unc:       # round dimple at the foreskin opening
                    sl = open_sig * k * (1.0 - 0.5 * peek)
                    pf = pf - tv * (open_mm * (1.0 - 0.7 * peek) * 0.001 * girth * math.exp(-0.5 * ((lat_f / sl) ** 2 + (dv_f / sl) ** 2)))
                else:
                    pf = pf - tv * (dm * math.exp(-0.5 * ((lat_f / s_lat) ** 2 + (dv_f / s_dv) ** 2)))
            if unc:
                asym = F["asymmetry_mm"] / 0.8 if F["asymmetry_mm"] else 0.0
                w_rim = _smooth01(0.45, 0.80, u_f)
                pf = pf + tv * (F["rim_tilt_mm"] * 0.001 * girth * math.sin(a) * w_rim)        # oblique rim
                pf = pf + right_f * (F["asymmetry_mm"] * 0.001 * girth * _smooth01(0.30, 1.0, u_f))  # slight drift
                pf = pf + (right_f * math.cos(a) + side_f * math.sin(a)) * (
                    0.25 * asym * pucker * math.sin(3.0 * a + 0.7))                            # uneven pleats
            erect_v.append(pe)
            flaccid_v.append(pf)
            cols.append(col)
    # root cap (buried) and tip apex
    erect_v.append(base.copy()); flaccid_v.append(base.copy()); cols.append((1.0, 1.0, 1.0, 1.0))
    root_idx = len(erect_v) - 1
    apex_depth = G["meatus_mm"] * 0.001 * girth
    tip_tv = sample(s_total)[1]
    tip_side_f = tip_tv.cross((x_axis - tip_tv * x_axis.dot(tip_tv)).normalized()).normalized()
    erect_v.append(base + axis * (P["tip_end"] * length) - side_e * (G["droop_mm"] * 0.001 * girth) - axis * apex_depth)
    flaccid_v.append(sample(s_total)[0] - tip_side_f * ((F["droop_mm"] if unc else G["droop_mm"]) * 0.001 * girth * flaccid_scale(1.0))
                     - tip_tv * ((open_mm if unc else G["meatus_mm"]) * 0.001 * girth))
    cols.append(cols[-2])
    apex_idx = len(erect_v) - 1

    rings = len(ring_t)
    faces = []
    for i in range(rings - 1):
        for j in range(segs):
            a_ = i * segs + j; b_ = i * segs + (j + 1) % segs
            c_ = (i + 1) * segs + (j + 1) % segs; d_ = (i + 1) * segs + j
            faces.append((a_, b_, c_, d_))
    last = (rings - 1) * segs
    for j in range(segs):
        faces.append((root_idx, (j + 1) % segs, j))
        faces.append((apex_idx, last + j, last + (j + 1) % segs))
    vol = 0.0
    for f in faces:
        pts = [erect_v[x] for x in f]
        for n in range(1, len(pts) - 1):
            vol += pts[0].dot(pts[n].cross(pts[n + 1])) / 6.0
    if vol < 0:
        faces = [tuple(reversed(f)) for f in faces]

    obj = create_mesh_object("Male anatomy · symmetric shaft and glans", [tuple(v) for v in erect_v],
                             faces, material, armature, pelvis_bone)
    # The shaft is driven entirely by the pelvis-parented anatomy bone chain.
    # Remove the default pelvis influence so AnatomyRoot scaling remains exact.
    pelvis_group = obj.vertex_groups.get(pelvis_bone)
    if pelvis_group is not None:
        pelvis_group.remove(list(range(len(erect_v))))
    shaft_groups = [obj.vertex_groups.new(name=n) for n in ("AnatomyRoot", "AnatomyMid", "AnatomyTip")]
    for vi in range(len(erect_v)):
        t = 0.0 if vi == root_idx else (P["tip_end"] if vi == apex_idx else ring_t[vi // segs])
        t = max(0.0, min(1.0, t))
        w = (max(0.0, min(1.0, (0.62 - t) / 0.42)), max(0.0, 1.0 - abs(t - 0.52) / 0.42),
             max(0.0, min(1.0, (t - 0.38) / 0.42)))
        total = sum(w)
        for g, wt in zip(shaft_groups, w):
            if wt > 0.001 and total > 0.0:
                g.add([vi], wt / total, "REPLACE")
    attr = obj.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for i, c in enumerate(cols):
        attr.data[i].color = c
    obj.data.color_attributes.active_color = attr
    obj["phallus_colour_painted"] = True
    obj["target_base"] = [float(v) for v in base]
    obj["target_axis"] = [float(v) for v in axis]
    obj["target_length_m"] = length
    obj["anatomy_state"] = anatomy_state
    obj["anatomy_parts"] = "flared_root,symmetric_shaft,sulcus,corona,rounded_glans"
    obj["anatomy_method"] = "symmetric_parametric_loft_fitted_to_accepted_erect_v1"
    obj["flaccid_positions"] = [float(c) for v in flaccid_v for c in v]
    visible_erect = P["tip_end"] * length - exit_e      # from where the centre line leaves the skin
    visible_flaccid = s_total - exit_f
    obj["visible_erect_length_m"] = float(visible_erect)
    obj["visible_flaccid_length_m"] = float(visible_flaccid)
    print(f"Symmetric phallus: {len(erect_v)} vertices, erect length {length:.4f} m "
          f"(visible {visible_erect * 100:.1f} cm erect, {visible_flaccid * 100:.1f} cm flaccid), max radius "
          f"{max(p[1] for p in P['profile_mm']) * 0.001 * girth:.4f} m")
    return obj


# ---------------------------------------------------------------------------
# Scrotum: parametric teardrop sac with two testis lobes.
#
# Built as horizontal rings hanging from the front of the perineal arch. Each ring is
# the soft union of two ellipses (the testes), which gives a natural median division
# without a modelled groove. On top of that: a left/right drop difference, a raphe
# ridge, and rugae (fine transverse wrinkles). The relaxed and erect forms are generated
# from the same grid, so they share a topology and form the scrotal half of the
# `Anatomy_Erect` morph target (the erect sac is shorter, tighter and finer-wrinkled).
#
# Metres for a 1.676 m body, scaled by body height. Edit this block to fine-tune.
# ---------------------------------------------------------------------------
SCROTUM = {
    "rings": 120, "segments": 120,
    "relaxed": {"length": 0.068, "half_width": 0.0255, "half_depth": 0.0205, "lobe_offset": 0.0115,
                "lobe_drop": 0.02, "drift": -0.012, "rugae_amp": 0.00022, "rugae_wavelength": 0.0060},
    "erect":   {"length": 0.056, "half_width": 0.0245, "half_depth": 0.0200, "lobe_offset": 0.0085,
                "lobe_drop": 0.0, "drift": -0.007, "groove_blend": 0.008, "rugae_amp": 0.00042, "rugae_wavelength": 0.0036},
    "groove_blend": 0.004,       # softness of the join between the lobes (larger = shallower division)
    "raphe_height": 0.0007,      # raised median ridge
    "closure_start": 0.70,       # where the sac closes into its rounded base
    # (v along the sac 0=top..1=base, scale) - narrow neck, widest over the testes, rounded base
    "width_profile": [(0.0, 0.55), (0.12, 0.62), (0.30, 0.85), (0.50, 1.00), (0.70, 0.95), (0.85, 0.80), (0.90, 0.72)],
    "depth_profile": [(0.0, 0.50), (0.12, 0.60), (0.30, 0.84), (0.50, 1.00), (0.70, 0.94), (0.85, 0.80), (0.90, 0.72)],
    "tint": (0.985, 0.935, 0.92),  # skin-relative colour (multiplies the skin texture)
}


def _catmull(points, t):
    ts = [p[0] for p in points]; vs = [p[1] for p in points]
    if t <= ts[0]:
        return vs[0]
    if t >= ts[-1]:
        return vs[-1]
    i = max(j for j in range(len(ts) - 1) if ts[j] <= t)
    u = (t - ts[i]) / (ts[i + 1] - ts[i])
    p0, p1, p2 = vs[max(i - 1, 0)], vs[i], vs[i + 1]
    p3 = vs[min(i + 2, len(vs) - 1)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                  + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)


def _lattice(i, j):
    x = math.sin(i * 127.1 + j * 311.7) * 43758.5453
    return (x - math.floor(x)) * 2.0 - 1.0


def _value_noise(theta, v, nt, nv):
    """Smooth value noise in [-1, 1], periodic around the sac."""
    u = ((theta / (2.0 * math.pi)) % 1.0) * nt
    w = v * nv
    i0, j0 = int(math.floor(u)), int(math.floor(w))
    fu, fw = u - i0, w - j0
    fu, fw = fu * fu * (3 - 2 * fu), fw * fw * (3 - 2 * fw)
    g = lambda i, j: _lattice(i % nt, j)
    a = g(i0, j0) * (1 - fu) + g(i0 + 1, j0) * fu
    b = g(i0, j0 + 1) * (1 - fu) + g(i0 + 1, j0 + 1) * fu
    return a * (1 - fw) + b * fw


def _ellipse_exit(theta, centre_x, a, b):
    """Distance from the origin to the boundary of an ellipse centred at (centre_x, 0)."""
    c, s = math.cos(theta), math.sin(theta)
    A = c * c / (a * a) + s * s / (b * b)
    B = centre_x * c / (a * a)
    C = centre_x * centre_x / (a * a) - 1.0
    return (B + math.sqrt(max(B * B - A * C, 0.0))) / A


def _scrotum_grid(state, origin, k):
    """Vertices (world space) and per-vertex colour for one scrotal state. Same topology for both states."""
    S = SCROTUM
    P = S[state]
    rings, segs = int(S["rings"]), int(S["segments"])
    length, hw, hd = P["length"] * k, P["half_width"] * k, P["half_depth"] * k
    xo_max, drop = P["lobe_offset"] * k, P["lobe_drop"]
    blend, closure = P.get("groove_blend", S["groove_blend"]) * k, S["closure_start"]
    amp, wl = P["rugae_amp"] * k, P["rugae_wavelength"] * k
    ox, oy, oz = origin
    v_max = 1.0 + drop

    def lobe(v):
        v = max(v, 0.0)
        cf = 1.0 if v <= closure else math.sqrt(max(0.0, 1.0 - ((v - closure) / (1.0 - closure)) ** 2))
        if v >= 1.0:
            return 0.0, 0.0, 0.0
        w = hw * _catmull(S["width_profile"], min(v, closure))
        xo = xo_max * _smooth01(0.12, 0.40, v) * (1.0 - 0.6 * _smooth01(0.75, 1.0, v))
        a = max(w - xo, 0.004 * k)
        return xo * cf, a * cf, hd * _catmull(S["depth_profile"], min(v, closure)) * cf

    verts, cols = [], []
    top_centre = Vector((ox, oy, oz))
    verts.append(top_centre); cols.append((1.0, 1.0, 1.0, 1.0))
    tint = S["tint"]
    for i in range(rings):
        t = i / rings
        v = t * v_max
        cy = oy + P["drift"] * k * min(v, 1.0)
        cz = oz - length * v
        xoR, aR, bR = lobe(v)
        xoL, aL, bL = lobe(v - drop)
        env_r = _smooth01(0.10, 0.30, v) * (1.0 - _smooth01(0.95, 1.05, v))
        env_m = _smooth01(0.12, 0.30, v) * (1.0 - _smooth01(0.92, 1.0, v))
        for j in range(segs):
            th = 2.0 * math.pi * j / segs
            rho_r = _ellipse_exit(th, +xoR, aR, bR) if aR > 0 else 0.0
            rho_l = _ellipse_exit(th, -xoL, aL, bL) if aL > 0 else 0.0
            hi, lo = max(rho_r, rho_l), min(rho_r, rho_l)
            h = max(blend - (hi - lo), 0.0) / blend
            rho = hi + h * h * blend * 0.25                   # soft union of the two lobes
            # rugae: irregular, patchy transverse wrinkles plus fine skin texture
            ths = th if math.cos(th) >= 0.0 else math.pi - th   # mirror about the midline so the pattern is symmetric
            n1 = _value_noise(ths, v, 8, 10)
            n2 = _value_noise(ths + 1.7, v + 0.3, 14, 22)
            ph1 = 0.9 * math.sin(ths + 1.3) + 0.5 * math.sin(2 * ths + 0.4) + 0.3 * math.sin(3 * ths + 2.1) + 1.8 * n1
            ph2 = 1.3 * math.sin(2 * ths + 0.9) + 0.7 * math.sin(3 * ths + 0.2) + 1.2 * n2
            wl_local = wl * (1.0 + 0.35 * n1)
            arc = v * length + 0.004 * k * math.cos(ths + 0.8) * (1.0 + n1)
            wr = (math.sin(2 * math.pi * arc / wl_local + ph1) + 0.5 * math.sin(2 * math.pi * arc / (wl_local * 0.53) + ph2)) / 1.5
            wr = wr * (0.35 + 0.65 * abs(n1) ** 0.7) + 0.4 * n2
            # raphe: raised median ridge on the front and back midline
            d_th = min(abs(math.remainder(th - math.pi / 2, 2 * math.pi)), abs(math.remainder(th + math.pi / 2, 2 * math.pi)))
            raphe = math.exp(-0.5 * (d_th / 0.05) ** 2) * env_m
            if rho > 0:
                rho += amp * env_r * wr + S["raphe_height"] * k * raphe
            rho = max(rho, 0.0)
            verts.append(Vector((ox + rho * math.cos(th), cy - rho * math.sin(th), cz)))
            m = math.exp(-0.5 * (d_th / 0.10) ** 2) * env_m
            shade = 1.0 - 0.05 * max(0.0, -wr) * env_r
            cols.append((tint[0] * shade * (1.0 - 0.07 * m), tint[1] * shade * (1.0 - 0.14 * m),
                         tint[2] * shade * (1.0 - 0.13 * m), 1.0))
    verts.append(Vector((ox, oy + P["drift"] * k, oz - length * v_max))); cols.append(cols[-1])
    return verts, cols


def create_scrotum(tree, material, armature, pelvis_bone, width, height, anatomy_z, anchor_y, anatomy_state, centre_x=0.0):
    """Teardrop sac hanging from the front of the perineal arch, plus its erect (tight, drawn-up) target."""
    k = height / 1.676
    S = SCROTUM
    y_top = anchor_y + 0.019 * k
    roof = tree.ray_cast(Vector((centre_x, y_top, anatomy_z - 0.35)), Vector((0.0, 0.0, 1.0)))
    roof_z = roof[0].z if roof and roof[0] is not None else anatomy_z - 0.02 * k
    origin = (centre_x, y_top, roof_z + 0.013 * k)         # neck buried in the body
    verts_relaxed, cols = _scrotum_grid("relaxed", origin, k)
    verts_erect, _ = _scrotum_grid("erect", origin, k)
    rings, segs = int(S["rings"]), int(S["segments"])
    faces = []
    for j in range(segs):                                   # top cap (buried)
        faces.append((0, 1 + (j + 1) % segs, 1 + j))
    for i in range(rings - 1):
        for j in range(segs):
            a = 1 + i * segs + j; b = 1 + i * segs + (j + 1) % segs
            c = 1 + (i + 1) * segs + (j + 1) % segs; d = 1 + (i + 1) * segs + j
            faces.append((a, b, c, d))
    apex = len(verts_relaxed) - 1
    last = 1 + (rings - 1) * segs
    for j in range(segs):
        faces.append((apex, last + j, last + (j + 1) % segs))
    # make sure the surface faces outward
    vol = 0.0
    for f in faces:
        pts = [verts_relaxed[x] for x in f]
        for n in range(1, len(pts) - 1):
            vol += pts[0].dot(pts[n].cross(pts[n + 1])) / 6.0
    if vol < 0:
        faces = [tuple(reversed(f)) for f in faces]

    def _normal_z(face):
        pts = [verts_relaxed[x] for x in face]
        return (pts[1] - pts[0]).cross(pts[2] - pts[0]).z

    fixed = []
    for n_face, face in enumerate(faces):
        if n_face < segs and _normal_z(face) < 0:                    # top cap must face up
            face = tuple(reversed(face))
        elif n_face >= len(faces) - segs and _normal_z(face) > 0:    # base cap must face down
            face = tuple(reversed(face))
        fixed.append(face)
    faces = fixed
    obj = create_mesh_object("Male anatomy · scrotum (teardrop, paired testes, raphe, rugae)",
                             [tuple(v) for v in verts_relaxed], faces, material, armature, pelvis_bone)
    attr = obj.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for idx, col in enumerate(cols):
        attr.data[idx].color = col
    obj.data.color_attributes.active_color = attr
    obj["scrotum_colour_painted"] = True
    obj["anatomy_state"] = anatomy_state
    obj["anatomy_parts"] = "scrotal_sac,left_testis_lobe,right_testis_lobe,median_raphe,rugae"
    obj["anatomy_method"] = "parametric_teardrop_soft_union_of_two_ellipses_v1"
    obj["erect_positions"] = [float(c) for v in verts_erect for c in v]
    return obj


def create_anal_detail(tree, skin_material, armature, pelvis_bone, height, hipline_z, centre_x=0.0):
    """Create a restrained, surface-conforming anal opening on the posterior midline.

    The male placement is referenced from the scrotoperineal region. Its vertical
    position is a modelling guide, not a claimed clinical population measurement.
    """
    # Ara faces -Y; sample posterior skin from +Y.
    anal_z = hipline_z - height * 0.065
    hit = normal = None
    z_offsets = (0.0, -0.008, 0.008, -0.016, 0.016, -0.024, 0.024)
    x_offsets = (0.006, 0.012, 0.020, 0.030)
    for z_offset in z_offsets:
        sampled = {}
        for x_offset in (0.0, *[v for pair in x_offsets for v in (pair, -pair)]):
            candidate, candidate_normal, _index, distance = tree.find_nearest(
                Vector((centre_x + height * x_offset, 3.0, anal_z + height * z_offset))
            )
            if candidate is not None and distance < 1.5:
                sampled[round(x_offset, 6)] = (candidate, candidate_normal)
        if 0.0 in sampled:
            hit, normal = sampled[0.0]
            anal_z += height * z_offset
            break
        # If the centre falls in the gluteal cleft, average the nearest posterior
        # surface points on both sides so the detail remains centred between cheeks.
        for magnitude in x_offsets:
            left_key, right_key = round(-magnitude, 6), round(magnitude, 6)
            if left_key in sampled and right_key in sampled:
                left, left_normal = sampled[left_key]
                right, right_normal = sampled[right_key]
                hit = (left + right) * 0.5
                normal = (left_normal + right_normal).normalized()
                hit.x = centre_x
                anal_z += height * z_offset
                break
        if hit is not None:
            break
    if hit is None or normal is None:
        raise RuntimeError("Could not locate posterior skin surfaces around the gluteal cleft") 
    rear = Vector((0.0, 1.0, 0.0))
    if normal.dot(rear) < 0.0:
        normal.negate()
    tangent_x = Vector((1.0, 0.0, 0.0)) - normal * normal.x
    if tangent_x.length < 1e-5:
        raise RuntimeError("Posterior skin normal is unsuitable for anal detail orientation")
    tangent_x.normalize()
    tangent_z = tangent_x.cross(normal).normalized()
    centre = hit + normal * 0.00025

    segments = 48
    loops = (
        (0.0100, 0.0068, 0.00025),
        (0.0080, 0.0054, 0.00110),
        (0.0061, 0.0039, 0.00075),
    )
    vertices = []
    for rx, rz, lift in loops:
        for j in range(segments):
            angle = 2.0 * math.pi * j / segments
            point = (centre + tangent_x * (rx * math.cos(angle))
                     + tangent_z * (rz * math.sin(angle)) + normal * lift)
            vertices.append(tuple(point))
    faces = []
    material_indices = []
    for ring in range(len(loops) - 1):
        outer = ring * segments
        inner = (ring + 1) * segments
        for j in range(segments):
            nxt = (j + 1) % segments
            faces.append((outer + j, inner + j, inner + nxt, outer + nxt))
            material_indices.append(0)

    centre_index = len(vertices)
    vertices.append(tuple(centre - normal * 0.00035))
    inner = (len(loops) - 1) * segments
    for j in range(segments):
        nxt = (j + 1) % segments
        faces.append((centre_index, inner + nxt, inner + j))
        material_indices.append(1)

    obj = create_mesh_object(
        "Male anatomy · anal opening and perianal rim",
        vertices, faces, skin_material, armature, pelvis_bone
    )
    dark = bpy.data.materials.new("Anatomy detail · recessed anal opening")
    dark.diffuse_color = (0.16, 0.055, 0.045, 1.0)
    dark.use_nodes = True
    shader = next((node for node in dark.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
    if shader:
        shader.inputs["Base Color"].default_value = (0.16, 0.055, 0.045, 1.0)
        shader.inputs["Roughness"].default_value = 0.88
    obj.data.materials.append(dark)
    for polygon, material_index in zip(obj.data.polygons, material_indices):
        polygon.material_index = material_index
    colour = obj.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for item in colour.data:
        item.color = (1.0, 1.0, 1.0, 1.0)
    obj.data.color_attributes.active_color = colour
    obj["anatomy_parts"] = "external_anal_opening,perianal_rim"
    obj["anal_reference_landmark"] = "male_scrotoperineal_region"
    obj["anal_position_method"] = "posterior_midline_surface_raycast_with_cleft_bridge"
    obj["anal_vertical_offset_from_hipline_mm"] = round((hipline_z - anal_z) * 1000.0, 2)
    obj["anal_opening_dimensions_mm"] = "12.2 x 7.8 inner oval; 20 x 13.6 outer rim"
    print("Male anal anatomy: posterior midline surface hit "
          f"at ({hit.x:.4f}, {hit.y:.4f}, {hit.z:.4f}); "
          f"hipline vertical offset {(hipline_z - anal_z) * 1000.0:.1f} mm")
    return obj


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



def paint_male_anatomy_detail(obj, centre_x, anatomy_z, height, anchor_y, state, part,
                              length_factor=1.0, girth_factor=1.0):
    mesh = obj.data
    if (part == 'scrotum' and obj.get('scrotum_colour_painted')):
        return
    old = mesh.color_attributes.get('Color')
    if old: mesh.color_attributes.remove(old)
    colour = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
    if part == 'phallus':
        axis = Vector((0.0, -0.43, -0.90)).normalized() if state == 'flaccid' else Vector((0.0, -0.985, -0.17)).normalized()
        length = height * (0.038 if state == 'flaccid' else 0.074) * length_factor
        base = Vector((centre_x, anchor_y + height * (0.003 if state == 'flaccid' else 0.016), anatomy_z + height * 0.004))
        for vertex in mesh.vertices:
            point = obj.matrix_world @ vertex.co
            relative = point - base
            along = relative.dot(axis)
            t = max(0.0, min(1.0, along / length))
            radial = (relative - axis * along).length
            radius = height * (0.0085 if state == 'flaccid' else 0.010) * girth_factor
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
    combined["anatomy_parts"] = "integrated_root,shaft,rounded_tip,scrotal_sac,anal_opening,perianal_rim"
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
    skin["male_anatomy_parts"] = "integrated_root,shaft,glans,corona,scrotal_sac,anal_opening,perianal_rim"
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


# ---------------------------------------------------------------------------
# Flaccid <-> erect: ONE mesh, ONE morph target.
#
# The accepted erect surface (Ara's finger-derived mesh) is the master. The
# flaccid pose is derived from that same mesh, so both states share a topology,
# and the shaft/glans character carries across. The base mesh is flaccid and the
# `Anatomy_Erect` shape key (glTF morph target / Godot blend shape) moves it to
# the erect form: weight 0 = flaccid, weight 1 = erect, anything between is a
# continuous transition. The scrotum shares the same key (it draws up and tightens).
#
# The penis uses absolute clinical dimensions; body height determines placement only.
# The scrotum retains its existing body-proportion scaling.
# ---------------------------------------------------------------------------
MALE_TRANSITION = {
    "shape_key": "Anatomy_Erect",
    # Erect size multipliers on the base mesh (12.4 cm long, 9.3 cm mid-shaft circumference at 1.676 m).
    # Do not edit these: resolve_penis_size() sets them at run time from SIZE and the CLI
    # (--length-scale / --girth-scale / --variation-seed). Length and girth are independent.
    # The flaccid pose is derived from the erect mesh, so both states follow.
    "erect_length_scale": 1.0,
    "erect_girth_scale": 1.0,
    "clip": "MaleAnatomy_Erection",   # 24-frame clip: 0 -> 1 (play backwards for the return)
    "clip_frames": (1, 24),
    # flaccid derivation (phallus)
    "glans_start": 0.79,         # where the glans begins along the erect mesh (0..1)
    "shaft_compress": 0.639,     # calibrated so the derived flaccid length is ~9.16 cm at the erect mean
    "glans_length_scale": 0.92,  # the glans keeps most of its length
    "shaft_girth": 0.7985,       # 9.31 / 11.66 cm: pooled flaccid / erect circumference
    "glans_girth": 0.845,        # radial scale of the glans vs erect (keeps the original glans:shaft ratio of 1.056)
    "root_flare": 0.0,           # (the phallus fillet now handles the body blend)
    "angle_root_deg": 36.0,      # centre line direction below horizontal at the root ...
    "angle_tip_deg": 84.0,       # ... and at the tip (hangs under gravity)
    "lateral": 0.0,              # sideways rest (0 = hangs straight, symmetric)
    # scrotum: see SCROTUM (its erect target is generated alongside the relaxed form)
}


def _smooth01(a, b, x):
    u = max(0.0, min(1.0, (x - a) / (b - a)))
    return u * u * (3.0 - 2.0 * u)


def derive_flaccid_positions(erect_world, base, axis, length):
    """Re-pose the erect phallus vertices (world space) as a hanging, shortened, thinner form."""
    P = MALE_TRANSITION
    axis = Vector(axis).normalized()
    base = Vector(base)
    x_axis = Vector((1.0, 0.0, 0.0))
    right_e = (x_axis - axis * x_axis.dot(axis)).normalized()
    side_e = axis.cross(right_e).normalized()
    along_g = P["glans_start"] * length
    comp, gls = P["shaft_compress"], P["glans_length_scale"]

    def to_s(a):
        return a * comp if a <= along_g else comp * along_g + (a - along_g) * gls

    alongs = [(Vector(p) - base).dot(axis) for p in erect_world]
    s_total = to_s(max(alongs))
    # gravity-curved centre line sampled by arc length
    steps = 400
    ds = s_total / steps
    path, tang = [base.copy()], []
    pos = base.copy()
    for i in range(steps):
        u = (i + 0.5) / steps
        phi = math.radians(P["angle_root_deg"] + (P["angle_tip_deg"] - P["angle_root_deg"]) * (u ** 1.3))
        tvec = Vector((P["lateral"], -math.cos(phi), -math.sin(phi))).normalized()
        pos = pos + tvec * ds
        tang.append(tvec)
        path.append(pos.copy())
    tang.append(tang[-1])

    def sample(s):
        if s <= 0.0:
            return base + tang[0] * s, tang[0]
        if s >= s_total:
            return path[-1] + tang[-1] * (s - s_total), tang[-1]
        f = s / ds
        i = int(f)
        k = f - i
        return path[i].lerp(path[i + 1], k), tang[i].lerp(tang[i + 1], k).normalized()

    out = []
    for p, a in zip(erect_world, alongs):
        rel = Vector(p) - base
        radial = rel - axis * a
        ca, cb = radial.dot(right_e), radial.dot(side_e)
        t = max(0.0, min(1.05, a / length))
        scale = (P["shaft_girth"] + (P["glans_girth"] - P["shaft_girth"]) * _smooth01(0.74, 0.82, t)) \
            * (1.0 + P["root_flare"] * (1.0 - _smooth01(0.0, 0.18, t)))
        centre, tv = sample(to_s(a))
        right_f = (x_axis - tv * x_axis.dot(tv)).normalized()
        side_f = tv.cross(right_f).normalized()
        out.append(centre + (right_f * ca + side_f * cb) * scale)
    return out


def derive_erect_scrotum_positions(relaxed_world, height):
    """Erect target for the scrotum: smaller, drawn up and in toward the body."""
    P = MALE_TRANSITION
    xs = [p.x for p in relaxed_world]; ys = [p.y for p in relaxed_world]; zs = [p.z for p in relaxed_world]
    cx, cy = 0.5 * (min(xs) + max(xs)), 0.5 * (min(ys) + max(ys))
    top = max(zs)
    return [Vector((cx + (p.x - cx) * P["scrotum_width"],
                    cy + (p.y - cy) * P["scrotum_depth"] + height * P["scrotum_draw_in"],
                    top - (top - p.z) * P["scrotum_height"])) for p in relaxed_world]


def add_erect_morph(skin, first_vertex, erect_world, state, author_clip):
    """Add the `Anatomy_Erect` morph target to the (already merged) skin mesh.

    Only the anatomy vertices move; every other vertex, and the facial shape
    keys, are untouched. Weight 0 = flaccid (the base mesh), 1 = erect.
    """
    P = MALE_TRANSITION
    mesh = skin.data
    if mesh.shape_keys is None:
        skin.shape_key_add(name="Basis", from_mix=False)
    key = skin.shape_key_add(name=P["shape_key"], from_mix=False)
    key.relative_key = mesh.shape_keys.key_blocks[0]
    inv = skin.matrix_world.inverted()
    for i, p in enumerate(erect_world):
        key.data[first_vertex + i].co = inv @ p
    key.slider_min, key.slider_max = 0.0, 1.0
    final = 1.0 if state == "erect" else 0.0
    if author_clip:
        sk = mesh.shape_keys
        for other in sk.key_blocks:          # the clip must not carry stray facial weights
            if other is not key:
                other.value = 0.0
        sk.animation_data_create()
        first, last = P["clip_frames"]
        for frame, value in ((first, 0.0), (last, 1.0)):
            key.value = value
            key.keyframe_insert("value", frame=frame)
        action = sk.animation_data.action
        action.name = P["clip"]
        # Push the clip onto an NLA track of the same name (as the glTF importer does for the
        # other clips) so the exporter writes it as its own animation: "MaleAnatomy_Erection".
        track = sk.animation_data.nla_tracks.new()
        track.name = P["clip"]
        track.strips.new(P["clip"], int(first), action)
        sk.animation_data.action = None
        bpy.context.scene.frame_start, bpy.context.scene.frame_end = first, last
        bpy.context.scene.frame_set(last if state == "erect" else first)
    key.value = final
    skin["anatomy_morph_target"] = P["shape_key"]
    skin["anatomy_morph_meaning"] = "weight 0 = flaccid, weight 1 = erect (phallus and scrotum)"
    skin["anatomy_default_state"] = state
    return key


# ---------------------------------------------------------------------------
# Size: population mean, caller scales, optional seeded per-character variation.
#
# Reference values are the pooled means / SDs of Veale et al., BJU Int 2015;115:978
# (systematic review, up to 15,521 men). At scale 1.0 and no seed the model is the mean.
# The clinical measurements are absolute adult averages; body height changes placement, not genital dimensions.
# ---------------------------------------------------------------------------
SIZE = {
    "reference_height_m": 1.676,
    "erect_length_cm": 13.12, "erect_length_sd_cm": 1.66,
    "erect_circumference_cm": 11.66, "erect_circumference_sd_cm": 1.10,
    "flaccid_length_cm": 9.16, "flaccid_length_sd_cm": 1.57,
    "flaccid_circumference_cm": 9.31, "flaccid_circumference_sd_cm": 0.90,
    "mesh_length_fraction": 0.074,          # base mesh length / body height (the T["erect_length_scale"] = 1 mesh)
    "circumference_measured_at_t": 0.5,     # mid-shaft, as in the source studies (not under the corona)
    "variation_clip_sd": 2.0,               # per-character draws are clipped to +/- this many SDs
    "length_girth_correlation": 0.0,        # 0 = independent draws; my assumption, not from the review. Raise it
                                            # (0.3-0.5) if you want longer characters to also tend to be thicker.
}


def resolve_penis_size(length_scale, girth_scale, seed, strength, body_height):
    """Turn CLI scales + optional seed into the mesh multipliers in MALE_TRANSITION. Returns a summary dict."""
    if length_scale <= 0.0 or girth_scale <= 0.0:
        raise SystemExit("--length-scale and --girth-scale must be positive")
    if not 0.0 <= strength <= 1.0:
        raise SystemExit("--variation-strength must be between 0 and 1 for realistic population variation")
    S = SIZE
    z_len = z_circ = 0.0
    if seed is not None and strength > 0.0:
        rng = random.Random(str(seed))                       # string seeds are deterministic across runs
        clip, rho = S["variation_clip_sd"], S["length_girth_correlation"]
        z_len = max(-clip, min(clip, rng.gauss(0.0, 1.0)))
        z_circ = max(-clip, min(clip, rho * z_len + math.sqrt(max(0.0, 1.0 - rho * rho)) * rng.gauss(0.0, 1.0)))
    length_cm = length_scale * (S["erect_length_cm"] + z_len * strength * S["erect_length_sd_cm"])
    circ_cm = girth_scale * (S["erect_circumference_cm"] + z_circ * strength * S["erect_circumference_sd_cm"])
    base_length_cm = S["mesh_length_fraction"] * S["reference_height_m"] * 100.0
    base_circ_cm = 2.0 * math.pi * _catmull(PHALLUS["profile_mm"], S["circumference_measured_at_t"]) / 10.0
    MALE_TRANSITION["erect_length_scale"] = length_cm / base_length_cm
    MALE_TRANSITION["erect_girth_scale"] = circ_cm / base_circ_cm
    pct = lambda z: 100.0 * 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))
    flaccid_circ = MALE_TRANSITION["shaft_girth"] * circ_cm
    flaccid_length = length_cm * (MALE_TRANSITION["glans_start"] * MALE_TRANSITION["shaft_compress"] + (1.0 - MALE_TRANSITION["glans_start"]) * MALE_TRANSITION["glans_length_scale"])
    print(f"Penis size (absolute adult measurements; body height {body_height:.3f} m affects placement only): erect {length_cm:.2f} cm / {circ_cm:.2f} cm circumference; flaccid approx. {flaccid_length:.2f} cm / {flaccid_circ:.2f} cm circumference "
          f"(mesh multipliers: length x{MALE_TRANSITION['erect_length_scale']:.3f}, "
          f"girth x{MALE_TRANSITION['erect_girth_scale']:.3f})")
    if seed is not None and strength > 0.0:
        print(f"  seed {seed!r}: length {z_len:+.2f} SD (~{pct(z_len):.0f}th percentile), "
              f"girth {z_circ:+.2f} SD (~{pct(z_circ):.0f}th percentile), strength {strength:g}")
    return {"length_cm": length_cm, "circumference_cm": circ_cm,
            "flaccid_length_cm": flaccid_length, "flaccid_circumference_cm": flaccid_circ,
            "z_length": z_len, "z_girth": z_circ}


# ---------------------------------------------------------------------------
# Skin texture / colour continuity.
#
# The anatomy meshes are built from raw vertices and have no UVs. After joining they would all sample
# one texel of the skin texture (UV 0,0), which reads as flat, mismatched colour. Each anatomy vertex
# therefore borrows the UV of the nearest point on the body, restricted to the UV island the pelvis front
# belongs to, so one continuous patch of the real skin texture is used and nothing smears across seams.
# ---------------------------------------------------------------------------
def ensure_skin_colour_layer(skin):
    """The joined mesh needs one consistent 'Color' layer (POINT / FLOAT_COLOR). Body vertices are white."""
    import numpy as np
    mesh = skin.data
    attr = mesh.color_attributes.get("Color")
    nv = len(mesh.vertices)
    if attr is not None and attr.domain == "POINT" and attr.data_type == "FLOAT_COLOR":
        return
    if attr is None:
        vertex_colour = np.ones((nv, 4), dtype=np.float32)
    else:
        raw = np.empty(len(attr.data) * 4, dtype=np.float32)
        attr.data.foreach_get("color", raw)
        raw = raw.reshape(-1, 4)
        if attr.domain == "CORNER":
            loop_v = np.empty(len(mesh.loops), dtype=np.int32)
            mesh.loops.foreach_get("vertex_index", loop_v)
            sums = np.zeros((nv, 4), dtype=np.float64)
            np.add.at(sums, loop_v, raw)
            vertex_colour = (sums / np.maximum(np.bincount(loop_v, minlength=nv), 1)[:, None]).astype(np.float32)
        else:
            vertex_colour = raw
        mesh.color_attributes.remove(attr)
    new = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    new.data.foreach_set("color", vertex_colour.reshape(-1))
    mesh.update()


def _uv_island_ids(loop_vertex, loop_edge, loop_start, uv, eps=1e-5):
    """Island id per polygon: faces are in one island when the UVs match on both ends of their shared edge."""
    import numpy as np
    n_loops, n_poly = len(loop_vertex), len(loop_start)
    loop_total = np.diff(np.append(loop_start, n_loops))
    poly_of_loop = np.repeat(np.arange(n_poly), loop_total)
    nxt = np.arange(n_loops) + 1
    nxt[loop_start + loop_total - 1] = loop_start
    order = np.argsort(loop_edge, kind="stable")
    sorted_edge = loop_edge[order]
    cut = np.flatnonzero(np.diff(sorted_edge)) + 1
    first = np.concatenate(([0], cut))
    last = np.concatenate((cut, [len(sorted_edge)]))
    pairs = np.flatnonzero(last - first == 2)                      # interior (manifold) edges only
    la, lb = order[first[pairs]], order[first[pairs] + 1]
    opposed = loop_vertex[la] == loop_vertex[nxt[lb]]              # normal winding: neighbours traverse the edge in opposite directions
    b_at_a0 = np.where(opposed[:, None], uv[nxt[lb]], uv[lb])
    b_at_a1 = np.where(opposed[:, None], uv[lb], uv[nxt[lb]])
    same = (np.abs(uv[la] - b_at_a0).max(1) <= eps) & (np.abs(uv[nxt[la]] - b_at_a1).max(1) <= eps)
    parent = list(range(n_poly))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b in zip(poly_of_loop[la[same]].tolist(), poly_of_loop[lb[same]].tolist()):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    return np.array([find(i) for i in range(n_poly)], dtype=np.int64)


def _barycentric_batch(a, b, c, p):
    """Barycentric weights (n,3) of points p (n,3) on triangles a,b,c (n,3 each); clamped to the triangle."""
    import numpy as np
    v0, v1, v2 = b - a, c - a, p - a
    d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
    d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
    den = d00 * d11 - d01 * d01
    den = np.where(np.abs(den) < 1e-20, 1e-20, den)
    v = (d11 * d20 - d01 * d21) / den
    w = (d00 * d21 - d01 * d20) / den
    weights = np.clip(np.stack([1.0 - v - w, v, w], axis=1), 0.0, None)
    return weights / np.maximum(weights.sum(1, keepdims=True), 1e-12)


def transfer_skin_uvs(skin, anatomy, anchor_world):
    """Give every vertex of `anatomy` the UVs of the nearest point on the skin's anchor UV island."""
    import numpy as np
    smesh, amesh = skin.data, anatomy.data
    if not smesh.uv_layers:
        print("WARNING: skin mesh has no UV map; anatomy keeps default UVs")
        return 0
    n_l, n_p = len(smesh.loops), len(smesh.polygons)

    def world_positions(obj, mesh):
        co = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
        mesh.vertices.foreach_get("co", co)
        m = np.array([list(row) for row in obj.matrix_world], dtype=np.float64)
        return co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]

    def uv_array(layer):
        arr = np.empty(n_l * 2, dtype=np.float32)
        layer.data.foreach_get("uv", arr)
        return arr.reshape(-1, 2).astype(np.float64)

    skin_world = world_positions(skin, smesh)
    loop_v = np.empty(n_l, dtype=np.int32); smesh.loops.foreach_get("vertex_index", loop_v)
    loop_e = np.empty(n_l, dtype=np.int32); smesh.loops.foreach_get("edge_index", loop_e)
    loop_start = np.empty(n_p, dtype=np.int32); smesh.polygons.foreach_get("loop_start", loop_start)
    layers = list(smesh.uv_layers)
    active = smesh.uv_layers.active or layers[0]
    smesh.calc_loop_triangles()
    n_t = len(smesh.loop_triangles)
    tri_v = np.empty(n_t * 3, dtype=np.int32); smesh.loop_triangles.foreach_get("vertices", tri_v); tri_v = tri_v.reshape(-1, 3)
    tri_l = np.empty(n_t * 3, dtype=np.int32); smesh.loop_triangles.foreach_get("loops", tri_l); tri_l = tri_l.reshape(-1, 3)
    tri_p = np.empty(n_t, dtype=np.int32); smesh.loop_triangles.foreach_get("polygon_index", tri_p)

    island_of_poly = _uv_island_ids(loop_v, loop_e, loop_start, uv_array(active))
    verts = [Vector(p) for p in skin_world.tolist()]
    everything = BVHTree.FromPolygons(verts, tri_v.tolist(), all_triangles=True)
    _loc, _nrm, anchor_tri, _dist = everything.find_nearest(Vector(anchor_world))
    if anchor_tri is None:
        print("WARNING: could not find skin near the anatomy anchor; anatomy keeps default UVs")
        return 0
    island = island_of_poly[tri_p[anchor_tri]]
    chosen = np.flatnonzero(island_of_poly[tri_p] == island)
    tree = BVHTree.FromPolygons(verts, tri_v[chosen].tolist(), all_triangles=True)

    points = world_positions(anatomy, amesh)
    hit_tri = np.empty(len(points), dtype=np.int64)
    hit_loc = np.empty((len(points), 3), dtype=np.float64)
    hit_dist = np.empty(len(points), dtype=np.float64)
    for i, point in enumerate(points.tolist()):
        loc, _n, idx, dist = tree.find_nearest(Vector(point))
        hit_tri[i], hit_loc[i], hit_dist[i] = chosen[idx], (loc[0], loc[1], loc[2]), dist
    weights = _barycentric_batch(skin_world[tri_v[hit_tri, 0]], skin_world[tri_v[hit_tri, 1]],
                                 skin_world[tri_v[hit_tri, 2]], hit_loc)

    a_loop_v = np.empty(len(amesh.loops), dtype=np.int32)
    amesh.loops.foreach_get("vertex_index", a_loop_v)
    for layer in layers:                                   # same names / order as the skin so the join lines up
        src = uv_array(layer)
        per_vertex = sum(weights[:, j, None] * src[tri_l[hit_tri, j]] for j in range(3))
        target = amesh.uv_layers.get(layer.name) or amesh.uv_layers.new(name=layer.name)
        target.data.foreach_set("uv", per_vertex[a_loop_v].astype(np.float32).reshape(-1))
        if layer.name == active.name:
            amesh.uv_layers.active = target
    amesh.update()
    print(f"Anatomy UVs: {len(points)} vertices sampled from UV island of {len(chosen)} skin triangles "
          f"(mean distance {hit_dist.mean() * 1000:.1f} mm, max {hit_dist.max() * 1000:.1f} mm)")
    return len(points)


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
    # The accepted erect surface is the master mesh. The flaccid pose is derived from
    # it (same topology), and the two are linked by one morph target.
    size = resolve_penis_size(args.length_scale, args.girth_scale, args.variation_seed,
                              args.variation_strength, height)
    PHALLUS["style"] = args.penis_style
    phallus = create_symmetric_phallus(
        skin, skin_material, armature, pelvis_bone, height, anatomy_z,
        pelvic_surface_y, "erect", centre_x, tree=surface_tree
    )
    scrotum = create_scrotum(
        surface_tree, skin_material, armature, pelvis_bone, width, height, anatomy_z,
        pelvic_surface_y, "erect", centre_x
    )
    anal_detail = create_anal_detail(surface_tree, skin_material, armature, pelvis_bone, height, hipline_z, centre_x)
    # Colour is painted by vertex membership, so it follows the vertices through the morph.
    paint_male_anatomy_detail(phallus, centre_x, anatomy_z, height, pelvic_surface_y, "erect", "phallus",
                              MALE_TRANSITION["erect_length_scale"], MALE_TRANSITION["erect_girth_scale"])
    paint_male_anatomy_detail(scrotum, centre_x, anatomy_z, height, pelvic_surface_y, "erect", "scrotum")

    ph_erect = [phallus.matrix_world @ v.co for v in phallus.data.vertices]
    sc_relaxed = [scrotum.matrix_world @ v.co for v in scrotum.data.vertices]
    flat_ph = list(phallus["flaccid_positions"])
    ph_flaccid = [Vector((flat_ph[i], flat_ph[i + 1], flat_ph[i + 2])) for i in range(0, len(flat_ph), 3)]
    del phallus["flaccid_positions"]
    flat = list(scrotum["erect_positions"])
    sc_erect = [Vector((flat[i], flat[i + 1], flat[i + 2])) for i in range(0, len(flat), 3)]
    del scrotum["erect_positions"]
    inverse = phallus.matrix_world.inverted()
    for vertex, point in zip(phallus.data.vertices, ph_flaccid):
        vertex.co = inverse @ point            # base mesh = flaccid
    phallus.data.update()
    erect_world = ph_erect + sc_erect          # morph target = erect (scrotum: tightened)

    anatomy = join_male_anatomy_parts(
        [phallus, scrotum, anal_detail], armature, pelvis_bone
    )
    anatomy["profile_name"] = args.profile_name
    anatomy["anatomy_state"] = args.anatomy_state
    # Join into the original Ara body mesh so the exported GLB retains one
    # full-rig skin rather than a separate pelvis-only skeleton palette.
    ensure_skin_colour_layer(skin)
    transfer_skin_uvs(skin, anatomy, Vector((centre_x, pelvic_surface_y, anatomy_z)))
    first_anatomy_vertex = len(skin.data.vertices)
    skin = merge_anatomy_into_skin(skin, anatomy, armature, pelvis_bone)
    skin["penis_erect_length_cm"] = size["length_cm"]
    skin["penis_erect_circumference_cm"] = size["circumference_cm"]
    skin["penis_flaccid_length_cm"] = size["flaccid_length_cm"]
    skin["penis_flaccid_circumference_cm"] = size["flaccid_circumference_cm"]
    skin["penis_size_seed"] = "" if args.variation_seed is None else str(args.variation_seed)
    if len(skin.data.vertices) - first_anatomy_vertex != len(erect_world):
        raise RuntimeError("Anatomy vertex count changed while joining; the erect morph target would be misaligned")
    add_erect_morph(skin, first_anatomy_vertex, erect_world, args.anatomy_state, args.author_transition_clip)
    if skin.data.color_attributes.get("Color") is None:
        raise RuntimeError("Male anatomy vertex colours were lost while joining anatomy into the Ara skin")
    skin.data.color_attributes.active_color = skin.data.color_attributes.get("Color")
    # After joining, Blender leaves the default (render) colour index unset (-1), and the glTF
    # exporter then silently drops COLOR_0. Make the anatomy colour the default colour attribute.
    skin.data.color_attributes.render_color_index = skin.data.color_attributes.active_color_index
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
        f"Exported Ara-derived adult male anatomy (default {args.anatomy_state}; Anatomy_Erect morph 0=flaccid..1=erect) "
        "with paired scrotal contours, integrated into the original full-rig skin mesh."
    )


if __name__ == "__main__":
    main()