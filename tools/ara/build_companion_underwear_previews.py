#!/usr/bin/env python3
"""Assemble the modular underwear catalogue onto approved companion body GLBs.

The body GLB is always the target. Ara-generated GLBs are used only as sources
for separate skinned garment primitives; no body parameters are regenerated.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSEMBLER = ROOT / "tools" / "ara" / "assemble_modular_glb.py"
OUTFITS = ROOT / "character-preview" / "outfits.json"

COMMON = [
    ("ara_person_standard_bra.glb", "Bra"),
    ("ara_person_standard_briefs.glb", "Briefs"),
    ("ara_person_g_string.glb", "G-string bottom"),
    ("ara_person_g_string.glb", "G-string strings*"),
    ("ara_person_lace_briefs.glb", "Bikini bottom=Lace briefs"),
    ("ara_person_lace_briefs.glb", "Bikini strings*=Lace briefs ties"),
    ("ara_person_fishnet_briefs.glb", "Bikini bottom=Fishnet briefs"),
    ("ara_person_fishnet_briefs.glb", "Bikini strings*=Fishnet briefs ties"),
    ("ara_person_halter_bra_lace.glb", "Halter lace bra cups"),
    ("ara_person_halter_bra_lace.glb", "Halter lace bra piping"),
    ("ara_person_halter_bra_lace.glb", "Halter lace bra straps"),
    ("ara_person_halter_bra_fishnet.glb", "Halter fishnet bra cups"),
    ("ara_person_halter_bra_fishnet.glb", "Halter fishnet bra straps"),
]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--character", required=True, choices=("wren", "dagna", "reyna", "mirabel", "aldric"))
    parser.add_argument("--base-glb", required=True, type=Path)
    parser.add_argument("--generated-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    if not args.base_glb.is_file():
        raise FileNotFoundError(args.base_glb)
    if not ASSEMBLER.is_file():
        raise FileNotFoundError(ASSEMBLER)
    if args.character == "aldric":
        # Female underwear is not forced onto the male companion. This smoke
        # test verifies the 69-joint/34-target Ara source can be retargeted to
        # Aldric's 72-joint/36-target rig without changing his body.
        sources = [(args.generated_dir / "ara_person_benchmark.glb", "Fatigue shirt")]
    else:
        sources = []
        if args.character == "wren":
            config = json.loads(OUTFITS.read_text())
            slots = config["characters"]["wren"]["slots"]
            top, bottom = slots["underTop"], slots["underBottom"]
            if (top["garmentId"], top["material"], top["color"], top["opacity"]) != ("bikini_top", "Triangle bikini top", "#000000", 0.5):
                raise ValueError("Wren's approved starting top config no longer matches the black 50% Ara triangle top")
            if (bottom["garmentId"], bottom["material"], bottom["color"], bottom["opacity"]) != ("bikini_bottom", "String bikini bottom", "#000000", 0.5):
                raise ValueError("Wren's approved starting bottom config no longer matches the black 50% string bikini bottom")
            sources.extend([
                (args.generated_dir / "ara_person_wren_starting_top.glb", "Bikini top=Triangle bikini top"),
                (args.generated_dir / "ara_person_wren_starting_top.glb", "Bikini strings*=Triangle bikini strings"),
                (args.generated_dir / "ara_person_wren_starting_bottom.glb", "Bikini bottom=String bikini bottom"),
                (args.generated_dir / "ara_person_wren_starting_bottom.glb", "Bikini strings*=String bikini strings"),
            ])
        else:
            sources.extend([
                (args.generated_dir / "ara_person_triangle_bikini_top.glb", "Bikini top=Triangle bikini top"),
                (args.generated_dir / "ara_person_triangle_bikini_top.glb", "Bikini strings*=Triangle bikini strings"),
                (args.generated_dir / "ara_person_string_bikini_bottom.glb", "Bikini bottom=String bikini bottom"),
                (args.generated_dir / "ara_person_string_bikini_bottom.glb", "Bikini strings*=String bikini strings"),
            ])
        sources.extend((args.generated_dir / filename, selector) for filename, selector in COMMON)

    for source, _selector in sources:
        if not source.is_file():
            raise FileNotFoundError(source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, str(ASSEMBLER), str(args.base_glb), str(args.output)]
    for source, selector in sources:
        command.extend((str(source), selector))
    print("Assembling", args.character, "from unchanged body:", args.base_glb, flush=True)
    subprocess.run(command, check=True)
    if not args.output.is_file() or args.output.stat().st_size == 0:
        raise RuntimeError("Companion modular GLB was not produced")
    print("Wrote", args.output, "with", len(sources), "independent garment primitives/material selections", flush=True)

if __name__ == "__main__":
    main()
