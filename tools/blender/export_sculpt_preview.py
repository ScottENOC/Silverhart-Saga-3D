"""Export the isolated sculpt source as a neutral clay GLB for the phone viewer."""
import bpy
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = root / "art" / "characters" / "wren" / "wren_sculpt_source.blend"
target = root / "art" / "characters" / "wren" / "wren_sculpt_source.glb"
if not source.exists():
    raise RuntimeError(f"Missing sculpt source: {source}")

bpy.ops.wm.open_mainfile(filepath=str(source))
body = bpy.data.objects.get("Wren_Sculpt_Body")
if body is None or body.type != "MESH":
    raise RuntimeError("Wren_Sculpt_Body mesh not found in sculpt source")

# A neutral clay material makes surface shape easier to judge than skin shading.
mat = bpy.data.materials.get("Sculpt_Clay")
if mat is None:
    mat = bpy.data.materials.new("Sculpt_Clay")
mat.diffuse_color = (0.48, 0.43, 0.37, 1.0)
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs["Base Color"].default_value = (0.48, 0.43, 0.37, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.88
body.data.materials.clear()
body.data.materials.append(mat)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.export_scene.gltf(
    filepath=str(target),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
)
if not target.exists() or target.stat().st_size < 1000:
    raise RuntimeError("Sculpt source GLB export failed")
print(f"Exported sculpt preview: {target} ({target.stat().st_size:,} bytes)")
