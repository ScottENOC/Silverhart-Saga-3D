"""Shared, data-driven garment fit policy for Ara-derived clothing.

This module deliberately has no Blender dependency. It is the single source of
truth for material behaviour and fit limits, and can be unit-tested outside the
Blender pipeline. Geometry deformation remains in the Blender adapter.
"""
from __future__ import annotations

import re
from typing import Any

SCHEMA_VERSION = 1

# Values are dimensionless except clearance (metres). max_strain is a hard
# authoring/fit limit, not a target: garments beyond it must fail validation or
# be resized/re-authored rather than stretched without limit.
FIT_PROFILES: dict[str, dict[str, Any]] = {
    "stretch_fabric": {
        "max_strain": 0.25,
        "comfort_strain": 0.12,
        "compression_limit": 0.035,
        "clearance_m": 0.0045,
        "max_unintended_gap_m": 0.003,
        "coverage_mode": "pattern_preserving",
        "texture_response": "uv_stretch",
    },
    "open_mesh": {
        "max_strain": 0.18,
        "comfort_strain": 0.08,
        "compression_limit": 0.015,
        "clearance_m": 0.0035,
        "max_unintended_gap_m": 0.003,
        "coverage_mode": "pattern_preserving",
        "texture_response": "preserve_openings",
    },
    "structured_bra": {
        "max_strain": 0.12,
        "comfort_strain": 0.06,
        "compression_limit": 0.08,
        "clearance_m": 0.004,
        "max_unintended_gap_m": 0.0025,
        "coverage_mode": "edge_constrained",
        "texture_response": "uv_stretch",
    },
    "rigid": {
        "max_strain": 0.02,
        "comfort_strain": 0.005,
        "compression_limit": 0.0,
        "clearance_m": 0.006,
        "max_unintended_gap_m": 0.002,
        "coverage_mode": "surface_shell",
        "texture_response": "rigid",
    },
    "loose_drape": {
        "max_strain": 0.08,
        "comfort_strain": 0.025,
        "compression_limit": 0.0,
        "clearance_m": 0.008,
        "max_unintended_gap_m": 0.006,
        "coverage_mode": "pattern_preserving",
        "texture_response": "uv_stretch",
    },
}

# More specific matches precede generic ones. The match is against material
# names, not object names, because one mesh can contain multiple garment slots.
MATERIAL_RULES = (
    (("fishnet", "lace", "mesh"), "open_mesh"),
    (("bra", "halter", "bustier", "corset"), "structured_bra"),
    (("armour", "armor", "plate", "mail"), "rigid"),
    (("cloak", "cape", "robe", "skirt", "dress"), "loose_drape"),
    (("brief", "bikini", "g-string", "underwear", "pants", "trouser", "breech",
      "shirt", "tank top", "top"), "stretch_fabric"),
)


def normalise_material_name(name: str) -> str:
    """Normalise punctuation/spacing without losing meaningful material words."""
    return re.sub(r"[^a-z0-9]+", " ", str(name or "").lower()).strip()


def profile_name_for_material(material_name: str) -> str:
    name = normalise_material_name(material_name)
    for tokens, profile in MATERIAL_RULES:
        if any(token in name for token in tokens):
            return profile
    return "stretch_fabric"


def profile_for_material(material_name: str) -> dict[str, Any]:
    """Return a fresh profile dictionary so callers cannot mutate global policy."""
    name = profile_name_for_material(material_name)
    return {"name": name, **FIT_PROFILES[name]}


def evaluate_fit(*, signed_distance_m: float, strain: float,
                 profile: dict[str, Any]) -> dict[str, Any]:
    """Classify a sampled fit point; negative signed distance means penetration."""
    clearance = float(profile["clearance_m"])
    max_strain = float(profile["max_strain"])
    gap_limit = float(profile["max_unintended_gap_m"])
    return {
        "penetrating": signed_distance_m < 0.0,
        "needs_clearance": signed_distance_m < clearance,
        "unintended_gap": signed_distance_m > clearance + gap_limit,
        "overstretched": strain > max_strain,
        "strain_ratio": strain / max(max_strain, 1e-9),
    }


def validate_profile(profile: dict[str, Any]) -> None:
    required = {
        "max_strain", "comfort_strain", "compression_limit", "clearance_m",
        "max_unintended_gap_m", "coverage_mode", "texture_response",
    }
    missing = required - set(profile)
    if missing:
        raise ValueError(f"Garment fit profile missing fields: {sorted(missing)}")
    if not (0.0 <= profile["comfort_strain"] <= profile["max_strain"]):
        raise ValueError("comfort_strain must be between zero and max_strain")
    if not (0.0 <= profile["compression_limit"] <= 0.15):
        raise ValueError("compression_limit must be between zero and 0.15")
    if profile["clearance_m"] < 0 or profile["max_unintended_gap_m"] < 0:
        raise ValueError("clearance and gap limits cannot be negative")
    if profile["coverage_mode"] not in {"pattern_preserving", "edge_constrained", "surface_shell"}:
        raise ValueError(f"Unknown coverage mode: {profile['coverage_mode']}")
    if profile["texture_response"] not in {"uv_stretch", "preserve_openings", "rigid"}:
        raise ValueError(f"Unknown texture response: {profile['texture_response']}")


for _profile in FIT_PROFILES.values():
    validate_profile(_profile)


def estimate_correction_strain(edge_pairs: list[tuple[int, int]],
                               original_positions: dict[int, tuple[float, float, float]],
                               corrections: dict[int, tuple[float, float, float]]) -> dict[str, float | int]:
    """Estimate local strain introduced by clearance corrections.

    For each original mesh edge, compare the correction vectors at its ends.
    Their differential divided by original edge length estimates the local
    deformation gradient contributed by the clearance pass. It is a diagnostic
    approximation, not a full cloth strain tensor.
    """
    max_strain = 0.0
    overstretched_edges = 0
    sampled_edges = 0
    for a, b in edge_pairs:
        if a not in corrections or b not in corrections:
            continue
        pa, pb = original_positions[a], original_positions[b]
        da, db = corrections[a], corrections[b]
        edge_length = sum((pa[i] - pb[i]) ** 2 for i in range(3)) ** 0.5
        if edge_length <= 1e-9:
            continue
        differential = sum((da[i] - db[i]) ** 2 for i in range(3)) ** 0.5
        strain = differential / edge_length
        sampled_edges += 1
        max_strain = max(max_strain, strain)
    return {
        "sampled_edges": sampled_edges,
        "max_estimated_strain": max_strain,
    }


def classify_strain(strain: float, profile: dict[str, Any]) -> dict[str, Any]:
    """Report comfort-limit and hard-limit violations separately."""
    return {
        "above_comfort_strain": strain > float(profile["comfort_strain"]),
        "overstretched": strain > float(profile["max_strain"]),
        "strain_ratio": strain / max(float(profile["max_strain"]), 1e-9),
    }
