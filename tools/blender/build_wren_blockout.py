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
HAIR = material("Wren | muted blue hair", (0.12, 0.20, 0.34))
SHIRT = material("Wren | dark green shirt", (0.13, 0.24, 0.15))
TRIM = material("Wren | rose red trim", (0.55, 0.12, 0.20))
TROUSERS = material("Wren | charcoal trousers", (0.075, 0.072, 0.08))
UNDER = material("Wren | underlayer", (0.25, 0.19, 0.10))
SWORD_METAL = material("Wren | sword steel", (0.48, 0.54, 0.59), 0.32, 0.65)
LEATHER = material("Wren | sword grip", (0.18, 0.095, 0.045))

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
    "Hand.L": ((0.52, 0, 1.10), (0.59, 0, 1.04), "Forearm.L"),
    "UpperArm.R": ((-0.18, 0, 1.39), (-0.38, 0, 1.25), "Spine"),
    "Forearm.R": ((-0.38, 0, 1.25), (-0.52, 0, 1.10), "UpperArm.R"),
    "Hand.R": ((-0.52, 0, 1.10), (-0.59, 0, 1.04), "Forearm.R"),
    "Thigh.L": ((0.12, 0, 0.88), (0.13, 0, 0.49), "Root"),
    "Shin.L": ((0.13, 0, 0.49), (0.13, 0, 0.15), "Thigh.L"),
    "Foot.L": ((0.13, 0, 0.15), (0.13, -0.18, 0.08), "Shin.L"),
    "Thigh.R": ((-0.12, 0, 0.88), (-0.13, 0, 0.49), "Root"),
    "Shin.R": ((-0.13, 0, 0.49), (-0.13, 0, 0.15), "Thigh.R"),
    "Foot.R": ((-0.13, 0, 0.15), (-0.13, -0.18, 0.08), "Shin.R"),
}
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

def sphere_piece(name, location, scale, mat, bone_name, segments=32, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
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
    centres = [Vector(p) for p in points]
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
        radius = radii[ring_index]
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
    (0.735, 0.175, 0.115, 0.000),
    (0.790, 0.215, 0.135, 0.000),
    (0.855, 0.235, 0.145, 0.000),
    (0.925, 0.205, 0.132, 0.000),
    (1.015, 0.172, 0.118, 0.000),
    (1.105, 0.190, 0.132, 0.000),
    (1.205, 0.218, 0.145, 0.000),
    (1.305, 0.225, 0.140, 0.000),
    (1.390, 0.255, 0.125, 0.000),
    (1.465, 0.145, 0.095, 0.000),
    (1.515, 0.075, 0.070, 0.000),
]
torso_verts, torso_faces, root_weights, spine_weights = [], [], [], []
torso_sides = 48
for ring_index, (z, width, depth, y_center) in enumerate(torso_rings):
    for side_index in range(torso_sides):
        angle = 2.0 * math.pi * side_index / torso_sides
        torso_verts.append((math.cos(angle) * width, y_center + math.sin(angle) * depth, z))
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
torso_faces.append(tuple(range(torso_sides - 1, -1, -1)))
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
        (1.145, 0.010, 0.012, -0.092),
        (1.165, 0.045, 0.035, -0.103),
        (1.195, 0.073, 0.052, -0.112),
        (1.230, 0.080, 0.059, -0.116),
        (1.265, 0.070, 0.052, -0.110),
        (1.295, 0.050, 0.038, -0.098),
        (1.315, 0.020, 0.018, -0.085),
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
    sphere_piece(f"Body_Glute_{side}", (sign * 0.112, 0.092, 0.835),
        (0.125, 0.105, 0.145), SKIN, "Root", 32, 24)
# Subtle, non-detailed external pelvic anatomy; no explicit genital detailing.
sphere_piece("Body_Pubic_Mound", (0, -0.112, 0.785),
    (0.105, 0.035, 0.065), SKIN, "Root", 18, 12)

sphere_piece("Body_Neck", (0, 0, 1.535), (0.072, 0.07, 0.105), SKIN, "Neck")
sphere_piece("Body_Head", (0, -0.005, 1.70), (0.125, 0.12, 0.16), SKIN, "Head", 24, 16)
# Nose bridge, tip and subtle alae are separate sculptural forms.
sphere_piece("Face_Nose_Bridge", (0, -0.112, 1.685), (0.020, 0.035, 0.060), SKIN, "Head", 12, 10)
sphere_piece("Face_Nose_Tip", (0, -0.145, 1.652), (0.027, 0.030, 0.023), SKIN, "Head", 12, 8)
for side, sign in (("L", 1), ("R", -1)):
    sphere_piece(f"Face_Nostril_Ala_{side}", (sign * 0.019, -0.132, 1.650),
        (0.014, 0.018, 0.014), SKIN, "Head", 10, 8)
    # Ear shell and inner concha, positioned on either side of the skull.
    sphere_piece(f"Body_Ear_{side}", (sign * 0.119, -0.002, 1.695),
        (0.030, 0.035, 0.052), SKIN, "Head", 16, 12)
    sphere_piece(f"Face_Ear_Concha_{side}", (sign * 0.137, -0.023, 1.695),
        (0.010, 0.018, 0.030), UNDER, "Head", 12, 8)
for side, sign in (("L", 1), ("R", -1)):
    x = sign * 0.18
    sphere_piece(f"Body_Ear_{side}", (x * 0.68, 0, 1.70), (0.035, 0.035, 0.055), SKIN, "Head", 10, 8)
    # Shoulder, upper arm, elbow and forearm are a single continuous surface.
    # The elbow is deliberately buried in the tube instead of being a side-on join.
    shoulder = (sign * 0.18, 0.0, 1.385)
    upper_mid = (sign * 0.285, -0.002, 1.315)
    elbow = (sign * 0.385, -0.006, 1.235)
    fore_mid = (sign * 0.455, -0.012, 1.155)
    wrist = (sign * 0.525, -0.018, 1.075)
    tube_mesh(f"Body_Arm_{side}", [shoulder, upper_mid, elbow, fore_mid, wrist],
        [0.092, 0.087, 0.073, 0.062, 0.043], SKIN,
        f"UpperArm.{side}", f"Forearm.{side}", sides=12)
    # Palm, individually modelled curled fingers and opposing thumb.
    # Fixed grip pose for now; separate finger bones can animate these later.
    palm = (sign * 0.555, -0.025, 1.025)
    sphere_piece(f"Body_Palm_{side}", palm, (0.055, 0.052, 0.073), SKIN, f"Hand.{side}")
    for finger in range(4):
        spread = (finger - 1.5) * 0.024
        base_x = sign * (0.565 + spread)
        finger_points = [
            (base_x, -0.045, 1.045 - abs(spread) * 0.35),
            (base_x + sign * 0.012, -0.080, 1.038 - abs(spread) * 0.25),
            (base_x + sign * 0.010, -0.105, 1.020 - abs(spread) * 0.20),
            (base_x - sign * 0.002, -0.105, 1.002 - abs(spread) * 0.15),
        ]
        tube_mesh(f"Body_Finger_{side}_{finger+1}", finger_points,
            [0.014, 0.013, 0.011, 0.008], SKIN, f"Hand.{side}", sides=8, depth_ratio=0.9)
    thumb_points = [
        (sign * 0.525, -0.025, 1.055),
        (sign * 0.505, -0.060, 1.055),
        (sign * 0.505, -0.095, 1.040),
        (sign * 0.525, -0.105, 1.020),
    ]
    tube_mesh(f"Body_Thumb_{side}", thumb_points, [0.019, 0.017, 0.014, 0.010],
        SKIN, f"Hand.{side}", sides=8, depth_ratio=0.9)
    leg_x = 0.13 if side == "L" else -0.13
    sphere_piece(f"Body_Thigh_{side}", (leg_x, 0, 0.69), (0.115, 0.115, 0.25), SKIN, f"Thigh.{side}")
    sphere_piece(f"Body_Shin_{side}", (leg_x, 0, 0.32), (0.078, 0.085, 0.22), SKIN, f"Shin.{side}")
    sphere_piece(f"Body_Foot_{side}", (leg_x, -0.075, 0.105), (0.075, 0.16, 0.07), SKIN, f"Foot.{side}")
    # Five short toes fan out from the front of each foot.
    for toe in range(5):
        toe_offset = (toe - 2) * 0.025
        toe_length = 0.075 - abs(toe_offset) * 0.55
        toe_points = [
            (leg_x + toe_offset * 0.72, -0.175, 0.095),
            (leg_x + toe_offset, -0.205 - toe_length * 0.30, 0.090),
            (leg_x + toe_offset * 1.08, -0.175 - toe_length, 0.083),
        ]
        tube_mesh(f"Body_Toe_{side}_{toe+1}", toe_points,
            [0.019 if toe == 2 else 0.015, 0.013, 0.006], SKIN,
            f"Foot.{side}", sides=8, depth_ratio=0.82)

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

# ---------------------------------------------------------------------------
# Anatomical base-model pass: no clothing meshes are generated here.
# Wren's garments will be added later as separate fitted polygon meshes.
# ---------------------------------------------------------------------------

sphere_piece("Hair_Cap", (0, 0.018, 1.79), (0.132, 0.125, 0.105), HAIR, "Head")
for i in range(7):
    z = 1.77 - i * 0.055
    x = 0.085 + 0.025 * math.sin(i * 0.8)
    y = 0.085 + 0.012 * math.cos(i * 0.8)
    sphere_piece(f"Hair_Braid_{i+1:02d}", (x, y, z), (0.037, 0.038, 0.052), HAIR, "Head", 10, 8)

# Blade points forward (-Y), perpendicular to the wrist-to-palm line in X/Z.
# The crossguard spans the palm; fingers curl around the grip.
sphere_piece("Weapon_Sword_Grip", (-0.555, -0.112, 1.025), (0.021, 0.095, 0.021), LEATHER, "Hand.R", 10, 8)
sphere_piece("Weapon_Sword_Guard", (-0.555, -0.205, 1.025), (0.085, 0.014, 0.012), SWORD_METAL, "Hand.R", 10, 6)
sphere_piece("Weapon_Sword_Blade", (-0.555, -0.435, 1.025), (0.035, 0.235, 0.009), SWORD_METAL, "Hand.R", 10, 8)

# ---------------------------------------------------------------------------
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
