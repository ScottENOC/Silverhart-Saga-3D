#!/usr/bin/env python3
"""Compare two Ara GLB exports for stable vertex/index topology.

This is a compatibility probe, not a mesh retargeter. Matching topology means
the two exports can be considered for direct vertex-delta blend-shape creation.
"""
from __future__ import annotations

import argparse
import json
import math
import struct
from pathlib import Path
from typing import Any


_COMPONENTS = {
    5121: ("B", 1),
    5123: ("H", 2),
    5125: ("I", 4),
    5126: ("f", 4),
}
_TYPE_WIDTHS = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
    "MAT2": 4,
    "MAT3": 9,
    "MAT4": 16,
}


def read_glb(path: str | Path) -> tuple[dict[str, Any], bytes]:
    payload = Path(path).read_bytes()
    if len(payload) < 20:
        raise ValueError(f"{path}: file is too short to be a GLB")
    magic, version, declared_length = struct.unpack_from("<4sII", payload, 0)
    if magic != b"glTF" or version != 2 or declared_length != len(payload):
        raise ValueError(f"{path}: invalid GLB 2.0 header")
    offset = 12
    document = None
    binary = None
    while offset + 8 <= len(payload):
        chunk_length, chunk_type = struct.unpack_from("<II", payload, offset)
        offset += 8
        chunk = payload[offset:offset + chunk_length]
        if len(chunk) != chunk_length:
            raise ValueError(f"{path}: truncated GLB chunk")
        if chunk_type == 0x4E4F534A:
            document = json.loads(chunk.decode("utf-8").rstrip(" \t\r\n\0"))
        elif chunk_type == 0x004E4942:
            binary = chunk
        offset += chunk_length
    if document is None or binary is None:
        raise ValueError(f"{path}: missing JSON or BIN chunk")
    return document, binary


def read_accessor(document: dict[str, Any], binary: bytes, accessor_index: int):
    accessor = document["accessors"][accessor_index]
    if "bufferView" not in accessor or "sparse" in accessor:
        raise ValueError(f"unsupported sparse or bufferless accessor {accessor_index}")
    component = _COMPONENTS.get(accessor["componentType"])
    width = _TYPE_WIDTHS.get(accessor["type"])
    if component is None or width is None:
        raise ValueError(f"unsupported accessor format at index {accessor_index}")
    fmt, component_size = component
    element_size = component_size * width
    view = document["bufferViews"][accessor["bufferView"]]
    stride = view.get("byteStride", element_size)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    rows = []
    for row in range(accessor["count"]):
        values = struct.unpack_from(
            "<" + fmt * width, binary, start + row * stride
        )
        rows.append(values[0] if width == 1 else values)
    return rows


def compare_glbs(base_path: str, variant_path: str, epsilon: float = 1e-7):
    base_doc, base_bin = read_glb(base_path)
    variant_doc, variant_bin = read_glb(variant_path)
    base_meshes = base_doc.get("meshes", [])
    variant_meshes = variant_doc.get("meshes", [])
    report: dict[str, Any] = {
        "base": base_path,
        "variant": variant_path,
        "base_mesh_count": len(base_meshes),
        "variant_mesh_count": len(variant_meshes),
        "same_layout": True,
        "meshes": [],
    }
    if len(base_meshes) != len(variant_meshes):
        report["same_layout"] = False
        return report

    for mesh_index, (base_mesh, variant_mesh) in enumerate(
        zip(base_meshes, variant_meshes)
    ):
        base_primitives = base_mesh.get("primitives", [])
        variant_primitives = variant_mesh.get("primitives", [])
        mesh_report = {
            "mesh_index": mesh_index,
            "base_name": base_mesh.get("name", ""),
            "variant_name": variant_mesh.get("name", ""),
            "same_layout": len(base_primitives) == len(variant_primitives),
            "primitives": [],
        }
        if not mesh_report["same_layout"]:
            report["same_layout"] = False
            report["meshes"].append(mesh_report)
            continue

        for primitive_index, (base_primitive, variant_primitive) in enumerate(
            zip(base_primitives, variant_primitives)
        ):
            base_attrs = base_primitive.get("attributes", {})
            variant_attrs = variant_primitive.get("attributes", {})
            same_attributes = set(base_attrs) == set(variant_attrs)
            base_position_index = base_attrs.get("POSITION")
            variant_position_index = variant_attrs.get("POSITION")
            if base_position_index is None or variant_position_index is None:
                raise ValueError("primitive is missing POSITION attribute")
            base_positions = read_accessor(base_doc, base_bin, base_position_index)
            variant_positions = read_accessor(
                variant_doc, variant_bin, variant_position_index
            )
            same_count = len(base_positions) == len(variant_positions)
            same_index_data = False
            if "indices" in base_primitive and "indices" in variant_primitive:
                base_indices = read_accessor(
                    base_doc, base_bin, base_primitive["indices"]
                )
                variant_indices = read_accessor(
                    variant_doc, variant_bin, variant_primitive["indices"]
                )
                same_index_data = base_indices == variant_indices
            elif "indices" not in base_primitive and "indices" not in variant_primitive:
                same_index_data = True

            moved = 0
            max_delta = 0.0
            if same_count:
                for left, right in zip(base_positions, variant_positions):
                    distance = math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))
                    if distance > epsilon:
                        moved += 1
                    max_delta = max(max_delta, distance)

            primitive_ok = same_attributes and same_count and same_index_data
            primitive_report = {
                "primitive_index": primitive_index,
                "same_attribute_set": same_attributes,
                "same_vertex_count": same_count,
                "same_index_data": same_index_data,
                "base_vertex_count": len(base_positions),
                "variant_vertex_count": len(variant_positions),
                "moved_vertices": moved,
                "max_position_delta": max_delta,
                "same_layout": primitive_ok,
            }
            mesh_report["primitives"].append(primitive_report)
            mesh_report["same_layout"] = mesh_report["same_layout"] and primitive_ok

        report["same_layout"] = report["same_layout"] and mesh_report["same_layout"]
        report["meshes"].append(mesh_report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--variant", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--epsilon", type=float, default=1e-7)
    args = parser.parse_args()
    report = compare_glbs(args.base, args.variant, args.epsilon)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
