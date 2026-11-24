import unittest

from tools.campaign2_authored_hex_audit import (
    building_cells,
    floor_room_cells,
    rasterize_segment,
)


class Campaign2AuthoredHexAuditTests(unittest.TestCase):
    def test_building_footprint_includes_both_edges(self):
        cells = building_cells({
            "center": {"q": 2, "r": -3},
            "half_q": 1,
            "half_r": 2,
        })
        self.assertEqual(len(cells), 15)
        self.assertIn("1,-5", cells)
        self.assertIn("3,-1", cells)

    def test_axial_segment_includes_endpoints_and_is_contiguous(self):
        cells = rasterize_segment({"q": 0, "r": 0}, {"q": 4, "r": -2})
        self.assertEqual(len(cells), 5)
        self.assertIn("0,0", cells)
        self.assertIn("4,-2", cells)

    def test_zero_length_segment_is_one_cell(self):
        cells = rasterize_segment({"q": -7, "r": 12}, {"q": -7, "r": 12})
        self.assertEqual(cells, {"-7,12"})

    def test_room_cells_are_separated_by_floor(self):
        data = {
            "locations": [
                {
                    "id": "tower",
                    "floors": [
                        {
                            "floor": 0,
                            "rooms": [{"center": {"q": 0, "r": 0}, "half_width": 1, "half_height": 1}],
                        },
                        {
                            "floor": 1,
                            "rooms": [{"center": {"q": 0, "r": 0}, "half_width": 1, "half_height": 1}],
                        },
                    ],
                }
            ]
        }
        total, unique = floor_room_cells(data)
        self.assertEqual(total, 18)
        self.assertEqual(unique, 18)


if __name__ == "__main__":
    unittest.main()
