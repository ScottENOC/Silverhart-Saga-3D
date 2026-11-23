"""Topology-preserving body-surface garment shell construction.

The input is a body surface plus a signed coverage field (positive = cloth).
Faces are clipped at the field's zero contour; shared intersections are cached
by source edge so neighbouring faces meet without cracks. The selected surface
is offset along its interpolated normals and its open boundary receives a
turned-in rim. Source references retain the data needed to transfer skinning,
morphs and other per-vertex attributes in a host adapter.
"""
from __future__ import annotations

from dataclasses import dataclass
from math import isfinite, sqrt
from typing import Callable, Iterable, Sequence

Vec3 = tuple[float, float, float]
Face = tuple[int, ...]
SourceRef = tuple


@dataclass(frozen=True)
class ShellMesh:
    positions: tuple[Vec3, ...]
    normals: tuple[Vec3, ...]
    faces: tuple[Face, ...]
    surface_face_count: int
    rim_face_count: int
    # ("vertex", source_index) or ("edge", source_a, source_b, t_from_a)
    source_refs: tuple[SourceRef, ...]
    boundary_edges: tuple[tuple[int, int], ...]


def _add(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _scale(a: Vec3, s: float) -> Vec3:
    return (a[0] * s, a[1] * s, a[2] * s)


def _unit(a: Vec3) -> Vec3:
    length = sqrt(sum(x * x for x in a))
    if length <= 1e-12:
        raise ValueError("Cannot interpolate a zero-length surface normal")
    return _scale(a, 1.0 / length)


def build_shell(
    vertices: Sequence[Vec3],
    normals: Sequence[Vec3],
    faces: Iterable[Sequence[int]],
    field_values: Sequence[float],
    offset: float | Sequence[float] | Callable[[int], float],
    hem_depth: float = 0.002,
) -> ShellMesh:
    """Clip and offset a body surface using a per-vertex signed coverage field.

    Faces are expected to be consistently wound and convex (triangles/quads
    are the intended body topology). Distances use the caller's mesh units.
    A positive field value means inside the garment; zero is the cutline.
    """
    count = len(vertices)
    if len(normals) != count or len(field_values) != count:
        raise ValueError("vertices, normals and field_values must have equal lengths")
    if hem_depth < 0:
        raise ValueError("hem_depth cannot be negative")
    for i, (p, n, value) in enumerate(zip(vertices, normals, field_values)):
        if len(p) != 3 or len(n) != 3 or not all(isfinite(x) for x in (*p, *n, value)):
            raise ValueError(f"invalid body vertex data at index {i}")
    if isinstance(offset, (int, float)):
        offsets = [float(offset)] * count
    elif callable(offset):
        offsets = [float(offset(i)) for i in range(count)]
    else:
        if len(offset) != count:
            raise ValueError("per-vertex offset must match vertex count")
        offsets = [float(x) for x in offset]
    if any(not isfinite(x) or x < 0 for x in offsets):
        raise ValueError("offsets must be finite and non-negative")

    positions: list[Vec3] = []
    out_normals: list[Vec3] = []
    refs: list[SourceRef] = []
    outer: list[Face] = []
    vertex_cache: dict[SourceRef, int] = {}

    def source_data(ref: SourceRef) -> tuple[Vec3, Vec3, float]:
        if ref[0] == "vertex":
            i = ref[1]
            return vertices[i], _unit(normals[i]), offsets[i]
        _, a, b, t = ref
        p = _add(_scale(vertices[a], 1.0 - t), _scale(vertices[b], t))
        n = _unit(_add(_scale(normals[a], 1.0 - t), _scale(normals[b], t)))
        o = offsets[a] * (1.0 - t) + offsets[b] * t
        return p, n, o

    def output_vertex(ref: SourceRef) -> int:
        if ref in vertex_cache:
            return vertex_cache[ref]
        p, n, o = source_data(ref)
        idx = len(positions)
        positions.append(_add(p, _scale(n, o)))
        out_normals.append(n)
        refs.append(ref)
        vertex_cache[ref] = idx
        return idx

    def edge_intersection(a: int, b: int) -> SourceRef:
        va, vb = field_values[a], field_values[b]
        if va == 0:
            return ("vertex", a)
        if vb == 0:
            return ("vertex", b)
        lo, hi = (a, b) if a < b else (b, a)
        # Always calculate from the canonical endpoint order. Computing 1-t
        # from the reversed edge can differ by one ULP and create a seam.
        t = field_values[lo] / (field_values[lo] - field_values[hi])
        return ("edge", lo, hi, t)

    for raw_face in faces:
        face = tuple(int(v) for v in raw_face)
        if len(face) < 3 or len(set(face)) != len(face):
            raise ValueError("each face must contain at least three distinct vertices")
        if any(v < 0 or v >= count for v in face):
            raise ValueError("face references an out-of-range vertex")
        if not any(field_values[v] >= 0 for v in face):
            continue
        # Sutherland-Hodgman clipping against the linearly interpolated field.
        clipped: list[SourceRef] = []
        for k, a in enumerate(face):
            b = face[(k + 1) % len(face)]
            inside_a = field_values[a] >= 0
            inside_b = field_values[b] >= 0
            if inside_a:
                clipped.append(("vertex", a))
            if inside_a != inside_b:
                clipped.append(edge_intersection(a, b))
        # Remove any repeated consecutive references caused by exact-zero values.
        compact: list[SourceRef] = []
        for ref in clipped:
            if not compact or ref != compact[-1]:
                compact.append(ref)
        if len(compact) > 1 and compact[0] == compact[-1]:
            compact.pop()
        if len(compact) >= 3:
            outer.append(tuple(output_vertex(ref) for ref in compact))

    if not outer:
        raise ValueError("coverage field selected no body surface")

    edge_use: dict[tuple[int, int], tuple[int, tuple[int, int]]] = {}
    for face in outer:
        for i, a in enumerate(face):
            b = face[(i + 1) % len(face)]
            key = (a, b) if a < b else (b, a)
            if key in edge_use:
                uses, directed = edge_use[key]
                edge_use[key] = (uses + 1, directed)
            else:
                edge_use[key] = (1, (a, b))
    # Retain the face winding: it determines the correct outward-facing rim.
    boundary = tuple(directed for uses, directed in edge_use.values() if uses == 1)

    inner_cache: dict[int, int] = {}
    rim: list[Face] = []
    for a, b in boundary:
        def inner_vertex(outer_index: int) -> int:
            if outer_index in inner_cache:
                return inner_cache[outer_index]
            ref = refs[outer_index]
            p, n, o = source_data(ref)
            depth = min(hem_depth, o)
            idx = len(positions)
            positions.append(_add(p, _scale(n, o - depth)))
            out_normals.append(n)
            refs.append(ref)
            inner_cache[outer_index] = idx
            return idx
        ia, ib = inner_vertex(a), inner_vertex(b)
        rim.append((b, a, ia, ib))

    return ShellMesh(
        tuple(positions), tuple(out_normals), tuple(outer + rim),
        len(outer), len(rim), tuple(refs), boundary,
    )
