"""Adult external-anatomy blockout helper.

This is intentionally a separate, reviewable geometry pass. It creates a
non-sexual anatomical blockout, not a finished deformation-ready sculpt.
Blender's native coordinates are assumed: Z up, character facing -Y.
"""
import argparse
import os
import sys

import bpy
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--profile", choices=("female", "male", "none"), required=True)
    parser.add_argument("--adult", action="store_true")
    return parser.parse_args(raw)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def smooth_mesh(obj, subdivision=1):
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    if subdivision:
        modifier = obj.modifiers.new("Anatomy smoothing", "SUBSURF")
        modifier.levels = subdivision
        modifier.render_levels = subdivision
    return obj


def uv_ellipsoid(name, location, scale, collection):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)
    return smooth_mesh(obj, 1)


def create_anatomy(profile, centre, width, height, collection):
    # Body faces -Y. Pelvic landmarks are estimated from the full body bounds;
    # these values must be checked against the source character's proportions.
    pelvis_z = centre.z - height * 0.19
    front_y = centre.y - width * 0.17
    half_width = width * 0.105
    depth = width * 0.055

    if profile == "female":
        # Mons and paired external labial forms, kept as distinct sculpt guides
        # so a Blender artist can merge/retopologise them into the body surface.
        uv_ellipsoid("Anatomy_F_Mons", (centre.x, front_y, pelvis_z + height * 0.018),
                     (half_width * 0.86, depth * 0.55, height * 0.025), collection)
        uv_ellipsoid("Anatomy_F_LabiaMajora_L",
                     (centre.x - half_width * 0.39, front_y - depth * 0.10, pelvis_z - height * 0.006),
                     (half_width * 0.34, depth * 0.48, height * 0.045), collection)
        uv_ellipsoid("Anatomy_F_LabiaMajora_R",
                     (centre.x + half_width * 0.39, front_y - depth * 0.10, pelvis_z - height * 0.006),
                     (half_width * 0.34, depth * 0.48, height * 0.045), collection)
        uv_ellipsoid("Anatomy_F_ClitoralHood_Guide",
                     (centre.x, front_y - depth * 0.58, pelvis_z + height * 0.020),
                     (half_width * 0.13, depth * 0.12, height * 0.009), collection)
    elif profile == "male":
        # Shaft axis follows the character's forward (-Y) direction.
        bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=width * 0.026,
                                        radius2=width * 0.018, depth=width * 0.19,
                                        location=(centre.x, front_y - width * 0.105, pelvis_z))
        shaft = bpy.context.object
        shaft.name = "Anatomy_M_PenisShaft_Guide"
        shaft.rotation_euler[0] = 1.5707963
        for c in list(shaft.users_collection):
            c.objects.unlink(shaft)
        collection.objects.link(shaft)
        smooth_mesh(shaft, 1)
        uv_ellipsoid("Anatomy_M_Glans_Guide",
                     (centre.x, front_y - width * 0.205, pelvis_z),
                     (width * 0.027, width * 0.035, width * 0.027), collection)
        uv_ellipsoid("Anatomy_M_Scrotum_L",
                     (centre.x - width * 0.035, front_y - width * 0.035, pelvis_z - height * 0.055),
                     (width * 0.035, width * 0.045, height * 0.050), collection)
        uv_ellipsoid("Anatomy_M_Scrotum_R",
                     (centre.x + width * 0.035, front_y - width * 0.035, pelvis_z - height * 0.055),
                     (width * 0.035, width * 0.045, height * 0.050), collection)


def main():
    args = arguments()
    if not args.adult:
        raise SystemExit("Refusing to add genital anatomy without explicit --adult confirmation")
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("Input GLB contains no mesh objects")
    points = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    minimum = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    maximum = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    centre = (minimum + maximum) * 0.5
    dimensions = maximum - minimum
    collection = bpy.data.collections.new("Adult Anatomy Blockout - review required")
    bpy.context.scene.collection.children.link(collection)
    if args.profile != "none":
        create_anatomy(args.profile, centre, dimensions.x, dimensions.z, collection)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = next((o for o in meshes if o.type == "MESH"), None)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False)
    print("Exported anatomy blockout. Review proportions, body intersection and rigging before use.")


if __name__ == "__main__":
    main()
