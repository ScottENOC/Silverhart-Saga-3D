"""Reusable garment-to-body landmark correspondence primitives.

The correspondence is stored in garment space as weights against stable body
landmarks. It can be reused when a body morph changes those landmarks, avoiding
a fresh nearest-surface guess for every generated character. This module is
Blender-independent; the Blender adapter supplies actual Ara landmark positions.
"""
from __future__ import annotations

from math import sqrt
from typing import Mapping, Sequence

Point3 = tuple[float, float, float]

# Semantic landmark names expected from the Ara/companion adapter. Coordinates
# are deliberately not hard-coded here: they must be sampled from each body.
BODY_LANDMARKS = {
    "neck_base", "left_shoulder", "right_shoulder", "sternum",
    "left_underbust", "right_underbust", "waist_front", "waist_back",
    "left_hip", "right_hip", "sacrum", "crotch",
    "left_thigh_root", "right_thigh_root",
}

LANDMARK_REGIONS = {
    "neck_base": "neck",
    "left_shoulder": "shoulder", "right_shoulder": "shoulder",
    "sternum": "chest",
    "left_underbust": "chest", "right_underbust": "chest",
    "waist_front": "waist", "waist_back": "waist",
    "left_hip": "pelvis", "right_hip": "pelvis",
    "sacrum": "pelvis", "crotch": "pelvis",
    "left_thigh_root": "thigh", "right_thigh_root": "thigh",
}


def _distance(a: Point3, b: Point3) -> float:
    return sqrt(sum((float(a[i]) - float(b[i])) ** 2 for i in range(3)))


def build_landmark_weights(
    garment_points: Sequence[Point3],
    body_landmarks: Mapping[str, Point3],
    *,
    neighbours: int = 4,
    falloff: float = 2.0,
    max_distance: float | None = None,
    region: str | None = None,
) -> list[dict[str, float]]:
    """Build inverse-distance weights from each garment point to body anchors.

    Exact landmark coincidences become a one-hot weight. A max_distance guard
    prevents a distant/unrelated anchor set from silently producing a bogus fit.
    """
    if not body_landmarks:
        raise ValueError("At least one body landmark is required")
    if region is not None:
        if region not in set(LANDMARK_REGIONS.values()):
            raise ValueError(f"Unknown body landmark region: {region!r}")
        body_landmarks = {
            name: point for name, point in body_landmarks.items()
            if LANDMARK_REGIONS.get(name) == region
        }
        if not body_landmarks:
            raise ValueError(f"No body landmarks available for region {region!r}")
    if neighbours < 1:
        raise ValueError("neighbours must be at least one")
    if falloff <= 0:
        raise ValueError("falloff must be positive")
    for name, point in body_landmarks.items():
        if len(point) != 3:
            raise ValueError(f"Landmark {name!r} must be a 3D point")

    result: list[dict[str, float]] = []
    for point in garment_points:
        if len(point) != 3:
            raise ValueError("Garment correspondence points must be 3D")
        distances = sorted(
            ((_distance(point, anchor), name) for name, anchor in body_landmarks.items()),
            key=lambda item: item[0],
        )[:neighbours]
        nearest_distance = distances[0][0]
        if max_distance is not None and nearest_distance > max_distance:
            raise ValueError(
                f"Garment point is {nearest_distance:.4f} m from its nearest body landmark "
                f"(limit {max_distance:.4f} m)"
            )
        if nearest_distance <= 1e-9:
            result.append({distances[0][1]: 1.0})
            continue
        raw = {name: 1.0 / max(distance, 1e-9) ** falloff for distance, name in distances}
        total = sum(raw.values())
        result.append({name: weight / total for name, weight in raw.items()})
    return result


def transfer_landmark_deltas(
    weights: Mapping[str, float],
    landmark_deltas: Mapping[str, Point3],
) -> Point3:
    """Interpolate a body-landmark displacement onto one mapped garment point."""
    if not weights:
        raise ValueError("A garment point must have at least one correspondence weight")
    missing = set(weights) - set(landmark_deltas)
    if missing:
        raise ValueError(f"Missing body landmark deltas: {sorted(missing)}")
    total = sum(float(weight) for weight in weights.values())
    if total <= 0:
        raise ValueError("Correspondence weights must sum to a positive value")
    return tuple(
        sum(float(weight) * float(landmark_deltas[name][axis]) for name, weight in weights.items()) / total
        for axis in range(3)
    )


def validate_landmark_set(body_landmarks: Mapping[str, Point3], required: Sequence[str]) -> None:
    """Fail early if a garment panel's required body anchors are unavailable."""
    missing = sorted(set(required) - set(body_landmarks))
    if missing:
        raise ValueError(f"Missing required body landmarks: {missing}")


def barycentric_weights(
    point: Point3,
    a: Point3,
    b: Point3,
    c: Point3,
    *,
    epsilon: float = 1e-12,
) -> tuple[float, float, float]:
    """Return barycentric coordinates of a point on a triangle.

    The Blender adapter supplies the closest point returned by its triangle
    BVH, so valid production mappings should lie on or very near the triangle.
    Degenerate triangles fail closed rather than producing unstable weights.
    """
    v0 = tuple(float(b[i]) - float(a[i]) for i in range(3))
    v1 = tuple(float(c[i]) - float(a[i]) for i in range(3))
    v2 = tuple(float(point[i]) - float(a[i]) for i in range(3))
    dot00 = sum(x * x for x in v0)
    dot01 = sum(v0[i] * v1[i] for i in range(3))
    dot11 = sum(x * x for x in v1)
    dot20 = sum(v2[i] * v0[i] for i in range(3))
    dot21 = sum(v2[i] * v1[i] for i in range(3))
    denominator = dot00 * dot11 - dot01 * dot01
    if abs(denominator) <= epsilon:
        raise ValueError("Cannot map to a degenerate body triangle")
    weight_b = (dot11 * dot20 - dot01 * dot21) / denominator
    weight_c = (dot00 * dot21 - dot01 * dot20) / denominator
    weight_a = 1.0 - weight_b - weight_c
    weights = (weight_a, weight_b, weight_c)
    if any(not (-1e-6 <= weight <= 1.0 + 1e-6) for weight in weights):
        raise ValueError(f"Point lies outside its mapped triangle: {weights}")
    # Remove tiny floating-point excursions while preserving a unit sum.
    clamped = tuple(max(0.0, min(1.0, weight)) for weight in weights)
    total = sum(clamped)
    if total <= epsilon:
        raise ValueError("Barycentric weights have no positive mass")
    return tuple(weight / total for weight in clamped)


def interpolate_triangle_delta(
    weights: Sequence[float],
    vertex_deltas: Sequence[Point3],
) -> Point3:
    """Transfer a body-surface displacement to a garment point."""
    if len(weights) != 3 or len(vertex_deltas) != 3:
        raise ValueError("Surface transfer requires exactly three triangle weights and deltas")
    normalised = tuple(float(weight) for weight in weights)
    if any(weight < -1e-8 for weight in normalised):
        raise ValueError("Surface correspondence weights cannot be negative")
    total = sum(normalised)
    if total <= 1e-12:
        raise ValueError("Surface correspondence weights must sum to a positive value")
    normalised = tuple(weight / total for weight in normalised)
    if any(len(delta) != 3 for delta in vertex_deltas):
        raise ValueError("Each body vertex delta must be a 3D point")
    return tuple(
        sum(normalised[i] * float(vertex_deltas[i][axis]) for i in range(3))
        for axis in range(3)
    )
