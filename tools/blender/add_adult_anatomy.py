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


def create_piercing_sockets(armature, surface_tree, minimum, height, width, pelvis_z, body_front_y):
    bones = list(armature.data.bones)
    def find_bone(names, fallback):
        return next((b.name for b in bones if b.name.lower() in names), fallback)

    head_bone = find_bone({"head", "head01"}, find_bone({"neck"}, "Hips"))
    chest_bone = find_bone({"spine2", "spine_2", "chest"}, find_bone({"spine1", "spine_1"}, "Hips"))
    hip_bone = find_bone({"hips", "hip", "pelvis"}, "Hips")

    # Surface-derived anchors for visible skin. These follow the rig in Godot.
    head_z = minimum.z + height * 0.915
    for side, label in [(1.0, "L"), (-1.0, "R")]:
        hit = front_hit_data(surface_tree, side * width * 0.095, head_z)
        if hit:
            create_socket(armature, "SOCKET_Earring_" + label, hit[0], hit[1], head_bone)

    # Place the ring so its upper edge meets the lower edge of the nose.
    nose_ring_top_z = minimum.z + height * 0.895
    nose_hit = front_hit_data(surface_tree, 0.0, nose_ring_top_z - 0.008)
    if nose_hit:
        create_socket(armature, "SOCKET_NoseRing", nose_hit[0], nose_hit[1], head_bone)

    necklace_hit = front_hit_data(surface_tree, 0.0, minimum.z + height * 0.82)
    if necklace_hit:
        create_socket(armature, "SOCKET_Necklace", necklace_hit[0], necklace_hit[1], chest_bone)

    # The ring's top edge, not its centre, aligns with the nipple.
    nipple_ring_top_z = minimum.z + height * 0.705
    nipple_z = nipple_ring_top_z - 0.008
    for side, label in [(1.0, "L"), (-1.0, "R")]:
        hit = front_hit_data(surface_tree, side * width * 0.105, nipple_z)
        if hit:
            create_socket(armature, "SOCKET_Nipple_" + label, hit[0], hit[1], chest_bone)

    clitoral_location = Vector((0.0, body_front_y - 0.030, pelvis_z + 0.040))
    create_socket(armature, "SOCKET_ClitoralHood", clitoral_location, Vector((0.0, -1.0, 0.0)), hip_bone)


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


def create_anatomy(pelvis_z, front_y, width, collection, skin_material, armature):
    # Soft mons above the vulvar cleft, paired outer folds, inner folds and a
    # modest clitoral hood. Forms overlap so they can be voxel-unified.
    half = max(0.055, min(0.075, width * 0.145))
    shapes = []
    shapes.append(uv_ellipsoid(
        "Vulva_Mons_Pubis", (0.0, front_y - 0.004, pelvis_z + 0.047),
        (half * 0.92, 0.020, 0.047), collection))
    for side, label in [(-1, "L"), (1, "R")]:
        shapes.append(uv_ellipsoid(
            "Vulva_Labia_Majora_" + label,
            (side * half * 0.34, front_y - 0.008, pelvis_z - 0.012),
            (half * 0.39, 0.018, 0.071), collection))
        shapes.append(uv_ellipsoid(
            "Vulva_Labia_Minora_" + label,
            (side * half * 0.145, front_y - 0.018, pelvis_z - 0.012),
            (half * 0.145, 0.010, 0.054), collection))
    shapes.append(uv_ellipsoid(
        "Vulva_Clitoral_Hood",
        (0.0, front_y - 0.024, pelvis_z + 0.040),
        (half * 0.17, 0.008, 0.016), collection))

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
    anatomy.data.materials.clear()
    anatomy.data.materials.append(skin_material)
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
        is_briefs = "brief" in label or "underwear" in label
        is_trousers = any(k in label for k in ("pants", "trouser", "bottom", "breech"))
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
    pelvis_z = minimum.z + height * 0.445

    # Use the actual exposed skin surface when available. In clothed exports,
    # skin is removed under trousers, so use the trouser surface and step inward.
    surface_tree = build_bvh(skin)
    hit = front_hit(surface_tree, 0.0, pelvis_z)
    body_front_y = hit.y if hit is not None else None
    if body_front_y is None:
        lower = [o for o in meshes if any(k in material_name(o) for k in ("pants", "trouser", "brief"))]
        if lower:
            hit = front_hit(build_bvh(max(lower, key=lambda o: len(o.data.polygons))), 0.0, pelvis_z)
            if hit is not None:
                body_front_y = hit.y + 0.010
    if body_front_y is None:
        raise RuntimeError("Could not locate the front pelvis surface; refusing guessed anatomy placement")

    # Expand lower garments before adding the anatomy so their surfaces clear it.
    expand_lower_garments(meshes, pelvis_z, body_front_y, width)

    collection = bpy.data.collections.new("Adult Anatomy - reviewable sculpt")
    bpy.context.scene.collection.children.link(collection)
    if args.profile == "female":
        create_anatomy(pelvis_z, body_front_y, width, collection, skin_material, armature)
    create_piercing_sockets(armature, surface_tree, minimum, height, width, pelvis_z, body_front_y)

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
