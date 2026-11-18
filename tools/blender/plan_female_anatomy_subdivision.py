#!/usr/bin/env python3
"""Create one deterministic subdivision plan from the neutral Ara female base.

The plan stores exact edge-index operations and the resulting topology. Low and
high body exports must have the same source topology before the plan is applied.
"""
import argparse
import json
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from add_female_anatomy_surface import (
    FEMALE_ANATOMY, _surface_midline, _locate_introitus, _prep_line,
    _project_many, material_name, mesh_world_bounds,
    pelvis_landmark_from_leg_roots,
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def topology(mesh):
    return {
        "vertices": len(mesh.vertices),
        "faces": [list(poly.vertices) for poly in mesh.polygons],
    }


def main():
    import bmesh
    args = parse_args()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    skin = max(
        (obj for obj in meshes if "skin" in material_name(obj)),
        key=lambda obj: len(obj.data.polygons), default=None
    )
    if skin is None or armature is None:
        raise RuntimeError("Neutral Ara export is missing its skin mesh or armature")

    bounds = [mesh_world_bounds(obj) for obj in meshes]
    minimum = Vector(tuple(min(b[0][i] for b in bounds) for i in range(3)))
    maximum = Vector(tuple(max(b[1][i] for b in bounds) for i in range(3)))
    height = maximum.z - minimum.z
    hipline_z = pelvis_landmark_from_leg_roots(armature, height)
    k = height / 1.687
    line, arc = _surface_midline(skin, hipline_z, k)
    iA = _locate_introitus(line, arc, k)
    sA = arc[iA]
    prep = _prep_line(line, arc)
    mw = skin.matrix_world
    z_lo, z_hi = hipline_z - 0.15 * k, hipline_z + 0.10 * k
    t_lo = FEMALE_ANATOMY["t_fourchette"] - 0.025
    t_ref_hi = FEMALE_ANATOMY["t_hood"] + 0.030
    target = FEMALE_ANATOMY["target_edge"] * k

    def coords_for(points):
        s_arr, dist = _project_many(prep, [p.y for p in points], [p.z for p in points])
        return (sA - s_arr) / k, dist / k

    source_topology = topology(skin.data)
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    bm.normal_update()
    passes = []
    for pass_index in range(4):
        bm.verts.ensure_lookup_table()
        bm.verts.index_update()
        candidates = []
        for face in bm.faces:
            centre = mw @ face.calc_center_median()
            if (abs(centre.x) <= 0.042 * k and z_lo <= centre.z <= z_hi
                    and centre.y < 0.02
                    and face.calc_perimeter() / len(face.verts) > target * 1.6):
                candidates.append((face, centre))
        if not candidates:
            break
        ts, ds = coords_for([centre for _face, centre in candidates])
        selected = [
            face for (face, _centre), t, distance in zip(candidates, ts, ds)
            if t_lo <= t <= t_ref_hi and distance <= 0.016
        ]
        if not selected:
            break
        edge_keys = sorted({
            tuple(sorted((edge.verts[0].index, edge.verts[1].index)))
            for face in selected for edge in face.edges
        })
        if not edge_keys:
            break
        edge_lookup = {
            tuple(sorted((edge.verts[0].index, edge.verts[1].index))): edge
            for edge in bm.edges
        }
        edges = [edge_lookup[key] for key in edge_keys]
        passes.append([list(key) for key in edge_keys])
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True)
        bm.verts.ensure_lookup_table()
        bm.verts.index_update()
        bm.edges.ensure_lookup_table()
        bm.faces.ensure_lookup_table()
        bm.normal_update()

    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    subdivided_topology = {
        "vertices": len(bm.verts),
        "faces": [[vertex.index for vertex in face.verts] for face in bm.faces],
    }
    bm.free()
    plan = {
        "schema": 1,
        "source_mesh": skin.name,
        "source_topology": source_topology,
        "passes": passes,
        "subdivided_topology": subdivided_topology,
        "reference": os.path.abspath(args.input),
        "target_edge_metres": FEMALE_ANATOMY["target_edge"] * k,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(plan, handle, indent=2)
        handle.write("\n")
    print(json.dumps({
        "source_vertices": source_topology["vertices"],
        "source_faces": len(source_topology["faces"]),
        "passes": [len(p) for p in passes],
        "subdivided_vertices": subdivided_topology["vertices"],
        "subdivided_faces": len(subdivided_topology["faces"]),
        "plan": os.path.abspath(args.output),
    }, indent=2))


if __name__ == "__main__":
    main()
