"""Join the backless dress bodice to its skirt and cut the side slit to the true hem."""
import argparse
import os
import sys

import bpy
import bmesh
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(raw)


def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return lo, hi


def material_faces(obj, token):
    found = []
    for poly in obj.data.polygons:
        if poly.material_index < len(obj.material_slots):
            material = obj.material_slots[poly.material_index].material
            if material and token in material.name.lower():
                found.append(poly)
    return found


def join_dress_meshes(meshes):
    dress_objects = [o for o in meshes if material_faces(o, "backless slit dress") or material_faces(o, "pencil skirt")]
    if not dress_objects:
        raise RuntimeError("Could not find the backless dress bodice or Pencil skirt")
    if len(dress_objects) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in dress_objects:
            obj.select_set(True)
        active = next((o for o in dress_objects if material_faces(o, "backless slit dress")), dress_objects[0])
        bpy.context.view_layer.objects.active = active
        bpy.ops.object.join()
        dress_objects = [active]
    return dress_objects[0]


def stitch_waist(obj):
    """Weld the two garment boundaries where the bodice meets the skirt."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    bodice_faces = [f for f in bm.faces
                    if f.material_index < len(obj.data.materials)
                    and obj.data.materials[f.material_index]
                    and "backless slit dress" in obj.data.materials[f.material_index].name.lower()]
    skirt_faces = [f for f in bm.faces
                   if f.material_index < len(obj.data.materials)
                   and obj.data.materials[f.material_index]
                   and "pencil skirt" in obj.data.materials[f.material_index].name.lower()]
    if not bodice_faces or not skirt_faces:
        bm.free()
        raise RuntimeError("Dress bodice and skirt material faces must both be present")
    bodice_min = min((obj.matrix_world @ v.co).z for f in bodice_faces for v in f.verts)
    skirt_max = max((obj.matrix_world @ v.co).z for f in skirt_faces for v in f.verts)
    seam_z = (bodice_min + skirt_max) * 0.5
    # Only select vertices close to the two waist boundaries, not the whole dress.
    seam_verts = set()
    inv = obj.matrix_world.inverted()
    for face in bodice_faces + skirt_faces:
        for vert in face.verts:
            world = obj.matrix_world @ vert.co
            if abs(world.z - seam_z) <= 0.035 or abs(world.z - bodice_min) <= 0.025 or abs(world.z - skirt_max) <= 0.025:
                seam_verts.add(vert)
    before = len(bm.verts)
    if seam_verts:
        bmesh.ops.remove_doubles(bm, verts=list(seam_verts), dist=0.014)
    merged = before - len(bm.verts)
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()
    print(f"Dress waist seam weld: {merged} vertices merged; bodice lower Z={bodice_min:.4f}, skirt upper Z={skirt_max:.4f}, seam Z={seam_z:.4f}", flush=True)


def cut_slit(obj, skin, armature):
    skirt_faces = material_faces(obj, "pencil skirt")
    if not skirt_faces:
        raise RuntimeError("Pencil skirt material is missing after dress join")
    skin_lo, skin_hi = world_bounds(skin)
    width = skin_hi.x - skin_lo.x
    body_centre_x = (skin_lo.x + skin_hi.x) * 0.5
    skirt_points = [obj.matrix_world @ obj.data.vertices[i].co
                    for face in skirt_faces for i in face.vertices]
    hem_z = min(p.z for p in skirt_points)
    hips = next((b for b in armature.data.bones
                 if b.name.lower() in ("hips", "hip", "pelvis")), None)
    if hips is None:
        raise RuntimeError("Ara rig has no Hips/Pelvis bone")
    pelvis_z = (armature.matrix_world @ ((hips.head_local + hips.tail_local) * 0.5)).z
    upper_z = pelvis_z - (skin_hi.z - skin_lo.z) * 0.28
    slit_x = body_centre_x + width * 0.155
    half_width = width * 0.038

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    remove = []
    for face in bm.faces:
        if face.material_index >= len(obj.data.materials):
            continue
        material = obj.data.materials[face.material_index]
        if not material or "pencil skirt" not in material.name.lower():
            continue
        points = [obj.matrix_world @ v.co for v in face.verts]
        centre = sum(points, Vector()) / len(points)
        x_overlap = min(p.x for p in points) <= slit_x + half_width and max(p.x for p in points) >= slit_x - half_width
        z_overlap = max(p.z for p in points) >= hem_z - 0.002 and min(p.z for p in points) <= upper_z
        if x_overlap and z_overlap:
            remove.append(face)
    print(f"Side slit: hem Z={hem_z:.4f}, upper Z={upper_z:.4f}, X={slit_x:.4f}, width={half_width*2:.4f}, faces={len(remove)}", flush=True)
    if len(remove) < 4:
        bm.free()
        raise RuntimeError(f"Could not cut a continuous side slit through the skirt hem ({len(remove)} faces)")
    bmesh.ops.delete(bm, geom=remove, context="FACES")
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()


def duplicate_dress_variant_v2(source):
    """Create a second isolated dress mesh while retaining the original garment."""
    variant = source.copy()
    variant.data = source.data.copy()
    variant.name = "Backless Slit Dress V2"
    bpy.context.collection.objects.link(variant)
    for index, material in enumerate(list(variant.data.materials)):
        if material is None:
            continue
        lower = material.name.lower()
        if "backless slit dress" in lower or "pencil skirt" in lower:
            copied = material.copy()
            copied.name = "Backless slit dress v2" if "backless slit dress" in lower else "Pencil skirt v2"
            variant.data.materials[index] = copied
    bm = bmesh.new()
    bm.from_mesh(variant.data)
    keep_indices = {i for i, material in enumerate(variant.data.materials)
                    if material and ("backless slit dress v2" in material.name.lower() or "pencil skirt v2" in material.name.lower())}
    remove = [face for face in bm.faces if face.material_index not in keep_indices]
    if remove:
        bmesh.ops.delete(bm, geom=remove, context="FACES")
    loose_edges = [edge for edge in bm.edges if not edge.link_faces]
    if loose_edges:
        bmesh.ops.delete(bm, geom=loose_edges, context="EDGES")
    loose_verts = [vert for vert in bm.verts if not vert.link_edges]
    if loose_verts:
        bmesh.ops.delete(bm, geom=loose_verts, context="VERTS")
    bm.to_mesh(variant.data)
    variant.data.update()
    bm.free()
    return variant


def cut_tapered_slit(obj, skin, armature):
    """Cut a clean triangular opening, starting almost closed and reaching the hem."""
    skirt_faces = material_faces(obj, "pencil skirt v2")
    if not skirt_faces:
        raise RuntimeError("Pencil skirt v2 material is missing")
    skin_lo, skin_hi = world_bounds(skin)
    body_width = skin_hi.x - skin_lo.x
    body_centre_x = (skin_lo.x + skin_hi.x) * 0.5
    skirt_points = [obj.matrix_world @ obj.data.vertices[i].co for face in skirt_faces for i in face.vertices]
    hem_z = min(point.z for point in skirt_points)
    hips = next((bone for bone in armature.data.bones if bone.name.lower() in ("hips", "hip", "pelvis")), None)
    if hips is None:
        raise RuntimeError("Ara rig has no Hips/Pelvis bone")
    pelvis_z = (armature.matrix_world @ ((hips.head_local + hips.tail_local) * 0.5)).z
    upper_z = pelvis_z - (skin_hi.z - skin_lo.z) * 0.28
    slit_x = body_centre_x + body_width * 0.155
    top_width = body_width * 0.004
    bottom_width = body_width * 0.057
    if upper_z <= hem_z:
        raise RuntimeError("Tapered slit start is not above the skirt hem")
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    def current_skirt_faces():
        return [face for face in bm.faces if face.material_index < len(obj.data.materials)
                and obj.data.materials[face.material_index]
                and "pencil skirt v2" in obj.data.materials[face.material_index].name.lower()]
    def bisect_skirt(plane_co_world, plane_no_world):
        faces = current_skirt_faces()
        verts = {vert for face in faces for vert in face.verts}
        edges = {edge for face in faces for edge in face.edges}
        inverse = obj.matrix_world.inverted()
        plane_co = inverse @ plane_co_world
        plane_no = (obj.matrix_world.to_3x3().transposed() @ plane_no_world).normalized()
        bmesh.ops.bisect_plane(bm, geom=list(verts) + list(edges) + faces, dist=0.000001,
                               plane_co=plane_co, plane_no=plane_no, clear_inner=False, clear_outer=False)
    y_mid = (skin_lo.y + skin_hi.y) * 0.5
    top_half, bottom_half = top_width * 0.5, bottom_width * 0.5
    vertical_span = upper_z - hem_z
    left_top, left_bottom = slit_x - top_half, slit_x - bottom_half
    right_top, right_bottom = slit_x + top_half, slit_x + bottom_half
    bisect_skirt(Vector((left_top, y_mid, upper_z)), Vector((1.0, 0.0, (left_bottom - left_top) / vertical_span)))
    bisect_skirt(Vector((right_top, y_mid, upper_z)), Vector((1.0, 0.0, (right_bottom - right_top) / vertical_span)))
    bisect_skirt(Vector((slit_x, y_mid, upper_z)), Vector((0.0, 0.0, 1.0)))
    bisect_skirt(Vector((slit_x, y_mid, hem_z)), Vector((0.0, 0.0, 1.0)))
    remove = []
    for face in current_skirt_faces():
        centre = obj.matrix_world @ face.calc_center_median()
        if centre.z < hem_z - 0.002 or centre.z > upper_z + 0.002:
            continue
        t = max(0.0, min(1.0, (upper_z - centre.z) / vertical_span))
        half_width = top_half + (bottom_half - top_half) * t
        if abs(centre.x - slit_x) <= half_width + 0.0005:
            remove.append(face)
    if len(remove) < 2:
        bm.free()
        raise RuntimeError("Tapered slit did not intersect enough skirt faces")
    bmesh.ops.delete(bm, geom=remove, context="FACES")
    loose_edges = [edge for edge in bm.edges if not edge.link_faces]
    if loose_edges:
        bmesh.ops.delete(bm, geom=loose_edges, context="EDGES")
    loose_verts = [vert for vert in bm.verts if not vert.link_edges]
    if loose_verts:
        bmesh.ops.delete(bm, geom=loose_verts, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()
    print("Tapered dress v2 slit: top width %.5f, hem width %.5f, removed %d faces" % (top_width, bottom_width, len(remove)), flush=True)

def main():
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    skin = next((o for o in meshes if any(s.material and "skin" in s.material.name.lower()
                                          for s in o.material_slots)), None)
    if not meshes or armature is None or skin is None:
        raise RuntimeError("Expected skinned Ara model, armature and Skin material")
    dress = join_dress_meshes(meshes)
    stitch_waist(dress)
    dress_v2 = duplicate_dress_variant_v2(dress)
    cut_slit(dress, skin, armature)
    cut_tapered_slit(dress_v2, skin, armature)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False, export_animations=True)
    print("Exported original dress plus tapered v2; both variants remain independently selectable")


if __name__ == "__main__":
    main()
