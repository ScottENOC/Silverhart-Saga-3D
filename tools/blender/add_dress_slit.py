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
    cut_slit(dress, skin, armature)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False, export_animations=True)
    print("Exported stitched bodice/skirt dress with side slit reaching the actual hem")


if __name__ == "__main__":
    main()
