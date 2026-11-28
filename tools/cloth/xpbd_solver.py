"""Small, deterministic XPBD core for offline garment fitting.

This module is deliberately geometry-agnostic. Blender adapters supply garment
particles, structural constraints and signed-distance contacts from the actual
body/piercing meshes. It contains no fake body clearance or mesh replacement.
"""
from __future__ import annotations

from dataclasses import dataclass
from math import sqrt
from typing import Iterable, Sequence

Vec3 = tuple[float, float, float]


def add(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a: Vec3, scalar: float) -> Vec3:
    return (a[0] * scalar, a[1] * scalar, a[2] * scalar)


def dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def length(a: Vec3) -> float:
    return sqrt(dot(a, a))


def normalise(a: Vec3) -> Vec3:
    magnitude = length(a)
    if magnitude < 1e-12:
        return (0.0, 0.0, 1.0)
    return mul(a, 1.0 / magnitude)


@dataclass
class Particle:
    position: Vec3
    previous: Vec3
    inverse_mass: float = 1.0

    @classmethod
    def at(cls, position: Vec3, inverse_mass: float = 1.0) -> "Particle":
        return cls(position, position, inverse_mass)


@dataclass(frozen=True)
class DistanceConstraint:
    a: int
    b: int
    rest_length: float
    compliance: float = 0.0
    stiffness: float = 1.0


@dataclass(frozen=True)
class Contact:
    """Signed-distance contact: positive distance is outside the collider."""
    particle: int
    distance: float
    normal: Vec3
    target_distance: float = 0.0
    compliance: float = 0.0


def solve_distance(particles: list[Particle], constraint: DistanceConstraint,
                   dt: float, lambdas: dict[tuple[int, int], float]) -> None:
    a, b = particles[constraint.a], particles[constraint.b]
    wa, wb = a.inverse_mass, b.inverse_mass
    weight = wa + wb
    if weight <= 0.0:
        return
    delta = sub(b.position, a.position)
    current = length(delta)
    if current < 1e-12:
        return
    alpha = constraint.compliance / (dt * dt)
    key = (constraint.a, constraint.b)
    old_lambda = lambdas.get(key, 0.0)
    # XPBD distance constraint. stiffness scales the positional correction,
    # while compliance controls timestep-independent softness.
    c = current - constraint.rest_length
    dlambda = (-c - alpha * old_lambda) / (weight + alpha)
    dlambda *= max(0.0, min(1.0, constraint.stiffness))
    lambdas[key] = old_lambda + dlambda
    gradient = mul(delta, 1.0 / current)
    a.position = sub(a.position, mul(gradient, wa * dlambda))
    b.position = add(b.position, mul(gradient, wb * dlambda))


def solve_contact(particles: list[Particle], contact: Contact) -> None:
    """Resolve non-penetration before elastic constraints in every iteration."""
    particle = particles[contact.particle]
    penetration = contact.target_distance - contact.distance
    if penetration <= 0.0 or particle.inverse_mass <= 0.0:
        return
    particle.position = add(particle.position, mul(normalise(contact.normal), penetration))



def contact_from_garment_outward_direction(point: Vec3, surface_point: Vec3,
                                             garment_outward: Vec3,
                                             particle_index: int,
                                             target_distance: float) -> Contact:
    """Build contact using the garment's outward direction, never body normals.

    The signed clearance is the projection from the nearest collider point onto
    the garment's own outward direction. This permits local expansion and
    tangential redistribution around concavities without inheriting a possibly
    inward-facing or discontinuous body normal.
    """
    direction = normalise(garment_outward)
    signed_clearance = dot(sub(point, surface_point), direction)
    return Contact(particle_index, signed_clearance, direction, target_distance)


def solve_coupled_contact(cloth: Particle, body: Particle, normal: Vec3,
                          penetration: float) -> None:
    """Separate both surfaces in proportion to their inverse masses."""
    if penetration <= 0.0:
        return
    total = cloth.inverse_mass + body.inverse_mass
    if total <= 0.0:
        return
    direction = normalise(normal)
    cloth.position = add(cloth.position, mul(direction, penetration * cloth.inverse_mass / total))
    body.position = sub(body.position, mul(direction, penetration * body.inverse_mass / total))


def nonlinear_body_compliance(displacement: float, base_stiffness: float,
                              hardening: float) -> float:
    """Return restoring force magnitude for progressively hardening tissue."""
    x = max(0.0, displacement)
    return max(0.0, base_stiffness) * x + max(0.0, hardening) * x * x * x


def project_to_normal_lines(particles: list[Particle],
                           anchors: Sequence[tuple[Vec3, Vec3]]) -> None:
    """Restrict each vertex to its original garment-normal line.

    The scalar distance along the line is unrestricted: large anatomical
    accommodation is valid, while tangential sliding/shear is not.
    """
    for particle, (origin, normal) in zip(particles, anchors):
        direction = normalise(normal)
        offset = sub(particle.position, origin)
        signed_offset = dot(offset, direction)
        particle.position = add(origin, mul(direction, signed_offset))


def solve_frame(particles: list[Particle], constraints: Sequence[DistanceConstraint],
                contact_provider, dt: float, gravity: Vec3 = (0.0, 0.0, -9.81),
                iterations: int = 12, damping: float = 0.02,
                normal_anchors: Sequence[tuple[Vec3, Vec3]] | None = None) -> None:
    """Advance one substep; contact is re-evaluated before springs each iteration.

    contact_provider(particles) must return current signed-distance contacts
    from the actual collision geometry. It is called again after the final
    elastic iteration so springs cannot leave cloth penetrating the body.
    """
    if dt <= 0.0:
        raise ValueError("dt must be positive")
    for particle in particles:
        if particle.inverse_mass <= 0.0:
            continue
        old = particle.position
        velocity = mul(sub(particle.position, particle.previous), max(0.0, 1.0 - damping))
        particle.previous = old
        particle.position = add(add(particle.position, velocity), mul(gravity, dt * dt))

    lambdas: dict[tuple[int, int], float] = {}
    for _ in range(max(1, iterations)):
        for contact in contact_provider(particles):
            solve_contact(particles, contact)
        for constraint in constraints:
            solve_distance(particles, constraint, dt, lambdas)
        if normal_anchors is not None:
            project_to_normal_lines(particles, normal_anchors)
    for contact in contact_provider(particles):
        solve_contact(particles, contact)
    if normal_anchors is not None:
        project_to_normal_lines(particles, normal_anchors)
