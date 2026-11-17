#!/usr/bin/env python3
"""Extract the exact hip/shoulder body modifiers from the installed Ara schema.

This deliberately does not guess modifier IDs or alter a character profile.
The schema is generated from the same asset catalogue used by the CLI version.
"""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path

PATTERNS = {
    "hips": re.compile(r"hip|pelvis|glute|buttock", re.I),
    "shoulders": re.compile(r"shoulder|clavicle|upper.?torso", re.I),
}

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()
    schema = json.loads(args.schema.read_text(encoding="utf-8"))
    try:
        modifiers = schema["properties"]["params"]["properties"]["modifiers"]["properties"]
    except KeyError as exc:
        raise SystemExit(f"Installed Ara schema has no expected modifiers catalogue: {exc}")
    results = {}
    for group, pattern in PATTERNS.items():
        matches = []
        for modifier_id, spec in sorted(modifiers.items()):
            label = str(spec.get("description", ""))
            if pattern.search(modifier_id) or pattern.search(label):
                matches.append({
                    "id": modifier_id,
                    "label": label,
                    "minimum": spec.get("minimum"),
                    "maximum": spec.get("maximum"),
                })
        results[group] = matches
    if not any(results.values()):
        raise SystemExit("No hip/pelvis or shoulder/clavicle modifiers found; refusing to invent IDs.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({
        "source": "ara3d schema character",
        "schema_id": schema.get("$id"),
        "modifier_count": len(modifiers),
        "matches": results,
        "note": "Exact IDs/ranges from this installed CLI schema. Review target direction in the Ara slider catalogue before assigning values."
    }, indent=2) + "\n", encoding="utf-8")
    for group, matches in results.items():
        print(f"\\n{group.upper()} ({len(matches)})")
        for item in matches:
            print(f"  {item['id']}: {item['label']} [{item['minimum']}, {item['maximum']}]")
    print(f"\\nWrote {args.output}")

if __name__ == "__main__":
    main()
