"""Dependency-free iterative garment clearance solver core.

The surface query callback must return (nearest_point, outward_unit_normal)
in the same coordinate system as the supplied garment vertices. The body is
never modified by this module.
"""
from __future__ import annotations

from dataclasses import dataclass
from math import sqrt
from typing import Callable, Iterable, Sequence

Vec3 = tuple[float, float, float]
SurfaceQuery = Callable[[Vec3], tuple[Vec3, Vec3] | None]


def _add(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _mul(a: Vec3, scale: float) -> Vec3:
    return (a[0] * scale, a[1] * scale, a[2] * scale)


def _dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _length(a: Vec3) -> float:
    return sqrt(_dot(a, a))


def _unit(a: Vec3) -> Vec3:
    size = _length(a)
    if size <= 1e-12:
        raise ValueError("Surface query returned a zero-length normal")
    return _mul(a, 1.0 / size)


@dataclass(frozen=True)
class FitConfig:
    target_clearance: float = 0.004
    max_vertex_displacement: float = 0.025
    max_step: float = 0.003
    smoothing: float = 0.2
    max_iterations: int = 20
    convergence_tolerance: float = 0.00025
    floating_tolerance: float = 0.015

    def validate(self) -> None:
        if self.target_clearance < 0:
            raise ValueError("target_clearance must be non-negative")
        if self.max_vertex_displacement <= 0 or self.max_step <= 0:
            raise ValueError("displacement limits must be positive")
        if not 0.0 <= self.smoothing < 0.5:
            raise ValueError("smoothing must be in [0, 0.5)")
        if self.max_iterations < 1:
            raise ValueError("max_iterations must be positive")


def _measure(vertices: Sequence[Vec3], query: SurfaceQuery):
    signed, distances = [], []
    for vertex in vertices:
        hit = query(vertex)
        if hit is None:
            signed.append(None)
            distances.append(None)
            continue
        point, normal = hit
        normal = _unit(normal)
        delta = _sub(vertex, point)
        signed.append(_dot(delta, normal))
        distances.append(_length(delta))
    return signed, distances


def _percentile(values: Iterable[float], fraction: float) -> float | None:
    ordered = sorted(values)
    if not ordered:
        return None
    index = min(len(ordered) - 1, max(0, int(round((len(ordered) - 1) * fraction))))
    return ordered[index]


def fit_clearance(
    vertices: Sequence[Vec3],
    edges: Sequence[tuple[int, int]],
    query_surface: SurfaceQuery,
    config: FitConfig = FitConfig(),
    movable: Sequence[bool] | None = None,
) -> tuple[list[Vec3], dict]:
    """Iteratively project garment vertices outside a static body surface.

    Displacement is smoothed over garment-edge adjacency, then re-projected on
    subsequent iterations. Per-vertex displacement and per-iteration steps are
    bounded. This is a clearance fitter, not a cloth dynamics or tissue solver.
    """
    config.validate()
    original = [tuple(map(float, point)) for point in vertices]
    count = len(original)
    if not count:
        raise ValueError("No garment vertices supplied")
    if movable is None:
        movable = [True] * count
    if len(movable) != count:
        raise ValueError("movable mask length must match vertices")

    neighbours = [set() for _ in original]
    for left, right in edges:
        if left < 0 or right < 0 or left >= count or right >= count:
            raise ValueError("Edge index outside vertex array")
        if left != right:
            neighbours[left].add(right)
            neighbours[right].add(left)

    positions = list(original)
    iterations = 0
    unresolved = set()
    for iteration in range(config.max_iterations):
        signed, _distances = _measure(positions, query_surface)
        corrections: list[Vec3] = []
        worst = 0.0
        for index, offset in enumerate(signed):
            if offset is None or not movable[index] or offset >= config.target_clearance:
                corrections.append((0.0, 0.0, 0.0))
                continue
            hit = query_surface(positions[index])
            if hit is None:
                corrections.append((0.0, 0.0, 0.0))
                continue
            _point, normal = hit
            normal = _unit(normal)
            deficit = config.target_clearance - offset
            worst = max(worst, deficit)
            corrections.append(_mul(normal, min(deficit, config.max_step)))

        if worst <= config.convergence_tolerance:
            iterations = iteration
            break

        next_positions = list(positions)
        for index, correction in enumerate(corrections):
            if not movable[index] or _length(correction) <= 1e-12:
                continue
            adjacent = neighbours[index]
            if adjacent and config.smoothing:
                average = tuple(
                    sum(corrections[n][axis] for n in adjacent) / len(adjacent)
                    for axis in range(3)
                )
                correction = _add(
                    _mul(correction, 1.0 - config.smoothing),
                    _mul(average, config.smoothing),
                )
            proposed = _add(positions[index], correction)
            total = _sub(proposed, original[index])
            total_length = _length(total)
            if total_length > config.max_vertex_displacement:
                proposed = _add(
                    original[index],
                    _mul(total, config.max_vertex_displacement / total_length),
                )
            next_positions[index] = proposed
        positions = next_positions
        iterations = iteration + 1

    signed, distances = _measure(positions, query_surface)
    valid_signed = [value for value in signed if value is not None]
    valid_distances = [value for value in distances if value is not None]
    penetration = [value for value in valid_signed if value < 0.0]
    below_target = [
        value for value in valid_signed
        if value < config.target_clearance - config.convergence_tolerance
    ]
    floating = [
        value for value in valid_signed
        if value > config.floating_tolerance
    ]
    displacement = [_length(_sub(now, before)) for now, before in zip(positions, original)]
    at_limit = [
        amount for amount in displacement
        if amount >= config.max_vertex_displacement - 1e-7
    ]
    unresolved = {
        "below_target": len(below_target),
        "at_displacement_limit": len(at_limit),
        "surface_query_misses": len(vertices) - len(valid_signed),
    }
    converged = not below_target and not floating and not unresolved["surface_query_misses"]
    report = {
        "status": "PASS" if converged else "FAIL",
        "solver": "iterative_clearance_projection_v1",
        "iterations": iterations,
        "converged": converged,
        "vertex_count": count,
        "measured_vertex_count": len(valid_signed),
        "target_clearance_m": config.target_clearance,
        "signed_clearance_m": {
            "min": min(valid_signed) if valid_signed else None,
            "median": _percentile(valid_signed, 0.5),
            "p95": _percentile(valid_signed, 0.95),
            "max": max(valid_signed) if valid_signed else None,
        },
        "penetrating_vertices": len(penetration),
        "below_target_vertices": len(below_target),
        "floating_vertices": len(floating),
        "nearest_distance_m": {
            "median": _percentile(valid_distances, 0.5),
            "p95": _percentile(valid_distances, 0.95),
            "max": max(valid_distances) if valid_distances else None,
        },
        "displacement_m": {
            "median": _percentile(displacement, 0.5),
            "p95": _percentile(displacement, 0.95),
            "max": max(displacement) if displacement else None,
        },
        "vertices_at_displacement_limit": len(at_limit),
        "unresolved": unresolved,
    }
    return positions, report
