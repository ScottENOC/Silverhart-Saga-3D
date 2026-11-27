import unittest

from tools.cloth.xpbd_solver import (
    Contact, DistanceConstraint, Particle, nonlinear_body_compliance,
    solve_coupled_contact, solve_distance, solve_frame, project_to_normal_lines,
)


class XPBDSolverTests(unittest.TestCase):
    def test_contact_is_resolved_before_springs_and_after_each_iteration(self):
        particles = [Particle.at((0.0, 0.0, -0.1))]
        calls = []
        def contacts(current):
            calls.append(current[0].position[2])
            return [Contact(0, current[0].position[2], (0.0, 0.0, 1.0))]
        solve_frame(particles, [], contacts, 1.0 / 60.0, gravity=(0, 0, 0), iterations=4)
        self.assertGreaterEqual(particles[0].position[2], -1e-9)
        self.assertGreaterEqual(len(calls), 5)

    def test_stretch_constraint_pulls_toward_rest_length(self):
        particles = [Particle.at((0, 0, 0)), Particle.at((2, 0, 0))]
        constraint = DistanceConstraint(0, 1, 1.0)
        solve_distance(particles, constraint, 1.0 / 60.0, {})
        self.assertAlmostEqual(
            (particles[1].position[0] - particles[0].position[0]), 1.0
        )

    def test_coupled_contact_moves_both_surfaces(self):
        cloth = Particle.at((0, 0, 0), inverse_mass=1.0)
        body = Particle.at((0, 0, 0), inverse_mass=0.25)
        solve_coupled_contact(cloth, body, (0, 0, 1), 0.1)
        self.assertAlmostEqual(cloth.position[2], 0.08)
        self.assertAlmostEqual(body.position[2], -0.02)

    def test_body_resistance_hardens_with_displacement(self):
        small = nonlinear_body_compliance(0.1, 10.0, 100.0)
        large = nonlinear_body_compliance(0.2, 10.0, 100.0)
        self.assertGreater(large / 0.2, small / 0.1)

    def test_normal_line_projection_allows_large_outward_motion_without_tangential_drift(self):
        particles = [Particle.at((0.0, 0.0, 0.0))]
        anchors = [((0.0, 0.0, 0.0), (0.0, 0.0, 1.0))]
        particles[0].position = (0.025, -0.01, 0.08)
        project_to_normal_lines(particles, anchors)
        self.assertAlmostEqual(particles[0].position[0], 0.0)
        self.assertAlmostEqual(particles[0].position[1], 0.0)
        self.assertAlmostEqual(particles[0].position[2], 0.08)

    def test_pinned_particle_is_not_moved_by_contact(self):
        particles = [Particle.at((0, 0, -0.2), inverse_mass=0.0)]
        from tools.cloth.xpbd_solver import solve_contact
        solve_contact(particles, Contact(0, -0.2, (0, 0, 1)))
        self.assertEqual(particles[0].position, (0, 0, -0.2))


if __name__ == "__main__":
    unittest.main()
