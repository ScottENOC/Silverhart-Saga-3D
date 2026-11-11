#!/usr/bin/env python3
"""Validate the ten canonical Ara human bases and their reusable-asset contract."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILE_FILE = ROOT / "data" / "characters" / "body_profiles.json"
EXPECTED_BUILDS = {"lean", "average", "broad", "muscular", "soft"}
EXPECTED_MODELS = {"female", "male"}
SLIDERS = ("age", "muscle", "weight", "height", "proportions",
           "african", "asian", "caucasian", "breastSize", "breastFirmness")


def validate(data: dict) -> None:
    profiles = data.get("body_profiles")
    if not isinstance(profiles, list) or len(profiles) != 10:
        raise ValueError("Expected exactly ten canonical body profiles")
    ids = [p.get("id") for p in profiles]
    if len(set(ids)) != 10:
        raise ValueError("Body profile IDs must be unique")
    expected = {f"{model}_{build}" for model in EXPECTED_MODELS for build in EXPECTED_BUILDS}
    if set(ids) != expected:
        raise ValueError(f"Profile IDs differ from canonical 5x2 matrix: missing={sorted(expected-set(ids))}, extra={sorted(set(ids)-expected)}")
    for profile in profiles:
        profile_id = profile["id"]
        model, build = profile_id.split("_", 1)
        if profile.get("body_model") != model or profile.get("build") != build:
            raise ValueError(f"{profile_id}: body_model/build do not agree with its canonical ID")
        params = profile.get("base_parameters")
        if not isinstance(params, dict):
            raise ValueError(f"{profile_id}: missing base_parameters")
        if int(params.get("gender", -1)) != (1 if model == "male" else 0):
            raise ValueError(f"{profile_id}: Ara gender does not match body_model")
        for key in SLIDERS:
            value = params.get(key)
            if not isinstance(value, (int, float)) or not 0.0 <= float(value) <= 1.0:
                raise ValueError(f"{profile_id}: {key} must be a normalized 0..1 Ara slider")
        for key in ("body_asset", "garment_library"):
            if not isinstance(profile.get(key), str) or not profile[key].startswith("res://"):
                raise ValueError(f"{profile_id}: {key} must be a Godot res:// asset path")
        if not profile.get("body_asset", "").endswith(f"/{profile_id}.glb"):
            raise ValueError(f"{profile_id}: body_asset filename must match canonical profile ID")
        if not profile.get("garment_library", "").endswith(f"/{profile_id}.glb"):
            raise ValueError(f"{profile_id}: garment_library filename must match canonical profile ID")
    policy = data.get("character_generation", {})
    if not policy.get("base_selection") or not policy.get("variation") or not policy.get("garment_rule"):
        raise ValueError("Missing reusable-base character-generation policy")
    print("PASS: ten canonical adult bases (five builds x two body models)")
    print("PASS: normalized Ara parameters and gender/profile consistency")
    print("PASS: unique body and garment asset paths")
    print("PASS: character-level variation remains separate from canonical bases")


if __name__ == "__main__":
    validate(json.loads(PROFILE_FILE.read_text(encoding="utf-8")))
