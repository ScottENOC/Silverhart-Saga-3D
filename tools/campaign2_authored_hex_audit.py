#!/usr/bin/env python3
"""Inventory source-traceable Campaign 2 geometry already represented in 3D data.

This intentionally counts authored geometry, not the procedural terrain field.
Run from the repository root:
    python3 tools/campaign2_authored_hex_audit.py
Optionally pass --source-root ../Hex-crpg to validate source builder references.
"""
from __future__ import annotations

import argparse
import json
import math
import re
from collections import defaultdict
from pathlib import Path
from typing import Any


def read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def axial_key(q: int, r: int) -> str:
    return f"{q},{r}"


def round_away_from_zero(value: float) -> int:
    """Match Godot roundi(), including exact half-cell interpolation."""
    return math.floor(value + 0.5) if value >= 0 else math.ceil(value - 0.5)


def rasterize_segment(start: dict[str, Any], finish: dict[str, Any]) -> set[str]:
    """Match the project's cube-coordinate line rasterisation."""
    x1, z1 = int(start["q"]), int(start["r"])
    x2, z2 = int(finish["q"]), int(finish["r"])
    y1, y2 = -x1 - z1, -x2 - z2
    steps = max(1, abs(x1 - x2), abs(y1 - y2), abs(z1 - z2))
    cells: set[str] = set()
    for step in range(steps + 1):
        t = step / steps
        x = x1 + (x2 - x1) * t
        y = y1 + (y2 - y1) * t
        z = z1 + (z2 - z1) * t
        rx, ry, rz = round_away_from_zero(x), round_away_from_zero(y), round_away_from_zero(z)
        dx, dy, dz = abs(rx - x), abs(ry - y), abs(rz - z)
        if dx > dy and dx > dz:
            rx = -ry - rz
        elif dy > dz:
            ry = -rx - rz
        else:
            rz = -rx - ry
        cells.add(axial_key(rx, rz))
    return cells


def record_path_cells(path: dict[str, Any]) -> set[str]:
    cells: set[str] = set()
    points = path.get("points")
    if isinstance(points, list) and len(points) >= 2:
        for index in range(len(points) - 1):
            cells.update(rasterize_segment(points[index], points[index + 1]))
    elif isinstance(path.get("from"), dict) and isinstance(path.get("to"), dict):
        cells.update(rasterize_segment(path["from"], path["to"]))
    return cells


def building_cells(building: dict[str, Any]) -> set[str]:
    centre = building.get("center", {})
    if not isinstance(centre, dict):
        return set()
    q, r = int(centre.get("q", 0)), int(centre.get("r", 0))
    half_q, half_r = int(building.get("half_q", 0)), int(building.get("half_r", 0))
    return {
        axial_key(cell_q, cell_r)
        for cell_q in range(q - half_q, q + half_q + 1)
        for cell_r in range(r - half_r, r + half_r + 1)
    }


def polygon_cells(corners: list[dict[str, Any]]) -> set[str]:
    """Rasterise an authored q/r polygon by testing integer hex centres."""
    if len(corners) < 3:
        return set()
    points = [(float(point["q"]), float(point["r"])) for point in corners]
    min_q = math.floor(min(point[0] for point in points))
    max_q = math.ceil(max(point[0] for point in points))
    min_r = math.floor(min(point[1] for point in points))
    max_r = math.ceil(max(point[1] for point in points))
    cells: set[str] = set()
    for q in range(min_q, max_q + 1):
        for r in range(min_r, max_r + 1):
            inside = False
            j = len(points) - 1
            for i, (x1, y1) in enumerate(points):
                x2, y2 = points[j]
                if ((y1 > r) != (y2 > r)) and (q < (x2 - x1) * (r - y1) / (y2 - y1) + x1):
                    inside = not inside
                j = i
            on_boundary = any(
                abs((q - x1) * (y2 - y1) - (r - y1) * (x2 - x1)) < 1e-9
                and min(x1, x2) <= q <= max(x1, x2)
                and min(y1, y2) <= r <= max(y1, y2)
                for index, (x1, y1) in enumerate(points)
                for x2, y2 in [points[(index + 1) % len(points)]]
            )
            if inside or on_boundary:
                cells.add(axial_key(q, r))
    return cells


def prop_anchor_cells(props: list[dict[str, Any]]) -> set[str]:
    return {
        axial_key(int(prop["anchor"]["q"]), int(prop["anchor"]["r"]))
        for prop in props
        if isinstance(prop.get("anchor"), dict)
        and "q" in prop["anchor"] and "r" in prop["anchor"]
    }


def floor_room_cells(multistory: dict[str, Any]) -> tuple[int, int]:
    """Return total and unique walkable room cells using the Godot floor builder rules."""
    total = 0
    unique_by_floor: dict[str, set[str]] = defaultdict(set)
    for location in multistory.get("locations", []):
        if not isinstance(location, dict):
            continue
        for floor in location.get("floors", []):
            if not isinstance(floor, dict):
                continue
            floor_key = f'{location.get("id", "unknown")}:{floor.get("floor", 0)}'
            for room in floor.get("rooms", []):
                if not isinstance(room, dict):
                    continue
                centre = room.get("center", {})
                if not isinstance(centre, dict):
                    continue
                q, r = int(centre.get("q", 0)), int(centre.get("r", 0))
                half_q = int(room.get("half_width", 0))
                half_r = int(room.get("half_height", 0))
                row_shift_mode = str(room.get("row_shift_mode", "flat"))
                room_set: set[str] = set()
                for delta_q in range(-half_q + 1, half_q):
                    row_shift = (
                        math.floor(delta_q / 2)
                        if row_shift_mode == "source_building"
                        else -math.floor(delta_q / 2)
                    )
                    for delta_r in range(-half_r + 1, half_r):
                        room_set.add(axial_key(q + delta_q, r + delta_r + row_shift))
                total += len(room_set)
                unique_by_floor[floor_key].update(room_set)
    unique = sum(len(cells) for cells in unique_by_floor.values())
    return total, unique



def source_interior_door_parity_report(
    runtime: dict[str, Any],
    multistory: dict[str, Any],
    layouts: dict[str, Any],
    regional_features_text: str = "",
) -> dict[str, Any]:
    """Compare source interior door anchors with target doors and fort gate access points."""
    source_regions = runtime.get("interiors", [])
    source_doors: list[dict[str, Any]] = []
    for index, region in enumerate(source_regions if isinstance(source_regions, list) else []):
        if not isinstance(region, dict):
            continue
        door = region.get("doorHex")
        if not isinstance(door, dict) or "q" not in door or "r" not in door:
            continue
        source_doors.append({
            "source_region_index": index,
            "q": int(door["q"]),
            "r": int(door["r"]),
            "bounds": {
                "min_q": region.get("minQ"),
                "max_q": region.get("maxQ"),
                "min_r": region.get("minR"),
                "max_r": region.get("maxR"),
            },
        })

    target_doors: set[str] = set()
    for location in multistory.get("locations", []):
        if not isinstance(location, dict):
            continue
        for floor in location.get("floors", []):
            if not isinstance(floor, dict):
                continue
            for obj in floor.get("tile_objects", []):
                if not isinstance(obj, dict) or str(obj.get("type", "")) not in {"door_open", "door", "door_closed"}:
                    continue
                position = obj.get("position", {})
                if isinstance(position, dict) and "q" in position and "r" in position:
                    target_doors.add(axial_key(int(position["q"]), int(position["r"])))
    for settlement in layouts.get("settlements", []):
        if not isinstance(settlement, dict):
            continue
        for building in settlement.get("buildings", []):
            if not isinstance(building, dict):
                continue
            door = building.get("door", {})
            if isinstance(door, dict) and "q" in door and "r" in door:
                target_doors.add(axial_key(int(door["q"]), int(door["r"])))

    target_gate_anchors = {
        axial_key(int(match.group(2)), int(match.group(3)))
        for match in re.finditer(
            r"const\s+(NORTHWATCH_GATE|RIDGEHOLD_GATE)\s*:=\s*Vector2i\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)",
            regional_features_text,
        )
    }
    matched_door_objects = [
        record for record in source_doors
        if axial_key(record["q"], record["r"]) in target_doors
    ]
    matched_gate_access = [
        record for record in source_doors
        if axial_key(record["q"], record["r"]) not in target_doors
        and axial_key(record["q"], record["r"]) in target_gate_anchors
    ]
    missing = [
        record for record in source_doors
        if axial_key(record["q"], record["r"]) not in target_doors
        and axial_key(record["q"], record["r"]) not in target_gate_anchors
    ]
    return {
        "source_interior_region_count": len(source_regions) if isinstance(source_regions, list) else 0,
        "source_regions_with_door_anchor": len(source_doors),
        "target_unique_door_anchor_count": len(target_doors),
        "target_gate_access_anchor_count": len(target_gate_anchors),
        "matched_source_door_object_count": len(matched_door_objects),
        "matched_source_gate_access_count": len(matched_gate_access),
        "matched_source_door_anchor_count": len(source_doors) - len(missing),
        "missing_source_door_anchor_count": len(missing),
        "missing_source_door_anchors": missing,
        "method_note": "Matches source interior doorHex coordinates to target door tile objects/building door records or explicitly declared Northwatch/Ridgehold gate access anchors; does not compare complete floor shapes or furnishings.",
    }


def source_runtime_summary(runtime: dict[str, Any]) -> dict[str, Any]:
    """Summarise the original scene builder's resolved writes without counting overlaps twice."""
    builder_cells = {
        name: set(cells)
        for name, cells in runtime.get("terrainCellsByBuilder", {}).items()
        if isinstance(cells, list)
    }
    base_cells = builder_cells.get("setupVillageScene", set())
    feature_cells: set[str] = set().union(*(
        cells for name, cells in builder_cells.items() if name != "setupVillageScene"
    )) if any(name != "setupVillageScene" for name in builder_cells) else set()
    all_builder_cells = set().union(*builder_cells.values()) if builder_cells else set()
    object_types: dict[str, int] = defaultdict(int)
    for record in runtime.get("tileObjects", {}).values():
        if isinstance(record, dict):
            object_types[str(record.get("type", "unknown"))] += 1
    npc_baseline = runtime.get("npcBaseline", {})
    npc_placements: list[dict[str, Any]] = []
    npc_by_side: dict[str, int] = defaultdict(int)
    npc_by_faction: dict[str, int] = defaultdict(int)
    npc_by_race: dict[str, int] = defaultdict(int)
    npc_missing_hex = 0
    if isinstance(npc_baseline, dict):
        for npc_name, npc in npc_baseline.items():
            if not isinstance(npc, dict):
                continue
            hex_value = npc.get("hex", {})
            if not isinstance(hex_value, dict) or "q" not in hex_value or "r" not in hex_value:
                npc_missing_hex += 1
                hex_value = {}
            side = str(npc.get("side", "neutral"))
            faction = str(npc.get("factionId", ""))
            race = str(npc.get("race", ""))
            npc_by_side[side] += 1
            if faction:
                npc_by_faction[faction] += 1
            if race:
                npc_by_race[race] += 1
            npc_placements.append({
                "name": str(npc.get("name", npc_name)),
                "q": int(hex_value.get("q", 0)) if hex_value else None,
                "r": int(hex_value.get("r", 0)) if hex_value else None,
                "floor": int(npc.get("floor", 0)),
                "side": side,
                "faction_id": faction,
                "race": race,
                "dialogue_id": str(npc.get("dialogueId", "")),
                "behavior_type": str(npc.get("behaviorType", "")),
                "home_hex": npc.get("homeHex"),
                "patrol_path": npc.get("patrolPath", []),
            })
    npc_placements.sort(key=lambda item: item["name"].casefold())
    floors = 0
    for building in runtime.get("multiStoryBuildings", []):
        if not isinstance(building, dict):
            continue
        for floor in building.get("floors", []):
            if isinstance(floor, dict) and isinstance(floor.get("terrain"), dict):
                floors += 1
    world_grid = runtime.get("worldMapData", [])
    world_markers = []
    terrain_counts: dict[str, int] = defaultdict(int)
    faction_counts: dict[str, int] = defaultdict(int)
    for row_index, row in enumerate(world_grid if isinstance(world_grid, list) else []):
        if not isinstance(row, list):
            continue
        for column_index, cell in enumerate(row):
            if not isinstance(cell, dict):
                continue
            terrain_counts[str(cell.get("t", "unknown"))] += 1
            faction = str(cell.get("o", ""))
            faction_counts[faction or "unclaimed"] += 1
            if str(cell.get("n", "")).strip():
                world_markers.append({
                    "name": str(cell.get("n", "")),
                    "row": row_index,
                    "column": column_index,
                    "shape": str(cell.get("f", "")),
                    "faction": faction,
                })
    world_map_summary = {
        "rows": len(world_grid) if isinstance(world_grid, list) else 0,
        "columns": len(world_grid[0]) if isinstance(world_grid, list) and world_grid and isinstance(world_grid[0], list) else 0,
        "cells": sum(len(row) for row in world_grid if isinstance(row, list)) if isinstance(world_grid, list) else 0,
        "terrain_counts": dict(sorted(terrain_counts.items())),
        "faction_counts": dict(sorted(faction_counts.items())),
        "markers": world_markers,
        "river_waypoints": len(runtime.get("worldRiverPath", [])),
        "river_path": runtime.get("worldRiverPath", []),
    }
    return {
        "terrain_cells": int(runtime.get("counts", {}).get("terrainCells", 0)),
        "strategic_map": world_map_summary,
        "terrain_by_name": runtime.get("counts", {}).get("terrainByName", {}),
        "base_setup_builder_cells": len(base_cells),
        "feature_builder_cells_unique": len(feature_cells),
        "base_only_cells": len(base_cells - feature_cells),
        "base_feature_overlap_cells": len(base_cells & feature_cells),
        "builder_union_cells": len(all_builder_cells),
        "builder_cells_by_owner": {
            name: len(cells) for name, cells in sorted(
                builder_cells.items(), key=lambda item: (-len(item[1]), item[0])
            )
        },
        "tile_object_placements": int(runtime.get("counts", {}).get("tileObjectPlacements", 0)),
        "tile_objects_by_type": dict(sorted(object_types.items())),
        "interior_regions": int(runtime.get("counts", {}).get("interiorRegions", 0)),
        "multi_story_buildings": int(runtime.get("counts", {}).get("multiStoryBuildings", 0)),
        "multi_story_floor_maps": floors,
        "npc_placement_count": len(npc_placements),
        "npc_placements_missing_hex": npc_missing_hex,
        "npc_placements_by_side": dict(sorted(npc_by_side.items())),
        "npc_placements_by_faction": dict(sorted(npc_by_faction.items())),
        "npc_placements_by_race": dict(sorted(npc_by_race.items())),
        "npc_placements": npc_placements,
        "unicorn_patrol_waypoints": int(runtime.get("counts", {}).get("unicornPatrolWaypoints", 0)),
        "source_commit": runtime.get("source", {}).get("commit"),
        "warning": "Feature-builder cells overlap one another and the base setup; counts by builder must not be summed. The unique feature-builder union excludes setupVillageScene and is not a target parity percentage.",
    }


def strategic_map_parity_report(runtime: dict[str, Any], geography: dict[str, Any]) -> dict[str, Any]:
    """Compare the extracted source 16x16 map with the target's explicit source-derived rules."""
    world_grid = runtime.get("worldMapData", [])
    geo = geography.get("geography", {})
    dimensions = geography.get("coordinate_system", {}).get("strategic_grid_dimensions", {})
    expected_columns = int(dimensions.get("columns", 0))
    expected_rows = int(dimensions.get("rows", 0))
    ocean_columns = set(int(value) for value in geo.get("ocean_columns", []))
    human_lands = geo.get("human_lands", {})
    orc_lands = geo.get("orc_lands", {})
    dwarven = geo.get("dwarven_mountains", {})
    elven = geo.get("elven_forest", {})
    variation = geo.get("terrain_variation", {})
    hash_rule = variation.get("strategic_hash", {})
    mountain_threshold = float(variation.get("orc_mountain_threshold", 0.8))
    hills_threshold = float(variation.get("orc_hills_threshold", 0.6))
    overrides = geo.get("faction_overrides", [])

    mismatches: list[dict[str, Any]] = []
    for row in range(expected_rows):
        for column in range(expected_columns):
            if row >= len(world_grid) or not isinstance(world_grid[row], list) or column >= len(world_grid[row]):
                mismatches.append({"row": row, "column": column, "reason": "missing_source_cell"})
                continue
            cell = world_grid[row][column]
            if not isinstance(cell, dict):
                mismatches.append({"row": row, "column": column, "reason": "invalid_source_cell"})
                continue
            is_ocean = column in ocean_columns
            is_mountain = (
                int(dwarven.get("columns", [expected_columns, expected_columns - 1])[0])
                <= column <= int(dwarven.get("columns", [expected_columns, expected_columns - 1])[1])
                and int(dwarven.get("rows", [0, -1])[0]) <= row <= int(dwarven.get("rows", [0, -1])[1])
            )
            is_forest = (
                not is_ocean
                and int(elven.get("columns", [1, 0])[0]) <= column <= int(elven.get("columns", [1, 0])[1])
                and int(elven.get("rows", [1, 0])[0]) <= row <= int(elven.get("rows", [1, 0])[1])
            )
            is_orc = (
                int(orc_lands.get("columns", [expected_columns, expected_columns - 1])[0])
                <= column <= int(orc_lands.get("columns", [expected_columns, expected_columns - 1])[1])
            )
            terrain = "G"
            if is_ocean:
                terrain = "W"
            elif is_mountain:
                terrain = "M"
            elif is_forest:
                terrain = "F"
            elif is_orc:
                hash_x = column * float(hash_rule.get("x_scale", 1.0)) + float(hash_rule.get("x_offset", 0.0))
                hash_y = row * float(hash_rule.get("y_scale", 1.0)) + float(hash_rule.get("y_offset", 0.0))
                rough = math.sin(hash_x * 12.9898 + hash_y * 78.233) * 43758.5453
                rough -= math.floor(rough)
                if rough > mountain_threshold:
                    terrain = "M"
                elif rough > hills_threshold:
                    terrain = "H"

            faction = "" if is_ocean else ("d" if is_mountain else ("e" if is_forest else ("o" if is_orc else "h")))
            for override in overrides:
                columns = override.get("columns", [])
                rows = override.get("rows", [])
                if columns and rows and int(columns[0]) <= column <= int(columns[1]) and int(rows[0]) <= row <= int(rows[1]):
                    faction = {"dwarves": "d", "orcs": "o", "humans": "h", "elves": "e"}.get(str(override.get("faction", "")), faction)

            # Source location markers deliberately replace the base terrain/faction
            # record at their cell; compare the underlying rules only on unmarked cells.
            if not str(cell.get("n", "")).strip():
                if str(cell.get("t", "")) != terrain or str(cell.get("o", "")) != faction:
                    mismatches.append({
                        "row": row,
                        "column": column,
                        "expected_terrain": terrain,
                        "actual_terrain": str(cell.get("t", "")),
                        "expected_faction": faction,
                        "actual_faction": str(cell.get("o", "")),
                    })

    expected_river = geo.get("river_path", [])
    actual_river = [
        [int(point.get("x", -999)), int(point.get("y", -999))]
        for point in runtime.get("worldRiverPath", [])
        if isinstance(point, dict)
    ]
    markers = []
    for row_index, row in enumerate(world_grid if isinstance(world_grid, list) else []):
        if not isinstance(row, list):
            continue
        for column_index, cell in enumerate(row):
            if isinstance(cell, dict) and str(cell.get("n", "")).strip():
                markers.append({"name": str(cell["n"]), "row": row_index, "column": column_index})

    marker_validation_performed = bool(geography.get("strategic_markers"))
    marker_mismatches: list[dict[str, Any]] = []
    if marker_validation_performed:
        coordinate_system = geography.get("coordinate_system", {})
        origin = coordinate_system.get("origin", {})
        scale = int(coordinate_system.get("local_hexes_per_strategic_cell", 0))
        locations_by_id = {
            str(location.get("id", "")): location
            for location in geography.get("locations", [])
            if isinstance(location, dict)
        }
        occupied: set[tuple[int, int]] = set()
        expected_markers: dict[str, tuple[int, int]] = {}
        for marker in geography.get("strategic_markers", []):
            if not isinstance(marker, dict):
                continue
            marker_id = str(marker.get("id", ""))
            location = locations_by_id.get(marker_id)
            if not location or scale <= 0:
                marker_mismatches.append({"id": marker_id, "reason": "missing_location_or_scale"})
                continue
            local_q = int(location.get("q", 0))
            local_r = int(location.get("r", 0))
            desired_column = int(origin.get("column", 0)) + math.floor((local_q - int(origin.get("local_q", 0))) / scale + 0.5)
            desired_row = int(origin.get("row", 0)) + math.floor((local_r - int(origin.get("local_r", 0))) / scale + 0.5)
            candidates = [
                (desired_column, desired_row),
                (desired_column + 1, desired_row),
                (desired_column, desired_row + 1),
                (desired_column - 1, desired_row),
                (desired_column, desired_row - 1),
            ]
            chosen = (desired_column, desired_row)
            for candidate in candidates:
                column, row = candidate
                if column < 0 or column >= expected_columns or row < 0 or row >= expected_rows or candidate in occupied:
                    continue
                chosen = candidate
                break
            occupied.add(chosen)
            source_name = str(marker.get("source_name", location.get("name", marker_id)))
            expected_markers[source_name] = chosen
        actual_markers = {
            str(marker.get("name", "")): (int(marker.get("column", -1)), int(marker.get("row", -1)))
            for marker in markers
        }
        for name, expected_cell in expected_markers.items():
            if actual_markers.get(name) != expected_cell:
                marker_mismatches.append({
                    "name": name,
                    "expected_cell": expected_cell,
                    "actual_cell": actual_markers.get(name),
                })
        for name, actual_cell in actual_markers.items():
            if name not in expected_markers:
                marker_mismatches.append({"name": name, "actual_cell": actual_cell, "reason": "unexpected_source_marker"})

    return {
        "expected_dimensions": {"rows": expected_rows, "columns": expected_columns},
        "actual_dimensions": {
            "rows": len(world_grid) if isinstance(world_grid, list) else 0,
            "columns": len(world_grid[0]) if isinstance(world_grid, list) and world_grid and isinstance(world_grid[0], list) else 0,
        },
        "dimensions_match": (
            isinstance(world_grid, list)
            and len(world_grid) == expected_rows
            and all(isinstance(row, list) and len(row) == expected_columns for row in world_grid)
        ),
        "unmarked_terrain_faction_mismatch_count": len(mismatches),
        "mismatch_samples": mismatches[:20],
        "river_path_matches_geography": actual_river == expected_river,
        "expected_river_waypoints": len(expected_river),
        "actual_river_waypoints": len(actual_river),
        "marker_count": len(markers),
        "markers": markers,
        "marker_validation_performed": marker_validation_performed,
        "markers_match": (len(marker_mismatches) == 0) if marker_validation_performed else None,
        "marker_mismatch_count": len(marker_mismatches),
        "marker_mismatch_samples": marker_mismatches[:20],
        "hollowmere_marker_at_origin": (
            len(world_grid) > 6 and isinstance(world_grid[6], list) and len(world_grid[6]) > 6
            and str(world_grid[6][6].get("n", "")) == "Hollowmere"
        ),
    }


def build_report(
    project_root: Path,
    source_root: Path | None = None,
    source_runtime_path: Path | None = None,
) -> dict[str, Any]:
    data_root = project_root / "data" / "world"
    layouts = read_json(data_root / "campaign2_settlement_layouts.json")
    roads = read_json(data_root / "campaign2_road_paths.json")
    geography = read_json(data_root / "campaign2_geography.json")
    multistory = read_json(data_root / "campaign2_multistory_locations.json")

    road_cells: set[str] = set()
    road_record_cells = 0
    road_summary: dict[str, dict[str, int]] = {}
    for name, road in roads.get("roads", {}).items():
        cells = {
            axial_key(int(cell["q"]), int(cell["r"]))
            for cell in road.get("cells", [])
            if isinstance(cell, dict) and "q" in cell and "r" in cell
        }
        road_record_cells += len(road.get("cells", []))
        road_cells.update(cells)
        road_summary[name] = {"source_cell_records": len(road.get("cells", [])), "unique_cells": len(cells)}

    building_union: set[str] = set()
    path_union: set[str] = set()
    prop_union: set[str] = set()
    field_union: set[str] = set()
    fence_union: set[str] = set()
    crop_union: set[str] = set()
    settlement_summary: list[dict[str, Any]] = []
    feature_counts: dict[str, int] = defaultdict(int)
    for settlement in layouts.get("settlements", []):
        if not isinstance(settlement, dict):
            continue
        settlement_buildings: set[str] = set()
        settlement_paths: set[str] = set()
        settlement_props = prop_anchor_cells(settlement.get("props", []))
        settlement_fields: set[str] = set()
        settlement_fences: set[str] = set()
        settlement_crops: set[str] = set()
        for field in settlement.get("fields", []):
            if isinstance(field, dict):
                settlement_fields.update(polygon_cells(field.get("corners", [])))
        for fence in settlement.get("fences", []):
            if isinstance(fence, dict):
                settlement_fences.update(record_path_cells({"points": fence.get("points", [])}))
        for crop_row in settlement.get("crop_rows", []):
            if isinstance(crop_row, dict):
                settlement_crops.update(record_path_cells(crop_row))
        for building in settlement.get("buildings", []):
            if isinstance(building, dict):
                settlement_buildings.update(building_cells(building))
        for path in settlement.get("paths", []):
            if isinstance(path, dict):
                settlement_paths.update(record_path_cells(path))
        building_union.update(settlement_buildings)
        path_union.update(settlement_paths)
        prop_union.update(settlement_props)
        field_union.update(settlement_fields)
        fence_union.update(settlement_fences)
        crop_union.update(settlement_crops)
        feature_counts["building_records"] += len(settlement.get("buildings", []))
        feature_counts["path_records"] += len(settlement.get("paths", []))
        feature_counts["prop_records"] += len(settlement.get("props", []))
        settlement_summary.append({
            "id": settlement.get("id", "unknown"),
            "buildings": len(settlement.get("buildings", [])),
            "building_footprint_hexes": len(settlement_buildings),
            "paths": len(settlement.get("paths", [])),
            "path_hexes": len(settlement_paths),
            "props": len(settlement.get("props", [])),
            "prop_anchor_hexes": len(settlement_props),
            "field_hexes": len(settlement_fields),
            "fence_hexes": len(settlement_fences),
            "crop_row_hexes": len(settlement_crops),
            "unique_exterior_hexes": len(settlement_buildings | settlement_paths | settlement_props | settlement_fields | settlement_fences | settlement_crops),
        })

    strategic = geography.get("coordinate_system", {}).get("strategic_grid_dimensions", {})
    strategic_cells = int(strategic.get("columns", 0)) * int(strategic.get("rows", 0))
    local_categories = {
        "strategic_roads": road_cells,
        "settlement_building_footprints": building_union,
        "settlement_paths": path_union,
        "map_prop_anchors": prop_union,
        "field_footprints": field_union,
        "fence_lines": fence_union,
        "crop_rows": crop_union,
    }
    combined: set[str] = set().union(*local_categories.values())
    overlaps = {
        "road_and_building": len(road_cells & building_union),
        "road_and_settlement_path": len(road_cells & path_union),
        "building_and_settlement_path": len(building_union & path_union),
        "prop_anchor_on_other_geometry": len(prop_union & (road_cells | building_union | path_union)),
    }
    floor_total, floor_unique = floor_room_cells(multistory)
    source_runtime_data = read_json(source_runtime_path) if source_runtime_path else None
    source_runtime_report = source_runtime_summary(source_runtime_data) if source_runtime_data else None
    strategic_map_validation = (
        strategic_map_parity_report(source_runtime_data, geography)
        if source_runtime_data is not None and source_runtime_data.get("worldMapData")
        else None
    )
    regional_features_path = project_root / "data" / "world" / "regions" / "silverhart_heartland" / "features.gd"
    regional_features_text = regional_features_path.read_text(encoding="utf-8") if regional_features_path.is_file() else ""
    interior_door_validation = (
        source_interior_door_parity_report(source_runtime_data, multistory, layouts, regional_features_text)
        if source_runtime_data is not None and source_runtime_data.get("interiors") is not None
        else None
    )

    source_info = roads.get("source", {})
    source_validation: dict[str, Any] = {
        "repository": source_info.get("repository"),
        "branch": source_info.get("branch"),
        "commit": source_info.get("commit"),
        "file": "campaign2World.js",
        "checked": False,
        "missing_builder_symbols": [],
    }
    if source_root is not None:
        source_file = source_root / "campaign2World.js"
        if not source_file.is_file():
            raise FileNotFoundError(f"Source file not found: {source_file}")
        source_text = source_file.read_text(encoding="utf-8")
        symbols: set[str] = set()
        for settlement in layouts.get("settlements", []):
            source_builder = str(settlement.get("source_builder", ""))
            if "campaign2World.js:" in source_builder:
                symbol = source_builder.split("campaign2World.js:", 1)[1].split()[0]
                if symbol.startswith("build"):
                    symbols.add(symbol)
        source_validation["checked"] = True
        source_validation["missing_builder_symbols"] = sorted(
            symbol for symbol in symbols
            if f"function {symbol}(" not in source_text
        )
        source_validation["builder_symbols_checked"] = sorted(symbols)

    return {
        "title": "Campaign 2 authored-hex inventory",
        "method": {
            "counts": "Unique axial q,r cells represented by explicit target map records",
            "includes": ["strategic road cells", "settlement building footprints", "settlement path segments", "map prop anchor cells"],
            "separate": ["16x16 strategic grid", "interior floor room footprints"],
            "excludes": ["procedural grass/forest/noise terrain", "generated wilderness", "source-authored regional feature GDScript not yet ingested", "terrain elevation samples", "NPC positions", "visual mesh subdivisions"],
            "caveat": "This is a target-side authored-geometry inventory, not yet a source-to-target parity percentage. Source builders contain loops and helper-generated footprints; a source runtime extractor is required before claiming a complete source denominator.",
        },
        "source": source_validation,
        "source_runtime": source_runtime_report,
        "strategic_map_validation": strategic_map_validation,
        "interior_door_validation": interior_door_validation,
        "totals": {
            "strategic_grid_cells": strategic_cells,
            "road_cell_records_in_data": road_record_cells,
            "unique_strategic_road_cells": len(road_cells),
            "unique_building_footprint_cells": len(building_union),
            "unique_settlement_path_cells": len(path_union),
            "unique_prop_anchor_cells": len(prop_union),
            "unique_field_footprint_cells": len(field_union),
            "unique_fence_line_cells": len(fence_union),
            "unique_crop_row_cells": len(crop_union),
            "unique_local_exterior_authored_cells": len(combined),
            "interior_room_footprint_cells_sum": floor_total,
            "interior_room_footprint_cells_unique_per_floor": floor_unique,
            "building_records": feature_counts["building_records"],
            "settlement_path_records": feature_counts["path_records"],
            "prop_records": feature_counts["prop_records"],
            "prop_anchor_records_deduplicated": len(prop_union),
        },
        "overlaps": overlaps,
        "roads": road_summary,
        "settlements": settlement_summary,
    }


def render_markdown(report: dict[str, Any]) -> str:
    totals = report["totals"]
    lines = [
        "# Campaign 2 authored-hex inventory",
        "",
        "> Target-side inventory only. This is not a source-to-target parity percentage.",
        "",
        "## Counts",
        "",
        "| Geometry | Hexes / records |",
        "|---|---:|",
    ]
    labels = [
        ("Strategic 16×16 grid cells (separate scale)", "strategic_grid_cells"),
        ("Unique strategic road cells", "unique_strategic_road_cells"),
        ("Unique settlement building-footprint cells", "unique_building_footprint_cells"),
        ("Unique settlement path cells", "unique_settlement_path_cells"),
        ("Unique map prop-anchor cells", "unique_prop_anchor_cells"),
        ("Unique field-footprint cells", "unique_field_footprint_cells"),
        ("Unique fence-line cells", "unique_fence_line_cells"),
        ("Unique crop-row cells", "unique_crop_row_cells"),
        ("Unique local exterior authored cells (overlap removed)", "unique_local_exterior_authored_cells"),
        ("Interior room footprint cells (sum across floors)", "interior_room_footprint_cells_sum"),
        ("Building records", "building_records"),
        ("Settlement path records", "settlement_path_records"),
        ("Prop records", "prop_records"),
    ]
    for label, key in labels:
        lines.append(f"| {label} | {totals[key]:,} |")
    lines.extend([
        "",
        "## By settlement",
        "",
        "| Settlement | Buildings | Building cells | Paths | Path cells | Props | Prop anchors | Field cells | Fence cells | Crop cells | Unique exterior cells |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ])
    for item in report["settlements"]:
        lines.append(
            f'| {item["id"]} | {item["buildings"]} | {item["building_footprint_hexes"]:,} '
            f'| {item["paths"]} | {item["path_hexes"]:,} | {item["props"]} '
            f'| {item["prop_anchor_hexes"]:,} | {item["field_hexes"]:,} | {item["fence_hexes"]:,} '
            f'| {item["crop_row_hexes"]:,} | {item["unique_exterior_hexes"]:,} |'
        )
    lines.extend([
        "",
        "## Original source runtime capture",
        "",
        "No source runtime capture was supplied." if report.get("source_runtime") is None else (
            f'The pinned source scene resolved {report["source_runtime"]["terrain_cells"]:,} terrain cells. '
            f'{report["source_runtime"]["feature_builder_cells_unique"]:,} unique cells were touched by explicit feature builders other than the broad setupVillageScene base pass; '
            f'{report["source_runtime"]["base_only_cells"]:,} cells were touched only by that base pass, with '
            f'{report["source_runtime"]["base_feature_overlap_cells"]:,} overlaps. '
            f'The scene also produced {report["source_runtime"]["tile_object_placements"]:,} physical object placements, '
            f'{report["source_runtime"]["interior_regions"]:,} interior regions and '
            f'{report["source_runtime"]["multi_story_buildings"]:,} multi-storey definitions, and '
            f'{report["source_runtime"]["npc_placement_count"]:,} NPC/creature baseline placements. '
            "These are source-side runtime totals, not target coverage."
        ),
        "",
        "",
        "## Strategic map source parity",
        "",
        "No strategic map was captured." if report.get("strategic_map_validation") is None else (
            f'Source map dimensions: {report["strategic_map_validation"]["actual_dimensions"]["columns"]}×{report["strategic_map_validation"]["actual_dimensions"]["rows"]}; '
            f'{report["strategic_map_validation"]["marker_count"]} named markers; '
            f'{report["strategic_map_validation"]["actual_river_waypoints"]} river waypoints. '
            f'Unmarked terrain/faction mismatches against the target geography rules: '
            f'{report["strategic_map_validation"]["unmarked_terrain_faction_mismatch_count"]}; '
            f'river path match: {report["strategic_map_validation"]["river_path_matches_geography"]}; '
            f'all source marker positions match: {report["strategic_map_validation"]["markers_match"]}; '
            f'Hollowmere at strategic origin: {report["strategic_map_validation"]["hollowmere_marker_at_origin"]}.'
        ),
        "",
        "## Source interior door-anchor coverage",
        "",
        "No source interior door-anchor comparison was available." if report.get("interior_door_validation") is None else (
            f'Source door anchors matched: {report["interior_door_validation"]["matched_source_door_anchor_count"]:,} '
            f'of {report["interior_door_validation"]["source_regions_with_door_anchor"]:,}; '
            f'{report["interior_door_validation"]["matched_source_door_object_count"]:,} via target door objects and '
            f'{report["interior_door_validation"]["matched_source_gate_access_count"]:,} via declared fort gate access points; '
            f'missing: {report["interior_door_validation"]["missing_source_door_anchor_count"]:,}. '
            f'Target unique door objects: {report["interior_door_validation"]["target_unique_door_anchor_count"]:,}.'
        ),
        "",
        "This checks only source door coordinates against target door records. It does not establish room-wall, fixture, transition or full floor-shape parity.",
        "",
        "| Source terrain builder | Unique cells touched |",
        "|---|---:|",
    ])
    if report.get("source_runtime") is not None:
        for name, count in report["source_runtime"]["builder_cells_by_owner"].items():
            lines.append(f"| {name} | {count:,} |")
    lines.extend([
        "",
        "## Counting rules and limitations",
        "",
        report["method"]["caveat"],
        "",
        "The exterior total is the union of strategic road cells, settlement building footprints, settlement path segments, map prop anchors, authored field footprints, fence lines and crop rows. Overlaps are counted once. The strategic 16×16 map and interior floors are reported separately and are not added to the local exterior total.",
        "",
        "Procedural terrain, generated wilderness, terrain elevation samples, NPC positions and mesh subdivisions are excluded.",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source-root", type=Path, default=None, help="Optional checkout of ScottENOC/Hex-crpg")
    parser.add_argument("--source-runtime", type=Path, default=None, help="Optional JSON output from the original scene runtime extractor")
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    args = parser.parse_args()

    report = build_report(
        args.project_root.resolve(),
        args.source_root.resolve() if args.source_root else None,
        args.source_runtime.resolve() if args.source_runtime else None,
    )
    rendered_json = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    rendered_markdown = render_markdown(report)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(rendered_json, encoding="utf-8")
    if args.markdown_out:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(rendered_markdown, encoding="utf-8")
    print(rendered_markdown)
    if args.source_root and report["source"]["missing_builder_symbols"]:
        print("Missing source builder symbols:", ", ".join(report["source"]["missing_builder_symbols"]))
        return 1
    map_check = report.get("strategic_map_validation")
    if map_check is not None and (
        not map_check["dimensions_match"]
        or map_check["unmarked_terrain_faction_mismatch_count"] > 0
        or not map_check["river_path_matches_geography"]
        or not map_check["hollowmere_marker_at_origin"]
        or map_check["markers_match"] is False
    ):
        print("Strategic map parity validation failed:", json.dumps(map_check, indent=2))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
