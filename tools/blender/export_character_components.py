"""Export modular GLB components from wren_blockout.blend.

Run after build_wren_blockout.py:
blender --background art/characters/wren/wren_blockout.blend --python tools/blender/export_character_components.py

Mesh prefixes define visual slots:
Body_/Face_, Hair_, Weapon_, Garment_<slot>_, Armour_<slot>_.
Each exported component includes the identical armature so the Godot assembler
can rebind its skinned meshes to the body component's shared Skeleton3D.
"""
import bpy
from pathlib import Path

root = Path(__file__).resolve().parents[2]
out = root / "art" / "characters" / "wren"
out.mkdir(parents=True, exist_ok=True)

armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
if len(armatures) != 1:
    raise RuntimeError(f"Expected one shared armature, found {len(armatures)}")
armature = armatures[0]

def export_component(filename: str, prefixes: tuple[str, ...]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    count = 0
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj.name.startswith(prefixes):
            obj.select_set(True)
            count += 1
    if count == 0:
        print(f"Skipping {filename}: no meshes for prefixes {prefixes}")
        return
    bpy.context.view_layer.objects.active = armature
    path = out / filename
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=False,
    )
    print(f"Exported {count} meshes: {path}")

export_component("body.glb", ("Body_", "Face_", "Hand_"))
export_component("hair_braid.glb", ("Hair_",))
export_component("weapon_sword.glb", ("Weapon_",))
# These slot exports are automatically populated when corresponding garment
# and armour meshes are authored in Blender.
export_component("garment_torso_base.glb", ("Garment_Torso_",))
export_component("garment_legs_base.glb", ("Garment_Legs_",))
export_component("armour_torso_base.glb", ("Armour_Torso_",))
export_component("armour_legs_base.glb", ("Armour_Legs_",))
