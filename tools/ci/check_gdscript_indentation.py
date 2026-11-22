#!/usr/bin/env python3
"""Check indentation conventions declared in the repository .editorconfig."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TAB_EXTENSIONS = {".tscn", ".tres"}
SPACE_WIDTHS = {".gd": 4, ".json": 2}


def check_file(path: Path) -> list[tuple[int, str]]:
    issues: list[tuple[int, str]] = []
    extension = path.suffix.lower()
    in_multiline_string = False

    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.lstrip(" \t")
        if not stripped:
            continue

        if extension == ".gd":
            quote_count = line.count('"""')
            if in_multiline_string:
                if quote_count % 2:
                    in_multiline_string = False
                continue

        prefix = line[: len(line) - len(stripped)]
        if extension in TAB_EXTENSIONS:
            if " " in prefix:
                reason = "mixed tabs and spaces" if "\t" in prefix else "spaces used; expected tabs"
                issues.append((number, reason))
        elif extension in SPACE_WIDTHS:
            if "\t" in prefix:
                issues.append((number, "tab used; expected spaces"))
            elif len(prefix) % SPACE_WIDTHS[extension]:
                width = SPACE_WIDTHS[extension]
                issues.append((number, f"indentation is not a multiple of {width} spaces"))

        if extension == ".gd" and line.count('"""') % 2:
            in_multiline_string = True

    return issues


def main() -> int:
    files = sorted(
        path for path in ROOT.rglob("*")
        if path.is_file()
        and path.suffix.lower() in TAB_EXTENSIONS | SPACE_WIDTHS.keys()
        and not any(part in {".git", ".godot"} for part in path.parts)
    )
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
    print("All scanned files comply with their .editorconfig indentation rules.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
