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
