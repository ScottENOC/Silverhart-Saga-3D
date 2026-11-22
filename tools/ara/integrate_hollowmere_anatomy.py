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
FEMALE_PLAN_TOOL = ROOT / "tools" / "blender" / "plan_female_anatomy_subdivision.py"
FEMALE_TOOL = ROOT / "tools" / "blender" / "add_female_anatomy_surface.py"
MALE_TOOL = ROOT / "tools" / "blender" / "add_male_anatomy.py"
ADULT_AGE_THRESHOLD = 0.34375


def run_blender(script: Path, *arguments: str) -> None:
    command = [
        "blender", "--background", "--python-exit-code", "1",
        "--python", str(script), "--", *arguments,
    ]
    subprocess.run(command, cwd=ROOT, check=True)


def apply_female_anatomy(source: Path, output: Path, shared_plan: Path) -> None:
    report = output.with_name(output.stem + ".female-anatomy-report.json")
    try:
        run_blender(
            FEMALE_TOOL,
            "--input", str(source),
            "--output", str(output),
            "--report", str(report),
            "--subdivision-plan", str(shared_plan),
            "--adult",
            "--deformation-scale", "1.65",
        )
    except subprocess.CalledProcessError:
        # Ara female exports normally share identical source topology. If a
        # future generator change breaks that assumption, safely create a
        # character-specific plan rather than applying mismatched edge indices.
        local_plan = output.with_name(output.stem + ".female-anatomy-plan.json")
        print(
            f"Shared female subdivision plan did not fit {source.name}; "
            "building a character-specific plan.",
            flush=True,
        )
        run_blender(
            FEMALE_PLAN_TOOL,
            "--input", str(source),
            "--output", str(local_plan),
        )
        run_blender(
            FEMALE_TOOL,
            "--input", str(source),
            "--output", str(output),
            "--report", str(report),
            "--subdivision-plan", str(local_plan),
            "--adult",
            "--deformation-scale", "1.65",
        )
        local_plan.unlink(missing_ok=True)
    if not report.is_file() or '"clothing_operations": "not run"' not in report.read_text():
        raise SystemExit(f"Female anatomy report failed validation: {report}")
    report.unlink()


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
    female_plan = Path("/tmp/hollowmere-female-anatomy-subdivision-plan.json")
    female_plan.unlink(missing_ok=True)
    female_plan_ready = False
    try:
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
                run_blender(
                    MALE_TOOL,
                    "--input", str(source),
                    "--output", str(output),
                    "--adult",
                    "--profile-name", character_id,
                )
            else:
                if not female_plan_ready:
                    run_blender(
                        FEMALE_PLAN_TOOL,
                        "--input", str(source),
                        "--output", str(female_plan),
                    )
                    if not female_plan.is_file() or female_plan.stat().st_size == 0:
                        raise SystemExit("Female anatomy subdivision plan was not produced.")
                    female_plan_ready = True
                apply_female_anatomy(source, output, female_plan)
            if not output.is_file() or output.stat().st_size < 100_000:
                raise SystemExit(f"Anatomy integration did not produce a valid GLB: {output}")
            os.replace(output, source)
            processed += 1
            print(f"Integrated anatomy: {character_id} ({'male' if int(params.get('gender', 0)) == 1 else 'female'})", flush=True)
    finally:
        female_plan.unlink(missing_ok=True)
    print(f"Integrated current gender-specific anatomy into {processed} adult Hollowmere models; skipped {skipped} non-adult models.", flush=True)


if __name__ == "__main__":
    main()
