#!/usr/bin/env python3
"""Integrate age-appropriate, gendered adult anatomy into each generated Hollowmere NPC GLB.

The output remains the NPC's own deterministic Ara export: anatomy is integrated
into its skin geometry in Blender, then the finished GLB is loaded by Godot.
"""
import argparse
import json
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FEMALE_TOOL = ROOT / "tools" / "blender" / "add_adult_anatomy.py"
MALE_TOOL = ROOT / "tools" / "blender" / "add_male_anatomy.py"
ADULT_AGE_THRESHOLD = 0.34375


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    args = parser.parse_args()
    directory = args.directory.resolve()
    manifest_path = directory / "profiles.json"
    if not manifest_path.is_file():
        raise SystemExit(f"Missing NPC manifest: {manifest_path}")
    manifest = json.loads(manifest_path.read_text())
    processed = 0
    skipped = 0
    for character in manifest.get("characters", []):
        character_id = str(character["id"])
        params = character.get("params", {})
        age = float(params.get("age", 0.0))
        if age < ADULT_AGE_THRESHOLD:
            print(f"Skipping anatomy for non-adult profile: {character_id} (age slider {age:.3f})", flush=True)
            skipped += 1
            continue
        source = directory / str(character.get("model", f"{character_id}.glb"))
        if not source.is_file():
            raise SystemExit(f"Missing generated NPC model: {source}")
        output = source.with_name(source.stem + ".anatomy.glb")
        if int(params.get("gender", 0)) == 1:
            command = [
                "blender", "--background", "--python-exit-code", "1",
                "--python", str(MALE_TOOL), "--",
                "--input", str(source), "--output", str(output),
                "--adult", "--profile-name", character_id,
            ]
        else:
            command = [
                "blender", "--background", "--python-exit-code", "1",
                "--python", str(FEMALE_TOOL), "--",
                "--input", str(source), "--output", str(output),
                "--profile", "female", "--adult",
            ]
        print(f"Integrating {'male' if int(params.get('gender', 0)) == 1 else 'female'} anatomy: {character_id}", flush=True)
        subprocess.run(command, cwd=ROOT, check=True)
        if not output.is_file() or output.stat().st_size < 100_000:
            raise SystemExit(f"Anatomy integration did not produce a valid GLB: {output}")
        os.replace(output, source)
        processed += 1
    print(f"Integrated anatomy into {processed} adult Hollowmere models; skipped {skipped} non-adult models.", flush=True)


if __name__ == "__main__":
    main()
