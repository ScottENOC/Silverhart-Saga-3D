# Run with Blender 5.2 LTS (also supports Blender 4.x):
# blender --background --python tools/blender/build_wren_blockout.py
#
# Generates an intentionally simple, rigged Wren blockout and GLB export.
# This is a scale / rig / equipment-layering prototype, not final character art.

import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "characters" / "wren"
OUT.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Scene and materials
# ---------------------------------------------------------------------------

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.armatures):
    for datablock in list(datablocks):
        if datablock.users == 0:
            datablocks.remove(datablock)

def material(name, colour, roughness=0.82, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*colour, 1.0)
    if mat.node_tree is None:
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat

SKIN = material("Wren | skin", (0.58, 0.39, 0.28))
HAIR = material("Wren | shock cobalt blue hair", (0.018, 0.105, 0.72))
HAIR_FLOW = material("Wren | hair flow highlights", (0.035, 0.16, 0.82))
SHIRT = material("Wren | dark green shirt", (0.13, 0.24, 0.15))
TRIM = material("Wren | rose red trim", (0.55, 0.12, 0.20))
TROUSERS = material("Wren | charcoal trousers", (0.075, 0.072, 0.08))
UNDER = material("Wren | underlayer", (0.25, 0.19, 0.10))
SWORD_METAL = material("Wren | sword steel", (0.48, 0.54, 0.59), 0.32, 0.65)
LEATHER = material("Wren | sword grip", (0.18, 0.095, 0.045))
TATTOO = material("Wren | dark blue-black tattoo ink", (0.025, 0.035, 0.075))
PIERCING_METAL = material("Wren | silver piercings", (0.62, 0.68, 0.72), 0.24, 0.82)
PUBIC_HAIR = material("Wren | dark brown body hair", (0.055, 0.028, 0.018))

# ---------------------------------------------------------------------------
# Shared human skeleton.
# ---------------------------------------------------------------------------

arm_data = bpy.data.armatures.new("Human_Skeleton")
arm = bpy.data.objects.new("Wren_Rig", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")

bone_defs = {
    "Root": ((0, 0, 0.05), (0, 0, 0.88), None),
    "Spine": ((0, 0, 0.88), (0, 0, 1.48), "Root"),
    "Neck": ((0, 0, 1.48), (0, 0, 1.60), "Spine"),
    "Head": ((0, 0, 1.60), (0, 0, 1.82), "Neck"),
    "UpperArm.L": ((0.18, 0, 1.39), (0.38, 0, 1.25), "Spine"),
    "Forearm.L": ((0.38, 0, 1.25), (0.52, 0, 1.10), "UpperArm.L"),
    "Wrist.L": ((0.50, -0.01, 1.095), (0.535, -0.02, 1.065), "Forearm.L"),
    "Hand.L": ((0.535, -0.02, 1.065), (0.59, -0.025, 1.02), "Wrist.L"),
    "UpperArm.R": ((-0.18, 0, 1.39), (-0.38, 0, 1.25), "Spine"),
    "Forearm.R": ((-0.38, 0, 1.25), (-0.52, 0, 1.10), "UpperArm.R"),
    "Wrist.R": ((-0.50, -0.01, 1.095), (-0.535, -0.02, 1.065), "Forearm.R"),
    "Hand.R": ((-0.535, -0.02, 1.065), (-0.59, -0.025, 1.02), "Wrist.R"),
    "Thigh.L": ((0.12, 0, 0.88), (0.13, 0, 0.49), "Root"),
    "Shin.L": ((0.13, 0, 0.49), (0.13, 0, 0.15), "Thigh.L"),
    "Ankle.L": ((0.13, 0, 0.19), (0.13, -0.005, 0.105), "Shin.L"),
    "Foot.L": ((0.13, -0.005, 0.105), (0.13, -0.18, 0.065), "Ankle.L"),
    "Thigh.R": ((-0.12, 0, 0.88), (-0.13, 0, 0.49), "Root"),
    "Shin.R": ((-0.13, 0, 0.49), (-0.13, 0, 0.15), "Thigh.R"),
    "Ankle.R": ((-0.13, 0, 0.19), (-0.13, -0.005, 0.105), "Shin.R"),
    "Foot.R": ((-0.13, -0.005, 0.105), (-0.13, -0.18, 0.065), "Ankle.R"),
}
# Three articulated phalanges per finger and thumb, parented to the hand.
for side, sign in (("L", 1), ("R", -1)):
    for digit_index, digit in enumerate(("Index", "Middle", "Ring", "Pinky")):
        finger_lengths = {"Index": 0.072, "Middle": 0.086, "Ring": 0.080, "Pinky": 0.064}
        length = finger_lengths[digit]
        spread_z = (digit_index - 1.5) * 0.015
        p0 = (sign * 0.614, -0.039, 1.025 + spread_z)
        p1 = (sign * (0.614 + length * 0.40), -0.041, 1.024 + spread_z * 0.94)
        p2 = (sign * (0.614 + length * 0.76), -0.027, 1.018 + spread_z * 0.86)
        p3 = (sign * (0.614 + length), -0.015, 1.010 + spread_z * 0.78)
        chain = [(p0, p1, f"Hand.{side}"), (p1, p2, f"{digit}1.{side}"), (p2, p3, f"{digit}2.{side}")]
        for segment_index, (head, tail, parent) in enumerate(chain, 1):
            bone_defs[f"{digit}{segment_index}.{side}"] = (head, tail, parent)
    thumb_chain = [
        ((sign*0.555,-0.039,1.052),(sign*0.555,-0.043,1.080),f"Hand.{side}"),
        ((sign*0.555,-0.043,1.080),(sign*0.535,-0.038,1.094),f"Thumb1.{side}"),
    ]
    for segment_index, (head, tail, parent) in enumerate(thumb_chain, 1):
        bone_defs[f"Thumb{segment_index}.{side}"] = (head, tail, parent)

bones = {}
for name, (head, tail, parent_name) in bone_defs.items():
    bone = arm_data.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bones[name] = bone
for name, (_, _, parent_name) in bone_defs.items():
    if parent_name:
        bones[name].parent = bones[parent_name]
bpy.ops.object.mode_set(mode="OBJECT")
arm.show_in_front = True
arm.display_type = "WIRE"

# ---------------------------------------------------------------------------
# Mesh helpers.
# ---------------------------------------------------------------------------

def finish_skinned_mesh(name, verts, faces, mat, weights_by_group):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for group_name, weights in weights_by_group.items():
        group = obj.vertex_groups.new(name=group_name)
        for vertex_index, weight in enumerate(weights):
            if weight > 0.0001:
                group.add([vertex_index], weight, "REPLACE")
    mod = obj.modifiers.new("Human skeleton", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj

def sphere_piece(name, location, scale, mat, bone_name, segments=32, rings=24, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(mat)
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("Human skeleton", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj

def tube_mesh(name, points, radii, mat, bone_a, bone_b=None, sides=20, depth_ratio=0.88, blend_start=0.46, blend_end=0.62):
    """One continuous tapered limb/sleeve, with rings along its length.

    Each ring is perpendicular to the limb centreline. The elbow is an interior
    cross-section, not the meeting point of two exposed cylinders.
    """
    # Interpolate the sparse anatomical guide points into a smooth centreline.
    # The old version created a visible ring at every guide point; voxel remesh
    # could not fully erase those radius/curvature changes, especially on arms.
    guide = [Vector(p) for p in points]
    guide_radii = list(radii)
    if len(guide) >= 3:
        centres, smooth_radii = [], []
        steps_per_span = 6
        for span in range(len(guide) - 1):
            p0 = guide[max(0, span - 1)]
            p1 = guide[span]
            p2 = guide[span + 1]
            p3 = guide[min(len(guide) - 1, span + 2)]
            r0 = guide_radii[max(0, span - 1)]
            r1 = guide_radii[span]
            r2 = guide_radii[span + 1]
            r3 = guide_radii[min(len(guide_radii) - 1, span + 2)]
            for step in range(steps_per_span):
                t = step / float(steps_per_span)
                t2, t3 = t*t, t*t*t
                def catmull(a, b, c, d):
                    return 0.5 * ((2*b) + (-a+c)*t + (2*a-5*b+4*c-d)*t2 + (-a+3*b-3*c+d)*t3)
                centres.append(Vector(tuple(catmull(p0[i], p1[i], p2[i], p3[i]) for i in range(3))))
                smooth_radii.append(max(0.001, catmull(r0, r1, r2, r3)))
        centres.append(guide[-1])
        smooth_radii.append(guide_radii[-1])
    else:
        centres, smooth_radii = guide, guide_radii
    verts, faces = [], []
    weights_a, weights_b = [], []
    reference = Vector((0, 1, 0))
    for ring_index, centre in enumerate(centres):
        if ring_index == 0:
            tangent = (centres[1] - centres[0]).normalized()
        elif ring_index == len(centres) - 1:
            tangent = (centres[-1] - centres[-2]).normalized()
        else:
            tangent = (centres[ring_index + 1] - centres[ring_index - 1]).normalized()
        axis_u = tangent.cross(reference).normalized()
        axis_v = tangent.cross(axis_u).normalized()
        radius = smooth_radii[ring_index]
        for side_index in range(sides):
            angle = 2.0 * math.pi * side_index / sides
            offset = axis_u * (math.cos(angle) * radius) + axis_v * (math.sin(angle) * radius * depth_ratio)
            verts.append(tuple(centre + offset))
            t = ring_index / (len(centres) - 1)
            if bone_b is None:
                wa, wb = 1.0, 0.0
            else:
                blend = max(0.0, min(1.0, (t - blend_start) / (blend_end - blend_start)))
                # Smoothstep avoids an abrupt weight boundary around the elbow.
                blend = blend * blend * (3.0 - 2.0 * blend)
                wa, wb = 1.0 - blend, blend
            weights_a.append(wa)
            weights_b.append(wb)
    for ring in range(len(centres) - 1):
        for side in range(sides):
            a = ring * sides + side
            b = ring * sides + (side + 1) % sides
            c = (ring + 1) * sides + (side + 1) % sides
            d = (ring + 1) * sides + side
            faces.append((a, b, c, d))
    faces.append(tuple(range(sides - 1, -1, -1)))
    last = (len(centres) - 1) * sides
    faces.append(tuple(last + i for i in range(sides)))
    groups = {bone_a: weights_a}
    if bone_b:
        groups[bone_b] = weights_b
    return finish_skinned_mesh(name, verts, faces, mat, groups)

def digit_mesh(name, points, radii, bone_names, mat):
    """One continuous finger surface with smoothly blended phalange weights."""
    centres = [Vector(p) for p in points]
    sides = 12
    verts, faces = [], []
    weights = {bone_name: [] for bone_name in bone_names}
    reference = Vector((0, 1, 0))
    for ring_index, centre in enumerate(centres):
        if ring_index == 0:
            tangent = (centres[1] - centres[0]).normalized()
        elif ring_index == len(centres) - 1:
            tangent = (centres[-1] - centres[-2]).normalized()
        else:
            tangent = (centres[ring_index + 1] - centres[ring_index - 1]).normalized()
        axis_u = tangent.cross(reference).normalized()
        axis_v = tangent.cross(axis_u).normalized()
        for side_index in range(sides):
            angle = 2.0 * math.pi * side_index / sides
            offset = axis_u * (math.cos(angle) * radii[ring_index]) + axis_v * (math.sin(angle) * radii[ring_index] * 0.82)
            verts.append(tuple(centre + offset))
            segment = min(len(bone_names) - 1, ring_index)
            if segment == len(bone_names) - 1:
                ring_weights = {bone_names[segment]: 1.0}
            else:
                blend = 0.18 if ring_index in (1, 2) else 0.0
                ring_weights = {bone_names[segment]: 1.0 - blend}
                if blend:
                    ring_weights[bone_names[segment + 1]] = blend
            for bone_name in bone_names:
                weights[bone_name].append(ring_weights.get(bone_name, 0.0))
    for ring in range(len(centres) - 1):
        for side in range(sides):
            a = ring * sides + side
            b = ring * sides + (side + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.extend([tuple(range(sides - 1, -1, -1)),
        tuple((len(centres) - 1) * sides + i for i in range(sides))])
    return finish_skinned_mesh(name, verts, faces, mat, weights)

def torus_piece(name, location, major_radius, minor_radius, mat, bone_name, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=6,
        location=location, major_radius=major_radius, minor_radius=minor_radius,
        rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("Human skeleton", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    return obj

# ---------------------------------------------------------------------------
# Body: average-build human woman, approximately 1.7 m tall.
# ---------------------------------------------------------------------------

# Continuous torso/pelvis loft: broad pelvis and shoulders, defined waist,
# ribcage and chest. Each ring is a cross-section of one surface.
torso_rings = [
    (0.610, 0.075, 0.060, 0.000),
    (0.625, 0.090, 0.072, 0.000),
    (0.645, 0.112, 0.082, 0.000),
    (0.670, 0.135, 0.092, 0.000),
    (0.680, 0.145, 0.098, 0.000),
    (0.690, 0.165, 0.105, 0.000),
    (0.710, 0.180, 0.115, 0.000),
    (0.735, 0.198, 0.128, 0.000),
    (0.755, 0.208, 0.132, 0.000),
    (0.770, 0.214, 0.135, 0.000),
    (0.785, 0.219, 0.137, 0.000),
    (0.795, 0.222, 0.138, 0.000),
    (0.805, 0.225, 0.140, 0.000),
    (0.815, 0.224, 0.141, 0.000),
    (0.825, 0.222, 0.141, 0.000),
    (0.835, 0.223, 0.142, 0.000),
    (0.850, 0.225, 0.142, 0.000),
    (0.855, 0.228, 0.142, 0.000),
    (0.905, 0.218, 0.136, 0.000),
    (0.955, 0.202, 0.128, 0.000),
    (1.005, 0.190, 0.122, 0.000),
    (1.055, 0.190, 0.125, 0.000),
    (1.105, 0.198, 0.132, 0.000),
    (1.155, 0.211, 0.140, 0.000),
    (1.205, 0.225, 0.145, 0.000),
    (1.255, 0.232, 0.145, 0.000),
    (1.305, 0.242, 0.137, 0.000),
    (1.355, 0.252, 0.128, 0.000),
    (1.405, 0.225, 0.118, 0.000),
    (1.450, 0.145, 0.095, 0.000),
    (1.495, 0.078, 0.070, 0.000),
]
torso_verts, torso_faces, root_weights, spine_weights = [], [], [], []
torso_sides = 96
for ring_index, (z, width, depth, y_center) in enumerate(torso_rings):
    for side_index in range(torso_sides):
        angle = 2.0 * math.pi * side_index / torso_sides
        # The lowest torso boundary is a saddle-shaped crotch, not a
        # horizontal cut. It dips between the thighs and rises into each
        # inner hip so the lower torso blends around the leg roots.
        ring_z = z
        if ring_index == 0:
            ring_z += 0.070 * (abs(math.cos(angle)) ** 1.5)
        x = math.cos(angle) * width
        y = y_center + math.sin(angle) * depth
        # Very shallow clavicular plane changes in the front of the upper chest.
        # They are part of this continuous torso surface, not added tubes.
        front = max(0.0, -math.sin(angle)) ** 8
        if 1.30 <= z <= 1.42:
            line_x = 0.035 + max(0.0, min(1.0, (z - 1.30) / 0.12)) * 0.155
            ridge = math.exp(-((abs(x) - line_x) / 0.035) ** 2)
            y -= front * ridge * 0.0035
        # A narrow, vertically oriented pubic mound is a shallow deformation
        # of the torso loft itself, never a flat patch pasted onto the surface.
        if 0.950 <= z <= 0.985:
            vertical = math.exp(-((z - 0.968) / 0.010) ** 2)
            centre = math.exp(-(x / 0.014) ** 2)
            y += front * vertical * centre * 0.008
        if 0.625 <= z <= 0.710:
            vertical = math.sin(math.pi * (z - 0.625) / 0.085)
            centre = math.exp(-(x / 0.060) ** 2)
            y -= front * max(0.0, vertical) * centre * 0.006
        if 0.625 <= z <= 0.700:
            profile = math.exp(-((z - 0.663) / 0.026) ** 2)
            paired = (math.exp(-((x - 0.020) / 0.013) ** 2)
                + math.exp(-((x + 0.020) / 0.013) ** 2))
            centre = math.exp(-(x / 0.0065) ** 2)
            y -= front * profile * paired * 0.012
            y += front * profile * centre * 0.009
        if 0.690 <= z <= 0.715:
            hood = math.exp(-((z - 0.700) / 0.009) ** 2) * math.exp(-(x / 0.012) ** 2)
            y -= front * hood * 0.006
        back = max(0.0, math.sin(angle)) ** 8
        if 0.770 <= z <= 0.805:
            rear_dimple = math.exp(-((z - 0.788) / 0.012) ** 2) * math.exp(-(x / 0.014) ** 2)
            y -= back * rear_dimple * 0.012
        # Gluteal volume is sculpted directly into this continuous pelvis
        # surface. The two broad lobes sit closer to the midline and slightly
        # lower than the old detached forms; their upper edge fades into the
        # sacrum and their lower edge tightens into the upper thighs.
        if back > 0.0:
            lobe_left = math.exp(-((x - 0.076) / 0.096) ** 2)
            lobe_right = math.exp(-((x + 0.076) / 0.096) ** 2)
            vertical = math.exp(-((z - 0.805) / 0.075) ** 2)
            lower_taper = max(0.0, min(1.0, (z - 0.775) / 0.045))
            lower_taper = lower_taper * lower_taper * (3.0 - 2.0 * lower_taper)
            y += back * (lobe_left + lobe_right) * vertical * (0.058 * lower_taper)
            central_cleft = math.exp(-(x / 0.014) ** 2) * math.exp(-((z - 0.795) / 0.032) ** 2)
            y -= back * central_cleft * 0.009
        torso_verts.append((x, y, ring_z))
        blend = max(0.0, min(1.0, (z - 0.82) / 0.20))
        blend = blend * blend * (3.0 - 2.0 * blend)
        root_weights.append(1.0 - blend)
        spine_weights.append(blend)
for ring in range(len(torso_rings) - 1):
    for side_index in range(torso_sides):
        a = ring * torso_sides + side_index
        b = ring * torso_sides + (side_index + 1) % torso_sides
        c = (ring + 1) * torso_sides + (side_index + 1) % torso_sides
        d = (ring + 1) * torso_sides + side_index
        torso_faces.append((a, b, c, d))
# Close the underside with concentric curved rings rather than a single fan.
# The centre is lower, while the front/back and inner-hip edges rise gradually.
outer = [Vector(torso_verts[i]) for i in range(torso_sides)]
previous_ring = list(range(torso_sides))
for factor in (0.78, 0.54, 0.30, 0.12):
    ring_indices = []
    for boundary in outer:
        point = boundary.lerp(Vector((0.0, 0.0, 0.640)), 1.0-factor)
        point.z -= 0.006 * math.sin(math.pi * (1.0-factor))
        ring_indices.append(len(torso_verts))
        torso_verts.append(tuple(point))
        root_weights.append(1.0)
        spine_weights.append(0.0)
    for side_index in range(torso_sides):
        nxt = (side_index + 1) % torso_sides
        torso_faces.append((previous_ring[side_index], previous_ring[nxt],
            ring_indices[nxt], ring_indices[side_index]))
    previous_ring = ring_indices
bottom_centre = len(torso_verts)
torso_verts.append((0.0, 0.0, 0.640))
root_weights.append(1.0)
spine_weights.append(0.0)
for side_index in range(torso_sides):
    nxt = (side_index + 1) % torso_sides
    torso_faces.append((previous_ring[side_index], previous_ring[nxt], bottom_centre))
last_ring = (len(torso_rings) - 1) * torso_sides
torso_faces.append(tuple(last_ring + i for i in range(torso_sides)))
finish_skinned_mesh("Body_Torso_Pelvis", torso_verts, torso_faces, SKIN,
    {"Root": root_weights, "Spine": spine_weights})

# Natural, restrained adult feminine body shape. These forms are integrated
# visually into the torso silhouette; they are body geometry, not garments.
def shaped_breast(name, centre_x):
    # Anatomical teardrop profile: narrower upper pole, fuller lower pole,
    # gently flattened chest wall and a forward-facing projection.
    rings = [
        (1.335, 0.007, 0.006, -0.090),
        (1.320, 0.020, 0.016, -0.104),
        (1.295, 0.043, 0.030, -0.120),
        (1.265, 0.065, 0.048, -0.134),
        (1.235, 0.082, 0.061, -0.146),
        (1.205, 0.088, 0.068, -0.151),
        (1.175, 0.080, 0.064, -0.146),
        (1.150, 0.058, 0.048, -0.131),
        (1.132, 0.027, 0.024, -0.111),
        (1.125, 0.007, 0.006, -0.098),
    ]
    sides = 32
    verts, faces = [], []
    for z, width, depth, y_centre in rings:
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            verts.append((centre_x + math.cos(angle) * width,
                y_centre + math.sin(angle) * depth, z))
    for ring in range(len(rings) - 1):
        for i in range(sides):
            a = ring * sides + i
            b = ring * sides + (i + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.extend([tuple(range(sides - 1, -1, -1)),
        tuple((len(rings) - 1) * sides + i for i in range(sides))])
    weights = [1.0] * len(verts)
    obj = finish_skinned_mesh(name, verts, faces, SKIN, {"Spine": weights})
    smooth = obj.modifiers.new("Soft anatomical surface", "SUBSURF")
    smooth.levels = 2
    smooth.render_levels = 2
    return obj

for side, sign in (("L", 1), ("R", -1)):
    shaped_breast(f"Body_Breast_{side}", sign * 0.108)
    # Gluteal anatomy is part of Body_Torso_Pelvis above, not separate meshes.
    # Deltoid volume blends the upper arm into the torso.
    sphere_piece(f"Body_Shoulder_{side}", (sign * 0.205, 0.0, 1.385),
        (0.105, 0.105, 0.105), SKIN, f"UpperArm.{side}", 24, 16)
# Subtle, non-detailed external pelvic anatomy; no explicit genital detailing.

tube_mesh("Body_Neck", [(0, 0, 1.455), (0, 0, 1.505), (0, 0, 1.555), (0, 0, 1.625)],
    [0.066, 0.067, 0.069, 0.075], SKIN, "Neck", sides=48, depth_ratio=0.95)
sphere_piece("Body_Head", (0, -0.005, 1.70), (0.125, 0.12, 0.16), SKIN, "Head", 24, 16)
# Nose bridge, tip and subtle alae are separate sculptural forms.
sphere_piece("Face_Nose_Bridge", (0, -0.112, 1.685), (0.020, 0.035, 0.060), SKIN, "Head", 12, 10)
sphere_piece("Face_Nose_Tip", (0, -0.145, 1.652), (0.027, 0.030, 0.023), SKIN, "Head", 12, 8)
for side, sign in (("L", 1), ("R", -1)):
    sphere_piece(f"Face_Nostril_Ala_{side}", (sign * 0.019, -0.132, 1.650),
        (0.014, 0.018, 0.014), SKIN, "Head", 10, 8)
for side, sign in (("L", 1), ("R", -1)):
    x = sign * 0.18
    sphere_piece(f"Body_Ear_{side}", (x * 0.68, 0, 1.70), (0.035, 0.035, 0.055), SKIN, "Head", 10, 8)
    # Shoulder, upper arm, elbow and forearm are a single continuous surface.
    # The elbow is deliberately buried in the tube instead of being a side-on join.
    shoulder = (sign * 0.17, 0.0, 1.395)
    upper_mid = (sign * 0.265, -0.002, 1.345)
    upper_low = (sign * 0.335, -0.006, 1.285)
    elbow = (sign * 0.385, -0.006, 1.235)
    fore_mid = (sign * 0.455, -0.012, 1.155)
    wrist = (sign * 0.525, -0.018, 1.075)
    # The arm is still a lofted anatomical guide, but use a much denser
    # circumference so its silhouette and normals do not resolve into long
    # polygonal bands. The elbow itself will receive a dedicated sculpt pass;
    # do not fake it with a detached sphere.
    tube_mesh(f"Body_Arm_{side}", [shoulder, upper_mid, upper_low, elbow, fore_mid, wrist],
        [0.095, 0.096, 0.082, 0.068, 0.071, 0.043], SKIN,
        f"UpperArm.{side}", f"Forearm.{side}", sides=48, blend_start=0.52, blend_end=0.76)
    # No separate elbow sphere: it created the conspicuous round lump visible
    # in the sculpt preview. The elbow contour is shaped by the continuous arm.
    # Separate wrist and palm; each finger has three independently weighted
    # phalanges so later hand animation can bend them at real joints.
    # A short, tapered wrist bridges the forearm into the palm instead of
    # leaving a round ball between two aligned blocks.
    tube_mesh(f"Hand_Wrist_{side}",
        [(sign*0.505, -0.018, 1.105), (sign*0.535, -0.027, 1.065),
         (sign*0.570, -0.034, 1.035)],
        [0.030, 0.025, 0.023], SKIN, f"Forearm.{side}", f"Wrist.{side}",
        sides=16, depth_ratio=0.78, blend_start=0.25, blend_end=0.78)
    # Palm's short ends meet wrist and fingers. Its broad faces are X/Z;
    # fingers extend along X, while the thumb branches across Z.
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sign * 0.558, -0.034, 1.025))
    palm = bpy.context.object
    palm.name = f"Hand_Palm_{side}"
    palm.dimensions = (0.112, 0.030, 0.066)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = palm.modifiers.new("Soft palm edges", "BEVEL")
    bevel.width = 0.014
    bevel.segments = 4
    bpy.context.view_layer.objects.active = palm
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    palm.data.materials.append(SKIN)
    palm_group = palm.vertex_groups.new(name=f"Hand.{side}")
    palm_group.add(list(range(len(palm.data.vertices))), 1.0, "REPLACE")
    palm_armature = palm.modifiers.new("Human skeleton", "ARMATURE")
    palm_armature.object = arm
    palm.parent = arm
    for poly in palm.data.polygons:
        poly.use_smooth = True
    for digit_index, digit in enumerate(("Index", "Middle", "Ring", "Pinky")):
        # Finger roots span the palm's broad edge. Each has a distinct length:
        # middle longest, then ring, index, little finger.
        finger_lengths = {"Index": 0.073, "Middle": 0.086, "Ring": 0.079, "Pinky": 0.061}
        length = finger_lengths[digit]
        spread_z = (digit_index - 1.5) * 0.015
        root_x = sign * 0.600
        joints = [
            (root_x, -0.039, 1.025 + spread_z),
            (sign*(0.600 + length*0.40), -0.041, 1.024 + spread_z*0.94),
            (sign*(0.600 + length*0.76), -0.027, 1.018 + spread_z*0.86),
            (sign*(0.600 + length), -0.015, 1.010 + spread_z*0.78),
        ]
        digit_mesh(f"Hand_{digit}_{side}",
            joints, [0.0095, 0.0088, 0.0072, 0.0058],
            [f"{digit}{segment+1}.{side}" for segment in range(3)], SKIN)
    # Thumb leaves the palm's long edge at a right angle to the fingers,
    # then turns slightly inward to oppose the index finger.
    thumb_joints = [
        (sign*0.555, -0.039, 1.052),
        (sign*0.555, -0.043, 1.080),
        (sign*0.535, -0.038, 1.094),
    ]
    digit_mesh(f"Hand_Thumb_{side}", thumb_joints,
        [0.014, 0.011, 0.008],
        [f"Thumb{segment+1}.{side}" for segment in range(2)], SKIN)
    leg_x = 0.13 if side == "L" else -0.13
    tube_mesh(f"Body_Leg_{side}", [
        (leg_x, 0.000, 0.875), (leg_x, -0.006, 0.790),
        (leg_x, -0.008, 0.690), (leg_x, -0.010, 0.590),
        (leg_x, -0.020, 0.500), (leg_x, 0.005, 0.420),
        (leg_x, 0.022, 0.335), (leg_x, 0.010, 0.245),
        (leg_x, 0.000, 0.155),
    ], [0.094, 0.108, 0.106, 0.090, 0.071, 0.073, 0.083, 0.064, 0.045],
        SKIN, f"Thigh.{side}", f"Shin.{side}", sides=48, blend_start=0.40, blend_end=0.63)
    sphere_piece(f"Body_Kneecap_{side}", (leg_x, -0.062, 0.495),
        (0.048, 0.022, 0.054), SKIN, f"Shin.{side}", 24, 16)
    sphere_piece(f"Body_Ankle_{side}", (leg_x, 0.000, 0.145),
        (0.050, 0.052, 0.047), SKIN, f"Ankle.{side}", 24, 16)
    foot_rings = [
        (0.025, 0.045, 0.047, 0.108), (-0.025, 0.054, 0.043, 0.105),
        (-0.095, 0.063, 0.037, 0.094), (-0.165, 0.077, 0.032, 0.080),
        (-0.225, 0.071, 0.027, 0.072), (-0.275, 0.043, 0.020, 0.068),
    ]
    foot_verts, foot_faces = [], []
    foot_sides = 24
    for y, width, height, zc in foot_rings:
        for i in range(foot_sides):
            angle = 2.0 * math.pi * i / foot_sides
            z = max(0.045, zc + math.sin(angle) * height)
            foot_verts.append((leg_x + math.cos(angle) * width, y, z))
    for ring in range(len(foot_rings)-1):
        for i in range(foot_sides):
            a = ring * foot_sides + i
            b = ring * foot_sides + (i+1) % foot_sides
            foot_faces.append((a, b, b+foot_sides, a+foot_sides))
    foot_faces.extend([tuple(range(foot_sides-1, -1, -1)),
        tuple((len(foot_rings)-1)*foot_sides+i for i in range(foot_sides))])
    finish_skinned_mesh(f"Body_Foot_{side}", foot_verts, foot_faces, SKIN,
        {f"Foot.{side}": [1.0] * len(foot_verts)})

# ---------------------------------------------------------------------------
# Fuse the body into one continuous anatomical surface.
#
# The preceding forms are modelling primitives. They are deliberately fused
# here so their intersections become one skin surface instead of visible
# overlapping shells. Facial details, hair and held equipment remain separate.
# ---------------------------------------------------------------------------

def point_segment_distance(point, start, end):
    segment = end - start
    length_sq = segment.length_squared
    if length_sq < 1e-10:
        return (point - start).length
    t = max(0.0, min(1.0, (point - start).dot(segment) / length_sq))
    return (point - (start + segment * t)).length

body_parts = [obj for obj in bpy.context.scene.objects
    if obj.type == "MESH" and (
        (obj.name.startswith("Body_") and not ("Areola_" in obj.name or "Nipple_" in obj.name)) or obj.name.startswith("Face_Nose_") or obj.name.startswith("Face_Nostril_Ala_")
    )]
if body_parts:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in body_parts:
        # Remesh in the bind pose, before skin deformation.
        for modifier in list(obj.modifiers):
            if modifier.type == "ARMATURE":
                obj.modifiers.remove(modifier)
        obj.parent = None
        obj.select_set(True)
    bpy.context.view_layer.objects.active = body_parts[0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = "Body_Continuous"
    body.data.name = "Body_Continuous_Mesh"

    remesh = body.modifiers.new("Fuse anatomical forms", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.0035
    remesh.use_smooth_shade = True
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    relax = body.modifiers.new("Relax fused anatomy", "SMOOTH")
    relax.factor = 0.55
    relax.iterations = 3
    bpy.ops.object.modifier_apply(modifier=relax.name)
    polish = body.modifiers.new("Polished skin surface", "SUBSURF")
    polish.levels = 1
    bpy.ops.object.modifier_apply(modifier=polish.name)

    # Flatten the underside after voxel remeshing; smoothing otherwise rounds
    # the sole back into a ball. Only the lowest foot vertices are clamped.
    for vertex in body.data.vertices:
        if vertex.co.z < 0.050:
            vertex.co.z = 0.045

    # Voxel remeshing creates a unified surface. Rebuild smooth skin weights
    # from the canonical rig's bone segments, blending the two nearest bones.
    for group in list(body.vertex_groups):
        body.vertex_groups.remove(group)
    bone_segments = []
    for bone in arm.data.bones:
        head = arm.matrix_world @ bone.head_local
        tail = arm.matrix_world @ bone.tail_local
        bone_segments.append((bone.name, head, tail))
    groups = {name: body.vertex_groups.new(name=name) for name, _, _ in bone_segments}
    for vertex in body.data.vertices:
        point = body.matrix_world @ vertex.co
        ranked = sorted(
            ((point_segment_distance(point, head, tail), name)
                for name, head, tail in bone_segments),
            key=lambda item: item[0]
        )[:2]
        if len(ranked) == 1 or ranked[0][0] < 1e-6:
            groups[ranked[0][1]].add([vertex.index], 1.0, "REPLACE")
        else:
            d0, n0 = ranked[0]
            d1, n1 = ranked[1]
            w0 = 1.0 / max(d0, 0.015)
            w1 = 1.0 / max(d1, 0.015)
            total = w0 + w1
            groups[n0].add([vertex.index], w0 / total, "REPLACE")
            groups[n1].add([vertex.index], w1 / total, "REPLACE")

    body.parent = arm
    skin_modifier = body.modifiers.new("Human skeleton", "ARMATURE")
    skin_modifier.object = arm
    for polygon in body.data.polygons:
        polygon.use_smooth = True

# Distinct but restrained anatomical surface details. These remain separate
# meshes within the body component so they can receive their own material.
AREOLA = material("Wren | areola", (0.39, 0.22, 0.19))
NIPPLE = material("Wren | nipple", (0.34, 0.17, 0.15))
LIP = material("Wren | lips", (0.48, 0.23, 0.22))
LOWER_LIP = material("Wren | lower lip", (0.58, 0.31, 0.29))
CREASE = material("Wren | soft crease", (0.22, 0.11, 0.10))
for side, sign in (("L", 1), ("R", -1)):
    sphere_piece(f"Body_Areola_{side}", (sign * 0.108, -0.214, 1.207),
        (0.024, 0.010, 0.018), AREOLA, "Spine", 20, 12)
    sphere_piece(f"Body_Nipple_{side}", (sign * 0.108, -0.225, 1.207),
        (0.008, 0.010, 0.008), NIPPLE, "Spine", 16, 10)

# Toe geometry is kept separate after remeshing so its definition survives.
def build_toes(side: str, sign: float) -> None:
    leg_x = sign * 0.13
    # Identical generation for both feet prevents a side-specific omission.
    # Big toe is on the medial edge; the remaining toes taper progressively.
    toe_lengths = [0.078, 0.070, 0.064, 0.056, 0.047]
    for toe in range(5):
        lateral = (toe - 2) * 0.019
        length = toe_lengths[toe]
        toe_width = [0.014, 0.0115, 0.0105, 0.0095, 0.0085][toe]
        sphere_piece(f"Body_Toe_{side}_{toe+1}",
            (leg_x + lateral, -0.265 - length * 0.38, 0.068),
            (toe_width, length * 0.62, 0.0095),
            SKIN, f"Foot.{side}", 24, 14)
build_toes("L", 1)
build_toes("R", -1)

# Clavicle definition is sculpted into the torso loft itself; no separate ridge mesh.

# Upper and lower lip volumes with a fine mouth line.
sphere_piece("Face_Upper_Lip", (0.0, -0.128, 1.620),
    (0.043, 0.010, 0.008), LIP, "Head", 20, 12)
sphere_piece("Face_Lower_Lip", (0.0, -0.129, 1.610),
    (0.040, 0.010, 0.009), LOWER_LIP, "Head", 20, 12)
sphere_piece("Face_Mouth_Line", (0.0, -0.138, 1.615),
    (0.035, 0.0025, 0.002), CREASE, "Head", 16, 8)

# Shallow navel inset and understated external adult anatomical detail.
# Navel is sculpted into the continuous torso mesh; no surface decal.
# Pelvic contour remains part of the continuous skin surface; no flat overlays.

EYE_WHITE = material("Wren | eye whites", (0.78, 0.70, 0.58))
IRIS = material("Wren | iris", (0.22, 0.15, 0.09))
EYE = material("Wren | pupils", (0.025, 0.020, 0.018))
for side, x in (("L", 0.047), ("R", -0.047)):
    sphere_piece(f"Face_EyeSocket_{side}", (x, -0.103, 1.715),
        (0.031, 0.023, 0.020), SKIN, "Head", 14, 10)
    sphere_piece(f"Face_Eye_{side}", (x, -0.121, 1.715),
        (0.022, 0.014, 0.014), EYE_WHITE, "Head", 14, 10)
    sphere_piece(f"Face_Iris_{side}", (x, -0.133, 1.715),
        (0.009, 0.006, 0.010), IRIS, "Head", 10, 8)
    sphere_piece(f"Face_Pupil_{side}", (x, -0.138, 1.715),
        (0.0045, 0.0035, 0.006), EYE, "Head", 8, 6)
    sphere_piece(f"Face_Brow_{side}", (x, -0.116, 1.746),
        (0.031, 0.012, 0.008), HAIR, "Head", 12, 8)
    # Fine upper and lower lashes follow the eye contour, close to the skin.
    tube_mesh(f"Face_UpperLashes_{side}", [
        (x - sign * 0.020, -0.132, 1.721),
        (x, -0.139, 1.730),
        (x + sign * 0.020, -0.132, 1.721),
    ], [0.0025, 0.0032, 0.0018], EYE, "Head", sides=8, depth_ratio=0.7)
    tube_mesh(f"Face_LowerLashes_{side}", [
        (x - sign * 0.017, -0.132, 1.708),
        (x, -0.137, 1.704),
        (x + sign * 0.017, -0.132, 1.708),
    ], [0.0015, 0.0020, 0.0012], EYE, "Head", sides=8, depth_ratio=0.7)

# ---------------------------------------------------------------------------
# Anatomical base-model pass: no clothing meshes are generated here.
# Wren's garments will be added later as separate fitted polygon meshes.
# ---------------------------------------------------------------------------

# Scalp cap with shallow raised flow-lines following the hair direction.
# These are broad sculptural grooves/locks, not individually rendered strands.
sphere_piece("Hair_Cap", (0, 0.018, 1.79), (0.132, 0.125, 0.105), HAIR, "Head")
for i in range(9):
    x0 = -0.092 + i * 0.023
    points = []
    for step in range(7):
        t = step / 6.0
        x = x0 * (1.0 - 0.35*t)
        y = -0.075 + 0.145*t
        inside = max(0.08, 1.0 - (x/0.132)**2 - ((y-0.018)/0.125)**2)
        z = 1.79 + 0.105 * math.sqrt(inside) + 0.0015
        points.append((x, y, z))
    tube_mesh(f"Hair_Texture_Ridge_{i+1:02d}", points,
        [0.0028,0.0032,0.0035,0.0035,0.0032,0.0028,0.0015],
        HAIR_FLOW, "Head", sides=7, depth_ratio=0.55)

# A continuous braid core with three interwoven lobes. The strands follow the
# shoulder-to-chest path rather than appearing as a string of spherical beads.
braid_path = [
    (0.085, 0.078, 1.785), (0.135, 0.060, 1.735),
    (0.180, 0.025, 1.680), (0.215, -0.020, 1.620),
    (0.225, -0.060, 1.555), (0.230, -0.100, 1.490),
    (0.225, -0.130, 1.425), (0.220, -0.150, 1.360),
    (0.215, -0.160, 1.295), (0.210, -0.160, 1.235),
    (0.205, -0.155, 1.190)
]
tube_mesh("Hair_Braid_Core", braid_path, [0.030]*10+[0.020],
    HAIR, "Head", sides=16, depth_ratio=0.9)
for strand in range(3):
    strand_points = []
    for i, point in enumerate(braid_path):
        phase = i * 1.15 + strand * (2.0*math.pi/3.0)
        strand_points.append((point[0] + math.cos(phase)*0.020,
            point[1] - 0.010 + math.sin(phase)*0.020, point[2]))
    tube_mesh(f"Hair_Braid_Interweave_{strand+1}", strand_points,
        [0.013]*10+[0.008], HAIR, "Head", sides=12, depth_ratio=0.82)

# Sword is held upright: grip sits in the palm, guard below it and blade rises.
upright = (math.radians(90), 0.0, 0.0)
sphere_piece("Weapon_Sword_Grip", (-0.650, -0.020, 1.035),
    (0.015, 0.078, 0.015), LEATHER, "Hand.R", 12, 8, upright)
sphere_piece("Weapon_Sword_Guard", (-0.650, -0.020, 1.112),
    (0.075, 0.010, 0.010), SWORD_METAL, "Hand.R", 12, 8)
sphere_piece("Weapon_Sword_Blade", (-0.650, -0.020, 1.275),
    (0.022, 0.155, 0.006), SWORD_METAL, "Hand.R", 12, 8, upright)


# ---------------------------------------------------------------------------
# Optional appearance layers: body hair, tattoos and piercings.
# Each category exports independently and can be changed at runtime.

def torso_surface_y(x, z, front=True):
    lower = torso_rings[0]
    upper = torso_rings[-1]
    for i in range(len(torso_rings)-1):
        if torso_rings[i][0] <= z <= torso_rings[i+1][0]:
            lower, upper = torso_rings[i], torso_rings[i+1]
            break
    t = max(0.0, min(1.0, (z-lower[0]) / max(0.0001, upper[0]-lower[0])))
    width = lower[1] * (1-t) + upper[1] * t
    depth = lower[2] * (1-t) + upper[2] * t
    section = math.sqrt(max(0.05, 1.0 - (x / width) ** 2))
    y = (-1.0 if front else 1.0) * depth * section
    if front:
        # Follow the actual breast loft rather than the narrower torso ellipsoid.
        breast_profile = [
            (1.335, 0.007, 0.006, -0.090), (1.320, 0.020, 0.016, -0.104),
            (1.295, 0.043, 0.030, -0.120), (1.265, 0.065, 0.048, -0.134),
            (1.235, 0.082, 0.061, -0.146), (1.205, 0.088, 0.068, -0.151),
            (1.175, 0.080, 0.064, -0.146), (1.150, 0.058, 0.048, -0.131),
            (1.132, 0.027, 0.024, -0.111), (1.125, 0.007, 0.006, -0.098),
        ]
        if 1.125 <= z <= 1.335:
            for i in range(len(breast_profile)-1):
                a, b = breast_profile[i], breast_profile[i+1]
                if min(a[0], b[0]) <= z <= max(a[0], b[0]):
                    t = (z-a[0]) / (b[0]-a[0])
                    bw = a[1]*(1-t) + b[1]*t
                    bd = a[2]*(1-t) + b[2]*t
                    by = a[3]*(1-t) + b[3]*t
                    for centre_x in (-0.108, 0.108):
                        dx = (x-centre_x) / max(0.001, bw)
                        dz = (z-1.235) / 0.105
                        if dx*dx + dz*dz < 1.0:
                            breast_y = by - bd * math.sqrt(max(0.0, 1.0-dx*dx-dz*dz))
                            y = min(y, breast_y)
                    break
        if 0.625 <= z <= 0.710:
            vertical = math.sin(math.pi * (z - 0.625) / 0.085)
            centre = math.exp(-(x / 0.060) ** 2)
            y -= max(0.0, vertical) * centre * 0.006
        if 0.625 <= z <= 0.700:
            profile = math.exp(-((z - 0.663) / 0.026) ** 2)
            paired = (math.exp(-((x - 0.020) / 0.013) ** 2)
                + math.exp(-((x + 0.020) / 0.013) ** 2))
            centre = math.exp(-(x / 0.0065) ** 2)
            y -= profile * paired * 0.012
            y += profile * centre * 0.009
        if 0.690 <= z <= 0.715:
            hood = math.exp(-((z - 0.700) / 0.009) ** 2) * math.exp(-(x / 0.012) ** 2)
            y -= hood * 0.006
    else:
        # Include the rear gluteal loft so the brief panel sits outside the
        # actual buttock silhouette instead of being buried in the skin.
        glute_profile = [
            (0.965, 0.008, 0.010), (0.950, 0.025, 0.028),
            (0.925, 0.050, 0.048), (0.895, 0.075, 0.068),
            (0.865, 0.094, 0.082), (0.830, 0.103, 0.090),
            (0.800, 0.096, 0.084), (0.775, 0.078, 0.068),
            (0.755, 0.052, 0.045), (0.744, 0.025, 0.022),
            (0.741, 0.006, 0.006),
        ]
        if 0.741 <= z <= 0.965:
            for i in range(len(glute_profile)-1):
                a, b = glute_profile[i], glute_profile[i+1]
                if min(a[0], b[0]) <= z <= max(a[0], b[0]):
                    t = (z-a[0]) / (b[0]-a[0])
                    gx = a[1]*(1-t) + b[1]*t
                    gy = a[2]*(1-t) + b[2]*t
                    for centre_x in (-0.112, 0.112):
                        dx = (x-centre_x) / max(0.001, gx)
                        if abs(dx) < 1.0:
                            glute_y = 0.075 + gy * math.sqrt(max(0.0, 1.0-dx*dx))
                            y = max(y, glute_y)
                    break
        rear_dimple = math.exp(-((z - 0.788) / 0.012) ** 2) * math.exp(-(x / 0.014) ** 2)
        y -= rear_dimple * 0.012
    return y

# ---------------------------------------------------------------------------
# First modular undergarments, based on Wren's original 2D preset:
# strapless bra + full-coverage briefs, both ochre with pale edging.
# These are separate skinned garment meshes, never fused into the body.
# ---------------------------------------------------------------------------
UNDERWEAR = material("Wren | dark ochre underwear HSV 55/58/20", (0.20, 0.188, 0.084))
UNDERWEAR_TRIM = material("Wren | pale gold underwear HSV 47/100/100", (1.0, 0.783, 0.0))

# Strapless bra: two shaped cups over the breast volume and a narrow band.
for side, sign in (("L", 1), ("R", -1)):
    sphere_piece(f"Garment_Bra_Cup_{side}", (sign * 0.108, -0.229, 1.225),
        (0.067, 0.016, 0.056), UNDERWEAR, "Spine", 48, 32)
    # Fine upper cup piping follows the cup's curved top edge.
    cup_points = []
    for step in range(13):
        angle = math.pi * (0.08 + 0.84 * step / 12.0)
        cup_points.append((sign * 0.108 + math.cos(angle) * 0.061,
            -0.245 - math.sin(angle) * 0.004, 1.225 + math.sin(angle) * 0.056))
    tube_mesh(f"Garment_Bra_CupTrim_{side}", cup_points,
        [0.0025] * (len(cup_points)-1) + [0.0018],
        UNDERWEAR_TRIM, "Spine", sides=7, depth_ratio=0.8)
    # Lace-inspired embroidery follows the cup surface.
    motif = [
        (sign * 0.108 - 0.025, -0.247, 1.225),
        (sign * 0.108 - 0.014, -0.250, 1.245),
        (sign * 0.108, -0.252, 1.252),
        (sign * 0.108 + 0.014, -0.250, 1.245),
        (sign * 0.108 + 0.025, -0.247, 1.225),
    ]
    tube_mesh(f"Garment_Bra_Embroidery_{side}", motif,
        [0.0018] * (len(motif)-1) + [0.0012],
        UNDERWEAR_TRIM, "Spine", sides=6, depth_ratio=0.65)

sphere_piece("Garment_Bra_CentreClasp", (0.0, -0.151, 1.153),
    (0.009, 0.004, 0.012), UNDERWEAR_TRIM, "Spine", 16, 10)

# The bandeau band wraps around the torso under the cups.
band_verts, band_faces = [], []
band_sides = 48
for z in (1.145, 1.162):
    for i in range(band_sides):
        angle = 2.0 * math.pi * i / band_sides
        x = math.cos(angle) * 0.218
        y = math.sin(angle) * 0.147
        band_verts.append((x * 1.015, y * 1.045, z))
for i in range(band_sides):
    nxt = (i + 1) % band_sides
    band_faces.append((i, nxt, band_sides+nxt, band_sides+i))
finish_skinned_mesh("Garment_Bra_Bandeau", band_verts, band_faces,
    UNDERWEAR, {"Spine": [1.0] * len(band_verts)})

# Side cradle panels physically connect each cup to the wraparound bandeau.
# Wren's source item is strapless, so these are side/under-cup supports, not
# invented shoulder straps.
for side, sign in (("L", 1), ("R", -1)):
    cradle_points = [
        (sign*0.155, -0.226, 1.190),
        (sign*0.180, -0.194, 1.178),
        (sign*0.205, -0.145, 1.163),
        (sign*0.216, -0.070, 1.153),
    ]
    tube_mesh(f"Garment_Bra_CupToBand_{side}", cradle_points,
        [0.010, 0.009, 0.008, 0.007], UNDERWEAR, "Spine",
        sides=10, depth_ratio=0.30)


# Full-coverage briefs. Front and rear panels follow the torso's elliptical
# surface, with a shaped leg-opening silhouette rather than a flat card.
# A single continuous briefs shell wraps front, rear, hips and crotch.
# The lower edge rises at the leg openings and dips into a narrow crotch gusset.
def make_briefs_wrap() -> None:
    verts, faces = [], []
    # Dense surface tessellation is necessary for small, curved floral
    # apertures. The previous coarse grid produced obvious square holes.
    around = 128
    rows = 64
    for row in range(rows):
        t = row / float(rows - 1)
        for col in range(around):
            angle = 2.0 * math.pi * col / around
            # Follow the full elliptical torso perimeter continuously.
            # Front/back meet smoothly at the hips instead of jumping between
            # positive and negative surface depths.
            side_factor = abs(math.sin(angle))
            front = math.cos(angle) > 0.0
            upper_z = 0.900 - 0.008 * side_factor
            if front:
                lower_z = 0.718 + 0.050 * side_factor
            else:
                lower_z = 0.735 + 0.038 * side_factor
            z = upper_z * (1.0 - t) + lower_z * t
            width = torso_rings[0][1]
            depth = torso_rings[0][2]
            for ring_index in range(len(torso_rings)-1):
                lo, hi = torso_rings[ring_index], torso_rings[ring_index+1]
                if lo[0] <= z <= hi[0]:
                    blend = (z-lo[0]) / (hi[0]-lo[0])
                    width = lo[1]*(1.0-blend) + hi[1]*blend
                    depth = lo[2]*(1.0-blend) + hi[2]*blend
                    break
            x = math.sin(angle) * width
            y = -math.cos(angle) * depth
            nx = math.sin(angle) / max(width, 0.001)
            ny = -math.cos(angle) / max(depth, 0.001)
            normal_len = math.sqrt(nx*nx + ny*ny)
            x += (nx / normal_len) * 0.006
            y += (ny / normal_len) * 0.006
            verts.append((x, y, z))
    for row in range(rows - 1):
        for col in range(around):
            nxt = (col + 1) % around
            # Repeating floral lace: each 16x16 repeat contains a small
            # central eyelet and six petal-shaped apertures. Their edges are
            # sampled by the dense mesh, so the gaps read as flowers rather
            # than square perforations.
            u = (col + 0.5) % 16.0
            v = (row + 0.5) % 16.0
            dx, dy = u - 8.0, v - 8.0
            radial = math.sqrt(dx*dx + dy*dy)
            in_flower_hole = radial < 1.20
            for petal in range(6):
                angle = petal * math.tau / 6.0
                px = math.cos(angle) * 4.0
                py = math.sin(angle) * 4.0
                # Slightly oval petals follow the radial direction.
                rx, ry = dx - px, dy - py
                along = rx * math.cos(angle) + ry * math.sin(angle)
                across = -rx * math.sin(angle) + ry * math.cos(angle)
                if (along / 1.75) ** 2 + (across / 1.35) ** 2 < 1.0:
                    in_flower_hole = True
            # Fine connecting eyelets between adjacent flowers create the
            # open net structure characteristic of lace.
            if in_flower_hole or (abs(dx) < 0.65 and 1.5 < abs(dy) < 2.8):
                continue
            a = row * around + col
            b = row * around + nxt
            cidx = (row + 1) * around + nxt
            d = (row + 1) * around + col
            faces.append((a, b, cidx, d))
    finish_skinned_mesh("Garment_Briefs_Continuous", verts, faces,
        UNDERWEAR, {"Root": [1.0] * len(verts)})

make_briefs_wrap()

# Continuous pale waistband follows the complete circumference.
waist_points = []
for i in range(33):
    angle = 2.0 * math.pi * i / 32.0
    x = math.cos(angle) * 0.151
    z = 0.894 - 0.006 * abs(math.cos(angle))
    front = math.sin(angle) < 0.0
    waist_points.append((x, torso_surface_y(x, z, front) +
        (-0.012 if front else 0.012), z))
tube_mesh("Garment_Briefs_Waist_Continuous", waist_points,
    [0.0025] * (len(waist_points)-1) + [0.0025],
    UNDERWEAR_TRIM, "Root", sides=7, depth_ratio=0.7)

# Neatly groomed, modest pubic hair is a separate appearance layer. It is
# offset just outside the front skin surface so it cannot show through the body.
for i in range(11):
    x = (i - 5) * 0.008
    z0 = 0.835 + abs(i - 5) * 0.0015
    z1 = 0.775 + abs(i - 5) * 0.003
    points = []
    for px, pz in [(x, z0), (x * 0.82, (z0+z1)*0.5), (x * 0.62, z1)]:
        points.append((px, torso_surface_y(px, pz, True)-0.003, pz))
    tube_mesh(f"BodyHair_Pubic_{i+1:02d}", points,
        [0.0020, 0.0018, 0.0006], PUBIC_HAIR, "Root", sides=6, depth_ratio=0.65)

# Ear hoops sit around the lobes, with the ring plane parallel to the front
# and rear of the head so both views show the complete hoop.
for side, sign in (("L", 1), ("R", -1)):
    torus_piece(f"Piercing_Ear_Hoop_{side}", (sign * 0.140, 0.0, 1.675),
        0.018, 0.0030, PIERCING_METAL, "Head", (math.radians(90), 0, 0))

# The top of this hoop intersects the nipple itself: a piercing must pass
# through tissue rather than float in front of it.
torus_piece("Piercing_Left_Nipple", (0.108, -0.226, 1.195),
    0.010, 0.0022, PIERCING_METAL, "Spine", (math.radians(90), 0, 0))

# Five-point star tattoo on the shoulder opposite the braid.
def tattoo_tube(name, coords, radius=0.0030):
    points = [(x, torso_surface_y(x, z, False)+0.002, z) for x, z in coords]
    tube_mesh(name, points, [radius] * (len(points)-1) + [radius*0.45],
        TATTOO, "Spine", sides=7, depth_ratio=0.55)

star_centre_x, star_centre_z = -0.190, 1.365
star_points = []
for point_index in range(10):
    angle = math.pi * 0.5 + point_index * math.pi / 5.0
    radius = 0.040 if point_index % 2 == 0 else 0.017
    star_points.append((star_centre_x + math.cos(angle) * radius,
        star_centre_z + math.sin(angle) * radius))
star_points.append(star_points[0])
tattoo_tube("Tattoo_Star_Shoulder", star_points, 0.0032)

# Preview setup and GLB export.
# ---------------------------------------------------------------------------

floor_mat = material("Preview | warm grey", (0.22, 0.22, 0.21))
bpy.ops.mesh.primitive_plane_add(size=5, location=(0, 0, 0))
floor = bpy.context.object
floor.name = "Preview_Floor"

bpy.ops.object.camera_add(location=(3.1, -5.2, 2.45))
camera = bpy.context.object
camera.name = "Preview_Camera"
target = Vector((0, 0, 0.92))
direction = target - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 3.1
bpy.context.scene.camera = camera

bpy.ops.object.light_add(type="AREA", location=(1.5, -3.0, 4.0))
key = bpy.context.object
key.name = "Preview_Key"
key.data.energy = 420
key.data.shape = "DISK"
key.data.size = 4

bpy.ops.object.light_add(type="AREA", location=(-2.0, 1.5, 2.5))
fill = bpy.context.object
fill.name = "Preview_Fill"
fill.data.energy = 180
fill.data.size = 3

character_collection = bpy.data.collections.new("WREN_CHARACTER")
bpy.context.scene.collection.children.link(character_collection)
for obj in list(bpy.context.scene.objects):
    if obj not in (floor, camera, key, fill):
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        character_collection.objects.link(obj)

bpy.ops.object.select_all(action="DESELECT")
for obj in character_collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = arm

engine_items = bpy.context.scene.render.bl_rna.properties["engine"].enum_items
available_engines = {item.identifier for item in engine_items}
if "BLENDER_EEVEE" in available_engines:
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
elif "BLENDER_EEVEE_NEXT" in available_engines:
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
else:
    bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
bpy.context.scene.render.resolution_x = 1000
bpy.context.scene.render.resolution_y = 1000
bpy.context.scene.render.resolution_percentage = 100

blend_path = OUT / "wren_blockout.blend"
glb_path = OUT / "wren_blockout.glb"
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB", use_selection=True)

print(f"Wren blockout saved to: {blend_path}")
print(f"Wren GLB exported to: {glb_path}")
