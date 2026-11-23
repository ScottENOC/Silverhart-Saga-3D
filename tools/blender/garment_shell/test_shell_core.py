import unittest

from shell_core import build_shell


class ShellCoreTests(unittest.TestCase):
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
                            [-1, 1, 1, -1, 1, -1], 0.01)
        self.assertEqual(shell.surface_face_count, 2)
        self.assertEqual(len(shell.boundary_edges), 6)
        self.assertEqual(len(shell.positions), 6 + 6)

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


if __name__ == "__main__":
    unittest.main()
