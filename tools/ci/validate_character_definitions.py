#!/usr/bin/env python3
"""Fail the build when canonical character inventory and equipment disagree."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from character_definitions import load_item_catalog, validate_character_definitions

manifest_path = ROOT / "data" / "characters" / "hollowmere_npcs.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
items = load_item_catalog()
validate_character_definitions(manifest, items)
print(f"Validated {len(manifest['characters'])} canonical character definitions against {len(items)} item definitions.")
