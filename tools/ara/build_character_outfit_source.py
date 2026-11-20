#!/usr/bin/env python3
"""Export selected Ara garments against one character's exact body profile.

The output is a complete Ara GLB used only as a fitted garment source. The
caller can transfer selected garment primitives onto that character's accepted
body GLB without changing the accepted body geometry or its custom details.
"""
import argparse
import json
import shutil
import subprocess
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--under-top", default="bra")
    parser.add_argument("--under-bottom", default="bikini_bottom")
    parser.add_argument("--colour", default="#0F52BA")
    parser.add_argument("--detail", choices=("low", "medium", "high"), default="high")
    args = parser.parse_args()

    ara_root = Path.cwd()
    if not (ara_root / "package.json").exists() or not (ara_root / "src").exists():
        raise SystemExit("Run this script from the pinned Ara 3D Gen repository root")
    if not args.profile.is_file():
        raise SystemExit(f"Missing character profile: {args.profile}")

    source = json.loads(args.profile.read_text())
    params = dict(source.get("params", {}))
    if not params:
        raise SystemExit("Character profile has no params object")

    # Keep the target's complete identity/body shape (including modifiers,
    # complexion, ears and seed) and ask Ara to build only these fitted layers.
    params.update({
        "name": params.get("name", "Character"),
        "outfit": "none",
        "top": "none",
        "underTop": args.under_top,
        "underBottom": args.under_bottom,
        "jacket": "none",
        "bottom": "none",
        "underwear": False,
        "shoes": "none",
        "hat": "none",
        "weapon": "none",
        "carry": "none",
        "accessories": [],
        "detail": args.detail,
        "rig": "game",
        "restPose": "A",
        "animations": True,
        "faceBones": True,
        "faceShapes": True,
        "speechShapes": False,
        "expression": "neutral",
    })
    styles = dict(params.get("garmentStyles", {}))
    styles[args.under_top] = {"pattern": "solid", "color": args.colour, "color2": args.colour}
    styles[args.under_bottom] = {"pattern": "solid", "color": args.colour, "color2": args.colour}
    params["garmentStyles"] = styles

    work = args.output.parent / ".mirabel_underwear_export"
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    params_path = work / "params.json"
    params_path.write_text(json.dumps(params, indent=2) + "\n")
    export_dir = work / "export"
    export_dir.mkdir()
    print("Building fitted underwear from profile:", params["name"], flush=True)
    print("Body seed:", params.get("seed"), "under-top:", args.under_top, "under-bottom:", args.under_bottom, flush=True)
    subprocess.run([
        "npm", "run", "export", "--",
        "--params", str(params_path),
        "--detail", args.detail,
        "--formats", "glb",
        "--out", str(export_dir),
    ], cwd=ara_root, check=True)

    candidates = sorted(export_dir.glob("*.glb"))
    if len(candidates) != 1:
        raise SystemExit(f"Expected one fitted Ara GLB, found {len(candidates)}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(candidates[0], args.output)
    if args.output.stat().st_size < 100_000:
        raise SystemExit("Fitted Ara GLB is unexpectedly small")
    print(f"Wrote target-profile fitted garment source: {args.output} ({args.output.stat().st_size:,} bytes)", flush=True)


if __name__ == "__main__":
    main()
