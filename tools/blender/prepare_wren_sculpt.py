"""Prepare a clean, continuous, sculpt-ready Wren body from the procedural blockout.

This does NOT claim to create a finished artistic sculpt. It removes the rig and
non-body assets, fuses all skin geometry into one mesh, and saves a dedicated
Blender file for the subsequent manual anatomy sculpt / retopology workflow.

Run:
blender --background art/characters/wren/wren_blockout.blend --python tools/blender/prepare_wren_sculpt.py
"""
import bpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "characters" / "wren"
OUT.mkdir(parents=True, exist_ok=True)

# Keep only the body surface pieces. The body generator has already fused the
# main torso, head, arms, legs, feet and nose; toes and small skin details are
# added afterwards and are fused here as well.
body_parts = [
    obj for obj in bpy.context.scene.objects
    if obj.type == "MESH" and (
        obj.name == "Body_Continuous"
        or obj.name.startswith("Body_Toe_")
        or obj.name.startswith("Body_Areola_")
        or obj.name.startswith("Body_Nipple_")
    )
]
if not body_parts:
    raise RuntimeError("No body geometry found. Generate wren_blockout.blend first.")

# Apply any deformation in the rest pose, then detach the body from the rig.
for obj in body_parts:
    for modifier in list(obj.modifiers):
        if modifier.type == "ARMATURE":
            obj.modifiers.remove(modifier)
    obj.parent = None
    obj.select_set(False)

bpy.ops.object.select_all(action="DESELECT")
for obj in body_parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = body_parts[0]
bpy.ops.object.join()
body = bpy.context.object
body.name = "Wren_Sculpt_Body"
body.data.name = "Wren_Sculpt_Body_Mesh"

# A finer voxel remesh removes the remaining overlaps and gives the sculptor
# even topology to work with. This is a starting surface, not final anatomy.
remesh = body.modifiers.new("Sculpt base | unified voxel surface", "REMESH")
remesh.mode = "VOXEL"
remesh.voxel_size = 0.0025
remesh.use_smooth_shade = True
bpy.context.view_layer.objects.active = body
bpy.ops.object.modifier_apply(modifier=remesh.name)

relax = body.modifiers.new("Sculpt base | light surface relaxation", "SMOOTH")
relax.factor = 0.28
relax.iterations = 2
bpy.ops.object.modifier_apply(modifier=relax.name)

# Remove every non-body object, including the rig, clothing, hair, props,
# preview floor and lights. The sculpt file is intentionally uncluttered.
for obj in list(bpy.context.scene.objects):
    if obj != body:
        bpy.data.objects.remove(obj, do_unlink=True)

for polygon in body.data.polygons:
    polygon.use_smooth = True

# Useful sculpt defaults: body selected, sculpt workspace active where present.
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
try:
    bpy.context.workspace = bpy.data.workspaces.get("Sculpting") or bpy.context.workspace
except Exception:
    pass
try:
    bpy.ops.object.mode_set(mode="SCULPT")
except Exception:
    bpy.ops.object.mode_set(mode="OBJECT")

path = OUT / "wren_sculpt_source.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(path))
print(f"Saved sculpt-ready Wren body: {path}")
print(f"Vertices: {len(body.data.vertices):,}; polygons: {len(body.data.polygons):,}")
