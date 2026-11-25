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
    con.use_rotation=False
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

def palm_anchor(actor, side):
    # Use the bases of the four fingers plus thumb as a stable palm reference.
    arm=actor["arm"]
    prefix="LeftHand" if side=="left" else "RightHand"
    aliases=[prefix+"Index1",prefix+"Middle1",prefix+"Ring1",prefix+"Pinky1",prefix+"Thumb1"]
    deps=bpy.context.evaluated_depsgraph_get()
    evaluated=arm.evaluated_get(deps)
    points=[]
    used=[]
    for alias in aliases:
        name=bone_name(actor,[alias])
        if name:
            pb=evaluated.pose.bones[name]
            points.append(evaluated.matrix_world @ pb.head)
            used.append(name)
    if not points:
        hand_name=bone_name(actor,["LeftHand","Hand_L"] if side=="left" else ["RightHand","Hand_R"])
        if not hand_name:return None,[]
        pb=evaluated.pose.bones[hand_name]
        return evaluated.matrix_world @ ((pb.head+pb.tail)*0.5),[hand_name]
    return sum(points,Vector())/len(points),used



def mesh_hand_contact_diagnostics(actor, report):
    """Measure skinned hand-surface vertices against a torso BVH.

    Arm/hand-weighted triangles are excluded from the target BVH to avoid
    reporting a hand's distance to its own forearm or palm as body contact.
    This is a geometric proximity audit, not a collision response solver.
    """
    deps = bpy.context.evaluated_depsgraph_get()
    result = {}
    for side in ("left", "right"):
        prefix = "Left" if side == "left" else "Right"
        digit_tokens = ("thumb", "index", "middle", "ring", "pinky", "little")
        hand_tokens = ("hand",) + digit_tokens
        body_points = []
        body_polygons = []
        hand_samples = {"palm": [], "digits": []}
        for source in actor["meshes"]:
            evaluated = source.evaluated_get(deps)
            mesh = evaluated.to_mesh(preserve_all_data_layers=True, depsgraph=deps)
            if mesh is None:
                continue
            mesh.calc_loop_triangles()
            group_names = {group.index: group.name for group in source.vertex_groups}
            arm_group_indices = {
                index for index, name in group_names.items()
                if name.lower().startswith(prefix.lower())
                and any(token in name.lower() for token in hand_tokens + ("forearm", "arm"))
            }
            palm_group_indices = {
                index for index, name in group_names.items()
                if name.lower().startswith(prefix.lower()) and "hand" in name.lower()
            }
            digit_group_indices = {
                index for index, name in group_names.items()
                if name.lower().startswith(prefix.lower())
                and any(token in name.lower() for token in digit_tokens)
            }
            vertex_weights = []
            for vertex in source.data.vertices:
                vertex_weights.append({
                    assignment.group: assignment.weight
                    for assignment in vertex.groups
                })
            world_vertices = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
            for tri in mesh.loop_triangles:
                indices = list(tri.vertices)
                arm_weight = max(
                    (vertex_weights[i].get(group_index, 0.0)
                     for i in indices for group_index in arm_group_indices),
                    default=0.0
                )
                if arm_weight > 0.20:
                    continue
                body_polygons.append(indices)
            for index, weights in enumerate(vertex_weights):
                palm_weight = max((weights.get(g, 0.0) for g in palm_group_indices), default=0.0)
                digit_weight = max((weights.get(g, 0.0) for g in digit_group_indices), default=0.0)
                if max(palm_weight, digit_weight) < 0.25:
                    continue
                point = world_vertices[index]
                if palm_weight >= digit_weight:
                    hand_samples["palm"].append(point)
                else:
                    hand_samples["digits"].append(point)
            body_points.extend(world_vertices)
            evaluated.to_mesh_clear()
        if not body_polygons or not hand_samples["palm"] and not hand_samples["digits"]:
            result[side] = {"available": False, "reason": "Missing body triangles or weighted hand vertices"}
            continue
        # Rebuild the target from the accumulated mesh vertices and filtered triangles.
        body_tree = BVHTree.FromPolygons(body_points, body_polygons, all_triangles=True)
        side_result = {"available": body_tree is not None}
        if body_tree is None:
            side_result["reason"] = "Could not build torso BVH"
            result[side] = side_result
            continue
        for surface_name, samples in hand_samples.items():
            distances = []
            for point in samples:
                hit = body_tree.find_nearest(point)
                if hit is not None and hit[0] is not None:
                    distances.append((hit[0] - point).length)
            distances.sort()
            side_result[surface_name] = {
                "sample_vertices": len(samples),
                "matched_vertices": len(distances),
                "minimum_gap_m": round(distances[0], 5) if distances else None,
                "median_gap_m": round(distances[len(distances) // 2], 5) if distances else None,
                "vertices_within_2mm": sum(1 for value in distances if value <= 0.002),
                "vertices_within_5mm": sum(1 for value in distances if value <= 0.005)
            }
        result[side] = side_result
    report["mesh_hand_contact"] = {
        "method": "Skinned hand vertices queried against a BVH of the evaluated body mesh, excluding arm/hand-weighted target triangles",
        "sides": result,
        "caveat": "Unsigned nearest-surface distances measure proximity only. They do not establish contact force, signed penetration, or two-way deformation."
    }
    return result

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
        ("buttock_left", surface_centres["buttock_left"], Vector((0.135,0.105,0.120)), 0.032),
        ("buttock_right", surface_centres["buttock_right"], Vector((0.135,0.105,0.120)), 0.032),
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




def render_buttock_pressure_preview(actor, lo, hi, report):
    shape_name = "pressure_buttock_right"
    for source in actor["meshes"]:
        keys = source.data.shape_keys
        if keys is None:
            continue
        for key in keys.key_blocks:
            key.value = 1.0 if key.name.lower() == shape_name else 0.0
    bpy.context.view_layer.update()

    scene = bpy.context.scene
    previous_camera = scene.camera
    extent = hi - lo
    target = Vector((0.0, lo.y + extent.y * 0.86, lo.z + extent.z * 0.52))
    bpy.ops.object.camera_add(location=target + Vector((-0.45, 2.1, 0.22)))
    camera = bpy.context.object
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 0.92
    scene.camera = camera
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.filepath = os.path.join(OUT_DIR, "wren-buttock-pressure-preview.png")
    bpy.ops.render.render(write_still=True)
    rendered = os.path.exists(scene.render.filepath)

    scene.camera = previous_camera
    bpy.data.objects.remove(camera, do_unlink=True)
    for source in actor["meshes"]:
        keys = source.data.shape_keys
        if keys is None:
            continue
        for key in keys.key_blocks:
            if key.name.lower().startswith("pressure_"):
                key.value = 0.0
    bpy.context.view_layer.update()
    report["buttock_pressure_preview"] = {
        "file": "wren-buttock-pressure-preview.png",
        "active_regions": [shape_name],
        "rendered": rendered,
        "shape_value": 1.0,
        "maximum_authored_displacement_m": 0.032,
        "note": "Posterior close-up with the buttock-right prototype shape at full authored strength; visual authoring check only, not a measured 1 N runtime response."
    }
    return rendered

def export_stiffness_sweep(actor, lo, hi, report):
    # Build a single inspection GLB containing four baked Wren copies. Each copy
    # uses the same authored hip pressure shape, scaled to the spring equilibrium
    # for 1 N at the candidate stiffness. This is a visual comparison, not a
    # claim that the native Ara mesh is a validated tissue model.
    cases = [(850.0, 1.0 / 850.0), (400.0, 1.0 / 400.0),
             (200.0, 1.0 / 200.0), (100.0, 1.0 / 100.0)]
    max_shape_depth = 0.032
    spacing = max(0.72, (hi.x - lo.x) * 1.35)
    collection = bpy.data.collections.new("Wren_Buttock_Stiffness_Comparison")
    bpy.context.scene.collection.children.link(collection)
    exportables = []
    case_report = []
    shape_name = "pressure_buttock_right"

    for case_index, (stiffness, compression_m) in enumerate(cases):
        shape_value = min(1.0, compression_m / max_shape_depth)
        for source in actor["meshes"]:
            keys = source.data.shape_keys
            if keys is not None:
                for key in keys.key_blocks:
                    if key.name.lower() == shape_name:
                        key.value = shape_value
            bpy.context.view_layer.update()
            deps = bpy.context.evaluated_depsgraph_get()
            evaluated = source.evaluated_get(deps)
            mesh_data = bpy.data.meshes.new_from_object(
                evaluated, preserve_all_data_layers=True, depsgraph=deps)
            if mesh_data is None:
                continue
            duplicate = bpy.data.objects.new(
                "Wren_%03dNpm_%s" % (int(stiffness), source.name), mesh_data)
            collection.objects.link(duplicate)
            duplicate.matrix_world = source.matrix_world.copy()
            duplicate.location.x += (case_index - 1.5) * spacing
            exportables.append(duplicate)

        label = bpy.data.curves.new("StiffnessLabel_%d" % int(stiffness), "FONT")
        label.body = "%d N/m\\n%.2f mm" % (int(stiffness), compression_m * 1000.0)
        label.size = 0.075
        label.align_x = "CENTER"
        label.extrude = 0.001
        label_obj = bpy.data.objects.new("Label_%dNpm" % int(stiffness), label)
        collection.objects.link(label_obj)
        label_obj.rotation_euler = (math.radians(90), 0.0, 0.0)
        label_obj.location = (
            (case_index - 1.5) * spacing,
            lo.y - 0.16,
            lo.z + 0.04)
        bpy.context.view_layer.objects.active = label_obj
        label_obj.select_set(True)
        bpy.ops.object.convert(target="MESH")
        label_obj = bpy.context.object
        label_obj.select_set(False)
        exportables.append(label_obj)
        case_report.append({
            "stiffness_n_per_m": stiffness,
            "force_n": 1.0,
            "equilibrium_compression_mm": round(compression_m * 1000.0, 3),
            "shape_value": round(shape_value, 5),
            "copy_offset_x_m": round((case_index - 1.5) * spacing, 3)
        })

    # Render the four side-by-side models for a quick visual check.
    scene = bpy.context.scene
    if scene.camera is not None:
        centre = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (lo.z + hi.z) * 0.5))
        centre.x = 0.0
        cam = scene.camera
        cam.location = centre + Vector((1.7, -4.8, 0.55))
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = max(3.6, spacing * 4.2)
        scene.render.resolution_x = 1800
        scene.render.resolution_y = 900
        scene.render.resolution_percentage = 100
        scene.render.filepath = os.path.join(OUT_DIR, "wren-stiffness-sweep-preview.png")
        bpy.ops.render.render(write_still=True)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in exportables:
        obj.select_set(True)
    if exportables:
        bpy.context.view_layer.objects.active = exportables[0]
    output_path = os.path.join(OUT_DIR, "wren-buttock-stiffness-sweep.glb")
    bpy.ops.export_scene.gltf(filepath=output_path, export_format="GLB",
        use_selection=True, export_animations=False, export_skins=False,
        export_draco_mesh_compression_enable=False)

    # Restore the original source shape values so the ordinary posed GLB remains
    # independent of this comparison package.
    for source in actor["meshes"]:
        keys = source.data.shape_keys
        if keys is not None:
            for key in keys.key_blocks:
                if key.name.lower().startswith("pressure_"):
                    key.value = 0.0
    bpy.context.view_layer.update()
    report["stiffness_sweep"] = {
        "cases": case_report,
        "glb": "wren-buttock-stiffness-sweep.glb",
        "preview": "wren-stiffness-sweep-preview.png",
        "glb_exported": os.path.exists(output_path),
        "preview_rendered": os.path.exists(os.path.join(OUT_DIR, "wren-stiffness-sweep-preview.png")),
        "note": "Four baked Wren copies show the hip pressure shape scaled to F/k for 1 N. The visual is an authored shape-key response, not tissue calibration."
    }
    return report["stiffness_sweep"]["glb_exported"]


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
    # The native model faces -Y, so the posterior gluteal surface is toward +Y.
    buttock_query = Vector((centre.x-width*0.13,lo.y+depth*0.86,lo.z+height*0.53))
    buttock_right_surface = nearest_surface(actor, buttock_query)
    buttock_left_surface = nearest_surface(actor, Vector((2.0*centre.x-buttock_query.x,buttock_query.y,buttock_query.z)))
    if buttock_right_surface is None or buttock_left_surface is None:
        raise RuntimeError("Could not resolve both posterior buttock surface anchors")
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
        "hip_right": Vector(right_hip_surface["surface_point_world"]),
        "buttock_left": Vector(buttock_left_surface["surface_point_world"]),
        "buttock_right": Vector(buttock_right_surface["surface_point_world"])
    }

    report={"scene":"Wren only: breast and hip hand-contact deformation test",
            "world_axes":{"up":"Z","front":"-Y","basis":"Imported mesh bounds and facing convention; verify in preview"},
            "body_bounds":{"min":[round(v,5) for v in lo],"max":[round(v,5) for v in hi]},
            "targets":{"left_hand_breast":[round(v,5) for v in left_breast],
                       "right_hand_hip":[round(v,5) for v in right_hip],
                       "posterior_buttock_query":[round(v,5) for v in buttock_query]},
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
    # Fit the palm reference point to the measured body surface. The IK target
    # controls the hand-bone tail, not the palm, so aiming the tail directly at
    # the surface leaves a systematic offset. Preserve the current wrist/finger
    # orientation and compensate for the measured tail-to-palm-anchor vector.
    # Iterate because Blender's IK evaluation can slightly alter that vector.
    surface_anchors = {"left": left_breast_surface, "right": right_hip_surface}
    targets_by_side = {"left": left_target, "right": right_target}
    for _fit_pass in range(5):
        bpy.context.view_layer.update()
        for side in ("left", "right"):
            target = targets_by_side[side]
            surface = surface_anchors[side]
            surface_point = Vector(surface["surface_point_world"])
            anchor, _anchor_bones = palm_anchor(actor, side)
            if anchor is None:
                raise RuntimeError("Could not resolve %s palm anchor" % side)
            target.location += surface_point - anchor
        for _ in range(3):
            bpy.context.view_layer.update()
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
    report["palm_anchor_surface_gaps"] = {}
    for side, surface in surface_anchors.items():
        anchor, anchor_bones = palm_anchor(actor, side)
        surface_point = Vector(surface["surface_point_world"])
        report["palm_anchor_surface_gaps"][side] = {
            "gap_m": round((anchor - surface_point).length, 5),
            "palm_anchor_world": [round(v, 5) for v in anchor],
            "surface_point_world": [round(v, 5) for v in surface_point],
            "anchor_bones": anchor_bones
        }
    report["contact_target_surface_anchors"]={
        "left_breast":left_breast_surface,
        "right_hip":right_hip_surface,
        "target_clearance_m":0.0,
        "note":"The finger-base palm proxy is iteratively fitted to the selected evaluated body-surface point. This is a pose-proximity diagnostic, not yet a mesh-to-mesh collision measurement."}
    report["hand_target_errors"]={}
    report["palm_target_errors"]={}
    for side,target in (("left",left_target),("right",right_target)):
        p=hand_position(actor,side)
        report["hand_target_errors"][side]=None if p is None else round((p-target.location).length,5)
        anchor,anchor_bones=palm_anchor(actor,side)
        report["palm_target_errors"][side]=None if anchor is None else {
            "distance_m":round((anchor-target.location).length,5),
            "palm_anchor_world":[round(v,5) for v in anchor],
            "finger_base_bones":anchor_bones}
    mesh_hand_contact_diagnostics(actor, report)
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
    buttock_preview_rendered = render_buttock_pressure_preview(actor, lo, hi, report)
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
    stiffness_sweep_exported = export_stiffness_sweep(actor, lo, hi, report)
    palm_anchor_gaps = [v["gap_m"] for v in report["palm_anchor_surface_gaps"].values()]
    report["validation"]={"wren_only":True,"both_arm_ik_created":all(v.get("created",False) for v in report["ik"].values()),
        "preview_rendered":os.path.exists(os.path.join(OUT_DIR,"wren-body-pressure-preview.png")),
        "posed_glb_exported":os.path.exists(os.path.join(OUT_DIR,"wren-body-pressure-pose.glb")),
        "palm_anchor_within_5mm_of_selected_surface":len(palm_anchor_gaps) == 2 and all(gap <= 0.005 for gap in palm_anchor_gaps),
        "pressure_shapes_authored":len(authored_shapes) >= 4 and all(x["affected_vertices"] > 0 for x in authored_shapes),
        "pressure_compressed_preview_rendered":pressure_preview_rendered,
        "stiffness_sweep_glb_exported":stiffness_sweep_exported,
        "stiffness_sweep_preview_rendered":report["stiffness_sweep"]["preview_rendered"],
        "buttock_pressure_preview_rendered":buttock_preview_rendered}
    with open(os.path.join(OUT_DIR,"wren-body-pressure-report.json"),"w",encoding="utf-8") as f: json.dump(report,f,indent=2)
    print("WREN_BODY_PRESSURE_REPORT="+json.dumps(report))

if __name__=="__main__": main()
