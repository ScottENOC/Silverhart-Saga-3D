#!/usr/bin/env python3
"""Build diagnostic garment-to-skin surface correspondence from an Ara GLB.

This pass does not deform or export character geometry. It maps each garment
vertex to the nearest triangle on the actual skin surface and records
barycentric weights so later body-morph deltas can be transferred without
guessing by vertex index or using one global clearance offset.
"""
import argparse
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "ara"))
from garment_correspondence import barycentric_weights
from garment_fit import profile_for_material

GARMENT_TOKENS = (
    "bra", "brief", "bikini", "g-string", "underwear", "pants",
    "trouser", "shirt", "tank", "dress", "lace", "fishnet",
)


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Combined body + garment GLB")
    parser.add_argument("--output", required=True, help="JSON correspondence report")
    parser.add_argument("--max-distance-m", type=float, default=0.08)
    return parser.parse_args(raw)


def material_label(obj, polygon):
    index = polygon.material_index
    if index >= len(obj.material_slots):
        return ""
    material = obj.material_slots[index].material
    return material.name.strip() if material else ""


def build_skin_surface(objects):
    vertices = []
    triangles = []
    sources = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        skin_material_indices = {
            index for index, slot in enumerate(obj.material_slots)
            if slot.material and "skin" in slot.material.name.lower()
        }
        if not skin_material_indices:
            continue
        offset = len(vertices)
        vertices.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
        face_count = 0
        for polygon in obj.data.polygons:
            if polygon.material_index not in skin_material_indices or len(polygon.vertices) < 3:
                continue
            face = [offset + int(index) for index in polygon.vertices]
            for index in range(1, len(face) - 1):
                triangles.append((face[0], face[index], face[index + 1]))
                face_count += 1
        if face_count:
            sources.append({"object": obj.name, "triangles": face_count})
    if not vertices or not triangles:
        raise RuntimeError("No triangulatable skin-material surface was found")
    tree = BVHTree.FromPolygons(vertices, triangles, all_triangles=True)
    if tree is None:
        raise RuntimeError("Could not build BVH for the skin surface")
    return vertices, triangles, tree, sources


def collect_garment_vertices(objects):
    groups = defaultdict(set)
    for obj in objects:
        if obj.type != "MESH":
            continue
        for polygon in obj.data.polygons:
            label = material_label(obj, polygon)
            if not label or not any(token in label.lower() for token in GARMENT_TOKENS):
                continue
            groups[(obj.name, label)].update(int(index) for index in polygon.vertices)
    return groups


def map_group(obj, label, vertex_indices, body_vertices, body_triangles, body_tree, max_distance):
    positions = []
    weights = []
    distances = []
    triangle_ids = []
    rejected = 0
    for vertex_index in sorted(vertex_indices):
        point = obj.matrix_world @ obj.data.vertices[vertex_index].co
        nearest = body_tree.find_nearest(point)
        if nearest is None or nearest[0] is None or nearest[2] < 0:
            positions.append(vertex_index)
            weights.append(None)
            distances.append(None)
            triangle_ids.append(None)
            rejected += 1
            continue
        surface_point, _normal, triangle_index, distance = nearest
        triangle = body_triangles[triangle_index]
        a, b, c = (body_vertices[index] for index in triangle)
        distance = float(distance)
        if distance > max_distance:
            positions.append(vertex_index)
            weights.append(None)
            distances.append(distance)
            triangle_ids.append(None)
            rejected += 1
            continue
        try:
            bary = barycentric_weights(
                tuple(surface_point), tuple(a), tuple(b), tuple(c),
            )
        except ValueError:
            positions.append(vertex_index)
            weights.append(None)
            distances.append(distance)
            triangle_ids.append(None)
            rejected += 1
            continue
        positions.append(vertex_index)
        weights.append([round(value, 8) for value in bary])
        distances.append(round(distance, 7))
        triangle_ids.append(list(triangle))

    valid_distances = [value for value in distances if value is not None and value <= max_distance]
    profile = profile_for_material(label)
    return {
        "object": obj.name,
        "material": label,
        "fabric_profile": profile["name"],
        "construction": profile["construction"],
        "coverage_mode": profile["coverage_mode"],
        "vertex_indices": positions,
        "body_triangle_vertex_indices": triangle_ids,
        "barycentric_weights": weights,
        "distance_m": distances,
        "summary": {
            "garment_vertices": len(positions),
            "mapped_vertices": len(valid_distances),
            "rejected_vertices": rejected,
            "mapped_fraction": round(len(valid_distances) / max(len(positions), 1), 5),
            "mean_surface_distance_m": round(sum(valid_distances) / max(len(valid_distances), 1), 6),
            "max_surface_distance_m": round(max(valid_distances, default=0.0), 6),
        },
    }


def main():
    args = arguments()
    if args.max_distance_m <= 0:
        raise ValueError("--max-distance-m must be positive")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    objects = list(bpy.context.scene.objects)

    body_vertices, body_triangles, body_tree, skin_sources = build_skin_surface(objects)
    groups = collect_garment_vertices(objects)
    if not groups:
        raise RuntimeError("No supported garment material groups found in input GLB")

    entries = []
    for (object_name, label), indices in sorted(groups.items()):
        obj = bpy.data.objects.get(object_name)
        if obj is None:
            raise RuntimeError(f"Garment mesh disappeared during inspection: {object_name}")
        entry = map_group(
            obj, label, indices, body_vertices, body_triangles, body_tree,
            args.max_distance_m,
        )
        entries.append(entry)
        summary = entry["summary"]
        print(
            f"Surface map {object_name}/{label}: "
            f"{summary['mapped_vertices']}/{summary['garment_vertices']} vertices "
            f"({summary['mapped_fraction']:.1%}), max="
            f"{summary['max_surface_distance_m']:.4f}m, "
            f"rejected={summary['rejected_vertices']}"
        )

    report = {
        "schema_version": 1,
        "input": os.path.abspath(args.input),
        "mapping_method": "nearest_skin_triangle_barycentric",
        "geometry_modified": False,
        "max_distance_m": args.max_distance_m,
        "skin_surface": {
            "vertex_count": len(body_vertices),
            "triangle_count": len(body_triangles),
            "sources": skin_sources,
        },
        "garments": entries,
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, separators=(",", ":")) + "\n")
    print(f"Wrote diagnostic surface correspondence: {output}")


if __name__ == "__main__":
    main()
