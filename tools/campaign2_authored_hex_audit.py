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


def build_report(project_root: Path, source_root: Path | None = None) -> dict[str, Any]:
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
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    args = parser.parse_args()

    report = build_report(args.project_root.resolve(), args.source_root.resolve() if args.source_root else None)
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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
