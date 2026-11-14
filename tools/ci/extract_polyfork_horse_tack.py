#!/usr/bin/env python3
"""Extract and fit Polyfork's named saddle and bridle meshes for Silverhart.

The source mesh is used under CC BY 4.0. Only the two named tack meshes are
retained; the source horse, rig and unrelated geometry are not redistributed.
"""
from __future__ import annotations
import json, math, pathlib, struct, sys


def read_glb(path: pathlib.Path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total != len(data):
        raise ValueError("Not a valid GLB 2.0 file")
    offset, doc, binary = 12, None, None
    while offset < len(data):
        length, kind = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk = data[offset:offset + length]
        offset += length
        if kind == b"JSON":
            doc = json.loads(chunk.rstrip(b" \\t\\r\\n\\0"))
        elif kind == b"BIN\\0":
            binary = chunk
    if doc is None or binary is None:
        raise ValueError("GLB is missing JSON or BIN chunk")
    return doc, binary


def extract(doc, binary, node_name, output, scale, offset):
    node = next((n for n in doc["nodes"] if n.get("name") == node_name), None)
    if node is None or not node.get("children"):
        raise ValueError(f"Missing mesh node {node_name}")
    mesh_node = doc["nodes"][node["children"][0]]
    primitive = doc["meshes"][mesh_node["mesh"]]["primitives"][0]
    attrs = primitive["attributes"]
    packed, views, accessors = bytearray(), [], []
    for semantic in ("POSITION", "COLOR_0", "NORMAL"):
        accessor = doc["accessors"][attrs[semantic]]
        view = doc["bufferViews"][accessor["bufferView"]]
        count = accessor["count"]
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        if accessor["componentType"] != 5126 or accessor["type"] != "VEC3":
            raise ValueError(f"Unexpected {semantic} accessor layout")
        values = list(struct.iter_unpack("<3f", binary[start:start + count * 12]))
        if semantic == "POSITION":
            values = [(v[0]*scale[0]+offset[0], v[1]*scale[1]+offset[1], v[2]*scale[2]+offset[2]) for v in values]
            bounds = {"min": [min(v[i] for v in values) for i in range(3)],
                      "max": [max(v[i] for v in values) for i in range(3)]}
        elif semantic == "NORMAL":
            converted = []
            for v in values:
                n = (v[0]/scale[0], v[1]/scale[1], v[2]/scale[2])
                length = math.sqrt(sum(x*x for x in n)) or 1.0
                converted.append(tuple(x/length for x in n))
            values = converted
        byte_start = len(packed)
        for value in values:
            packed.extend(struct.pack("<3f", *value))
        view_index = len(views)
        views.append({"buffer": 0, "byteOffset": byte_start,
                      "byteLength": len(packed)-byte_start,
                      "target": 34962, "byteStride": 12})
        new_accessor = {"bufferView": view_index, "componentType": 5126,
                        "count": count, "type": "VEC3"}
        if semantic == "POSITION":
            new_accessor.update(bounds)
        accessors.append(new_accessor)
    root_name = "SaddleAsset" if node_name == "attach-saddle" else "BridleAsset"
    out_doc = {
        "asset": {"version": "2.0", "generator": "Silverhart Saga tack extraction"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"name": root_name, "children": [1]},
                  {"name": node_name + "-mesh", "mesh": 0}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "COLOR_0": 1, "NORMAL": 2},
                                    "material": 0}]}],
        "materials": doc.get("materials", [{"pbrMetallicRoughness": {"metallicFactor": 0,
                         "roughnessFactor": 0.85}, "doubleSided": True}]),
        "buffers": [{"byteLength": len(packed)}],
        "bufferViews": views, "accessors": accessors,
    }
    json_chunk = json.dumps(out_doc, separators=(",", ":")).encode()
    json_chunk += b" " * ((4-len(json_chunk)%4)%4)
    bin_chunk = bytes(packed)
    bin_chunk += b"\\0" * ((4-len(bin_chunk)%4)%4)
    total = 12 + 8 + len(json_chunk) + 8 + len(bin_chunk)
    output.write_bytes(struct.pack("<4sII", b"glTF", 2, total) +
                       struct.pack("<I4s", len(json_chunk), b"JSON") + json_chunk +
                       struct.pack("<I4s", len(bin_chunk), b"BIN\\0") + bin_chunk)
    print(f"{output}: {len(output.read_bytes())} bytes; {count} vertices; {bounds}")


def main():
    source, output = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    output.mkdir(parents=True, exist_ok=True)
    doc, binary = read_glb(source)
    # Independent transforms account for the longer neck of the Quaternius horse.
    extract(doc, binary, "attach-saddle", output/"horse_saddle.glb",
            (1.25, 1.25, 1.25), (0.0, 2.10, -0.20))
    extract(doc, binary, "attach-bridle", output/"horse_bridle.glb",
            (1.15, 1.15, 1.15), (0.0, 2.10, 2.10))
    (output/"ATTRIBUTION.md").write_text(
        "# Horse tack mesh attribution\\n\\n"
        "Extracted and modified from **Saddled Horse** by Polyfork: "
        "https://polyfork.dev/asset/saddled-horse-da86d3\\n\\n"
        "Licensed under **Creative Commons Attribution 4.0 International "
        "(CC BY 4.0)**: https://creativecommons.org/licenses/by/4.0/\\n\\n"
        "Changes: extracted the named saddle and bridle meshes, removed source "
        "rig weights, retained vertex colours and normals, and applied separate "
        "fitting transforms for Silverhart's Quaternius horse.\\n",
        encoding="utf-8")


if __name__ == "__main__":
    main()
