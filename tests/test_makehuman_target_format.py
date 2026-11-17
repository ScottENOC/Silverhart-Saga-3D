import gzip
import tempfile
import unittest
from pathlib import Path

from tools.makehuman.target_format import (
    load_target,
    parse_target_lines,
    validate_vertex_count,
)


class MakeHumanTargetFormatTests(unittest.TestCase):
    def test_parses_axis_order_and_inverted_y(self):
        target = parse_target_lines([
            "# basemesh hm08\n",
            "3 0.1 0.3 -0.2\n",
            "9 -.05 .0 .04\n",
        ])
        self.assertEqual(target.deltas[3], (0.1, 0.2, 0.3))
        self.assertEqual(target.deltas[9], (-0.05, -0.04, 0.0))

    def test_loads_gzip_target(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sample.target.gz"
            with gzip.open(path, "wt", encoding="utf-8") as handle:
                handle.write("12 0.01 0.02 -0.03\n")
            target = load_target(path)
        self.assertEqual(target.deltas[12], (0.01, 0.03, 0.02))

    def test_rejects_duplicate_indices(self):
        with self.assertRaisesRegex(ValueError, "duplicate vertex index"):
            parse_target_lines(["1 0 0 0\n", "1 0.1 0 0\n"])

    def test_rejects_out_of_range_indices(self):
        target = parse_target_lines(["8 0.1 0.0 0.0\n"])
        with self.assertRaisesRegex(ValueError, "only 8 vertices"):
            validate_vertex_count(target, 8)

    def test_rejects_malformed_rows(self):
        with self.assertRaisesRegex(ValueError, "expected 4 fields"):
            parse_target_lines(["1 0.1 0.2\n"])


if __name__ == "__main__":
    unittest.main()
