"""Add a restrained adult external vulva sculpt to an Ara GLB.

The anatomy is a separate skin-matched mesh weighted to the Hips bone. It is
intended as a reviewable production starting point, not a claim of finished
medical/anatomical accuracy. On clothed exports, lower garments are expanded
locally at the front pelvis to reduce intersection with the new anatomy.

Ara GLB axes after Blender import: Z up, character facing -Y.
"""
import argparse
import os
import sys
import math

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default=os.environ.get("ARA_INPUT"), required=not bool(os.environ.get("ARA_INPUT")))
    parser.add_argument("--output", default=os.environ.get("ARA_OUTPUT"), required=not bool(os.environ.get("ARA_OUTPUT")))
    parser.add_argument("--profile", choices=("female", "none"), default=os.environ.get("ARA_PROFILE"), required=not bool(os.environ.get("ARA_PROFILE")))
    parser.add_argument("--adult", action="store_true", default=os.environ.get("ARA_ADULT") == "1")
    parser.add_argument("--fit-existing", action="store_true", help="Only expand lower garments around anatomy already present in the input GLB")
    return parser.parse_args(raw)


def material_name(obj):
    return " ".join(slot.material.name.lower() for slot in obj.material_slots if slot.material)


def mesh_world_bounds(obj):
    pts = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector(tuple(min(p[i] for p in pts) for i in range(3))),
        Vector(tuple(max(p[i] for p in pts) for i in range(3))),
    )


def build_bvh(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    verts = [obj.matrix_world @ v.co for v in mesh.vertices]
    polys = [list(p.vertices) for p in mesh.polygons]
    tree = BVHTree.FromPolygons(verts, polys, all_triangles=False)
    evaluated.to_mesh_clear()
    return tree


def front_hit_data(tree, x, z):
    location, normal, _index, _distance = tree.ray_cast(
        Vector((x, -2.0, z)), Vector((0.0, 1.0, 0.0)), 4.0
    )
    if location is None:
        return None
    return location, normal


def front_hit(tree, x, z):
    hit = front_hit_data(tree, x, z)
    return hit[0] if hit else None


def create_socket(armature, name, location, normal, bone_name):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "SPHERE"
    empty.empty_display_size = 0.007
    bpy.context.collection.objects.link(empty)
    empty.parent = armature
    empty.parent_type = "BONE"
    empty.parent_bone = bone_name
    orientation = Vector((0.0, 0.0, 1.0)).rotation_difference(normal.normalized())
    empty.matrix_world = Matrix.Translation(location) @ orientation.to_matrix().to_4x4()
    empty["socket_type"] = name.replace("SOCKET_", "").lower()
    empty["review_anchor"] = "surface-derived"
    return empty


def bone_world_span(armature, names, fallback=None):
    for bone in armature.data.bones:
        if bone.name.lower() in names:
            a = armature.matrix_world @ bone.head_local
            b = armature.matrix_world @ bone.tail_local
            return min(a.z, b.z), max(a.z, b.z), bone.name
    if fallback:
        return fallback
    raise RuntimeError("Required anatomical rig landmark not found: " + "/".join(sorted(names)))


def pelvis_landmark_from_leg_roots(armature, minimum, height):
    """Locate the pelvic centre from the left/right femur roots, not Hips-bone midpoint.

    On Ara/Mixamo rigs the Hips bone spans much of the lower torso; its midpoint
    is not a reliable genital landmark and can place both the sculpt and hood
    socket up on the abdomen. The paired upper-leg heads identify the hip-joint
    line. Fail loudly if the expected rig landmarks are absent rather than
    silently reverting to a visually unsafe torso-height estimate.
    """
    aliases = {
        "left": {"leftupleg", "leftupperleg", "upleg_l", "upperleg_l",
                 "thigh_l", "leftthigh", "lthigh", "thigh.l"},
        "right": {"rightupleg", "rightupperleg", "upleg_r", "upperleg_r",
                  "thigh_r", "rightthigh", "rthigh", "thigh.r"},
    }
    found = {}
    for side, names in aliases.items():
        bone = next((b for b in armature.data.bones
                     if b.name.lower().replace(" ", "").replace("-", "_") in names), None)
        if bone is not None:
            found[side] = armature.matrix_world @ bone.head_local
    if len(found) != 2:
        available = ", ".join(b.name for b in armature.data.bones
                              if any(token in b.name.lower() for token in ("leg", "thigh", "upleg")))
        raise RuntimeError(
            "Cannot locate paired upper-leg roots for pelvic anatomy placement. "
            f"Found {sorted(found)}; relevant rig bones: {available or 'none'}"
        )
    z = (found["left"].z + found["right"].z) * 0.5
    print(
        "Pelvic landmark from paired upper-leg roots: "
        f"left={found['left'].z:.4f}, right={found['right'].z:.4f}, "
        f"centre={z:.4f} (character height={height:.4f})"
    )
    return z


def frontmost_vertex_anchor(obj, x_min, x_max, z_min, z_max):
    # Pick an actual evaluated skin vertex in a tightly bounded anatomical region.
    # The vertex normal gives a stable surface orientation for the accessory.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    best = None
    for v in mesh.vertices:
        p = obj.matrix_world @ v.co
        if not (x_min <= p.x <= x_max and z_min <= p.z <= z_max):
            continue
        n = (obj.matrix_world.to_3x3() @ v.normal).normalized()
        if n.y > -0.12:
            continue
        score = p.y
        if best is None or score < best[0]:
            best = (score, p.copy(), n.copy())
    evaluated.to_mesh_clear()
    return (best[1], best[2]) if best else None


def create_piercing_sockets(armature, skin, surface_tree, minimum, height, width, anatomy_z, body_front_y):
    bones = list(armature.data.bones)
    def find_bone(names, fallback):
        return next((b.name for b in bones if b.name.lower() in names), fallback)

    head_bone = find_bone({"head", "head01"}, find_bone({"neck"}, "Hips"))
    chest_bone = find_bone({"spine2", "spine_2", "chest"}, find_bone({"spine1", "spine_1"}, "Hips"))

    # Ear sockets are selected from the lateral ear contour, not a front-view
    # point on the cheek. Require a side-facing normal and the lower head band.
    ear_z = minimum.z + height * 0.875
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = skin.evaluated_get(depsgraph)
    mesh_eval = evaluated.to_mesh()
    for side, label in ((1.0, "L"), (-1.0, "R")):
        best = None
        for v in mesh_eval.vertices:
            p = skin.matrix_world @ v.co
            n = (skin.matrix_world.to_3x3() @ v.normal).normalized()
            if side*p.x < width*0.13 or side*p.x > width*0.29:
                continue
            if abs(p.z-ear_z) > height*0.035 or side*n.x < 0.22:
                continue
            score = side*n.x*2.0 - abs(p.z-ear_z)/max(height*0.035, 1e-5)
            if best is None or score > best[0]:
                best = (score, p.copy(), n.copy())
        if best:
            # Move the earring anchor just clear of the ear surface and slightly
            # forward of the hairline so hoops remain visible in the Workshop.
            earring_location = best[1] + best[2] * 0.003 + Vector((0.0, -0.005, 0.0))
            create_socket(armature, "SOCKET_Earring_" + label, earring_location, best[2], head_bone)
    evaluated.to_mesh_clear()

    # Nose ring sits 1 cm below the former anchor, with a fresh surface raycast
    # at that lower height so the socket remains flush to the nose.
    head_lo, head_hi, _ = bone_world_span(armature, {"head", "head01"},
                                          (minimum.z + height*.84, minimum.z + height*.96, head_bone))
    nose = frontmost_vertex_anchor(skin, -width*.055, width*.055,
                                   head_lo + (head_hi-head_lo)*.34,
                                   head_lo + (head_hi-head_lo)*.78)
    if nose:
        lowered = front_hit_data(surface_tree, nose[0].x, nose[0].z - 0.010)
        if lowered:
            create_socket(armature, "SOCKET_NoseRing", lowered[0], lowered[1], head_bone)

    necklace_hit = front_hit_data(surface_tree, 0.0, minimum.z + height * 0.82)
    if necklace_hit:
        create_socket(armature, "SOCKET_Necklace", necklace_hit[0], necklace_hit[1], chest_bone)

    # Use the actual breast-height band of the body. Do not derive this from
    # Spine1: on this Ara rig that bone can span the upper abdomen.
    # Use the skin mesh bounds rather than all character meshes (hair and
    # footwear distort whole-character height ratios). The earlier band sat too
    # low on this Ara body; keep the search above the navel and within the bust.
    skin_min, skin_max = mesh_world_bounds(skin)
    skin_height = skin_max.z - skin_min.z
    nipple_z0 = skin_min.z + skin_height * 0.69
    nipple_z1 = skin_min.z + skin_height * 0.84
    for side, label in ((1.0, "L"), (-1.0, "R")):
        x0, x1 = ((width*.055, width*.30) if side > 0 else (-width*.30, -width*.055))
        hit = frontmost_vertex_anchor(skin, x0, x1, nipple_z0, nipple_z1)
        if hit:
            create_socket(armature, "SOCKET_Nipple_" + label, hit[0], hit[1], chest_bone)


def uv_ellipsoid(name, location, scale, collection):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    collection.objects.link(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def integrate_anatomy_into_skin(skin, anatomy_z, width, height):
    """Sculpt the existing skin mesh in-place, preserving its UVs/material/weights."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    bm.normal_update()
    inv = skin.matrix_world.inverted()
    edges = []
    for edge in bm.edges:
        mid = (edge.verts[0].co + edge.verts[1].co) * 0.5
        world = skin.matrix_world @ mid
        normal = skin.matrix_world.to_3x3() @ (edge.verts[0].normal + edge.verts[1].normal)
        if normal.length:
            normal.normalize()
        if abs(world.x) < width*0.25 and abs(world.z-anatomy_z) < 0.125 and normal.y < -0.12:
            edges.append(edge)
    if edges:
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=2, use_grid_fill=True)
        bm.normal_update()

    def g(x,z,cx,cz,sx,sz):
        return math.exp(-0.5*(((x-cx)/sx)**2+((z-cz)/sz)**2))

    # Ara faces -Y. The femur-root line is a hip-joint landmark, not the
    # vulvar centre: place the vulva clearly inferior to it, toward the perineum.
    # Every feature is displaced from the original skin surface; no genital
    # mesh is added. Paired longitudinal folds define the labia majora/minora,
    # with a narrow inset cleft and a small transverse clitoral-hood rise.
    centre_z = pelvis_z
    for v in bm.verts:
        p = skin.matrix_world @ v.co
        n = skin.matrix_world.to_3x3() @ v.normal
        if n.length:
            n.normalize()
        if n.y > -0.10 or abs(p.x) > width*0.27 or abs(p.z-centre_z) > 0.15:
            continue
        mons = g(p.x,p.z,0.0,centre_z+0.058,width*0.105,0.032)
        outer_l = g(p.x,p.z,-width*0.060,centre_z-0.004,width*0.036,0.052)
        outer_r = g(p.x,p.z, width*0.060,centre_z-0.004,width*0.036,0.052)
        inner_l = g(p.x,p.z,-width*0.024,centre_z-0.006,width*0.017,0.039)
        inner_r = g(p.x,p.z, width*0.024,centre_z-0.006,width*0.017,0.039)
        cleft = g(p.x,p.z,0.0,centre_z-0.010,width*0.010,0.047)
        hood = g(p.x,p.z,0.0,centre_z+0.034,width*0.024,0.012)
        p.y -= (0.0030*mons + 0.0065*(outer_l+outer_r)
                + 0.0032*(inner_l+inner_r) + 0.0030*hood
                - 0.0030*cleft)
        v.co = inv @ p
    bm.normal_update()
    bm.to_mesh(skin.data)
    bm.free()
    skin.data.update()
    for poly in skin.data.polygons:
        poly.use_smooth = True
    skin["anatomy_profile"] = "adult_female_integrated_skin"
    skin["review_status"] = "integrated_mesh_blockout_for_art_review"
    skin["anatomy_method"] = "local_subdivision_and_surface_displacement"
    return skin


def expand_lower_garments(objects, pelvis_z, body_front_y, width):
    # Apply the local pelvic allowance only to vertices belonging to lower-garment
    # material faces. Modular GLBs can contain skin and garments in one Blender
    # object; moving every vertex in that object would deform the body itself.
    for obj in objects:
        if obj.type != "MESH":
            continue
        briefs_vertices, trouser_vertices = set(), set()
        for poly in obj.data.polygons:
            if poly.material_index >= len(obj.material_slots):
                continue
            material = obj.material_slots[poly.material_index].material
            label = material.name.lower() if material else ""
            is_bikini_lower = "bikini bottom" in label or "bikini string" in label
            if "brief" in label or "underwear" in label or is_bikini_lower:
                briefs_vertices.update(poly.vertices)
            elif any(k in label for k in ("pants", "trouser", "breech")):
                trouser_vertices.update(poly.vertices)
        inv = obj.matrix_world.inverted()
        for indices, amplitude in ((briefs_vertices, 0.034), (trouser_vertices, 0.040)):
            for index in indices:
                vert = obj.data.vertices[index]
                world = obj.matrix_world @ vert.co
                if world.y > body_front_y + 0.055:
                    continue
                if abs(world.x) > width * 0.22 or abs(world.z - pelvis_z) > 0.13:
                    continue
                fx = (world.x / max(width * 0.18, 0.065)) ** 2
                fz = ((world.z - pelvis_z) / 0.115) ** 2
                falloff = max(0.0, 1.0 - fx) * max(0.0, 1.0 - fz)
                falloff = falloff * falloff
                world.y -= amplitude * falloff
                vert.co = inv @ world
        obj.data.update()


def fit_pants_clearance(objects, skin, clearance=0.004):
    """Push trouser vertices outside the retained skin surface, without moving skin."""
    tree = build_bvh(skin)
    for obj in objects:
        if obj.type != "MESH":
            continue
        pants_vertices = set()
        for poly in obj.data.polygons:
            if poly.material_index >= len(obj.material_slots):
                continue
            material = obj.material_slots[poly.material_index].material
            label = material.name.lower() if material else ""
            if any(k in label for k in ("pants", "trouser", "breech")):
                pants_vertices.update(poly.vertices)
        if not pants_vertices:
            continue
        inv = obj.matrix_world.inverted()
        moved = 0
        for index in pants_vertices:
            vert = obj.data.vertices[index]
            world = obj.matrix_world @ vert.co
            nearest = tree.find_nearest(world)
            if not nearest or nearest[0] is None or nearest[1] is None:
                continue
            location, normal, _face, _distance = nearest
            normal = normal.normalized()
            signed = (world - location).dot(normal)
            if signed < clearance:
                world += normal * (clearance - signed)
                vert.co = inv @ world
                moved += 1
        obj.data.update()
        print(f"Fitted {obj.name}: moved {moved} trouser vertices to {clearance * 1000:.1f} mm skin clearance")


def main():
    args = arguments()
    if not args.adult:
        raise SystemExit("Refusing to add external genital anatomy without explicit --adult confirmation")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if not meshes or armature is None:
        raise RuntimeError("Expected Ara mesh objects and a game armature")

    skin = max((o for o in meshes if "skin" in material_name(o)), key=lambda o: len(o.data.polygons), default=None)
    if skin is None or not skin.data.materials:
        raise RuntimeError("Could not identify Ara's Skin mesh/material")
    skin_material = next((m for m in skin.data.materials if m and "skin" in m.name.lower()), skin.data.materials[0]).copy()
    skin_material.name = "Skin"

    all_bounds = [mesh_world_bounds(o) for o in meshes]
    minimum = Vector(tuple(min(b[0][i] for b in all_bounds) for i in range(3)))
    maximum = Vector(tuple(max(b[1][i] for b in all_bounds) for i in range(3)))
    height = maximum.z - minimum.z
    width = max(mesh_world_bounds(skin)[1].x - mesh_world_bounds(skin)[0].x, 0.4)
    # The Hips bone midpoint is a torso landmark, not a genital landmark.
    # Use the paired femur roots so the sculpt and clitoral-hood socket are
    # calibrated to the actual pelvic/hip-joint line.
    pelvis_z = pelvis_landmark_from_leg_roots(armature, minimum, height)
    # Femur roots identify the hip-joint line. The vulvar centre is inferior
    # to it, toward the perineum; scale the offset to Ara's actual body height.
    anatomy_z = pelvis_z - height * 0.035

    # Use the actual exposed skin surface when available. In clothed exports,
    # skin is removed under trousers, so use the trouser surface and step inward.
    surface_tree = build_bvh(skin)
    hit = front_hit(surface_tree, 0.0, anatomy_z)
    body_front_y = hit.y if hit is not None else None
    pelvis_surface_tree = surface_tree
    if body_front_y is None:
        # Ara may omit the exact centreline pelvis face in a clothed export.
        # Search a small grid across the lower torso and use an actual mesh
        # surface hit, rather than inventing a depth from the character bounds.
        candidates = []
        x_samples = [0.0, -0.025, 0.025, -0.05, 0.05, -0.075, 0.075,
                     -width * 0.10, width * 0.10, -width * 0.14, width * 0.14]
        z_samples = [anatomy_z + dz for dz in (0.0, -0.015, 0.015, -0.03, 0.03,
                                               -0.045, 0.045, -0.06, 0.06)]
        # Prefer a lower-garment mesh when its material is identifiable, but
        # also inspect all remaining meshes: Ara's material labels vary by export.
        ordered = sorted(meshes, key=lambda o: (
            0 if any(k in material_name(o) for k in ("pants", "trouser", "brief", "underwear")) else 1,
            -len(o.data.polygons)))
        for candidate_obj in ordered:
            tree = build_bvh(candidate_obj)
            for x in x_samples:
                for z in z_samples:
                    result = front_hit_data(tree, x, z)
                    if result:
                        location, normal = result
                        if normal.y < -0.15:
                            candidates.append((abs(z - anatomy_z) + abs(x) * 0.35,
                                               location.y, location, candidate_obj.name))
            if candidates and any(k in material_name(candidate_obj) for k in ("pants", "trouser", "brief", "underwear")):
                break
        if candidates:
            _score, surface_y, location, source_name = min(candidates, key=lambda item: item[0])
            body_front_y = surface_y + 0.010
            source_obj = next(o for o in meshes if o.name == source_name)
            pelvis_surface_tree = build_bvh(source_obj)
            print(f"Pelvis surface fallback: {source_name} at {tuple(round(v, 4) for v in location)}")
    if body_front_y is None:
        details = []
        for obj in meshes:
            lo, hi = mesh_world_bounds(obj)
            details.append(f"{obj.name}: materials={material_name(obj)!r}, z={lo.z:.3f}..{hi.z:.3f}, polys={len(obj.data.polygons)}")
        raise RuntimeError("Could not locate the front pelvis surface after grid scan. Meshes: " + " | ".join(details))

    # Expand lower garments before adding the anatomy so their surfaces clear it.
    expand_lower_garments(meshes, anatomy_z, body_front_y, width)

    if args.fit_existing:
        # The base skin remains present beneath transparent clothing. Fit only
        # trouser material vertices against it; never hide or displace the skin.
        fit_pants_clearance(meshes, skin, clearance=0.004)
        # The modular GLBs already contain the anatomy and piercing sockets
        # from the integrated body base. Only fit briefs, bikini bottoms and
        # trousers over that existing geometry; do not add a second sculpt.
        bpy.ops.object.select_all(action="DESELECT")
        for obj in bpy.context.scene.objects:
            if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
                obj.select_set(True)
        bpy.context.view_layer.objects.active = armature
        os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
        bpy.ops.export_scene.gltf(
            filepath=os.path.abspath(args.output),
            export_format="GLB",
            use_selection=True,
            export_apply=False,
        )
        print("Fitted lower garments around existing adult anatomy")
        return

    anatomy = None
    if args.profile == "female":
        anatomy = integrate_anatomy_into_skin(skin, anatomy_z, width, height)
        surface_tree = build_bvh(skin)
        pelvis_surface_tree = surface_tree
    create_piercing_sockets(armature, skin, surface_tree, minimum, height, width, anatomy_z, body_front_y)
    if anatomy is not None:
        # The hood sits just above the vulvar cleft, not on the mons pubis.
        hood_hit = front_hit_data(surface_tree, 0.0, anatomy_z + 0.034)
        if hood_hit:
            location = hood_hit[0] + hood_hit[1].normalized() * 0.0015
            hip_name = next((b.name for b in armature.data.bones if b.name.lower() in ("hips", "hip", "pelvis")), "Hips")
            create_socket(armature, "SOCKET_ClitoralHood", location, hood_hit[1], hip_name)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(args.output),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
    )
    print("Exported adult anatomy variant. Inspect front, side and three-quarter views before production use.")


if __name__ == "__main__":
    main()
