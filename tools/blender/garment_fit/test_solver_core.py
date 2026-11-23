import math
import unittest

from solver_core import FitConfig, fit_clearance


def plane_query(point):
    # Body surface is z=0 with an outward +Z normal.
    return ((point[0], point[1], 0.0), (0.0, 0.0, 1.0))


class SolverCoreTests(unittest.TestCase):
    def test_projects_penetrating_vertex_to_target_clearance(self):
        result, report = fit_clearance(
            [(0.0, 0.0, -0.01)], [], plane_query,
            FitConfig(target_clearance=0.004, max_step=0.003, smoothing=0.0),
        )
        self.assertAlmostEqual(result[0][2], 0.004, places=4)
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["penetrating_vertices"], 0)

    def test_leaves_vertex_already_at_clearance_unchanged(self):
        source = [(0.0, 0.0, 0.004)]
        result, report = fit_clearance(source, [], plane_query)
        self.assertEqual(result, source)
        self.assertEqual(report["iterations"], 0)

    def test_does_not_move_pinned_vertices(self):
        source = [(0.0, 0.0, -0.01)]
        result, report = fit_clearance(source, [], plane_query, movable=[False])
        self.assertEqual(result, source)
        self.assertEqual(report["status"], "FAIL")
        self.assertEqual(report["below_target_vertices"], 1)

    def test_respects_maximum_vertex_displacement(self):
        source = [(0.0, 0.0, -0.1)]
        result, report = fit_clearance(
            source, [], plane_query,
            FitConfig(target_clearance=0.004, max_vertex_displacement=0.01,
                      max_step=0.003, smoothing=0.0, max_iterations=20),
        )
        moved = abs(result[0][2] - source[0][2])
        self.assertLessEqual(moved, 0.0100001)
        self.assertEqual(report["status"], "FAIL")
        self.assertEqual(report["vertices_at_displacement_limit"], 1)

    def test_rejects_invalid_edge_indices(self):
        with self.assertRaises(ValueError):
            fit_clearance([(0.0, 0.0, 0.0)], [(0, 2)], plane_query)

    def test_rejects_zero_surface_normal(self):
        with self.assertRaises(ValueError):
            fit_clearance(
                [(0.0, 0.0, -0.01)], [], lambda _p: ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))
            )

    def test_reports_floating_vertices(self):
        _result, report = fit_clearance(
            [(0.0, 0.0, 0.03)], [], plane_query,
            FitConfig(floating_tolerance=0.015),
        )
        self.assertEqual(report["floating_vertices"], 1)

    def test_smoothing_uses_garment_adjacency(self):
        source = [
            (0.0, 0.0, -0.01),
            (1.0, 0.0, 0.003),
            (2.0, 0.0, 0.003),
        ]
        result, _report = fit_clearance(
            source, [(0, 1), (1, 2)], plane_query,
            FitConfig(target_clearance=0.004, smoothing=0.2, max_step=0.003),
        )
        self.assertGreater(result[1][2], source[1][2])
        self.assertGreater(result[2][2], source[2][2])

    def test_is_deterministic(self):
        source = [(0.0, 0.0, -0.01), (1.0, 0.0, 0.003)]
        config = FitConfig()
        first = fit_clearance(source, [(0, 1)], plane_query, config)
        second = fit_clearance(source, [(0, 1)], plane_query, config)
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
