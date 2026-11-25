#!/usr/bin/env python3
"""Check that each GDScript file uses one consistent indentation style."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TAB_EXTENSIONS = {".tscn", ".tres"}
SPACE_WIDTHS = {".json": 2}
SPACE_GDSCRIPT_FILES = {"scripts/simulation/world_simulation.gd"}


def check_file(path: Path) -> list[tuple[int, str]]:
    issues: list[tuple[int, str]] = []
    extension = path.suffix.lower()
    in_multiline_string = False
    gdscript_style: str | None = None

    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.lstrip(" \t")
        if not stripped:
            continue

        quote_count = line.count('"""') if extension == ".gd" else 0
        if in_multiline_string:
            if quote_count % 2:
                in_multiline_string = False
            continue

        prefix = line[: len(line) - len(stripped)]
        has_tabs = "\t" in prefix
        has_spaces = " " in prefix

        if extension == ".gd":
            relative_path = path.relative_to(ROOT).as_posix()
            if relative_path in SPACE_GDSCRIPT_FILES:
                if has_tabs:
                    issues.append((number, "tabs used; this legacy file uses four-space indentation"))
                elif has_spaces and len(prefix) % 4:
                    issues.append((number, "indentation is not a multiple of four spaces"))
            elif has_spaces:
                reason = "mixed tabs and spaces in indentation" if has_tabs else "spaces used; expected tabs"
                issues.append((number, reason))
            elif prefix:
                line_style = "tabs"
                if gdscript_style is None:
                    gdscript_style = line_style
                elif line_style != gdscript_style:
                    issues.append((number, f"{line_style} used; this file uses {gdscript_style}"))
        elif extension in TAB_EXTENSIONS:
            if has_spaces:
                reason = "mixed tabs and spaces" if has_tabs else "spaces used; expected tabs"
                issues.append((number, reason))
        elif extension in SPACE_WIDTHS:
            if has_tabs:
                issues.append((number, "tab used; expected spaces"))
            elif len(prefix) % SPACE_WIDTHS[extension]:
                width = SPACE_WIDTHS[extension]
                issues.append((number, f"indentation is not a multiple of {width} spaces"))

        if quote_count % 2:
            in_multiline_string = True

    return issues


def main() -> int:
    requested = [Path(arg) for arg in sys.argv[1:]]
    files = sorted((ROOT / path).resolve() for path in requested) if requested else sorted(
        path for path in ROOT.rglob("*")
        if path.is_file()
        and path.suffix.lower() in TAB_EXTENSIONS | {".gd", ".json"}
        and not any(part in {".git", ".godot"} for part in path.parts)
    )
    files = [path for path in files if path.is_file() and path.is_relative_to(ROOT)]
    counts = {ext: 0 for ext in (".gd", ".tscn", ".tres", ".json")}
    failures = 0

    for path in files:
        counts[path.suffix.lower()] += 1
        for line, reason in check_file(path):
            failures += 1
            print(f"{path.relative_to(ROOT)}:{line}: {reason}")

    print(
        "Scanned " + ", ".join(f"{ext}={counts[ext]}" for ext in counts)
        + f" ({len(files)} files total)."
    )
    if failures:
        print(f"Found {failures} indentation issue(s).")
        return 1
    print("All scanned files use consistent indentation.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
