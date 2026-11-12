#!/usr/bin/env python3
"""High-resolution, body-conforming external vulva sculpt prototype.

Creates a dense continuous surface patch sampled from Ara's actual front pelvis
surface. Anatomical relief is formed as smooth sculpt fields (paired labia
majora/minora, clitoral hood, vestibular recess and surrounding transition).
The output is a review prototype, not yet retopologised or production-approved.
"""
import argparse, json, math, os, sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def args():
    raw=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    p=argparse.ArgumentParser()
    p.add_argument("--input",required=True)
    p.add_argument("--output",required=True)
    p.add_argument("--review-dir",required=True)
    p.add_argument("--resolution",type=int,default=160)
    return p.parse_args(raw)

def bounds(obj):
    pts=[obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return Vector(tuple(min(p[i] for p in pts) for i in range(3))),Vector(tuple(max(p[i] for p in pts) for i in range(3)))

def gauss(x,z,cx,cz,sx,sz):
    return math.exp(-0.5*((x-cx)/sx)**2-0.5*((z-cz)/sz)**2)

def smoothstep(a,b,x):
    t=max(0.0,min(1.0,(x-a)/(b-a)))
    return t*t*(3.0-2.0*t)

def main():
    a=args(); os.makedirs(a.review_dir,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(a.input))
    skins=[o for o in bpy.context.scene.objects if o.type=="MESH" and any(s.material and "skin" in s.material.name.lower() for s in o.material_slots)]
    if not skins: raise RuntimeError("No Ara skin mesh/material found")
    skin=max(skins,key=lambda o:len(o.data.polygons))
    arm=next((o for o in bpy.context.scene.objects if o.type=="ARMATURE"),None)
    if arm is None: raise RuntimeError("No Ara armature found")
    material=next(s.material for s in skin.material_slots if s.material and "skin" in s.material.name.lower())
    lo,hi=bounds(skin); height=hi.z-lo.z; width=hi.x-lo.x
    aliases={"left":{"leftupleg","leftupperleg","upleg_l","upperleg_l","thigh_l","leftthigh","lthigh","thigh.l"},
             "right":{"rightupleg","rightupperleg","upleg_r","upperleg_r","thigh_r","rightthigh","rthigh","thigh.r"}}
    roots={}
    for side,names in aliases.items():
        bone=next((b for b in arm.data.bones if b.name.lower().replace(" ","").replace("-","_") in names),None)
        if bone: roots[side]=arm.matrix_world @ bone.head_local
    if len(roots)!=2: raise RuntimeError("Cannot locate paired upper-leg roots")
    hip=(roots["left"]+roots["right"])*0.5
    centre_x=hip.x
    centre_z=hip.z-height*0.032
    # A broad, shallow patch that includes the pubic and perineal transition.
    half_w=min(width*0.17,height*0.050)
    half_h=height*0.050
    res=max(96,a.resolution)
    deps=bpy.context.evaluated_depsgraph_get()
    evaluated=skin.evaluated_get(deps); mesh=evaluated.to_mesh()
    verts=[skin.matrix_world @ v.co for v in mesh.vertices]
    faces=[list(p.vertices) for p in mesh.polygons]
    tree=BVHTree.FromPolygons(verts,faces,all_triangles=False)
    inv=skin.matrix_world.inverted()
    vertices=[]; quads=[]; misses=0
    for iz in range(res+1):
        nz=iz/res
        z=centre_z-half_h+2*half_h*nz
        for ix in range(res+1):
            nx=ix/res
            x=centre_x-half_w+2*half_w*nx
            hit,normal,index,distance=tree.ray_cast(Vector((x,-3.0,z)),Vector((0,1,0)),6.0)
            if hit is None:
                misses+=1; hit=Vector((x,lo.y,z)); normal=Vector((0,-1,0))
            dx=x-centre_x; dz=z-centre_z
            # Local coordinates in metres, centred on the vulvar anatomy.
            # Positive relief moves toward the camera/front (-Y).
            # A subtle base pad blends the anatomical patch into surrounding skin.
            pad=0.0018*gauss(dx,dz,0.0,-0.003,half_w*0.68,half_h*0.72)
            # Paired, soft labia majora: fuller upper/middle thirds, tapered ends.
            left_major=0.0048*gauss(dx,dz,-0.013,-0.010,0.0105,0.025)
            right_major=0.0045*gauss(dx,dz,0.0135,-0.009,0.0100,0.024)
            # Slight lateral asymmetry is intentional; avoid a diagrammatic mirror.
            left_curve=0.0012*gauss(dx,dz,-0.018,-0.012,0.006,0.021)
            right_curve=0.0008*gauss(dx,dz,0.018,-0.008,0.006,0.019)
            # Inner labial folds, narrower and more delicate than the outer folds.
            left_minor=0.0026*gauss(dx,dz,-0.0058,-0.010,0.0038,0.018)
            right_minor=0.0023*gauss(dx,dz,0.0056,-0.011,0.0036,0.017)
            # Clitoral hood forms a short curved cap at the superior end.
            hood=0.0027*gauss(dx,dz,0.0,0.014,0.0058,0.0042)
            hood_arc=0.0010*gauss(dx,dz,0.0,0.017,0.009,0.0028)
            # Small underlying glans landmark; restrained, not a protruding knob.
            glans=0.0010*gauss(dx,dz,0.0,0.010,0.0024,0.0022)
            # Vestibular bowl and central cleft are shallow recesses, not a black line.
            vestibule=0.0018*gauss(dx,dz,0.0,-0.013,0.0055,0.010)
            cleft=0.0009*gauss(dx,dz,0.0,-0.008,0.0016,0.021)
            # Taper all relief smoothly into the surrounding sampled skin.
            edge=max(abs(dx)/half_w,abs(dz)/half_h)
            fade=1.0-smoothstep(0.70,1.0,edge)
            relief=(pad+left_major+right_major+left_curve+right_curve+
                    left_minor+right_minor+hood+hood_arc+glans-vestibule-cleft)*fade
            point=hit+normal.normalized()*(0.0007+relief)
            vertices.append(tuple(point))
    evaluated.to_mesh_clear()
    for iz in range(res):
        for ix in range(res):
            v=iz*(res+1)+ix
            quads.append((v,v+1,v+res+2,v+res+1))
    data=bpy.data.meshes.new("FemaleVulva_HighResolution_SculptMesh")
    data.from_pydata(vertices,[],quads); data.materials.append(material); data.update()
    patch=bpy.data.objects.new("Female external anatomy · high-resolution sculpt prototype",data)
    bpy.context.collection.objects.link(patch)
    for p in data.polygons: p.use_smooth=True
    # Bind the patch to the pelvis for a first-pass deformation test.
    group=patch.vertex_groups.new(name="Hips" if arm.data.bones.get("Hips") else next((b.name for b in arm.data.bones if "hip" in b.name.lower() or "pelvis" in b.name.lower()),arm.data.bones[0].name))
    group.add(list(range(len(vertices))),1.0,"REPLACE")
    patch.parent=arm; patch.matrix_parent_inverse=arm.matrix_world.inverted()
    mod=patch.modifiers.new("Ara pelvis deformation","ARMATURE"); mod.object=arm
    patch["anatomy_method"]="dense_body_conforming_surface_relief"
    patch["anatomy_features"]="labia_majora,labia_minora,clitoral_hood,clitoral_glans_landmark,vestibular_recess,perineal_transition"
    patch["review_status"]="high_resolution_sculpt_prototype_requires_visual_review_and_retopology"
    patch["grid_resolution"]=res
    # Export a standalone unrigged high-res sculpt patch for independent review.
    patch.parent=None; patch.modifiers.clear()
    bpy.ops.object.select_all(action="DESELECT"); patch.select_set(True); bpy.context.view_layer.objects.active=patch
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(a.output),export_format="GLB",use_selection=True,export_apply=False)
    # Restore the patch to the review character and render multi-angle closeups.
    patch.parent=arm; patch.parent_type="OBJECT"; patch.matrix_parent_inverse=arm.matrix_world.inverted()
    mod=patch.modifiers.new("Ara pelvis deformation","ARMATURE"); mod.object=arm
    scene=bpy.context.scene
    scene.render.engine="BLENDER_EEVEE_NEXT"; scene.render.resolution_x=1000; scene.render.resolution_y=1000
    scene.render.resolution_percentage=100; scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="Standard"; scene.world.color=(0.18,0.18,0.18)
    scene.render.film_transparent=False
    target=Vector((centre_x,lo.y+0.01,centre_z))
    for idx,(name,offset) in enumerate((("front",Vector((0,-0.50,0.015))),("side",Vector((0.48,-0.12,0.015))),("three_quarter",Vector((0.38,-0.40,0.02)) ))):
        cd=bpy.data.cameras.new("FemaleSculptReviewCamera"); cam=bpy.data.objects.new("FemaleSculptReviewCamera",cd); scene.collection.objects.link(cam)
        cam.location=target+offset; cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
        cd.type="ORTHO"; cd.ortho_scale=max(half_w*3.3,0.18); scene.camera=cam
        ld=bpy.data.lights.new("FemaleSculptReviewKey","AREA"); light=bpy.data.objects.new("FemaleSculptReviewKey",ld); scene.collection.objects.link(light)
        light.location=target+Vector((-0.25,-0.35,0.32)); ld.energy=500; ld.shape="DISK"; ld.size=0.3
        scene.render.filepath=os.path.join(a.review_dir,f"female_vulva_sculpt_{name}.png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam,do_unlink=True); bpy.data.objects.remove(light,do_unlink=True)
    report={"source":os.path.abspath(a.input),"output":os.path.abspath(a.output),
            "grid_resolution":res,"vertices":len(vertices),"faces":len(quads),
            "raycast_misses":misses,"features":patch["anatomy_features"],
            "note":"Standalone high-resolution relief sculpt prototype; not yet retopologised or accepted."}
    with open(os.path.join(a.review_dir,"female_vulva_sculpt_report.json"),"w") as f: json.dump(report,f,indent=2)
    print(json.dumps(report,indent=2))
if __name__=="__main__": main()
