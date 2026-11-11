#!/usr/bin/env python3
"""Instrument the existing female sculpt and male silhouette functions without changing anatomy.

Runs each production deformation against its raw Ara GLB, records in-memory vertex
movement, exports a temporary GLB, reimports it, and checks whether that movement
survived the round trip. No production asset is overwritten.
"""
import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree


def args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--female-raw", required=True)
    p.add_argument("--male-raw", required=True)
    p.add_argument("--work-dir", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--female-script", required=True)
    p.add_argument("--male-script", required=True)
    return p.parse_args(raw)


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_model(path):
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    skin = max((o for o in meshes if "skin" in " ".join(
        s.material.name.lower() for s in o.material_slots if s.material)),
        key=lambda o: len(o.data.polygons), default=None)
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if skin is None or armature is None:
        raise RuntimeError("Could not find Ara skin mesh and armature in " + str(path))
    return skin, armature


def world_points(skin):
    return [skin.matrix_world @ v.co for v in skin.data.vertices]


def movement(before, after, region_fn=None):
    deltas = []
    for i, (a, b) in enumerate(zip(before, after)):
        d = (b-a).length
        if region_fn is None or region_fn(a):
            deltas.append(d)
    moved = [d for d in deltas if d > 1e-8]
    return {
        "sample_vertices": len(deltas),
        "vertices_moved_over_0_01mm": sum(d > 0.00001 for d in deltas),
        "vertices_moved_over_0_1mm": sum(d > 0.0001 for d in deltas),
        "vertices_moved_over_1mm": sum(d > 0.001 for d in deltas),
        "max_displacement_m": max(deltas, default=0.0),
        "rms_displacement_m": (sum(d*d for d in deltas)/max(1,len(deltas)))**0.5,
        "moved_rms_displacement_m": (sum(d*d for d in moved)/max(1,len(moved)))**0.5,
    }


def dimensions(points):
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    h = hi[2]-lo[2]
    out = {"bounds_min_xyz": lo, "bounds_max_xyz": hi}
    for label, ratio in (("shoulders",.795),("chest",.685),("waist",.595),("pelvis",.485)):
        z = lo[2]+h*ratio
        band = [p for p in points if abs(p.z-z) <= h*.012]
        if band:
            out[label+"_width_m"] = max(p.x for p in band)-min(p.x for p in band)
    return out


def roundtrip(path, expected_points, region_fn=None):
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    skin = max((o for o in meshes if "skin" in " ".join(
        s.material.name.lower() for s in o.material_slots if s.material)),
        key=lambda o: len(o.data.polygons), default=None)
    if skin is None:
        raise RuntimeError("Export/reimport lost identifiable Ara skin mesh")
    actual = world_points(skin)
    tree = KDTree(len(expected_points))
    for i,p in enumerate(expected_points):
        tree.insert(p,i)
    tree.balance()
    distances = []
    for p in actual:
        if region_fn is not None and not region_fn(p):
            continue
        _co,_index,dist = tree.find(p)
        distances.append(dist)
    return {
        "reimported_vertices": len(actual),
        "expected_vertices": len(expected_points),
        "topology_vertex_count_matches": len(actual)==len(expected_points),
        "nearest_expected_vertex_distance": {
            "sample_vertices":len(distances),
            "max_m":max(distances,default=0.0),
            "rms_m":(sum(d*d for d in distances)/max(1,len(distances)))**0.5,
            "over_0_1mm":sum(d>0.0001 for d in distances),
            "over_1mm":sum(d>0.001 for d in distances),
        }
    }


def run_female(a, work):
    mod = load_module(a.female_script, "female_anatomy_audit_module")
    skin, armature = import_model(a.female_raw)
    before = world_points(skin)
    lo,hi = mod.mesh_world_bounds(skin)
    height=hi.z-lo.z
    width=max(hi.x-lo.x,.4)
    pelvis=mod.pelvis_landmark_from_leg_roots(armature,height)
    anatomy_z=pelvis-height*.035
    # This is the exact production deformation function, not a reimplementation.
    mod.integrate_anatomy_into_skin(skin,anatomy_z,width,height)
    after=world_points(skin)
    region=lambda p: abs(p.x)<=width*.27 and abs(p.z-anatomy_z)<=.15 and p.z>lo.z
    result={
        "input":a.female_raw,
        "skin_object":skin.name,
        "shape_keys":[k.name for k in skin.data.shape_keys.key_blocks] if skin.data.shape_keys else [],
        "anatomy_z_m":anatomy_z,
        "width_m":width,
        "before_vertex_count":len(before),
        "after_vertex_count":len(after),
        "topology_changed":len(before)!=len(after),
        "movement_all":movement(before,after),
        "movement_pelvic_band":movement(before,after,region),
        "raw_dimensions":dimensions(before),
        "deformed_dimensions":dimensions(after),
    }
    out=work/"female_deformation_roundtrip.glb"
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type in {"MESH","ARMATURE","EMPTY"}: o.select_set(True)
    bpy.context.view_layer.objects.active=armature
    bpy.ops.export_scene.gltf(filepath=str(out),export_format="GLB",use_selection=True,export_apply=False,export_animations=True)
    result["export_roundtrip"]=roundtrip(out,after,region)
    result["audit_glb"]=str(out)
    return result


def run_male(a, work):
    mod = load_module(a.male_script, "male_anatomy_audit_module")
    skin, armature = import_model(a.male_raw)
    before=world_points(skin)
    # Exact production silhouette operation, before genital geometry is added.
    mod.masculinise_body_mesh(skin)
    after=world_points(skin)
    lo,hi=mod.bounds(skin)
    height=hi.z-lo.z
    width=hi.x-lo.x
    region=lambda p: lo.z <= p.z <= hi.z
    result={
        "input":a.male_raw,
        "skin_object":skin.name,
        "shape_keys":[k.name for k in skin.data.shape_keys.key_blocks] if skin.data.shape_keys else [],
        "before_vertex_count":len(before),
        "after_vertex_count":len(after),
        "topology_changed":len(before)!=len(after),
        "movement_all":movement(before,after),
        "raw_dimensions":dimensions(before),
        "masculinised_dimensions":dimensions(after),
    }
    out=work/"male_silhouette_roundtrip.glb"
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type in {"MESH","ARMATURE","EMPTY"}: o.select_set(True)
    bpy.context.view_layer.objects.active=armature
    bpy.ops.export_scene.gltf(filepath=str(out),export_format="GLB",use_selection=True,export_apply=False,export_animations=True)
    result["export_roundtrip"]=roundtrip(out,after,region)
    result["audit_glb"]=str(out)
    return result


def main():
    a=args()
    work=Path(a.work_dir); work.mkdir(parents=True,exist_ok=True)
    female=run_female(a,work)
    male=run_male(a,work)
    report={
        "schema_version":1,
        "purpose":"Measure exact production deformation functions before and after GLB export/reimport; no production assets modified.",
        "female":female,
        "male":male,
        "interpretation":{
            "female_pelvic_movement":"If zero or near-zero, the production female deformation function is not moving sampled pelvic vertices.",
            "female_export":"Compare export_roundtrip nearest distances; large distances indicate the export/reimport did not preserve the deformed surface.",
            "male_silhouette":"movement_all and cross-section widths measure the actual production male torso deformation before anatomy is added.",
            "roundtrip":"Nearest-vertex comparison is a point-cloud preservation check, not a substitute for surface-distance or visual inspection."
        }
    }
    Path(a.output).parent.mkdir(parents=True,exist_ok=True)
    Path(a.output).write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,indent=2))


if __name__=="__main__":
    main()
