#!/usr/bin/env python3
"""Render a configurable Ara character directly from repository GLBs (no Godot)."""
import json, math, sys
from pathlib import Path
import bpy, bmesh
from mathutils import Vector

def args():
    a = sys.argv[sys.argv.index("--") + 1:]
    if len(a) != 3: raise SystemExit("usage: blender --background --python render_character_preview.py -- CONFIG OUTPUT_DIR ROOT")
    return Path(a[0]), Path(a[1]), Path(a[2])

def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def import_glb(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.context.scene.objects if o not in before]

def find_meshes(objects):
    return [o for o in objects if o.type == "MESH"]

def apply_profile(objects, profile):
    tints = profile.get("material_tints", {})
    hidden = {x.casefold() for x in profile.get("hide_materials", [])}
    for obj in find_meshes(objects):
        if obj.data.shape_keys:
            for key, value in profile.get("shape_keys", {}).items():
                block = obj.data.shape_keys.key_blocks.get(key)
                if block: block.value = float(value)
        for slot in obj.material_slots:
            mat = slot.material
            if not mat: continue
            name = mat.name.casefold()
            for token, colour in tints.items():
                if token.casefold() in name:
                    c = colour.lstrip("#")
                    rgb = tuple(int(c[i:i+2],16)/255 for i in (0,2,4))
                    if mat.use_nodes and mat.node_tree:
                        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                        if bsdf:
                            bsdf.inputs["Base Color"].default_value = (*rgb, 1)
                    mat.diffuse_color = (*rgb, 1)
        if hidden:
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            remove = []
            for face in bm.faces:
                idx = face.material_index
                material = obj.data.materials[idx] if idx < len(obj.data.materials) else None
                if material and any(token in material.name.casefold() for token in hidden):
                    remove.append(face)
            if remove:
                bmesh.ops.delete(bm, geom=remove, context="FACES")
                loose = [v for v in bm.verts if not v.link_faces]
                if loose: bmesh.ops.delete(bm, geom=loose, context="VERTS")
                bm.to_mesh(obj.data)
                obj.data.update()
            bm.free()

def setup_render(centre, radius, out, view):
    scene = bpy.context.scene
    # Ubuntu's Blender 5.0 package exposes EEVEE under BLENDER_EEVEE.
    engines = {item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items}
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 720, 960
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.055, 0.065, 0.085)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    direction = {"front":Vector((0,-1,0.08)), "side":Vector((1,0,0.08)), "rear":Vector((0,1,0.08))}[view]
    cam_data = bpy.data.cameras.new("PreviewCamera")
    cam = bpy.data.objects.new("PreviewCamera", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = centre + direction.normalized() * radius * 3.0
    cam.rotation_euler = (centre-cam.location).to_track_quat("-Z","Y").to_euler()
    cam_data.lens = 55
    scene.camera = cam
    for name, offset, power, size in [
        ("Key",Vector((-radius,-radius*1.4,radius*1.6)),1700,radius*1.2),
        ("Fill",Vector((radius*1.2,-radius,radius*0.7)),900,radius),
        ("Rim",Vector((0,radius*1.5,radius*1.3)),1400,radius),
    ]:
        ld=bpy.data.lights.new(name,"AREA"); lo=bpy.data.objects.new(name,ld); bpy.context.collection.objects.link(lo)
        lo.location=centre+offset; ld.energy=power; ld.shape="DISK"; ld.size=size
    scene.render.filepath=str(out / (view+".png"))
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam,do_unlink=True)
    for o in [o for o in scene.objects if o.type=="LIGHT"]:
        bpy.data.objects.remove(o,do_unlink=True)

def main():
    config_path, output, root = args()
    profile=json.loads(config_path.read_text())
    clear(); output.mkdir(parents=True,exist_ok=True)
    model=root/profile["model"]
    if not model.is_file(): raise FileNotFoundError(model)
    objects=import_glb(model)
    hair=profile.get("hair_asset","")
    if hair:
        hair_path=root/hair
        if not hair_path.is_file(): raise FileNotFoundError(hair_path)
        objects += import_glb(hair_path)
    apply_profile(objects,profile)
    meshes=find_meshes(objects)
    if not meshes: raise RuntimeError("No mesh objects imported")
    deps=bpy.context.evaluated_depsgraph_get()
    pts=[]
    for obj in meshes:
        ev=obj.evaluated_get(deps)
        for corner in ev.bound_box: pts.append(ev.matrix_world @ Vector(corner))
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    centre=(lo+hi)*0.5; radius=max((hi-lo).length*0.5,0.5)
    for view in ("front","side","rear"): setup_render(centre,radius,output,view)
    mesh_stats=[]
    for obj in meshes:
        world_points=[obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
        dims=[max(p[i] for p in world_points)-min(p[i] for p in world_points) for i in range(3)]
        key_names=list(obj.data.shape_keys.key_blocks.keys())[1:] if obj.data.shape_keys else []
        mesh_stats.append({"object":obj.name,"dimensions_xyz":[round(v,5) for v in dims],
                           "shape_keys_available":key_names})
    report={"name":profile.get("name","Ara Character"),"model":profile["model"],"hair_asset":hair,
            "shape_keys_applied":profile.get("shape_keys",{}),"material_tints":profile.get("material_tints",{}),
            "mesh_count":len(meshes),"mesh_stats":mesh_stats,"views":["front","side","rear"]}
    (output/"profile_report.json").write_text(json.dumps(report,indent=2))
    print("[Character preview] rendered front, side and rear:", output, flush=True)
if __name__=="__main__": main()
