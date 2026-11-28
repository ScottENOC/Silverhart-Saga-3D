#!/usr/bin/env python3
"""Attach locally generated Ara bikini geometry to the immutable accepted Wren GLB.

The garment OBJ is in Ara's +Y-up/+Z-front coordinates and metres. Blender's
glTF importer maps that frame to Z-up/-Y-front, so the OBJ vertices receive the
same (x, -z, y) conversion. No Wren mesh, material, armature, or skin is edited.
"""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input-glb", required=True)
    p.add_argument("--garment-obj", required=True)
    p.add_argument("--generation-report", required=True)
    p.add_argument("--output-glb", required=True)
    p.add_argument("--report", required=True)
    return p.parse_args(raw)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def read_mtl(path):
    materials = {}
    current = None
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        key, values = fields[0], fields[1:]
        if key == "newmtl":
            current = {"name": " ".join(values), "colour": (1, 1, 1), "roughness": 0.4, "metallic": 0.5, "opacity": 1.0}
            materials[current["name"]] = current
        elif current is not None and key == "Kd" and len(values) >= 3:
            current["colour"] = tuple(float(x) for x in values[:3])
        elif current is not None and key == "Pr" and values:
            current["roughness"] = max(0.0, min(1.0, float(values[0])))
        elif current is not None and key == "Pm" and values:
            current["metallic"] = max(0.0, min(1.0, float(values[0])))
        elif current is not None and key == "d" and values:
            current["opacity"] = max(0.0, min(1.0, float(values[0])))
        elif current is not None and key == "map_Kd" and values:
            current["texture"] = " ".join(values)
    return materials


def blender_material(spec, folder):
    mat = bpy.data.materials.new(spec["name"])
    mat.diffuse_color = (*spec["colour"], spec["opacity"])
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*spec["colour"], spec["opacity"])
    bsdf.inputs["Roughness"].default_value = spec["roughness"]
    bsdf.inputs["Metallic"].default_value = spec["metallic"]
    if spec.get("texture"):
        image_path = os.path.join(folder, spec["texture"])
        if not os.path.isfile(image_path):
            raise FileNotFoundError(image_path)
        image = bpy.data.images.load(image_path, check_existing=True)
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if spec["opacity"] < 1:
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "DITHERED"
        elif hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"
        bsdf.inputs["Alpha"].default_value = spec["opacity"]
    return mat


def parse_obj(path):
    vertices, uvs, faces = [], [], []
    current_material = None
    face_materials = []
    face_uvs = []
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if fields[0] == "v":
            x, y, z = map(float, fields[1:4])
            # Same coordinate conversion applied by Blender's glTF importer.
            vertices.append((x, -z, y))
        elif fields[0] == "vt":
            u, v = map(float, fields[1:3])
            uvs.append((u, v))
        elif fields[0] == "usemtl":
            current_material = " ".join(fields[1:])
        elif fields[0] == "f":
            v_indices, uv_indices = [], []
            for token in fields[1:]:
                bits = token.split("/")
                v_indices.append(int(bits[0]) - 1)
                uv_indices.append(int(bits[1]) - 1 if len(bits) > 1 and bits[1] else -1)
            faces.append(v_indices)
            face_uvs.append(uv_indices)
            face_materials.append(current_material)
    if not vertices or not faces:
        raise RuntimeError("Ara OBJ contains no usable vertices/faces")
    return vertices, uvs, faces, face_uvs, face_materials


def main():
    opt = arguments()
    body_path, obj_path, out_path = map(os.path.abspath, (opt.input_glb, opt.garment_obj, opt.output_glb))
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=body_path)
    body_objects = list(bpy.context.scene.objects)
    body_meshes = [o for o in body_objects if o.type == "MESH"]
    armatures = [o for o in body_objects if o.type == "ARMATURE"]
    if not body_meshes or not armatures:
        raise RuntimeError("Accepted Wren GLB must contain both body meshes and its original armature")
    original_mesh_vertices = sum(len(o.data.vertices) for o in body_meshes)
    original_armature_names = sorted(o.name for o in armatures)

    vertices, uvs, faces, face_uvs, face_materials = parse_obj(obj_path)
    mtl_path = os.path.splitext(obj_path)[0] + ".mtl"
    specs = read_mtl(mtl_path)
    mats = {name: blender_material(spec, os.path.dirname(obj_path)) for name, spec in specs.items()}
    mesh = bpy.data.meshes.new("Wren_Ara_Bikini_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    garment = bpy.data.objects.new("Wren_Ara_Bikini", mesh)
    bpy.context.scene.collection.objects.link(garment)
    for name, mat in mats.items():
        mesh.materials.append(mat)
    material_index = {name: i for i, name in enumerate(mats)}
    uv_layer = mesh.uv_layers.new(name="AraUV")
    for poly, uv_indices, mat_name in zip(mesh.polygons, face_uvs, face_materials):
        if mat_name not in material_index:
            raise RuntimeError("Missing Ara garment material: " + str(mat_name))
        poly.material_index = material_index[mat_name]
        for loop_index, uv_index in zip(poly.loop_indices, uv_indices):
            if uv_index >= 0:
                uv_layer.data[loop_index].uv = uvs[uv_index]
    for poly in mesh.polygons:
        poly.use_smooth = True

    # Ara has already generated this garment against the accepted Wren skin and piercing surface.
    # Do not extend, project or deform it here: that would reintroduce post-generation repair.
    with open(opt.generation_report, "r", encoding="utf-8") as f:
        generation = json.load(f)
    if generation.get("bodySource") != "accepted Wren GLB geometry":
        raise RuntimeError("Garment was not generated against the accepted Wren body")
    if generation.get("piercingGeometryUsedDuringGeneration") is not True:
        raise RuntimeError("Garment generation did not include piercing collision geometry")
    if generation.get("bodySurfaceSha256") != sha256(body_path):
        raise RuntimeError("Garment fitting surface does not match the accepted Wren GLB")
    piercing_objects = sorted(
        o.name for o in body_objects
        if o.type == "MESH" and o.name.lower().startswith("piercing")
    )
    if not piercing_objects:
        raise RuntimeError("Accepted Wren GLB contains no preserved piercing objects")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in body_objects + [garment]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = garment
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format="GLB", use_selection=True,
        export_apply=False, export_animations=True,
    )
    if not os.path.isfile(out_path) or os.path.getsize(out_path) < 1000:
        raise RuntimeError("GLB export failed or was unexpectedly small")
    report = {
        "accepted_wren_input": body_path,
        "accepted_wren_sha256": sha256(body_path),
        "output_glb": out_path,
        "garment_obj": obj_path,
        "garment_sha256": sha256(obj_path),
        "generation_report": os.path.abspath(opt.generation_report),
        "original_body_mesh_count": len(body_meshes),
        "original_body_vertex_count": original_mesh_vertices,
        "original_armatures": original_armature_names,
        "preserved_piercing_objects": piercing_objects,
        "garment_vertex_count": len(vertices),
        "garment_face_count": len(faces),
        "garment_materials": sorted(mats),
        "garment_generated_against_accepted_body": True,
        "piercing_geometry_used_during_generation": True,
        "post_generation_vertex_corrections": 0,
        "body_meshes_modified": False,
        "body_meshes_hidden_or_deleted": False,
        "original_armature_preserved": True,
        "garment_is_static_preview_geometry": True,
    }
    Path(opt.report).parent.mkdir(parents=True, exist_ok=True)
    Path(opt.report).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("WREN_ACCEPTED_BODY_WITH_ARA_GARMENT_OK", json.dumps(report))


if __name__ == "__main__":
    main()
