#!/usr/bin/env python3
"""Reject space-based or mixed indentation in GDScript source files.

Blank lines and the contents of triple-quoted multiline strings are ignored.
The repository convention is one tab per indentation level.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def violations(path: Path) -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []
    in_multiline_string = False

    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.lstrip(" \t")
        if not stripped:
            continue

        # GDScript multiline strings use triple double quotes. Their content is
        # data, not code indentation, so do not inspect it.
        quote_count = line.count('"""')
        if in_multiline_string:
            if quote_count % 2:
                in_multiline_string = False
            continue

        prefix = line[: len(line) - len(stripped)]
        if " " in prefix:
            reason = "mixed tabs and spaces" if "\t" in prefix else "spaces used for indentation"
            found.append((number, reason))

        if quote_count % 2:
            in_multiline_string = True

    return found


def main() -> int:
    files = sorted(ROOT.rglob("*.gd"))
    failures = 0
    for path in files:
        # Ignore generated/imported directories and Git metadata.
        if any(part in {".git", ".godot"} for part in path.parts):
            continue
        issues = violations(path)
        if issues:
            failures += len(issues)
            rel = path.relative_to(ROOT)
            for line, reason in issues:
                print(f"{rel}:{line}: {reason}")

    if failures:
        print(f"\nFound {failures} GDScript indentation issue(s). Use tabs, not spaces.")
        return 1

    print(f"Checked {len(files)} GDScript files: indentation is tab-only.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
