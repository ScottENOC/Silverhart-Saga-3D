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


def axis_parameter(point: Vec3, start: Vec3, end: Vec3) -> float:
    """Return the signed fraction along a 3D landmark axis, independent of world-up.

    0 is start, 1 is end. All three points must be expressed in the same
    coordinate space (the garment adapter uses body-local mesh coordinates).
    """
    axis = _sub(end, start)
    length_sq = sum(component * component for component in axis)
    if length_sq <= 1e-12:
        raise ValueError("landmark axis has zero length")
    return sum((point[i] - start[i]) * axis[i] for i in range(3)) / length_sq


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


def _dot(a: Vec3, b: Vec3) -> float:
    return sum(a[i] * b[i] for i in range(3))


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def curved_trunk_limit(
    lateral_distance: float,
    half_width: float,
    base: float = 0.12,
    side_rise: float = 0.018,
) -> float:
    """Raise the waistband gradually towards the outer hips."""
    if half_width <= 0 or side_rise < 0:
        raise ValueError("half_width must be positive and side_rise non-negative")
    t = _clamp(abs(lateral_distance) / half_width, 0.0, 1.0)
    smooth = t * t * (3.0 - 2.0 * t)
    return base + side_rise * smooth


def curved_leg_limit(
    outwardness: float,
    base: float = 0.10,
    high_cut_delta: float = 0.025,
) -> float:
    """Raise the leg opening at the outer thigh and lower it at the inner thigh.

    outwardness is signed: +1 is the outside of the leg, -1 is the inside.
    """
    if high_cut_delta < 0:
        raise ValueError("high_cut_delta must be non-negative")
    return base - high_cut_delta * _clamp(outwardness, -1.0, 1.0)


def bridge_midline_concavities(
    positions: Sequence[Vec3],
    normals: Sequence[Vec3],
    sample_positions: Sequence[Vec3],
    sample_normals: Sequence[Vec3],
    center: Vec3,
    lateral_axis: Vec3,
    vertical_axis: Vec3,
    depth_axis: Vec3,
    *,
    min_height: float = -0.14,
    max_height: float = 0.08,
    bridge_half_width: float = 0.055,
    sample_outer_width: float = 0.10,
    vertical_band: float = 0.018,
    strength: float = 0.82,
    max_bridge_distance: float = 0.025,
    minimum_gap: float = 0.002,
) -> tuple[Vec3, ...]:
    """Pull cloth out of narrow central body valleys without changing its outline.

    At each height, nearby body samples on the same anterior/posterior surface
    and farther out on both sides provide a bridge depth. Only vertices inside
    the central corridor are moved, and only when that bridge lies outward of
    the local body surface. Normals distinguish the front and rear surfaces.
    """
    if len(positions) != len(normals) or len(sample_positions) != len(sample_normals):
        raise ValueError("position and normal arrays must have matching lengths")
    if vertical_band <= 0 or bridge_half_width <= 0 or sample_outer_width <= bridge_half_width:
        raise ValueError("invalid bridge sampling dimensions")
    if not 0.0 <= strength <= 1.0 or max_bridge_distance < 0 or minimum_gap < 0:
        raise ValueError("invalid bridge strength or distance")

    # Samples are bucketed by surface side and height, avoiding an O(n*m)
    # search across the 77k-vertex body mesh.
    buckets: dict[tuple[int, int], list[tuple[float, float, float]]] = {}
    for point, normal in zip(sample_positions, sample_normals):
        facing = _dot(normal, depth_axis)
        if abs(facing) < 0.25:
            continue
        relative = _sub(point, center)
        height = _dot(relative, vertical_axis)
        lateral = _dot(relative, lateral_axis)
        if not min_height - vertical_band <= height <= max_height + vertical_band:
            continue
        if abs(lateral) > sample_outer_width:
            continue
        depth = _dot(relative, depth_axis)
        side = 1 if facing > 0 else -1
        bucket = int(height // vertical_band)
        buckets.setdefault((side, bucket), []).append((height, lateral, depth))

    result: list[Vec3] = []
    for point, normal in zip(positions, normals):
        relative = _sub(point, center)
        height = _dot(relative, vertical_axis)
        lateral = _dot(relative, lateral_axis)
        if not (min_height <= height <= max_height) or abs(lateral) >= bridge_half_width:
            result.append(point)
            continue

        facing = _dot(normal, depth_axis)
        if abs(facing) < 0.25:
            result.append(point)
            continue
        side = 1 if facing > 0 else -1
        first_bucket = int((height - vertical_band) // vertical_band)
        last_bucket = int((height + vertical_band) // vertical_band)
        left_samples: list[tuple[float, float]] = []
        right_samples: list[tuple[float, float]] = []
        required_lateral = abs(lateral) + 0.012
        for bucket in range(first_bucket, last_bucket + 1):
            for sample_height, sample_lateral, sample_depth in buckets.get((side, bucket), ()):
                if abs(sample_height - height) > vertical_band:
                    continue
                if abs(sample_lateral) < required_lateral or abs(sample_lateral) > sample_outer_width:
                    continue
                weighted_depth = (sample_depth, 1.0 / (0.004 + abs(sample_height - height)))
                (left_samples if sample_lateral < 0 else right_samples).append(weighted_depth)

        if not left_samples and not right_samples:
            result.append(point)
            continue
        means = []
        for side_samples in (left_samples, right_samples):
            if side_samples:
                total_weight = sum(weight for _, weight in side_samples)
                means.append(sum(depth * weight for depth, weight in side_samples) / total_weight)
        bridge_depth = sum(means) / len(means)
        current_depth = _dot(relative, depth_axis)
        outward_gap = (bridge_depth - current_depth) * side
        if outward_gap <= minimum_gap:
            result.append(point)
            continue

        t = _clamp(abs(lateral) / bridge_half_width, 0.0, 1.0)
        lateral_fade = 1.0 - t * t * (3.0 - 2.0 * t)
        displacement = min(outward_gap, max_bridge_distance) * strength * lateral_fade
        result.append(_add(point, _scale(depth_axis, side * displacement)))

    return tuple(result)
