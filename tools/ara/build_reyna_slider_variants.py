#!/usr/bin/env python3
"""Generate controlled Reyna body-slider profiles from the approved base profile."""
import json
from pathlib import Path

base = json.loads(Path("character-preview/reyna-ara.json").read_text())
variants = {
    "baseline": {},
    "hips_subtle": {
        "buttocks/buttocks-volume": -0.20,
        "hip/hip-scale-horiz": -0.20,
        "hip/hip-scale-depth": -0.10,
    },
    "shoulders_subtle": {
        "armslegs/upperarm-shoulder-muscle:decr|incr": 0.25,
    },
    "combined_subtle": {
        "buttocks/buttocks-volume": -0.20,
        "hip/hip-scale-horiz": -0.20,
        "hip/hip-scale-depth": -0.10,
        "armslegs/upperarm-shoulder-muscle:decr|incr": 0.25,
    },
    "combined_stronger": {
        "buttocks/buttocks-volume": -0.35,
        "hip/hip-scale-horiz": -0.50,
        "hip/hip-scale-depth": -0.40,
        "armslegs/upperarm-shoulder-muscle:decr|incr": 0.70,
    },
}
root = Path("build/reyna-slider-comparison")
for name, modifiers in variants.items():
    profile = json.loads(json.dumps(base))
    profile["params"]["modifiers"] = modifiers
    out = root / name
    out.mkdir(parents=True, exist_ok=True)
    (out / "profile.json").write_text(json.dumps(profile, indent=2) + "\n")
    print(f"{name}: {json.dumps(modifiers, sort_keys=True)}")
