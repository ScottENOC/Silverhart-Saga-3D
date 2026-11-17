#!/usr/bin/env python3
"""Read MakeHuman/MPFB .target and .target.gz files without applying them.

MakeHuman target rows are: vertex_index, x_offset, z_offset, y_offset.
The stored Y offset is sign-inverted. This module converts rows to XYZ offsets
but deliberately does not assume that a target's vertex indices match an
Ara-generated GLB.
"""
from __future__ import annotations

import argparse
import gzip
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class Target:
    path: str
    deltas: dict[int, tuple[float, float, float]]

    @property
    def affected_vertices(self) -> int:
        return len(self.deltas)

    @property
    def max_vertex_index(self) -> int:
        return max(self.deltas, default=-1)


def _open_text(path: Path):
    if path.suffix == ".gz":
        return gzip.open(path, "rt", encoding="utf-8")
    return path.open("rt", encoding="utf-8")


def parse_target_lines(lines: Iterable[str], source: str = "<memory>") -> Target:
    """Parse a MakeHuman target into {vertex_index: (x, y, z)} offsets."""
    deltas: dict[int, tuple[float, float, float]] = {}
    for line_number, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith('"'):
            continue
        fields = line.split()
        if len(fields) != 4:
            raise ValueError(
                f"{source}:{line_number}: expected 4 fields, got {len(fields)}"
            )
        try:
            vertex_index = int(fields[0])
            x_offset = float(fields[1])
            z_offset = float(fields[2])
            stored_y_offset = float(fields[3])
        except ValueError as exc:
            raise ValueError(f"{source}:{line_number}: invalid target row") from exc
        if vertex_index < 0:
            raise ValueError(f"{source}:{line_number}: negative vertex index")
        if vertex_index in deltas:
            raise ValueError(
                f"{source}:{line_number}: duplicate vertex index {vertex_index}"
            )
        deltas[vertex_index] = (x_offset, -stored_y_offset, z_offset)
    if not deltas:
        raise ValueError(f"{source}: target contains no vertex offsets")
    return Target(source, deltas)


def load_target(path: str | Path) -> Target:
    target_path = Path(path)
    with _open_text(target_path) as handle:
        return parse_target_lines(handle, str(target_path))


def validate_vertex_count(target: Target, vertex_count: int) -> None:
    """Raise if any target index is outside the supplied base mesh."""
    if vertex_count <= 0:
        raise ValueError("vertex_count must be positive")
    if target.max_vertex_index >= vertex_count:
        raise ValueError(
            f"{target.path}: target references vertex {target.max_vertex_index}, "
            f"but the base mesh has only {vertex_count} vertices"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="Path to .target or .target.gz")
    parser.add_argument(
        "--vertex-count",
        type=int,
        help="Optional base-mesh vertex count for index-range validation",
    )
    args = parser.parse_args()
    target = load_target(args.target)
    if args.vertex_count is not None:
        validate_vertex_count(target, args.vertex_count)
    print(f"Target: {target.path}")
    print(f"Affected vertices: {target.affected_vertices}")
    print(f"Maximum vertex index: {target.max_vertex_index}")
    if args.vertex_count is not None:
        print(f"Base mesh vertices: {args.vertex_count}")
        print("Index range: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
