#!/usr/bin/env python3
"""Generate a deterministic trio of reusable Ara NPC preview models.

Run from the pinned Ara checkout after setup-assets:
  python "$GITHUB_WORKSPACE/tools/ara/build_npc_previews.py" --out "$GITHUB_WORKSPACE/art/characters/npc"
Each character uses the same generator, base anatomy dataset, export format and game rig.
"""
import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILES = ROOT / "tools" / "ara" / "npc_profiles.json"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--detail", default="low", choices=("low", "medium", "high"))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    profiles = json.loads(PROFILES.read_text())
    if len(profiles) != 3 or len({p["id"] for p in profiles}) != 3:
        raise SystemExit("Expected exactly three uniquely identified NPC profiles")
    for profile in profiles:
        params = {
            "name": profile["name"],
            "seed": profile["seed"],
            "gender": profile["gender"],
            "age": profile["age"],
            "muscle": profile["muscle"],
            "weight": profile["weight"],
            "height": profile["height"],
            "proportions": profile["proportions"],
            "african": profile["african"],
            "asian": profile["asian"],
            "caucasian": profile["caucasian"],
            "hair": profile["hair"],
            "hairTint": profile["hairTint"],
            "outfit": "none",
            "top": profile["top"],
            "jacket": "none",
            "bottom": profile["bottom"],
            "underwear": True,
            "shoes": profile["shoes"],
            "hat": "none",
            "weapon": "none",
            "carry": "none",
            "detail": args.detail,
            "rig": "game",
            "restPose": "A",
            "animations": False,
            "faceBones": False,
            "faceShapes": False,
            "speechShapes": False,
            "expression": "neutral",
            "garmentStyles": {
                profile["top"]: {"pattern": "solid", "color": profile["shirt"], "color2": profile["shirt"]},
                profile["bottom"]: {"pattern": "solid", "color": profile["trousers"], "color2": profile["trousers"]}
            }
        }
        params_path = args.out / f"{profile['id']}.params.json"
        params_path.write_text(json.dumps(params, indent=2) + "\n")
        export_dir = args.out / f"{profile['id']}_export"
        export_dir.mkdir(exist_ok=True)
        subprocess.run([
            "npm", "run", "export", "--", "--params", str(params_path),
            "--detail", args.detail, "--formats", "glb", "--out", str(export_dir)
        ], check=True)
        candidates = sorted(export_dir.glob("*.glb"))
        if not candidates:
            raise SystemExit(f"Ara produced no GLB for {profile['id']}")
        target = args.out / f"{profile['id']}.glb"
        target.write_bytes(candidates[0].read_bytes())
        if target.stat().st_size < 100_000:
            raise SystemExit(f"Suspiciously small GLB for {profile['id']}: {target.stat().st_size}")
        print(f"Built {profile['name']}: {target} ({target.stat().st_size:,} bytes)")

if __name__ == "__main__":
    main()
