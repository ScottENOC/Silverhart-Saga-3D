#!/usr/bin/env python3
"""Render a configurable Ara character directly from repository GLBs (no Godot)."""
import json, math, sys
from pathlib import Path
import bpy, bmesh
PREVIEW_CLEARED_ACTIONS = []
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
    # A character preview should not inherit an imported animation such as "Carry idle".
    # Clear actions in this temporary Blender scene so the mesh uses its neutral rest pose.
    global PREVIEW_CLEARED_ACTIONS
    PREVIEW_CLEARED_ACTIONS = []
    if profile.get("reset_armatures_to_rest", True):
        for obj in objects:
            if obj.type == "ARMATURE" and obj.animation_data:
                action_name = obj.animation_data.action.name if obj.animation_data.action else None
                obj.animation_data_clear()
                PREVIEW_CLEARED_ACTIONS.append({"armature": obj.name, "cleared_action": action_name})
    tints = profile.get("material_tints", {})
    hidden = {x.casefold() for x in profile.get("hide_materials", [])}
    for obj in find_meshes(objects):
        if profile.get("disable_armature_modifiers", False):
            for modifier in obj.modifiers:
                if modifier.type == "ARMATURE":
                    modifier.show_viewport = False
                    modifier.show_render = False
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
    engines = {item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items}
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 720, 960
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    # Neutral studio environment with restrained illumination.
    if scene.world is None:
        scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    if background:
        background.inputs["Color"].default_value = (0.055, 0.065, 0.085, 1)
        background.inputs["Strength"].default_value = 0.28
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "Medium High Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = -0.65
    scene.view_settings.gamma = 1.0
    direction = {"front":Vector((0,-1,0)), "side":Vector((1,0,0))}[view]
    cam_data = bpy.data.cameras.new("PreviewCamera")
    cam = bpy.data.objects.new("PreviewCamera", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = centre + direction.normalized() * radius * 4.0
    cam.rotation_euler = (centre-cam.location).to_track_quat("-Z","Y").to_euler()
    # Orthographic projection avoids perspective exaggeration of hands near the lens.
    cam_data.type = "ORTHO"
    aspect = scene.render.resolution_x / scene.render.resolution_y
    cam_data.ortho_scale = radius * 4.0  # generous full-body margin; includes head and feet
    scene.camera = cam
    for name, offset, power, size in [
        ("Key",Vector((-radius,-radius*1.4,radius*1.5)),65,radius*1.35),
        ("Fill",Vector((radius*1.2,-radius,radius*0.7)),28,radius*1.2),
        ("Rim",Vector((0,radius*1.5,radius*1.3)),42,radius*1.3),
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
    # Large imported helper icospheres must not distort character framing.
    frame_meshes=[o for o in meshes if o.name.casefold() not in {"icosphere","icosphere.001"}]
    if not frame_meshes: frame_meshes=meshes
    pts=[]
    for obj in frame_meshes:
        ev=obj.evaluated_get(deps)
        for corner in ev.bound_box: pts.append(ev.matrix_world @ Vector(corner))
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    centre=(lo+hi)*0.5; radius=max((hi-lo).length*0.5,0.5)
    for view in ("front","side"): setup_render(centre,radius,output,view)
    mesh_stats=[]
    key_audit=[]
    deps=bpy.context.evaluated_depsgraph_get()
    requested=profile.get("shape_keys",{})
    for obj in meshes:
        sk=obj.data.shape_keys
        available=list(sk.key_blocks.keys())[1:] if sk else []
        matched=[]
        missing=[]
        key_ranges={}
        if sk:
            for block in sk.key_blocks:
                if block.name != "Basis":
                    key_ranges[block.name]={"min":float(block.slider_min),"max":float(block.slider_max)}
            # Measure actual evaluated vertex movement, not the static object bound_box.
            original_values={block.name:block.value for block in sk.key_blocks}
            for block in sk.key_blocks:
                if block.name != "Basis": block.value=0.0
            deps.update()
            ev=obj.evaluated_get(deps)
            base_mesh=ev.to_mesh()
            base_coords=[v.co.copy() for v in base_mesh.vertices]
            ev.to_mesh_clear()
            for key_name, value in requested.items():
                block=sk.key_blocks.get(key_name)
                if block is None:
                    missing.append(key_name)
                    key_audit.append({"object":obj.name,"key":key_name,"requested_value":float(value),"matched":False})
                    continue
                matched.append(key_name)
                block.value=float(value)
                effective_value=float(block.value)
                deps.update()
                ev=obj.evaluated_get(deps)
                test_mesh=ev.to_mesh()
                coords=[v.co.copy() for v in test_mesh.vertices]
                ev.to_mesh_clear()
                if len(coords)==len(base_coords) and coords:
                    deltas=[(a-b).length for a,b in zip(coords,base_coords)]
                    max_delta=max(deltas)
                    mean_delta=sum(deltas)/len(deltas)
                else:
                    max_delta=mean_delta=None
                key_audit.append({"object":obj.name,"key":key_name,"requested_value":float(value),
                                  "matched":True,"effective_value_after_clamp":effective_value,
                                  "slider_min":float(block.slider_min),"slider_max":float(block.slider_max),
                                  "max_vertex_delta":round(max_delta,7) if max_delta is not None else None,
                                  "mean_vertex_delta":round(mean_delta,7) if mean_delta is not None else None})
                block.value=0.0
            for block in sk.key_blocks:
                if block.name in original_values: block.value=original_values[block.name]
            deps.update()
        ev=obj.evaluated_get(deps)
        evaluated_mesh=ev.to_mesh()
        if evaluated_mesh.vertices:
            coords=[v.co for v in evaluated_mesh.vertices]
            lo_v=[min(v[i] for v in coords) for i in range(3)]
            hi_v=[max(v[i] for v in coords) for i in range(3)]
            dims=[hi_v[i]-lo_v[i] for i in range(3)]
        else:
            dims=[0.0,0.0,0.0]
        ev.to_mesh_clear()
        mesh_stats.append({"object":obj.name,"location_xyz":[round(v,5) for v in obj.matrix_world.translation],
                           "parent":obj.parent.name if obj.parent else None,
                           "vertex_count":len(obj.data.vertices),
                           "material_names":[m.name if m else None for m in obj.data.materials],
                           "evaluated_dimensions_xyz":[round(v,5) for v in dims],
                           "shape_key_ranges":key_ranges,
                           "shape_keys_available":available,"requested_keys_matched":matched,
                           "requested_keys_missing":missing})
    scene_diagnostics=[]
    for obj in bpy.context.scene.objects:
        item={"name":obj.name,"type":obj.type,
              "parent":obj.parent.name if obj.parent else None,
              "location":[round(v,6) for v in obj.location],
              "rotation_euler":[round(v,6) for v in obj.rotation_euler],
              "scale":[round(v,6) for v in obj.scale]}
        if obj.type == "MESH":
            item["vertex_groups"]=[g.name for g in obj.vertex_groups]
            item["modifiers"]=[{"name":m.name,"type":m.type,
                                "show_viewport":bool(m.show_viewport),
                                "show_render":bool(m.show_render),
                                "target":m.object.name if m.type=="ARMATURE" and m.object else None}
                               for m in obj.modifiers]
        elif obj.type == "ARMATURE":
            item["bone_count"]=len(obj.data.bones)
            item["bones"]=[{"name":b.name,"length":round(b.length,6),
                            "parent":b.parent.name if b.parent else None,
                            "pose_location":[round(v,6) for v in obj.pose.bones[b.name].location],
                            "pose_rotation_euler":[round(v,6) for v in obj.pose.bones[b.name].rotation_euler],
                            "rotation_mode":obj.pose.bones[b.name].rotation_mode}
                           for b in obj.data.bones]
            item["animation_data"]=bool(obj.animation_data and obj.animation_data.action)
            if obj.animation_data and obj.animation_data.action:
                item["action_name"]=obj.animation_data.action.name
        scene_diagnostics.append(item)
    report={"name":profile.get("name","Ara Character"),"model":profile["model"],"hair_asset":hair,
            "shape_keys_applied":profile.get("shape_keys",{}),"material_tints":profile.get("material_tints",{}),
            "mesh_count":len(meshes),"framing_objects":[o.name for o in frame_meshes],
            "mesh_stats":mesh_stats,"shape_key_vertex_audit":key_audit,"scene_diagnostics":scene_diagnostics,"animation_actions_cleared":PREVIEW_CLEARED_ACTIONS,"views":["front","side"]}
    (output/"profile_report.json").write_text(json.dumps(report,indent=2))
    print("[Character preview] rendered orthographic front and side:", output, flush=True)
if __name__=="__main__": main()
