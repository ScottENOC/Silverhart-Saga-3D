import unittest

from tools.campaign2_authored_hex_audit import (
    building_cells,
    floor_room_cells,
    polygon_cells,
    rasterize_segment,
    round_away_from_zero,
    source_runtime_summary,
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

    def test_half_values_match_godot_roundi(self):
        self.assertEqual(round_away_from_zero(0.5), 1)
        self.assertEqual(round_away_from_zero(-0.5), -1)

    def test_axis_aligned_field_includes_boundary_hex_centres(self):
        cells = polygon_cells([
            {"q": -1, "r": 2},
            {"q": 1, "r": 2},
            {"q": 1, "r": 4},
            {"q": -1, "r": 4},
        ])
        self.assertEqual(len(cells), 9)
        self.assertIn("-1,2", cells)
        self.assertIn("1,4", cells)

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
        self.assertEqual(total, 2)
        self.assertEqual(unique, 2)

    def test_room_cells_match_source_building_row_shift_and_interior_bounds(self):
        data = {
            "locations": [{
                "id": "shifted",
                "floors": [{
                    "floor": 0,
                    "rooms": [{
                        "center": {"q": 0, "r": 0},
                        "half_width": 2,
                        "half_height": 2,
                        "row_shift_mode": "source_building",
                    }],
                }],
            }],
        }
        total, unique = floor_room_cells(data)
        self.assertEqual(total, 9)
        self.assertEqual(unique, 9)


    def test_source_runtime_summary_deduplicates_builder_overlaps(self):
        summary = source_runtime_summary({
            "counts": {
                "terrainCells": 3,
                "terrainByName": {"Grass": 2, "Path": 1},
                "tileObjectPlacements": 1,
                "interiorRegions": 2,
                "multiStoryBuildings": 1,
                "unicornPatrolWaypoints": 8,
            },
            "terrainCellsByBuilder": {
                "setupVillageScene": ["0,0", "1,0"],
                "buildTown": ["1,0", "2,0"],
            },
            "tileObjects": {"0,0": {"type": "table"}},
            "multiStoryBuildings": [{"floors": [None, {"terrain": {"0,0": "Wood Floor"}}]}],
            "source": {"commit": "abc123"},
        })
        self.assertEqual(summary["feature_builder_cells_unique"], 2)
        self.assertEqual(summary["base_only_cells"], 1)
        self.assertEqual(summary["base_feature_overlap_cells"], 1)
        self.assertEqual(summary["builder_union_cells"], 3)
        self.assertEqual(summary["tile_objects_by_type"], {"table": 1})
        self.assertEqual(summary["multi_story_floor_maps"], 1)


if __name__ == "__main__":
    unittest.main()
