#!/usr/bin/env python3
"""Review-only male anatomy morph + pose experiment.

Imports the unchanged erect-reference GLB, adds a real mesh shape key to the
Ara skin mesh, and combines that morph with the existing AnatomyRoot/Mid/Tip
bone animation. The source GLB is never modified.
"""
import argparse, json, os
import bpy
from mathutils import Vector

def args():
    raw = __import__("sys").argv
    raw = raw[raw.index("--")+1:] if "--" in raw else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--review-dir", required=True)
    return p.parse_args(raw)

def find_skin():
    candidates=[]
    for obj in bpy.context.scene.objects:
        if obj.type=="MESH" and any(s.material and "skin" in s.material.name.lower() for s in obj.material_slots):
            candidates.append(obj)
    if not candidates: raise RuntimeError("No Ara skin mesh found")
    return max(candidates,key=lambda o:len(o.data.polygons))

def main():
    a=args(); os.makedirs(a.review_dir,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(a.input))
    skin=find_skin()
    arm=next((o for o in bpy.context.scene.objects if o.type=="ARMATURE"),None)
    if arm is None: raise RuntimeError("No Ara armature in erect reference GLB")
    names=("AnatomyRoot","AnatomyMid","AnatomyTip")
    groups={n:skin.vertex_groups.get(n) for n in names}
    if any(g is None for g in groups.values()):
        raise RuntimeError("Erect reference has no dedicated anatomy vertex groups")
    bones=[arm.data.bones.get(n) for n in names]
    if any(b is None for b in bones): raise RuntimeError("Dedicated anatomy bones missing")
    base=arm.matrix_world @ bones[0].head_local
    tip=arm.matrix_world @ bones[-1].tail_local
    axis=(tip-base).normalized()
    inv=skin.matrix_world.inverted()
    group_ids={g.index for g in groups.values()}
    if skin.data.shape_keys is None:
        skin.shape_key_add(name="Basis",from_mix=False)
    keys=skin.data.shape_keys.key_blocks
    if keys.get("FlaccidVolume") is not None:
        raise RuntimeError("FlaccidVolume shape key already exists; refusing duplicate")
    morph=skin.shape_key_add(name="FlaccidVolume",from_mix=False)
    affected=0; min_along=1e9; max_along=-1e9
    # Preserve the accepted erect mesh as Basis. The morph compresses length
    # while retaining shaft girth, and slightly softens the distal profile.
    for v in skin.data.vertices:
        if not any(g.group in group_ids and g.weight>0.05 for g in v.groups):
            continue
        p=skin.matrix_world @ v.co
        rel=p-base
        along=rel.dot(axis)
        radial=rel-axis*along
        if along < -0.004 or along > (tip-base).length*1.15:
            continue
        t=max(0.0,min(1.0,along/max((tip-base).length,1e-6)))
        # A non-uniform longitudinal compression avoids simply scaling the
        # erect shape into a miniature. Radial fullness is deliberately kept.
        compressed=along*(0.54 + 0.035*t)
        radial_scale=1.045 - 0.035*t
        target=base+axis*compressed+radial*radial_scale
        morph.data[v.index].co=inv @ target
        affected+=1; min_along=min(min_along,along); max_along=max(max_along,along)
    if affected<150: raise RuntimeError(f"Only {affected} anatomy vertices were affected")
    # Morph is animated on the mesh datablock; the existing rig action supplies
    # the root hang/rotation. These are deliberately independent controls.
    shape_data=skin.data.shape_keys
    shape_data.animation_data_create()
    action=bpy.data.actions.new("MaleMorphPoseTest_ShapeKeys")
    shape_data.animation_data.action=action
    for frame,value in ((1,0.0),(24,1.0)):
        morph.value=value
        morph.keyframe_insert(data_path="value",frame=frame,group="Anatomy Morph")
    scene=bpy.context.scene
    scene.frame_start=1; scene.frame_end=24
    # Verify the rig animation exists; don't silently substitute a static pose.
    has_rig_animation = (arm.animation_data is not None and
                         (arm.animation_data.action is not None or len(arm.animation_data.nla_tracks) > 0))
    if not has_rig_animation:
        raise RuntimeError("No imported AnatomyRoot/Mid/Tip pose animation to combine with morph")
    for frame in (1,8,16,24):
        scene.frame_set(frame); bpy.context.view_layer.update()
        # Render a pelvis close-up from front and three-quarter angles.
        points=[skin.matrix_world @ Vector(c) for c in skin.bound_box]
        lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
        hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
        height=hi.z-lo.z
        root=arm.matrix_world @ arm.data.bones["AnatomyRoot"].head_local
        target=Vector((root.x,root.y,root.z-height*0.005))
        for view,offset in (("front",Vector((0,-0.55,0.015))),("three_quarter",Vector((0.40,-0.45,0.02)))):
            camdata=bpy.data.cameras.new("MorphReviewCamera")
            cam=bpy.data.objects.new("MorphReviewCamera",camdata); scene.collection.objects.link(cam)
            cam.location=target+offset
            cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
            camdata.type="ORTHO"; camdata.ortho_scale=max(height*0.18,0.12)
            scene.camera=cam
            # Use a neutral studio setup.
            scene.render.engine="BLENDER_EEVEE_NEXT"
            scene.render.resolution_x=900; scene.render.resolution_y=900
            scene.render.resolution_percentage=100
            scene.render.image_settings.file_format="PNG"
            scene.world.color=(0.18,0.18,0.18)
            scene.view_settings.view_transform="Standard"
            scene.render.film_transparent=False
            ld=bpy.data.lights.new("MorphReviewKey","AREA"); lo_obj=bpy.data.objects.new("MorphReviewKey",ld); scene.collection.objects.link(lo_obj)
            lo_obj.location=target+Vector((-0.25,-0.35,0.35)); ld.energy=450; ld.shape="DISK"; ld.size=0.3
            scene.render.filepath=os.path.join(a.review_dir,f"male_morph_frame_{frame:02d}_{view}.png")
            bpy.ops.render.render(write_still=True)
            bpy.data.objects.remove(cam,do_unlink=True); bpy.data.objects.remove(lo_obj,do_unlink=True)
    scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    for o in scene.objects:
        if o.type in {"MESH","ARMATURE"}: o.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(a.output),export_format="GLB",
                              use_selection=True,export_animations=True,export_morph=True)
    report={"source":os.path.abspath(a.input),"output":os.path.abspath(a.output),
            "mesh":skin.name,"morph":"FlaccidVolume","morph_vertex_count":affected,
            "pose_bones":list(names),"frames":{"erect":1,"intermediate_1":8,"intermediate_2":16,"flaccid":24},
            "basis_preserves_accepted_erect_geometry":True,
            "note":"Review-only comparison asset; not a production replacement."}
    with open(os.path.join(a.review_dir,"male_morph_pose_report.json"),"w") as f: json.dump(report,f,indent=2)
    print(json.dumps(report,indent=2))
if __name__=="__main__": main()
