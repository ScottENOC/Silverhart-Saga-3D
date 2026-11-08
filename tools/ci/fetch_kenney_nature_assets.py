#!/usr/bin/env python3
"""Fetch a small, verified subset of Kenney Nature Kit for the Godot build.

The full archive is not committed to the repository. Only the models used by
Silverhart are extracted, together with Kenney's original licence text.
"""
from __future__ import annotations

import hashlib
import io
import urllib.request
import zipfile
from pathlib import Path

ARCHIVE_URL = "https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip"
ARCHIVE_SHA256 = "fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d"
OUTPUT = Path("art/environment/kenney_nature")

# output filename: acceptable case-insensitive basenames in the official ZIP.
ASSETS = {
    "tree_oak.glb": ("tree_oak.glb",),
    "tree_oak_fall.glb": ("tree_oak_fall.glb",),
    "tree_default.glb": ("tree_default.glb",),
    "tree_default_fall.glb": ("tree_default_fall.glb",),
    "tree_pine_tall_a.glb": ("tree_pinetalla.glb", "tree_pine_tall_a.glb"),
    "rock_large_a.glb": ("rock_largea.glb", "rock_large_a.glb"),
    "rock_large_d.glb": ("rock_larged.glb", "rock_large_d.glb"),
    "plant_bush_detailed.glb": ("plant_bushdetailed.glb", "plant_bush_detailed.glb"),
    "stump_round_detailed.glb": ("stump_rounddetailed.glb", "stump_round_detailed.glb"),
    "log_large.glb": ("log_large.glb",),
    "flower_purple_a.glb": ("flower_purplea.glb", "flower_purple_a.glb"),
    "mushroom_red_group.glb": ("mushroom_redgroup.glb", "mushroom_red_group.glb"),
}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(ARCHIVE_URL, headers={"User-Agent": "SilverhartSagaAssetBootstrap/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        archive_bytes = response.read()
    digest = hashlib.sha256(archive_bytes).hexdigest()
    if digest != ARCHIVE_SHA256:
        raise SystemExit(f"Kenney Nature Kit checksum mismatch: {digest}")

    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
        members = [name for name in archive.namelist() if not name.endswith("/")]
        by_basename = {Path(name).name.lower(): name for name in members}
        missing: list[str] = []
        for output_name, candidates in ASSETS.items():
            source_name = next((by_basename[c.lower()] for c in candidates if c.lower() in by_basename), None)
            if source_name is None:
                missing.append(output_name)
                continue
            (OUTPUT / output_name).write_bytes(archive.read(source_name))
        license_name = next((name for name in members if Path(name).name.lower() in {"license.txt", "license"}), None)
        if license_name is None:
            missing.append("License.txt")
        else:
            (OUTPUT / "LICENSE.txt").write_bytes(archive.read(license_name))

    if missing:
        raise SystemExit("Kenney Nature Kit archive is missing expected files: " + ", ".join(missing))
    manifest = [
        "# Kenney Nature Kit assets",
        "",
        "Source: https://kenney.nl/assets/nature-kit",
        "Creator: Kenney",
        "License: CC0 1.0 Universal (see LICENSE.txt)",
        f"Source archive SHA-256: {ARCHIVE_SHA256}",
        "",
        "Only the models listed in this directory were extracted for Silverhart Saga.",
    ]
    (OUTPUT / "ASSET_SOURCE.md").write_text("\n".join(manifest) + "\n", encoding="utf-8")
    print(f"Installed {len(ASSETS)} Kenney Nature Kit models into {OUTPUT}")


if __name__ == "__main__":
    main()
