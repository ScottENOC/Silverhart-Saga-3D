#!/usr/bin/env python3
"""Validate the generated Ara character pack before Godot imports/exports it."""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data/characters/hollowmere_npcs.json"
ASSETS = ROOT / "art/characters/hollowmere"


def fail(message: str) -> None:
    raise SystemExit(f"Hollowmere Ara asset validation failed: {message}")


def main() -> None:
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    generated_path = ASSETS / "profiles.json"
    if not generated_path.is_file():
        fail("generated profiles.json is missing")
    generated = json.loads(generated_path.read_text(encoding="utf-8"))
    expected = {item["id"] for item in source.get("characters", [])}
    actual_items = generated.get("characters", [])
    actual = {item.get("id") for item in actual_items}
    if len(expected) != 14:
        fail(f"source cast changed unexpectedly: expected 13 village NPCs plus 1 player avatar, found {len(expected)}")
    if not any(item.get("id") == "player_avatar" and item.get("role") == "player avatar" for item in source.get("characters", [])):
        fail("generic Ara player avatar profile is missing")
    if len(actual_items) != len(expected) or actual != expected:
        fail(f"profile mismatch; missing={sorted(expected - actual)}, extra={sorted(actual - expected)}")

    for item in actual_items:
        character_id = item["id"]
        model_name = item.get("model", "")
        if model_name != f"{character_id}.glb":
            fail(f"{character_id}: unexpected model path {model_name!r}")
        model = ASSETS / model_name
        if not model.is_file():
            fail(f"{character_id}: model file is missing")
        data = model.read_bytes()
        if len(data) < 100_000:
            fail(f"{character_id}: model is suspiciously small ({len(data):,} bytes)")
        if len(data) < 12 or data[:4] != b"glTF":
            fail(f"{character_id}: file is not a GLB")
        version, declared_length = struct.unpack_from("<II", data, 4)
        if version != 2 or declared_length != len(data):
            fail(f"{character_id}: invalid GLB header (version={version}, declared={declared_length}, actual={len(data)})")
        params = ASSETS / f"{character_id}.params.json"
        if not params.is_file():
            fail(f"{character_id}: Ara parameter file is missing")

    print(f"Validated {len(actual_items)} Ara GLBs and parameter files for the complete Hollowmere cast.")


if __name__ == "__main__":
    main()
