"""Surface-following female anatomy sculpt for the Ara adult base body.

This is deliberately anatomy-only: no garment expansion, clothing fitting,
hybrid add-on meshes, or accessory socket changes are performed here.
The original skin mesh, UVs, material, vertex groups and armature are retained.
Review the generated adult model from multiple angles before production use.
"""
import argparse
import json
import os
import sys
import math

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", default="")
    parser.add_argument("--subdivision-plan", required=True)
    parser.add_argument("--adult", action="store_true")
    parser.add_argument("--deformation-scale", type=float, default=1.65)
    return parser.parse_args(raw)


def material_name(obj):
    return " ".join(slot.material.name.lower() for slot in obj.material_slots if slot.material)


def mesh_world_bounds(obj):
    pts = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector(tuple(min(p[i] for p in pts) for i in range(3))),
        Vector(tuple(max(p[i] for p in pts) for i in range(3))),
    )

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


def main():
    args = arguments()
    if not args.adult:
        raise SystemExit("Refusing to add external anatomy without explicit --adult confirmation")
    if args.deformation_scale <= 0:
        raise ValueError("--deformation-scale must be positive")

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if not meshes or armature is None:
        raise RuntimeError("Expected Ara mesh objects and an armature")

    skin = max(
        (obj for obj in meshes if "skin" in material_name(obj)),
        key=lambda obj: len(obj.data.polygons),
        default=None,
    )
    if skin is None or not skin.data.materials:
        raise RuntimeError("Could not identify Ara's skin mesh/material")

    # Isolate the vertex-colour shader change to this skin mesh. Do not mutate
    # a shared material that may also be used by other character components.
    skin_index = next(
        (i for i, material in enumerate(skin.data.materials)
         if material and "skin" in material.name.lower()),
        0,
    )
    skin_material = skin.data.materials[skin_index].copy()
    skin_material.name = "Skin_Anatomy"
    skin.data.materials[skin_index] = skin_material

    all_bounds = [mesh_world_bounds(obj) for obj in meshes]
    minimum = Vector(tuple(min(bounds[0][i] for bounds in all_bounds) for i in range(3)))
    maximum = Vector(tuple(max(bounds[1][i] for bounds in all_bounds) for i in range(3)))
    height = maximum.z - minimum.z
    if height <= 0:
        raise RuntimeError(f"Invalid character height: {height}")
    skin_min, skin_max = mesh_world_bounds(skin)
    width = max(skin_max.x - skin_min.x, 0.4)

    hipline_z = pelvis_landmark_from_leg_roots(armature, height)
    anatomy_z = hipline_z - height * 0.035

    integrate_anatomy_into_skin(
        skin, anatomy_z, width, height, args.deformation_scale,
        hipline_z=hipline_z, subdivision_plan_path=args.subdivision_plan
    )
    apply_anatomy_pigmentation(skin, anatomy_z, width, height)
    wire_vertex_colour_to_skin_material(skin_material, "Color")

    # Recreate the surface-derived accessory sockets that the legacy builder
    # added after sculpting. These are rig anchors, not clothing operations.
    surface_tree = build_bvh(skin)
    create_piercing_sockets(armature, skin, surface_tree, minimum, height,
                            width, anatomy_z, None)
    hood_anchor = skin.get("anatomy_hood_anchor")
    if hood_anchor:
        hood_normal = Vector((hood_anchor[3], hood_anchor[4], hood_anchor[5])).normalized()
        hood_location = Vector((hood_anchor[0], hood_anchor[1], hood_anchor[2])) + hood_normal * 0.0015
        hip_name = next((b.name for b in armature.data.bones
                         if b.name.lower() in ("hips", "hip", "pelvis")), "Hips")
        create_socket(armature, "SOCKET_ClitoralHood", hood_location, hood_normal, hip_name)
    # Preserve shared-subdivision vertex identity through GLB indexed export.
    add_correspondence_uv_layer(skin.data)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature

    output_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_morph=True,
        export_animations=True,
        export_apply=False,
        export_vertex_color="ACTIVE",
    )

    colour = skin.data.color_attributes.get("Color")
    original_colour_vertices = len(colour.data) if colour else 0
    original_pigmented_vertices = skin.get("anatomy_pigmented_vertex_count", 0)
    original_skin_name = skin.name
    original_skin_vertices = len(skin.data.vertices)
    original_skin_faces = len(skin.data.polygons)
    original_anatomy_profile = skin.get("anatomy_profile", "")
    original_anatomy_method = skin.get("anatomy_method", "")

    # Verify the actual GLB payload by importing it again. This catches a
    # Blender-only colour layer that silently disappears during export.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=output_path)
    exported_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    exported_skin = max(
        (obj for obj in exported_meshes if "skin" in material_name(obj)),
        key=lambda obj: len(obj.data.polygons), default=None,
    )
    if exported_skin is None:
        raise RuntimeError("Exported GLB re-import contains no identifiable skin mesh")
    exported_colour = next(
        (attribute for attribute in exported_skin.data.color_attributes
         if len(attribute.data) in (len(exported_skin.data.vertices), len(exported_skin.data.loops))),
        None,
    )
    if exported_colour is None:
        raise RuntimeError("Anatomy pigmentation did not survive GLB export/re-import")
    exported_nonwhite = 0
    for item in exported_colour.data:
        rgba = item.color
        if any(abs(float(rgba[channel]) - 1.0) > 1e-4 for channel in range(3)):
            exported_nonwhite += 1
    if exported_nonwhite == 0:
        raise RuntimeError("Exported GLB contains a colour layer, but all values are white")

    report = {
        "input": os.path.abspath(args.input),
        "output": output_path,
        "height_metres": height,
        "hipline_z": hipline_z,
        "anatomy_z": anatomy_z,
        "deformation_scale": args.deformation_scale,
        "skin_mesh": original_skin_name,
        "skin_vertices": original_skin_vertices,
        "skin_faces": original_skin_faces,
        "colour_attribute_vertices": original_colour_vertices,
        "exported_colour_attribute": exported_colour.name,
        "exported_colour_vertices": len(exported_colour.data),
        "exported_nonwhite_colour_vertices": exported_nonwhite,
        "anatomy_pigmented_vertex_count": original_pigmented_vertices,
        "vertex_colour_export_mode": "ACTIVE",
        "anatomy_profile": original_anatomy_profile,
        "anatomy_method": original_anatomy_method,
        "anatomy_pigmented_vertex_count": original_pigmented_vertices,
        "clothing_operations": "not run",
    }
    if args.report:
        report_path = os.path.abspath(args.report)
        os.makedirs(os.path.dirname(report_path), exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2)
            handle.write("\n")
    print(json.dumps(report, indent=2))
    print("Exported anatomy-only adult female Ara variant. Multi-angle art review required.")


if __name__ == "__main__":
    main()
