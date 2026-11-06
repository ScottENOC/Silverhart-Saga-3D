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


def create_piercing_sockets(armature, skin, surface_tree, minimum, height, width, pelvis_z, body_front_y):
    bones = list(armature.data.bones)
    def find_bone(names, fallback):
        return next((b.name for b in bones if b.name.lower() in names), fallback)

    head_bone = find_bone({"head", "head01"}, find_bone({"neck"}, "Hips"))
    chest_bone = find_bone({"spine2", "spine_2", "chest"}, find_bone({"spine1", "spine_1"}, "Hips"))
    hip_bone = find_bone({"hips", "hip", "pelvis"}, "Hips")

    # Earrings can use the head's actual front-side surface; keep this legacy
    # region limited to the ears while the nose and chest use anatomical anchors.
    head_lo, head_hi, _ = bone_world_span(armature, {"head", "head01"}, (minimum.z + height*.84, minimum.z + height*.96, head_bone))
    head_z = head_lo + (head_hi-head_lo)*.58
    for side, label in [(1.0, "L"), (-1.0, "R")]:
        hit = front_hit_data(surface_tree, side * width * 0.095, head_z)
        if hit:
            create_socket(armature, "SOCKET_Earring_" + label, hit[0], hit[1], head_bone)

    # Nose: find the most anterior skin vertex around the middle/lower face,
    # not a percentage of total character height.
    nose_z0 = head_lo + (head_hi-head_lo)*.34
    nose_z1 = head_lo + (head_hi-head_lo)*.78
    nose = frontmost_vertex_anchor(skin, -width*.055, width*.055, nose_z0, nose_z1)
    if nose:
        create_socket(armature, "SOCKET_NoseRing", nose[0], nose[1], head_bone)

    necklace_hit = front_hit_data(surface_tree, 0.0, minimum.z + height * 0.82)
    if necklace_hit:
        create_socket(armature, "SOCKET_Necklace", necklace_hit[0], necklace_hit[1], chest_bone)

    # Nipples: select the anterior apex on each actual breast surface, constrained
    # by the chest/spine bones and lateral chest region. No whole-body height ratio.
    chest_lo, chest_hi, _ = bone_world_span(armature, {"spine1", "spine_1", "spine2", "spine_2", "chest"},
                                            (minimum.z + height*.62, minimum.z + height*.79, chest_bone))
    nipple_z0 = chest_lo - (chest_hi-chest_lo)*.08
    nipple_z1 = chest_hi + (chest_hi-chest_lo)*.08
    for side, label in [(1.0, "L"), (-1.0, "R")]:
        x0, x1 = (width*.055, width*.30) if side > 0 else (-width*.30, -width*.055)
        hit = frontmost_vertex_anchor(skin, x0, x1, nipple_z0, nipple_z1)
        if hit:
            create_socket(armature, "SOCKET_Nipple_" + label, hit[0], hit[1], chest_bone)

    # The clitoral socket is supplied by the anatomy mesh itself after it is built.
    # It is added by main() from the hood's exposed surface, not guessed from pelvis depth.


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


def create_anatomy(pelvis_z, front_y, width, collection, skin_material, armature, surface_tree):
    # Soft mons above the vulvar cleft, paired outer folds, inner folds and a
    # modest clitoral hood. Forms overlap so they can be voxel-unified.
    half = max(0.055, min(0.075, width * 0.145))
    shapes = []
    def anchored_y(x, z, depth):
        # Sample the real body/garment surface at each sculpt centre. The old
        # single centreline depth produced gaps as the pelvis curves laterally.
        hit = front_hit_data(surface_tree, x, z)
        if not hit:
            raise RuntimeError(f"Cannot anchor anatomy to pelvis surface at x={x:.3f}, z={z:.3f}")
        return hit[0].y - depth

    # Move the sculpt slightly superiorly and posteriorly relative to the old
    # blockout, and overlap its back edge into the sampled body surface.
    base_z = pelvis_z + 0.022
    shapes.append(uv_ellipsoid(
        "Vulva_Mons_Pubis", (0.0, anchored_y(0.0, base_z + 0.047, 0.013), base_z + 0.047),
        (half * 0.92, 0.019, 0.044), collection))
    for side, label in [(-1, "L"), (1, "R")]:
        x_outer = side * half * 0.34
        x_inner = side * half * 0.145
        z = base_z - 0.012
        shapes.append(uv_ellipsoid(
            "Vulva_Labia_Majora_" + label,
            (x_outer, anchored_y(x_outer, z, 0.012), z),
            (half * 0.39, 0.017, 0.066), collection))
        shapes.append(uv_ellipsoid(
            "Vulva_Labia_Minora_" + label,
            (x_inner, anchored_y(x_inner, z, 0.008), z),
            (half * 0.145, 0.009, 0.050), collection))
    hood_z = base_z + 0.040
    shapes.append(uv_ellipsoid(
        "Vulva_Clitoral_Hood",
        (0.0, anchored_y(0.0, hood_z, 0.005), hood_z),
        (half * 0.17, 0.007, 0.014), collection))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in shapes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = shapes[0]
    bpy.ops.object.join()
    anatomy = bpy.context.object
    anatomy.name = "Adult_External_Anatomy"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    anatomy.data.remesh_voxel_size = 0.0035
    bpy.ops.object.voxel_remesh()
    smooth = anatomy.modifiers.new("Anatomy surface smoothing", "SMOOTH")
    smooth.factor = 1.15
    smooth.iterations = 4
    sub = anatomy.modifiers.new("Anatomy final surface", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    # Voxel remeshing destroys the original UV layout. Reusing Ara's textured
    # skin material on this new topology samples unrelated atlas pixels (the
    # red/purple patches seen in review). Build a clean skin-tone material from
    # the source material's base colour; do not apply the broken texture atlas.
    clean_skin = skin_material.copy()
    clean_skin.name = "Anatomy_Skin_Base"
    if clean_skin.use_nodes and clean_skin.node_tree:
        nodes = clean_skin.node_tree.nodes
        links = clean_skin.node_tree.links
        principled = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        base_colour = tuple(clean_skin.diffuse_color)
        for link in list(links):
            if principled and link.to_node == principled and link.to_socket.name in ("Base Color", "Alpha"):
                links.remove(link)
        for node in list(nodes):
            if node.type == "TEX_IMAGE":
                nodes.remove(node)
        if principled:
            principled.inputs["Base Color"].default_value = base_colour
            principled.inputs["Alpha"].default_value = 1.0
    anatomy.data.materials.clear()
    anatomy.data.materials.append(clean_skin)
    # Clamp the hidden/back side of the sculpt onto the sampled pelvis surface.
    # This turns the separate sculpt into a conforming overlay rather than a
    # collection of ellipsoids floating in front of the body.
    for vert in anatomy.data.vertices:
        p = anatomy.matrix_world @ vert.co
        hit = front_hit_data(surface_tree, p.x, p.z)
        if hit and p.y > hit[0].y - 0.001:
            p.y = hit[0].y - 0.001
            vert.co = anatomy.matrix_world.inverted() @ p
    for poly in anatomy.data.polygons:
        poly.use_smooth = True

    # Keep the anatomy attached to the pelvis in the game rig.
    hip_name = next((b.name for b in armature.data.bones if b.name.lower() in ("hips", "hip", "pelvis")), None)
    if not hip_name:
        raise RuntimeError("Ara rig has no Hips/Pelvis bone for external anatomy")
    group = anatomy.vertex_groups.new(name=hip_name)
    group.add(list(range(len(anatomy.data.vertices))), 1.0, "REPLACE")
    mod = anatomy.modifiers.new("Ara game rig", "ARMATURE")
    mod.object = armature
    anatomy["anatomy_profile"] = "adult_female_external"
    anatomy["review_status"] = "blockout_for_art_review"
    return anatomy


def expand_lower_garments(objects, pelvis_z, body_front_y, width):
    # The new external form projects a little beyond Ara's neutral pelvis.
    # Give briefs a smaller allowance and outer trousers a larger one.
    for obj in objects:
        if obj.type != "MESH":
            continue
        label = material_name(obj)
        is_bikini_lower = "bikini bottom" in label or "bikini string" in label
        is_briefs = "brief" in label or "underwear" in label or is_bikini_lower
        is_trousers = not is_bikini_lower and any(k in label for k in ("pants", "trouser", "bottom", "breech"))
        if not (is_briefs or is_trousers):
            continue
        amplitude = 0.040 if is_trousers else 0.034
        inv = obj.matrix_world.inverted()
        for vert in obj.data.vertices:
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
    hip_bone = next((b for b in armature.data.bones if b.name.lower() in ("hips", "hip", "pelvis")), None)
    pelvis_z = ((armature.matrix_world @ ((hip_bone.head_local + hip_bone.tail_local) * 0.5)).z
                if hip_bone else minimum.z + height * 0.445)

    # Use the actual exposed skin surface when available. In clothed exports,
    # skin is removed under trousers, so use the trouser surface and step inward.
    surface_tree = build_bvh(skin)
    hit = front_hit(surface_tree, 0.0, pelvis_z)
    body_front_y = hit.y if hit is not None else None
    pelvis_surface_tree = surface_tree
    if body_front_y is None:
        # Ara may omit the exact centreline pelvis face in a clothed export.
        # Search a small grid across the lower torso and use an actual mesh
        # surface hit, rather than inventing a depth from the character bounds.
        candidates = []
        x_samples = [0.0, -0.025, 0.025, -0.05, 0.05, -0.075, 0.075,
                     -width * 0.10, width * 0.10, -width * 0.14, width * 0.14]
        z_samples = [pelvis_z + dz for dz in (0.0, -0.015, 0.015, -0.03, 0.03,
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
                            candidates.append((abs(z - pelvis_z) + abs(x) * 0.35,
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
    expand_lower_garments(meshes, pelvis_z, body_front_y, width)

    if args.fit_existing:
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

    collection = bpy.data.collections.new("Adult Anatomy - reviewable sculpt")
    bpy.context.scene.collection.children.link(collection)
    anatomy = None
    if args.profile == "female":
        anatomy = create_anatomy(pelvis_z, body_front_y, width, collection, skin_material, armature, pelvis_surface_tree)
    create_piercing_sockets(armature, skin, surface_tree, minimum, height, width, pelvis_z, body_front_y)
    if anatomy is not None:
        anatomy_tree = build_bvh(anatomy)
        hood_z = pelvis_z + 0.022 + 0.040
        hood_hit = front_hit_data(anatomy_tree, 0.0, hood_z)
        if hood_hit:
            # Stand the piercing just proud of the hood surface.
            location = hood_hit[0] + hood_hit[1].normalized() * 0.0025
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
