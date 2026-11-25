import json
import math
import unittest
from pathlib import Path

from tools.campaign2_authored_hex_audit import (
    building_cells,
    floor_room_cells,
    polygon_cells,
    rasterize_segment,
    round_away_from_zero,
    source_runtime_summary,
    strategic_map_parity_report,
    target_floor_cells_by_level,
    source_floor_cells_by_level,
    interior_floor_parity_report,
    source_road_parity_report,
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


    def test_source_road_parity_reports_exact_cell_differences(self):
        source = {"terrainCellsByBuilder": {"paintRoad": ["0,0", "1,0"]}}
        report = source_road_parity_report(source, {"0,0", "2,0"})
        self.assertEqual(report["matching_cells"], 1)
        self.assertEqual(report["source_only_samples"], ["1,0"])
        self.assertEqual(report["target_only_samples"], ["2,0"])
        self.assertFalse(report["matches_source"])

    def test_target_floor_cells_include_rooms_corridors_and_explicit_masks(self):
        target = {
            "locations": [{
                "id": "test",
                "floors": [{
                    "floor": 0,
                    "rooms": [{"center": {"q": 0, "r": 0}, "half_width": 2, "half_height": 2}],
                    "corridors": [{"from": {"q": 2, "r": 0}, "to": {"q": 4, "r": 0}}],
                    "floor_hexes": [{"q": 8, "r": 8}],
                    "tile_objects": [{"position": {"q": 9, "r": 8}}],
                }],
            }],
        }
        cells = target_floor_cells_by_level(target)[0]
        self.assertIn("0,0", cells)
        self.assertIn("2,0", cells)
        self.assertIn("4,0", cells)
        self.assertIn("8,8", cells)
        self.assertIn("9,8", cells)

    def test_source_floor_cells_use_surface_and_multistory_maps(self):
        source = {
            "terrain": {
                "0,0": {"name": "Wood Floor"},
                "1,0": {"name": "Cave Floor"},
                "2,0": {"name": "Grass"},
            },
            "interiors": [{"floorHexes": [{"q": 0, "r": 0}, {"q": 1, "r": 0}]}],
            "multiStoryBuildings": [{
                "floors": [None, {"terrain": {"0,0": "Wall", "1,0": "Wood Floor"}}],
            }],
        }
        cells = source_floor_cells_by_level(source)
        self.assertEqual(cells[0], {"0,0", "1,0"})
        self.assertNotIn(-9, cells)
        self.assertEqual(cells[1], {"1,0"})

    def test_interior_floor_parity_reports_coordinate_gaps(self):
        source = {
            "terrain": {"0,0": {"name": "Wood Floor"}, "1,0": {"name": "Wood Floor"}},
            "interiors": [{"floorHexes": [{"q": 0, "r": 0}, {"q": 1, "r": 0}]}],
            "multiStoryBuildings": [],
        }
        target = {
            "locations": [{
                "id": "test",
                "floors": [{
                    "floor": 0,
                    "rooms": [{"center": {"q": 0, "r": 0}, "half_width": 1, "half_height": 1}],
                    "corridors": [],
                }],
            }],
        }
        report = interior_floor_parity_report(source, target)
        self.assertEqual(report["levels"]["0"]["matching_cells"], 1)
        self.assertEqual(report["levels"]["0"]["source_only_cells"], 1)
        self.assertEqual(report["levels"]["0"]["source_only_samples"], ["1,0"])

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
            "npcBaseline": {
                "Mira Ashbrook": {
                    "name": "Mira Ashbrook",
                    "hex": {"q": 12, "r": 9},
                    "floor": 0,
                    "side": "neutral",
                    "factionId": "hollowmere",
                    "race": "human",
                    "dialogueId": "mira_ashbrook",
                    "behaviorType": "routine",
                },
            },
            "source": {"commit": "abc123"},
        })
        self.assertEqual(summary["feature_builder_cells_unique"], 2)
        self.assertEqual(summary["base_only_cells"], 1)
        self.assertEqual(summary["base_feature_overlap_cells"], 1)
        self.assertEqual(summary["builder_union_cells"], 3)
        self.assertEqual(summary["tile_objects_by_type"], {"table": 1})
        self.assertEqual(summary["multi_story_floor_maps"], 1)
        self.assertEqual(summary["npc_placement_count"], 1)
        self.assertEqual(summary["npc_placements"][0]["name"], "Mira Ashbrook")
        self.assertEqual(summary["npc_placements"][0]["q"], 12)
        self.assertEqual(summary["npc_placements_by_faction"], {"hollowmere": 1})


    def test_silverhart_ring_roads_are_closed_source_polylines(self):
        root = Path(__file__).resolve().parents[1]
        layout = json.loads((root / "data/world/campaign2_settlement_layouts.json").read_text(encoding="utf-8"))
        silverhart = next(item for item in layout["settlements"] if item["id"] == "silverhart")
        routes = {item["id"]: item for item in silverhart["paths"]}
        for route_id in ("silverhart_outer_ring_road", "silverhart_middle_ring_road"):
            route = routes[route_id]
            points = route["points"]
            self.assertEqual(len(points), 7, route_id)
            self.assertEqual(points[0], points[-1], route_id)
            self.assertEqual(len(route["widths"]), len(points), route_id)
            cells = set()
            for start, finish in zip(points, points[1:]):
                cells.update(rasterize_segment(start, finish))
            self.assertGreater(len(cells), 100, route_id)

    def test_strategic_map_matches_source_rules_and_river(self):
        geography = {
            "coordinate_system": {"strategic_grid_dimensions": {"columns": 16, "rows": 16}},
            "geography": {
                "ocean_columns": [0, 1],
                "orc_lands": {"columns": [10, 15], "rows": [0, 15]},
                "dwarven_mountains": {"columns": [12, 15], "rows": [0, 4]},
                "elven_forest": {"columns": [2, 9], "rows": [12, 15]},
                "river_path": [[1, 5], [2, 5]],
                "faction_overrides": [
                    {"columns": [10, 11], "rows": [0, 1], "faction": "dwarves"},
                    {"columns": [12, 15], "rows": [4, 4], "faction": "orcs"},
                ],
                "terrain_variation": {
                    "strategic_hash": {"x_scale": 2.3, "x_offset": 5, "y_scale": 1.7, "y_offset": 3},
                    "orc_mountain_threshold": 0.8,
                    "orc_hills_threshold": 0.6,
                },
            },
        }
        grid = []
        for row in range(16):
            line = []
            for column in range(16):
                is_ocean = column in (0, 1)
                is_mountain = 12 <= column <= 15 and 0 <= row <= 4
                is_forest = not is_ocean and 2 <= column <= 9 and 12 <= row <= 15
                is_orc = 10 <= column <= 15
                terrain = "G"
                if is_ocean:
                    terrain = "W"
                elif is_mountain:
                    terrain = "M"
                elif is_forest:
                    terrain = "F"
                elif is_orc:
                    rough = math.sin((column * 2.3 + 5) * 12.9898 + (row * 1.7 + 3) * 78.233) * 43758.5453
                    rough -= math.floor(rough)
                    if rough > 0.8:
                        terrain = "M"
                    elif rough > 0.6:
                        terrain = "H"
                faction = "" if is_ocean else ("d" if is_mountain else ("e" if is_forest else ("o" if is_orc else "h")))
                if 10 <= column <= 11 and row <= 1:
                    faction = "d"
                if 12 <= column <= 15 and row == 4:
                    faction = "o"
                line.append({"t": terrain, "o": faction, "f": "", "p": 0, "n": ""})
            grid.append(line)
        grid[6][6] = {"t": "G", "f": "V", "o": "h", "p": 1, "n": "Hollowmere"}
        runtime = {
            "worldMapData": grid,
            "worldRiverPath": [{"x": 1, "y": 5}, {"x": 2, "y": 5}],
        }
        report = strategic_map_parity_report(runtime, geography)
        self.assertTrue(report["dimensions_match"])
        self.assertEqual(report["unmarked_terrain_faction_mismatch_count"], 0)
        self.assertTrue(report["river_path_matches_geography"])
        self.assertTrue(report["hollowmere_marker_at_origin"])

    def test_strategic_map_parity_reports_terrain_and_river_drift(self):
        geography = {
            "coordinate_system": {"strategic_grid_dimensions": {"columns": 1, "rows": 1}},
            "geography": {
                "ocean_columns": [0],
                "orc_lands": {"columns": [1, 0], "rows": [0, 0]},
                "dwarven_mountains": {"columns": [1, 0], "rows": [1, 0]},
                "elven_forest": {"columns": [1, 0], "rows": [1, 0]},
                "river_path": [[0, 0]],
                "faction_overrides": [],
                "terrain_variation": {"strategic_hash": {}, "orc_mountain_threshold": 0.8, "orc_hills_threshold": 0.6},
            },
        }
        runtime = {
            "worldMapData": [[{"t": "G", "o": "h", "n": ""}]],
            "worldRiverPath": [{"x": 1, "y": 0}],
        }
        report = strategic_map_parity_report(runtime, geography)
        self.assertEqual(report["unmarked_terrain_faction_mismatch_count"], 1)
        self.assertFalse(report["river_path_matches_geography"])

    def test_strategic_marker_positions_follow_source_collision_order(self):
        geography = {
            "coordinate_system": {
                "strategic_grid_dimensions": {"columns": 3, "rows": 3},
                "local_hexes_per_strategic_cell": 10,
                "origin": {"local_q": 0, "local_r": 0, "column": 0, "row": 0},
            },
            "geography": {
                "ocean_columns": [],
                "orc_lands": {"columns": [3, 2], "rows": [0, 2]},
                "dwarven_mountains": {"columns": [3, 2], "rows": [0, -1]},
                "elven_forest": {"columns": [3, 2], "rows": [0, -1]},
                "river_path": [],
                "faction_overrides": [],
                "terrain_variation": {"strategic_hash": {}, "orc_mountain_threshold": 0.8, "orc_hills_threshold": 0.6},
            },
            "locations": [
                {"id": "first", "name": "First", "q": 0, "r": 0},
                {"id": "second", "name": "Second", "q": 1, "r": 0},
            ],
            "strategic_markers": [
                {"id": "first", "short": "V"},
                {"id": "second", "short": "F"},
            ],
        }
        grid = [[{"t": "G", "o": "h", "n": ""} for _ in range(3)] for _ in range(3)]
        grid[0][0]["n"] = "First"
        grid[0][1]["n"] = "Second"
        runtime = {
            "worldMapData": grid,
            "worldRiverPath": [],
        }
        report = strategic_map_parity_report(runtime, geography)
        self.assertTrue(report["markers_match"])
        grid[0][1]["n"] = "Wrong Cell"
        report = strategic_map_parity_report(runtime, geography)
        self.assertFalse(report["markers_match"])


if __name__ == "__main__":
    unittest.main()
