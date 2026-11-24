import unittest

from shell_core import axis_parameter, build_shell


class ShellCoreTests(unittest.TestCase):
    def test_axis_parameter_is_independent_of_y_or_z_up(self):
        self.assertAlmostEqual(axis_parameter((0, 0.5, 0), (0, 0, 0), (0, 1, 0)), 0.5)
        self.assertAlmostEqual(axis_parameter((0, 0, 0.5), (0, 0, 0), (0, 0, 1)), 0.5)

    def test_axis_parameter_handles_rotated_landmark_axis(self):
        self.assertAlmostEqual(axis_parameter((1.5, 2.5, 3.5), (1, 2, 3), (2, 3, 4)), 0.5)

    def test_axis_parameter_rejects_degenerate_landmarks(self):
        with self.assertRaisesRegex(ValueError, "zero length"):
            axis_parameter((0, 0, 0), (1, 1, 1), (1, 1, 1))

    def setUp(self):
        self.vertices = [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)]
        self.normals = [(0, 0, 1)] * 4

    def test_clips_face_at_zero_contour_and_closes_cutline(self):
        shell = build_shell(self.vertices, self.normals, [(0, 1, 2, 3)],
                            [-1, 1, 1, -1], 0.01, hem_depth=0.004)
        self.assertEqual(shell.surface_face_count, 1)
        self.assertEqual(shell.rim_face_count, 4)
        self.assertEqual(len(shell.boundary_edges), 4)
        self.assertAlmostEqual(min(p[0] for p in shell.positions[:4]), 0.5)
        self.assertAlmostEqual(max(p[0] for p in shell.positions[:4]), 1.0)

    def test_adjacent_faces_share_cut_vertices_without_seam(self):
        vertices = self.vertices + [(2, 0, 0), (2, 1, 0)]
        normals = [(0, 0, 1)] * 6
        shell = build_shell(vertices, normals, [(0, 1, 2, 3), (1, 4, 5, 2)],
                            [-1, -0.3, 0.7, -1, 1, -1], 0.01)
        self.assertEqual(shell.surface_face_count, 2)
        self.assertEqual(len(shell.boundary_edges), 7)
        self.assertEqual(len(shell.positions), 7 + 7)

    def test_all_inside_preserves_full_face(self):
        shell = build_shell(self.vertices, self.normals, [(0, 1, 2, 3)],
                            [1, 1, 1, 1], 0.01)
        self.assertEqual(shell.surface_face_count, 1)
        self.assertEqual(shell.rim_face_count, 4)
        self.assertEqual(shell.source_refs[:4],
                         (("vertex", 0), ("vertex", 1), ("vertex", 2), ("vertex", 3)))

    def test_all_outside_returns_clear_error(self):
        with self.assertRaisesRegex(ValueError, "selected no body surface"):
            build_shell(self.vertices, self.normals, [(0, 1, 2, 3)],
                        [-1, -1, -1, -1], 0.01)

    def test_per_vertex_offsets_are_interpolated(self):
        shell = build_shell(self.vertices, self.normals, [(0, 1, 2, 3)],
                            [-1, 1, 1, -1], [0.01, 0.02, 0.02, 0.01])
        self.assertAlmostEqual(shell.positions[0][2], 0.015)

    def test_rejects_invalid_face_indices(self):
        with self.assertRaisesRegex(ValueError, "out-of-range"):
            build_shell(self.vertices, self.normals, [(0, 1, 8)], [1] * 4, 0.01)

    def test_rejects_mismatched_vertex_arrays(self):
        with self.assertRaisesRegex(ValueError, "equal lengths"):
            build_shell(self.vertices, self.normals[:-1], [(0, 1, 2, 3)], [1] * 4, 0.01)


    def test_exact_zero_cutline_uses_the_existing_body_vertex(self):
        shell = build_shell(self.vertices, self.normals, [(0, 1, 2, 3)],
                            [-1, 0, 1, -1], 0.01)
        self.assertEqual(shell.surface_face_count, 1)
        self.assertIn(("vertex", 1), shell.source_refs)

    def test_rim_winding_faces_outward_from_the_cloth(self):
        shell = build_shell(self.vertices, self.normals, [(0, 1, 2, 3)],
                            [-1, 1, 1, -1], 0.01)
        self.assertEqual(shell.faces[1], (1, 0, 4, 5))


    def test_waistband_rises_smoothly_towards_outer_hips(self):
        from shell_core import curved_trunk_limit
        self.assertAlmostEqual(curved_trunk_limit(0.0, 0.2), 0.12)
        self.assertAlmostEqual(curved_trunk_limit(0.2, 0.2), 0.138)
        self.assertGreater(curved_trunk_limit(0.1, 0.2), 0.12)
        self.assertLess(curved_trunk_limit(0.1, 0.2), 0.138)

    def test_leg_opening_is_higher_outside_and_lower_inside(self):
        from shell_core import curved_leg_limit
        self.assertAlmostEqual(curved_leg_limit(1.0), 0.075)
        self.assertAlmostEqual(curved_leg_limit(-1.0), 0.125)

    def test_midline_bridge_pulls_inward_valley_towards_side_surfaces(self):
        from shell_core import bridge_midline_concavities
        positions = [(0.0, 0.0, 0.0), (0.07, 0.0, 0.0)]
        normals = [(0.0, 1.0, 0.0)] * 2
        samples = [(-0.04, 0.02, 0.0), (0.04, 0.02, 0.0)]
        sample_normals = [(0.0, 1.0, 0.0)] * 2
        result = bridge_midline_concavities(
            positions, normals, samples, sample_normals, (0, 0, 0),
            (1, 0, 0), (0, 0, 1), (0, 1, 0),
        )
        self.assertAlmostEqual(result[0][1], 0.0164, places=4)
        self.assertEqual(result[1], positions[1])

    def test_midline_bridge_respects_front_and_rear_surface_normals(self):
        from shell_core import bridge_midline_concavities
        result = bridge_midline_concavities(
            [(0.0, 0.0, 0.0)],
            [(0.0, -1.0, 0.0)],
            [(-0.04, -0.02, 0.0), (0.04, -0.02, 0.0)],
            [(0.0, -1.0, 0.0)] * 2,
            (0, 0, 0), (1, 0, 0), (0, 0, 1), (0, 1, 0),
        )
        self.assertAlmostEqual(result[0][1], -0.0164, places=4)

    def test_midline_bridge_does_not_pull_surface_that_is_already_outward(self):
        from shell_core import bridge_midline_concavities
        result = bridge_midline_concavities(
            [(0.0, 0.03, 0.0)], [(0.0, 1.0, 0.0)],
            [(-0.04, 0.02, 0.0), (0.04, 0.02, 0.0)],
            [(0.0, 1.0, 0.0)] * 2, (0, 0, 0),
            (1, 0, 0), (0, 0, 1), (0, 1, 0),
        )
        self.assertEqual(result[0], (0.0, 0.03, 0.0))


if __name__ == "__main__":
    unittest.main()
