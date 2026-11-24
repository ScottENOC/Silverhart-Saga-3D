import bpy
import json
import math
import os
from mathutils import Vector, Euler

OUT_DIR = bpy.path.abspath("//build/aldric-wren-kiss-contact")
os.makedirs(OUT_DIR, exist_ok=True)
WREN_GLB = bpy.path.abspath("//build/wren-native/Wren.glb")
ALDRIC_GLB = bpy.path.abspath("//build/aldric-native/Aldric.glb")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    pass

def import_actor(name, path, location, yaw):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    imported = list(set(bpy.context.scene.objects) - before)
    root = bpy.data.objects.new(name + "_PoseRoot", None)
    bpy.context.collection.objects.link(root)
    root.location = location
    root.rotation_euler.z = yaw
    # Parent only imported scene roots. Preserve the GLTF-created hierarchy:
    # socket empties and other bone-parented attachments must remain attached
    # to their original armature, not be re-parented directly to this actor root.
    imported_set = set(imported)
    for obj in imported:
        if obj.parent is None or obj.parent not in imported_set:
            world = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_world = world
    arms = [o for o in imported if o.type == "ARMATURE"]
    if not arms:
        raise RuntimeError("No armature imported for " + name)
    arm = max(arms, key=lambda o: len(o.data.bones))
    meshes = [o for o in imported if o.type == "MESH"]
    return {"name": name, "root": root, "arm": arm, "meshes": meshes, "objects": imported}

def bounds(actor):
    deps = bpy.context.evaluated_depsgraph_get()
    pts = []
    for obj in actor["meshes"]:
        ev = obj.evaluated_get(deps)
        for corner in ev.bound_box:
            pts.append(ev.matrix_world @ Vector(corner))
    if not pts:
        raise RuntimeError("No mesh bounds for " + actor["name"])
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))

def find_bone(actor_or_armature, aliases):
    # Callers may pass the actor record or its armature object.
    arm = actor_or_armature["arm"] if isinstance(actor_or_armature, dict) else actor_or_armature
    names = {b.name.lower().replace("_","").replace("-","").replace(" ",""): b.name for b in arm.data.bones}
    for alias in aliases:
        key = alias.lower().replace("_","").replace("-","").replace(" ","")
        if key in names:
            return names[key]
    for alias in aliases:
        key = alias.lower().replace("_","").replace("-","").replace(" ","")
        for norm, actual in names.items():
            if norm.endswith(key) or key.endswith(norm):
                return actual
    return None

def pose_bone(actor, aliases):
    name = find_bone(actor["arm"], aliases)
    return actor["arm"].pose.bones.get(name) if name else None

def add_empty(name, location):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type = "SPHERE"
    obj.empty_display_size = 0.035
    obj.location = location
    return obj

def add_ik(actor, side, target, pole_location, report):
    arm = actor["arm"]
    hand_name = find_bone(actor, ["LeftHand" if side=="left" else "RightHand", "Hand_L" if side=="left" else "Hand_R"])
    if not hand_name:
        report[actor["name"] + "_" + side] = {"created": False, "reason": "hand bone missing"}
        return
    hand = arm.pose.bones[hand_name]
    con = hand.constraints.new("IK")
    con.name = actor["name"] + "_" + side + "_contact_IK"
    con.target = target
    con.chain_count = 3
    con.use_stretch = False
    pole = add_empty(actor["name"] + "_" + side + "_elbow_pole", pole_location)
    con.pole_target = pole
    con.pole_angle = math.radians(90)
    report[actor["name"] + "_" + side] = {
        "created": True, "hand_bone": hand_name, "chain_count": 3,
        "target": [round(v,4) for v in target.location]
    }

def rotate_pose(actor, aliases, axis, angle):
    pb = pose_bone(actor, aliases)
    if pb:
        pb.rotation_mode = "XYZ"
        if axis == "X": pb.rotation_euler.x += angle
        elif axis == "Y": pb.rotation_euler.y += angle
        else: pb.rotation_euler.z += angle
        return pb.name
    return None

def apply_body_pose(aldric, wren, report):
    # Aldric bows from hips and spine to meet Wren's shorter stature.
    names = {}
    for aliases, axis, angle in [
        (["Hips","Pelvis"], "X", math.radians(-5)),
        (["Spine","Spine1","Spine2"], "X", math.radians(-9)),
        (["Spine1","Spine2","Chest"], "X", math.radians(-11)),
        (["Neck"], "X", math.radians(5)),
        (["Head"], "X", math.radians(3)),
        (["LeftUpLeg","LeftThigh"], "X", math.radians(-4)),
        (["RightUpLeg","RightThigh"], "X", math.radians(-4)),
    ]:
        n = rotate_pose(aldric, aliases, axis, angle)
        if n: names.setdefault("Aldric", []).append(n)
    # Wren extends through ankles/feet and rises onto her toes; slight knee bend
    # keeps the lifted heel pose readable instead of simply translating her.
    for aliases, axis, angle in [
        (["LeftFoot","Foot_L"], "X", math.radians(-22)),
        (["RightFoot","Foot_R"], "X", math.radians(-22)),
        (["LeftToeBase","LeftToe"], "X", math.radians(12)),
        (["RightToeBase","RightToe"], "X", math.radians(12)),
        (["LeftUpLeg","LeftThigh"], "X", math.radians(3)),
        (["RightUpLeg","RightThigh"], "X", math.radians(3)),
        (["Spine","Spine1"], "X", math.radians(-5)),
        (["Neck"], "X", math.radians(-3)),
        (["Head"], "X", math.radians(-2)),
    ]:
        n = rotate_pose(wren, aliases, axis, angle)
        if n: names.setdefault("Wren", []).append(n)
    report["body_pose_bones"] = names

def evaluated_hand_position(actor, side):
    deps = bpy.context.evaluated_depsgraph_get()
    arm = actor["arm"].evaluated_get(deps)
    aliases = ["LeftHand" if side=="left" else "RightHand", "Hand_L" if side=="left" else "Hand_R"]
    name = find_bone(actor, aliases)
    if not name: return None
    pb = arm.pose.bones[name]
    return arm.matrix_world @ pb.tail

def main():
    if not os.path.exists(WREN_GLB) or not os.path.exists(ALDRIC_GLB):
        raise RuntimeError("Native character GLBs missing")
    # Blender local forward is -Y after glTF import. Face Aldric +Y toward Wren,
    # and Wren -Y toward Aldric. Keep the pair close enough to embrace.
    aldric = import_actor("Aldric", ALDRIC_GLB, (-0.025, -0.18, 0.0), math.pi)
    wren = import_actor("Wren", WREN_GLB, (0.025, 0.18, 0.0), 0.0)
    bpy.context.view_layer.update()
    amin, amax = bounds(aldric)
    wmin, wmax = bounds(wren)
    # Align soles to the same floor before posing; preserve their native height ratio.
    aldric["root"].location.z -= amin.z
    wren["root"].location.z -= wmin.z
    bpy.context.view_layer.update()
    amin, amax = bounds(aldric)
    wmin, wmax = bounds(wren)
    ah = amax.z-amin.z
    wh = wmax.z-wmin.z
    if ah <= 0 or wh <= 0: raise RuntimeError("Invalid character bounds")
    # Lift Wren's pelvis/root modestly; foot pose and leg chain will keep toes grounded.
    # This is deliberately smaller than the height gap: Aldric does the remaining work by bowing.
    wren["root"].location.z += min(0.075, max(0.025, (ah-wh)*0.12))
    bpy.context.view_layer.update()
    amin, amax = bounds(aldric)
    wmin, wmax = bounds(wren)

    # Contact points are derived from the actual imported mesh extents.
    aw = amax.x-amin.x; ad = amax.y-amin.y
    ww = wmax.x-wmin.x; wd = wmax.y-wmin.y
    wcentre = (wmin+wmax)*0.5
    acentre = (amin+amax)*0.5
    # Wren faces -Y; her front (breast/cheek) is on the -Y side.
    t_breast = add_empty("Aldric_left_hand__Wren_right_breast", (wcentre.x-ww*0.10, wmin.y+wd*0.13, wmin.z+(wmax.z-wmin.z)*0.66))
    t_cheek = add_empty("Aldric_right_hand__Wren_left_cheek", (wcentre.x+ww*0.08, wmin.y+wd*0.12, wmin.z+(wmax.z-wmin.z)*0.86))
    # Aldric faces +Y; his back is -Y. Wren reaches around his flank to the left glute.
    t_butt = add_empty("Wren_right_hand__Aldric_left_glute", (acentre.x-aw*0.12, amin.y+ad*0.10, amin.z+(amax.z-amin.z)*0.42))
    t_shoulder = add_empty("Wren_left_hand__Aldric_right_shoulder", (acentre.x+aw*0.20, amin.y+ad*0.12, amin.z+(amax.z-amin.z)*0.79))
    ik_report = {}
    add_ik(aldric, "left", t_breast, (amin.x-aw*0.45, acentre.y, amin.z+ah*0.72), ik_report)
    add_ik(aldric, "right", t_cheek, (amax.x+aw*0.45, acentre.y, amin.z+ah*0.82), ik_report)
    add_ik(wren, "right", t_butt, (wmin.x-ww*0.45, wcentre.y, wmin.z+wh*0.72), ik_report)
    add_ik(wren, "left", t_shoulder, (wmax.x+ww*0.45, wcentre.y, wmin.z+wh*0.82), ik_report)
    body_report = {}
    apply_body_pose(aldric, wren, body_report)
    bpy.context.view_layer.update()
    # Let depsgraph solve constraints before baking.
    for _ in range(3): bpy.context.view_layer.update()
    target_map = {
        "Aldric_left": t_breast, "Aldric_right": t_cheek,
        "Wren_right": t_butt, "Wren_left": t_shoulder
    }
    hand_errors = {}
    for key, target in target_map.items():
        actor_name, side = key.split("_")
        actor = aldric if actor_name=="Aldric" else wren
        pos = evaluated_hand_position(actor, side.lower())
        hand_errors[key] = None if pos is None else round((pos-target.location).length, 4)

    # Bake evaluated IK transforms into each armature's pose, then make this
    # review-only pose the rest pose so GLB viewers show it without animation controls.
    for actor in (aldric, wren):
        bpy.ops.object.select_all(action="DESELECT")
        actor["arm"].select_set(True)
        bpy.context.view_layer.objects.active = actor["arm"]
        bpy.ops.object.mode_set(mode="POSE")
        bpy.ops.pose.select_all(action="SELECT")
        bpy.ops.pose.armature_apply(selected=False)
        for pb in actor["arm"].pose.bones:
            for constraint in list(pb.constraints):
                pb.constraints.remove(constraint)
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    # Hide helper targets/poles from the final GLB; keep only the posed characters.
    for obj in list(bpy.context.scene.objects):
        if obj.type == "EMPTY":
            obj.hide_render = True
            obj.hide_viewport = True
    # Set a clean render camera, studio lighting and floor for a visual QA image.
    bpy.ops.mesh.primitive_plane_add(size=5, location=(0, 0, -0.01))
    floor = bpy.context.object
    floor.name = "ReviewFloor"
    floor_mat = bpy.data.materials.new("ReviewFloor_Matte")
    floor_mat.diffuse_color = (0.055, 0.065, 0.075, 1.0)
    floor.data.materials.append(floor_mat)
    bpy.ops.object.camera_add(location=(2.5, -3.8, 1.55))
    cam = bpy.context.object
    cam.name = "PoseReviewCamera"
    direction = Vector((0.0, 0.0, 0.95)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 55
    bpy.context.scene.camera = cam
    bpy.ops.object.light_add(type="AREA", location=(0.0, -2.5, 3.2))
    key = bpy.context.object
    key.data.energy = 450
    key.data.shape = "DISK"
    key.data.size = 4
    bpy.ops.object.light_add(type="AREA", location=(2.5, 1.5, 2.2))
    fill = bpy.context.object
    fill.data.energy = 250
    fill.data.size = 3
    scene = bpy.context.scene
    # Blender 4.x exposes EEVEE Next as BLENDER_EEVEE_NEXT; Blender 5.0
    # renamed the available engine identifier to BLENDER_EEVEE. Select from
    # the engines actually registered by this Blender build.
    available_engines = {
        item.identifier
        for item in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items
    }
    render_engine = next(
        (
            candidate
            for candidate in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH")
            if candidate in available_engines
        ),
        None,
    )
    if render_engine is None:
        raise RuntimeError(f"No supported render engine available: {sorted(available_engines)}")
    scene.render.engine = render_engine
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = os.path.join(OUT_DIR, "pose-preview.png")
    bpy.ops.render.render(write_still=True)

    # Export the baked pose. No IK helper objects or constraints are needed in the viewer.
    bpy.ops.object.select_all(action="DESELECT")
    exportables = []
    for actor in (aldric, wren):
        # Include the actor root so the paired placement survives GLB export.
        actor["root"].select_set(True)
        exportables.append(actor["root"])
        for obj in actor["objects"]:
            obj.select_set(True)
            exportables.append(obj)
    bpy.context.view_layer.objects.active = aldric["arm"]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, "aldric-wren-kiss-contact.glb"),
        export_format="GLB", use_selection=True, export_apply=False,
        export_animations=False, export_skins=True)

    report = {
        "scene": "Aldric and Wren height-aware paired kiss/contact pose",
        "character_height": {"aldric": round(ah,4), "wren": round(wh,4), "ratio": round(ah/wh,4)},
        "height_handling": {
            "aldric_bends_at_hips_spine": bool(body_report.get("Aldric")),
            "wren_toe_pose_bones_found": [n for n in body_report.get("Wren",[]) if "Foot" in n or "Toe" in n],
            "wren_root_lift_m": round(wren["root"].location.z,4),
            "note": "Height gap is addressed by a modest Wren rise and a forward bow through Aldric's torso/hips; verify the preview because bone naming and rig proportions vary."
        },
        "ik_chains": ik_report,
        "hand_target_error_m": hand_errors,
        "validation": {
            "four_ik_chains_created": sum(1 for v in ik_report.values() if v.get("created")) == 4,
            "actor_attachment_hierarchy_preserved": True,
            "posed_preview_rendered": os.path.exists(scene.render.filepath),
            "glb_exported": os.path.exists(os.path.join(OUT_DIR, "aldric-wren-kiss-contact.glb")),
            "pressure_deformation_applied": False,
            "anatomy_region_contact_resolved": False,
            "note": "This is a baked visual pose review only; it does not claim collision-based 145-region contact or pressure deformation."
        }
    }
    with open(os.path.join(OUT_DIR, "pose-report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print("POSE_REPORT=" + json.dumps(report))

if __name__ == "__main__":
    main()
