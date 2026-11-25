#!/usr/bin/env python3
"""Integrate current gender-specific adult anatomy into raw Hollowmere Ara exports.

Every output is rebuilt from a fresh, unsculpted Ara export. Female anatomy uses
the accepted surface-following/subdivision workflow; male anatomy uses the
current dedicated male anatomy builder. Never run either sculpt on an already
anatomy-integrated GLB.
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


def run_blender(script: Path, *arguments: str) -> None:
    command = [
        "blender", "--background", "--python-exit-code", "1",
        "--python", str(script), "--", *arguments,
    ]
    subprocess.run(command, cwd=ROOT, check=True)


def apply_female_anatomy(source: Path, output: Path) -> None:
    """Apply the validated integrated v2 external sculpt to a fresh female Ara GLB."""
    run_blender(
        FEMALE_TOOL,
        "--input", str(source),
        "--output", str(output),
        "--profile", "female",
        "--adult",
        "--method", "integrated",
        "--deformation-scale", "1.65",
        "--no-canal",
        "--no-anus",
    )
    if not output.is_file() or output.stat().st_size < 100_000:
        raise SystemExit(f"Female anatomy integration did not produce a valid GLB: {output}")
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
            male_arguments = [
                "--input", str(source),
                "--output", str(output),
                "--adult",
                "--profile-name", character_id,
            ]
            authored_size = character.get("anatomy_size", {})
            if isinstance(authored_size, dict) and authored_size:
                male_arguments.extend([
                    "--length-scale", str(authored_size.get("length_scale", 1.0)),
                    "--girth-scale", str(authored_size.get("girth_scale", 1.0)),
                    "--variation-strength", "0",
                ])
            else:
                variation_seed = str(params.get("seed", character_id))
                male_arguments.extend([
                    "--variation-seed", variation_seed,
                    "--variation-strength", "1.0",
                ])
            run_blender(MALE_TOOL, *male_arguments)
        else:
            apply_female_anatomy(source, output)
        if not output.is_file() or output.stat().st_size < 100_000:
            raise SystemExit(f"Anatomy integration did not produce a valid GLB: {output}")
        os.replace(output, source)
        processed += 1
        print(f"Integrated anatomy v2: {character_id} ({'male' if int(params.get('gender', 0)) == 1 else 'female'})", flush=True)
    print(f"Integrated current gender-specific anatomy into {processed} adult Hollowmere models; skipped {skipped} non-adult models.", flush=True)


if __name__ == "__main__":
    main()
