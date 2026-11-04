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
    # New materials use nodes by default. Enable only if a configuration disabled them.
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
# Shared human skeleton. The first pass uses rigid bone weights and overlapping
# low-poly forms; later garment/body meshes can use smooth skin weights.
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
# Reusable mesh helpers. Each blockout piece is its own mesh, skinned rigidly
# to a bone. That makes the first export inspectable and keeps garments separate.
# ---------------------------------------------------------------------------

def sphere_piece(name, location, scale, mat, bone_name, segments=14, rings=10):
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
    return obj

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

sphere_piece("Body_Pelvis", (0, 0, 0.88), (0.205, 0.135, 0.16), SKIN, "Root")
sphere_piece("Body_Torso", (0, 0, 1.20), (0.235, 0.145, 0.34), SKIN, "Spine")
sphere_piece("Body_Neck", (0, 0, 1.55), (0.072, 0.07, 0.105), SKIN, "Neck")
sphere_piece("Body_Head", (0, -0.005, 1.70), (0.125, 0.12, 0.16), SKIN, "Head", 18, 12)
sphere_piece("Body_Nose", (0, -0.119, 1.685), (0.025, 0.025, 0.042), SKIN, "Head", 10, 8)
for side, x in (("L", 0.18), ("R", -0.18)):
    sphere_piece(f"Body_Ear_{side}", (x * 0.68, 0, 1.70), (0.035, 0.035, 0.055), SKIN, "Head", 10, 8)
    sphere_piece(f"Body_UpperArm_{side}", (x * 1.55, 0, 1.32), (0.095, 0.09, 0.19), SKIN, f"UpperArm.{side}")
    sphere_piece(f"Body_Forearm_{side}", (x * 2.50, 0, 1.17), (0.075, 0.075, 0.17), SKIN, f"Forearm.{side}")
    sphere_piece(f"Body_Hand_{side}", (x * 3.05, -0.005, 1.075), (0.065, 0.045, 0.09), SKIN, f"Hand.{side}")
    leg_x = 0.13 if side == "L" else -0.13
    sphere_piece(f"Body_Thigh_{side}", (leg_x, 0, 0.69), (0.115, 0.115, 0.25), SKIN, f"Thigh.{side}")
    sphere_piece(f"Body_Shin_{side}", (leg_x, 0, 0.32), (0.078, 0.085, 0.22), SKIN, f"Shin.{side}")
    sphere_piece(f"Body_Foot_{side}", (leg_x, -0.075, 0.105), (0.075, 0.16, 0.07), SKIN, f"Foot.{side}")

# Simple eyes: deliberately restrained until the face-design pass.
EYE = material("Wren | eyes", (0.045, 0.035, 0.03))
for side, x in (("L", 0.047), ("R", -0.047)):
    sphere_piece(f"Face_Eye_{side}", (x, -0.113, 1.72), (0.012, 0.009, 0.014), EYE, "Head", 8, 6)

# ---------------------------------------------------------------------------
# Wren's actual authored outfit. Each garment is separate from the body.
# The simple overlapping forms are placeholders for fitted garment meshes.
# ---------------------------------------------------------------------------

# Shirt torso and sleeves.
sphere_piece("Garment_Shirt_Torso", (0, -0.002, 1.20), (0.248, 0.158, 0.345), SHIRT, "Spine")
sphere_piece("Garment_Shirt_Sleeve_L", (0.285, 0, 1.32), (0.105, 0.105, 0.17), SHIRT, "UpperArm.L")
sphere_piece("Garment_Shirt_Sleeve_R", (-0.285, 0, 1.32), (0.105, 0.105, 0.17), SHIRT, "UpperArm.R")
torus_piece("Garment_Shirt_Collar_Trim", (0, 0, 1.485), 0.105, 0.018, TRIM, "Spine")
torus_piece("Garment_Shirt_Hem_Trim", (0, 0, 0.94), 0.205, 0.012, TRIM, "Spine")

# Dark lattice trousers: hip section and individual legs.
sphere_piece("Garment_Trousers_Hips", (0, 0.002, 0.88), (0.218, 0.148, 0.17), TROUSERS, "Root")
for side, x in (("L", 0.13), ("R", -0.13)):
    sphere_piece(f"Garment_Trousers_Thigh_{side}", (x, 0.002, 0.69), (0.126, 0.126, 0.255), TROUSERS, f"Thigh.{side}")
    sphere_piece(f"Garment_Trousers_Lower_{side}", (x, 0.002, 0.32), (0.088, 0.094, 0.225), TROUSERS, f"Shin.{side}")

# Braided dark-blue hair: cap and a low-poly braid falling behind the left shoulder.
sphere_piece("Hair_Cap", (0, 0.018, 1.79), (0.132, 0.125, 0.105), HAIR, "Head")
for i in range(7):
    z = 1.77 - i * 0.055
    x = 0.085 + 0.025 * math.sin(i * 0.8)
    y = 0.085 + 0.012 * math.cos(i * 0.8)
    sphere_piece(f"Hair_Braid_{i+1:02d}", (x, y, z), (0.037, 0.038, 0.052), HAIR, "Head", 10, 8)

# Sword: separate held equipment, attached to Wren's right hand.
sphere_piece("Weapon_Sword_Grip", (-0.59, -0.015, 1.08), (0.022, 0.025, 0.095), LEATHER, "Hand.R", 10, 8)
sphere_piece("Weapon_Sword_Guard", (-0.59, -0.015, 1.17), (0.085, 0.025, 0.018), SWORD_METAL, "Hand.R", 10, 6)
sphere_piece("Weapon_Sword_Blade", (-0.59, -0.015, 1.37), (0.027, 0.012, 0.19), SWORD_METAL, "Hand.R", 10, 8)

# ---------------------------------------------------------------------------
# Preview setup. The GLB export below selects only the rig and Wren's meshes.
# ---------------------------------------------------------------------------

floor_mat = material("Preview | warm grey", (0.22, 0.22, 0.21))
bpy.ops.mesh.primitive_plane_add(size=5, location=(0, 0, 0))
floor = bpy.context.object
floor.name = "Preview_Floor"
floor.data.materials.append(floor_mat)

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

# Organise model parts in a collection for clean selection/export.
character_collection = bpy.data.collections.new("WREN_CHARACTER")
bpy.context.scene.collection.children.link(character_collection)
for obj in list(bpy.context.scene.objects):
    if obj not in (floor, camera, key, fill):
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        character_collection.objects.link(obj)

# Select only character meshes and the armature for GLB export.
bpy.ops.object.select_all(action="DESELECT")
for obj in character_collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = arm

# Blender 4.x called Eevee BLENDER_EEVEE_NEXT; Blender 5.x calls it BLENDER_EEVEE.
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
