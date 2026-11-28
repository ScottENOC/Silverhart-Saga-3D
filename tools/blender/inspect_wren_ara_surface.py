#!/usr/bin/env python3
"""Inspect the accepted Wren GLB as input to the Ara body-surface adapter.

Read-only: imports the GLB and writes a structural report. It never changes or
exports the accepted character asset.
"""
import argparse
import json
import os
import sys

import bpy
from mathutils import Vector


def args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input-glb", required=True)
    p.add_argument("--report", required=True)
    return p.parse_args(raw)


def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return {
        "min": [min(p[i] for p in points) for i in range(3)],
        "max": [max(p[i] for p in points) for i in range(3)],
    }


def main():
    opt = args()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(opt.input_glb))
    objects = []
    for obj in sorted(bpy.context.scene.objects, key=lambda x: x.name):
        item = {
            "name": obj.name,
            "type": obj.type,
            "parent": obj.parent.name if obj.parent else None,
            "world_bounds": world_bounds(obj) if obj.type == "MESH" else None,
        }
        if obj.type == "MESH":
            mesh = obj.data
            item.update({
                "vertices": len(mesh.vertices),
                "edges": len(mesh.edges),
                "polygons": len(mesh.polygons),
                "polygon_size_histogram": {
                    str(n): sum(1 for p in mesh.polygons if len(p.vertices) == n)
                    for n in sorted({len(p.vertices) for p in mesh.polygons})
                },
                "materials": [m.name if m else None for m in mesh.materials],
                "vertex_groups": [
                    {"name": g.name, "index": g.index}
                    for g in obj.vertex_groups
                ],
                "armature_modifiers": [
                    m.object.name for m in obj.modifiers
                    if m.type == "ARMATURE" and m.object
                ],
                "custom_attributes": [
                    {"name": a.name, "domain": a.domain, "data_type": a.data_type}
                    for a in mesh.attributes
                ],
            })
        elif obj.type == "ARMATURE":
            item["bones"] = [
                {
                    "name": b.name,
                    "parent": b.parent.name if b.parent else None,
                    "head_local": list(b.head_local),
                    "tail_local": list(b.tail_local),
                    "deform": b.use_deform,
                }
                for b in obj.data.bones
            ]
        objects.append(item)

    meshes = [o for o in objects if o["type"] == "MESH"]
    armatures = [o for o in objects if o["type"] == "ARMATURE"]
    report = {
        "input_glb": os.path.abspath(opt.input_glb),
        "coordinate_system": "Blender scene coordinates after glTF import",
        "mesh_count": len(meshes),
        "armature_count": len(armatures),
        "objects": objects,
        "likely_piercing_candidates": [
            o for o in meshes
            if any(token in (o["name"] + " " + " ".join(str(x) for x in o["materials"])).lower()
                   for token in ("pierc", "nipple", "jewel", "ring", "stud", "barbell"))
        ],
        "read_only_inspection": True,
    }
    os.makedirs(os.path.dirname(os.path.abspath(opt.report)), exist_ok=True)
    with open(opt.report, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print("WREN_GLTF_SURFACE_INSPECTION_OK", json.dumps({
        "mesh_count": len(meshes),
        "armature_count": len(armatures),
        "mesh_summaries": [
            {k: o.get(k) for k in ("name", "vertices", "polygons", "materials", "vertex_groups", "armature_modifiers")}
            for o in meshes
        ],
        "armatures": [{"name": a["name"], "bones": [b["name"] for b in a.get("bones", [])]} for a in armatures],
        "likely_piercing_candidates": [o["name"] for o in report["likely_piercing_candidates"]],
    }))


if __name__ == "__main__":
    main()
