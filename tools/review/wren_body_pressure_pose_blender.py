import bpy
import json
import math
import os
import re
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT_DIR = bpy.path.abspath("//build/wren-body-pressure-pose")
WREN_GLB = bpy.path.abspath("//build/wren-native/Wren.glb")
os.makedirs(OUT_DIR, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def import_wren(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    imported = list(set(bpy.context.scene.objects) - before)
    root = bpy.data.objects.new("Wren_PoseRoot", None)
    bpy.context.collection.objects.link(root)
    for obj in imported:
        if obj.parent is None or obj.parent not in imported:
            world = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_world = world
    armatures = [o for o in imported if o.type == "ARMATURE"]
    if not armatures:
        raise RuntimeError("Native Wren GLB contains no armature")
    arm = max(armatures, key=lambda o: len(o.data.bones))
    meshes = [o for o in imported if o.type == "MESH" and not o.name.lower().startswith("icosphere")]
    if not meshes:
        raise RuntimeError("Native Wren GLB contains no visible mesh")
    return {"root":root, "arm":arm, "meshes":meshes, "objects":imported}

def bone_name(actor, aliases):
    bones = actor["arm"].data.bones
    normal = {b.name.lower().replace("_","").replace("-","").replace(" ",""):b.name for b in bones}
    for alias in aliases:
        key=alias.lower().replace("_","").replace("-","").replace(" ","")
        if key in normal: return normal[key]
    for alias in aliases:
        key=alias.lower().replace("_","").replace("-","").replace(" ","")
        for norm,actual in normal.items():
            if norm.endswith(key) or key.endswith(norm): return actual
    return None

def add_target(name, point):
    obj=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type="SPHERE"
    obj.empty_display_size=0.025
    obj.location=point
    return obj

def add_arm_ik(actor, side, target, pole_point, report):
    upper_alias=["LeftArm","LeftUpperArm","UpperArm_L"] if side=="left" else ["RightArm","RightUpperArm","UpperArm_R"]
    fore_alias=["LeftForeArm","LeftLowerArm","ForeArm_L"] if side=="left" else ["RightForeArm","RightLowerArm","ForeArm_R"]
    hand_alias=["LeftHand","Hand_L"] if side=="left" else ["RightHand","Hand_R"]
    # Resolve each segment from its alias set; variants are alternatives, not required bones.
    names=[bone_name(actor,upper_alias), bone_name(actor,fore_alias), bone_name(actor,hand_alias)]
    if not all(names):
        report[side+"_ik"]={"created":False,"resolved_chain":names}
        return
    hand=actor["arm"].pose.bones[names[-1]]
    con=hand.constraints.new("IK")
    con.name="Wren_"+side+"_contact_IK"
    con.target=target
    con.chain_count=3
    con.use_stretch=False
    pole=add_target("Wren_"+side+"_elbow_pole",pole_point)
    con.pole_target=pole
    con.pole_angle=math.radians(-90)
    report[side+"_ik"]={"created":True,"chain":names,"target_world":[round(v,4) for v in target.location]}

def bounds(actor):
    deps=bpy.context.evaluated_depsgraph_get()
    points=[]
    for source in actor["meshes"]:
        ev=source.evaluated_get(deps)
        points.extend(ev.matrix_world @ Vector(c) for c in ev.bound_box)
    return (Vector(tuple(min(p[i] for p in points) for i in range(3))),
            Vector(tuple(max(p[i] for p in points) for i in range(3))))

def nearest_surface(actor, point):
    deps=bpy.context.evaluated_depsgraph_get()
    best=None
    for source in actor["meshes"]:
        ev=source.evaluated_get(deps)
        tree=BVHTree.FromObject(ev,deps)
        if tree is None: continue
        hit=tree.find_nearest(ev.matrix_world.inverted() @ point)
        if hit and hit[0] is not None:
            world=ev.matrix_world @ hit[0]
            gap=(world-point).length
            if best is None or gap<best["gap_m"]:
                normal_world = source.matrix_world.to_3x3().inverted().transposed() @ hit[1]
            best={"gap_m":round(gap,5),"mesh":source.name,
                  "surface_point_world":[round(v,5) for v in world],
                  "surface_normal_world":[round(v,5) for v in normal_world.normalized()]}
    return best

def hand_position(actor, side):
    name=bone_name(actor,["LeftHand","Hand_L"] if side=="left" else ["RightHand","Hand_R"])
    if not name:return None
    deps=bpy.context.evaluated_depsgraph_get()
    arm=actor["arm"].evaluated_get(deps)
    return arm.matrix_world @ arm.pose.bones[name].tail

def finger_inventory(actor):
    arm=actor["arm"]
    names=[]
    for bone in arm.data.bones:
        n=bone.name.lower()
        if any(k in n for k in ("thumb","index","middle","ring","pinky","little")):
            names.append(bone.name)
    return names

def pressure_shape_inventory(actor):
    found=[]
    for obj in actor["meshes"]:
        keys=obj.data.shape_keys
        if not keys: continue
        for key in keys.key_blocks:
            if key.name.lower().startswith("pressure_"):
                found.append({"mesh":obj.name,"shape":key.name,"value":round(float(key.value),4)})
    return found

def author_pressure_shapes(actor, surface_centres, report):
    definitions = [
        ("breast_left", surface_centres["breast_left"], Vector((0.105,0.095,0.090)), 0.032),
        ("breast_right", surface_centres["breast_right"], Vector((0.105,0.095,0.090)), 0.032),
        ("hip_left", surface_centres["hip_left"], Vector((0.115,0.090,0.115)), 0.022),
        ("hip_right", surface_centres["hip_right"], Vector((0.115,0.090,0.115)), 0.022),
    ]
    authored = []
    for source in actor["meshes"]:
        if source.data.shape_keys is None:
            source.shape_key_add(name="Basis", from_mix=False)
        basis = source.data.shape_keys.key_blocks[0]
        inverse_linear = source.matrix_world.to_3x3().inverted()
        normal_matrix = inverse_linear.transposed()
        for region_id, centre, radii, max_depth in definitions:
            key_name = "Pressure_" + region_id
            if source.data.shape_keys.key_blocks.get(key_name) is not None:
                continue
            key = source.shape_key_add(name=key_name, from_mix=False)
            affected = 0
            maximum_delta = 0.0
            for index, vertex in enumerate(source.data.vertices):
                world_position = source.matrix_world @ vertex.co
                offset = world_position - centre
                normalized_distance = ((offset.x / radii.x) ** 2
                    + (offset.y / radii.y) ** 2
                    + (offset.z / radii.z) ** 2)
                if normalized_distance >= 1.0:
                    continue
                weight = (1.0 - normalized_distance) ** 2
                normal_world = normal_matrix @ vertex.normal
                if normal_world.length_squared < 0.000001:
                    continue
                normal_world.normalize()
                world_delta = -normal_world * (max_depth * weight)
                local_delta = inverse_linear @ world_delta
                key.data[index].co = basis.data[index].co + local_delta
                affected += 1
                maximum_delta = max(maximum_delta, world_delta.length)
            key.value = 0.0
            authored.append({"mesh": source.name, "shape": key_name,
                "region_id": region_id, "affected_vertices": affected,
                "max_displacement_m": round(maximum_delta, 5),
                "profile_max_compression_m": max_depth})
    report["authored_pressure_shapes"] = authored
    return authored

def render_pressure_preview(actor, output_name, active_regions, report):
    for source in actor["meshes"]:
        keys = source.data.shape_keys
        if keys is None:
            continue
        for key in keys.key_blocks:
            if key.name.lower().startswith("pressure_"):
                key.value = 1.0 if key.name.lower() in active_regions else 0.0
    bpy.context.view_layer.update()
    scene = bpy.context.scene
    scene.render.filepath = os.path.join(OUT_DIR, output_name)
    bpy.ops.render.render(write_still=True)
    rendered = os.path.exists(scene.render.filepath)
    for source in actor["meshes"]:
        keys = source.data.shape_keys
        if keys is None:
            continue
        for key in keys.key_blocks:
            if key.name.lower().startswith("pressure_"):
                key.value = 0.0
    bpy.context.view_layer.update()
    report["pressure_preview"] = {"file": output_name,
        "active_regions": sorted(active_regions), "rendered": rendered}
    return rendered

def world_bone(actor, aliases):
    name=bone_name(actor,aliases)
    if not name:return None
    deps=bpy.context.evaluated_depsgraph_get()
    arm=actor["arm"].evaluated_get(deps)
    pb=arm.pose.bones[name]
    return {"bone":name,"head":[round(v,5) for v in arm.matrix_world @ pb.head],
            "tail":[round(v,5) for v in arm.matrix_world @ pb.tail]}

def render_scene(actor, lo, hi):
    centre=(lo+hi)*0.5
    extent=hi-lo
    bpy.ops.object.camera_add(location=centre+Vector((1.7,-3.4,0.35)))
    cam=bpy.context.object
    cam.rotation_euler=(centre-cam.location).to_track_quat("-Z","Y").to_euler()
    cam.data.type="ORTHO"
    cam.data.ortho_scale=max(2.2,extent.length*1.15)
    bpy.context.scene.camera=cam
    bpy.ops.object.light_add(type="AREA",location=centre+Vector((-2.0,-2.5,2.5)))
    bpy.context.object.data.energy=500
    bpy.context.object.data.size=3
    bpy.ops.object.light_add(type="AREA",location=centre+Vector((2.5,1.0,1.8)))
    bpy.context.object.data.energy=300
    bpy.context.object.data.size=3
    scene=bpy.context.scene
    engines={e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    scene.render.engine=next((e for e in ("BLENDER_EEVEE_NEXT","BLENDER_EEVEE","BLENDER_WORKBENCH") if e in engines))
    scene.render.resolution_x=1200
    scene.render.resolution_y=1200
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=os.path.join(OUT_DIR,"wren-body-pressure-preview.png")
    bpy.ops.render.render(write_still=True)

def main():
    if not os.path.exists(WREN_GLB): raise RuntimeError("Native Wren GLB missing: "+WREN_GLB)
    actor=import_wren(WREN_GLB)
    bpy.context.view_layer.update()
    lo,hi=bounds(actor)
    actor["root"].location.z-=lo.z
    bpy.context.view_layer.update()
    lo,hi=bounds(actor)
    width=hi.x-lo.x
    depth=hi.y-lo.y
    height=hi.z-lo.z
    centre=(lo+hi)*0.5

    # Imported native Ara Wren faces -Y in this Blender scene. Contact targets
    # are placed from her measured bounds, then checked against the evaluated mesh.
    left_breast=Vector((centre.x+width*0.14,lo.y+depth*0.13,lo.z+height*0.665))
    right_hip=Vector((centre.x-width*0.22,lo.y+depth*0.25,lo.z+height*0.56))
    left_target=add_target("Left_hand_contact_target_breast",left_breast)
    right_target=add_target("Right_hand_contact_target_hip",right_hip)

    left_breast_surface = nearest_surface(actor, left_breast)
    right_hip_surface = nearest_surface(actor, right_hip)
    mirrored_breast_surface = nearest_surface(actor, Vector((-left_breast.x,left_breast.y,left_breast.z)))
    mirrored_hip_surface = nearest_surface(actor, Vector((-right_hip.x,right_hip.y,right_hip.z)))
    surface_centres = {
        "breast_left": Vector(left_breast_surface["surface_point_world"]),
        "breast_right": Vector(mirrored_breast_surface["surface_point_world"]),
        "hip_left": Vector(mirrored_hip_surface["surface_point_world"]),
        "hip_right": Vector(right_hip_surface["surface_point_world"])
    }

    report={"scene":"Wren only: breast and hip hand-contact deformation test",
            "world_axes":{"up":"Z","front":"-Y","basis":"Imported mesh bounds and facing convention; verify in preview"},
            "body_bounds":{"min":[round(v,5) for v in lo],"max":[round(v,5) for v in hi]},
            "targets":{"left_hand_breast":[round(v,5) for v in left_breast],
                       "right_hand_hip":[round(v,5) for v in right_hip]},
            "ik":{}}
    # Left arm: upper arm reaches horizontally out from torso; pole is lateral
    # to keep the elbow bend fully folded toward the chest contact target.
    add_arm_ik(actor,"left",left_target,
               Vector((centre.x+width*0.43,centre.y,lo.z+height*0.79)),report["ik"])
    # Right arm: shoulder drops and abducts; elbow pole stays outside the hip
    # so the forearm folds inward to the palm-on-hip target.
    add_arm_ik(actor,"right",right_target,
               Vector((centre.x-width*0.42,centre.y,lo.z+height*0.68)),report["ik"])

    bpy.context.view_layer.update()
    for _ in range(5): bpy.context.view_layer.update()
    authored_shapes = author_pressure_shapes(actor, surface_centres, report)
    report["bones"]={
        "left_shoulder":world_bone(actor,["LeftShoulder","Shoulder_L"]),
        "left_upper_arm":world_bone(actor,["LeftArm","LeftUpperArm","UpperArm_L"]),
        "left_forearm":world_bone(actor,["LeftForeArm","LeftLowerArm","ForeArm_L"]),
        "left_hand":world_bone(actor,["LeftHand","Hand_L"]),
        "right_shoulder":world_bone(actor,["RightShoulder","Shoulder_R"]),
        "right_upper_arm":world_bone(actor,["RightArm","RightUpperArm","UpperArm_R"]),
        "right_forearm":world_bone(actor,["RightForeArm","RightLowerArm","ForeArm_R"]),
        "right_hand":world_bone(actor,["RightHand","Hand_R"])}
    report["hand_surface_gaps"]={
        "left_breast":nearest_surface(actor,left_breast),
        "right_hip":nearest_surface(actor,right_hip)}
    report["hand_target_errors"]={}
    for side,target in (("left",left_target),("right",right_target)):
        p=hand_position(actor,side)
        report["hand_target_errors"][side]=None if p is None else round((p-target.location).length,5)
    report["finger_bones"]=finger_inventory(actor)
    report["pressure_blend_shapes"]=pressure_shape_inventory(actor)
    report["deformation_status"]={
        "pressure_shapes_found":len(report["pressure_blend_shapes"]),
        "pressure_solver_applied":False,
        "finger_contact_clamp_applied":False,
        "note":"This first Wren-only pass isolates pose and audits the actual native mesh. The Godot pressure controller needs Pressure_<region> blend shapes on the native body mesh; no deformation is claimed unless those shapes are present and driven by the controller."}
    bpy.context.view_layer.update()
    lo,hi=bounds(actor)
    render_scene(actor,lo,hi)
    pressure_preview_rendered = render_pressure_preview(
        actor, "wren-body-pressure-compressed-preview.png",
        {"pressure_breast_left", "pressure_hip_right"}, report
    )
    # Export evaluated posed meshes for a phone-friendly static review.
    exportables=[]
    collection=bpy.data.collections.new("WrenStaticPose")
    bpy.context.scene.collection.children.link(collection)
    for source in actor["meshes"]:
        dup=source.copy(); dup.data=source.data.copy()
        collection.objects.link(dup); dup.matrix_world=source.matrix_world.copy()
        bpy.ops.object.select_all(action="DESELECT")
        dup.select_set(True); bpy.context.view_layer.objects.active=dup
        bpy.ops.object.convert(target="MESH")
        baked=bpy.context.object
        baked.parent=None; baked.matrix_world=source.matrix_world.copy()
        baked.modifiers.clear(); baked.vertex_groups.clear()
        exportables.append(baked)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in exportables: obj.select_set(True)
    bpy.context.view_layer.objects.active=exportables[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR,"wren-body-pressure-pose.glb"),
        export_format="GLB",use_selection=True,export_animations=False,export_skins=False,
        export_draco_mesh_compression_enable=False)
    report["validation"]={"wren_only":True,"both_arm_ik_created":all(v.get("created",False) for v in report["ik"].values()),
        "preview_rendered":os.path.exists(os.path.join(OUT_DIR,"wren-body-pressure-preview.png")),
        "posed_glb_exported":os.path.exists(os.path.join(OUT_DIR,"wren-body-pressure-pose.glb")),
        "surface_contact_measured":all(v is not None for v in report["hand_surface_gaps"].values()),
        "pressure_shapes_authored":len(authored_shapes) >= 4 and all(x["affected_vertices"] > 0 for x in authored_shapes),
        "pressure_compressed_preview_rendered":pressure_preview_rendered}
    with open(os.path.join(OUT_DIR,"wren-body-pressure-report.json"),"w",encoding="utf-8") as f: json.dump(report,f,indent=2)
    print("WREN_BODY_PRESSURE_REPORT="+json.dumps(report))

if __name__=="__main__": main()
