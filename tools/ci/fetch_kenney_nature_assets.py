#!/usr/bin/env python3
"""Fetch pinned CC0 Kenney Nature Kit models for the Godot build.

The source archive is not committed. We fetch only the models used by this
prototype from a pinned mirror commit and verify every Git blob SHA-1 before
placing it in the project.
"""
from __future__ import annotations

import hashlib
import urllib.request
from pathlib import Path

SOURCE_REPOSITORY = "Hidencod/tge-assets"
SOURCE_COMMIT = "ea2f2aa1ca8da0898330c97df8a5489976b051d0"
SOURCE_BASE = f"https://raw.githubusercontent.com/{SOURCE_REPOSITORY}/{SOURCE_COMMIT}/"
OUTPUT = Path("art/environment/kenney_nature")

# output filename: source path and GitHub Git blob SHA-1 at SOURCE_COMMIT.
ASSETS = {
    "tree_oak.glb": ("packs/nature-kit/tree-oak.glb", "b136723ada4b5574b71f727120ab21fa579bf2fb"),
    "tree_oak_fall.glb": ("packs/nature-kit/tree-oak-fall.glb", "9ee679dd4dc02224a474eefd8a0f8f31cf937de3"),
    "tree_default.glb": ("packs/nature-kit/tree-default.glb", "13247443438a210c252d3324c511aba3cb3b392a"),
    "tree_default_fall.glb": ("packs/nature-kit/tree-default-fall.glb", "8a514472fe5a76bb2fe3111b07d8cc8aabc4b747"),
    "tree_pine_tall_a.glb": ("packs/nature-kit/tree-pinetalla.glb", "b064580b04a93cea7cbb76f83dd880a55f530fed"),
    "rock_large_a.glb": ("packs/nature-kit/rock-largea.glb", "40e1365a43b706bd78c2658b48b189c9a35f8923"),
    "rock_large_d.glb": ("packs/nature-kit/rock-larged.glb", "0137c12d9b027702ec4a3c4ab089ce36e80d30cd"),
    "plant_bush_detailed.glb": ("packs/nature-kit/plant-bushdetailed.glb", "e5279fa53adb3037ae93bbed23a0716322cae79a"),
    "stump_round_detailed.glb": ("packs/nature-kit/stump-rounddetailed.glb", "df986a36c6d4423d9f8741424cf36f9f4140090a"),
    "log_large.glb": ("packs/nature-kit/log-large.glb", "52e362e62522cc0b14d7102b5bdd4216935f5d3b"),
    "flower_purple_a.glb": ("packs/nature-kit/flower-purplea.glb", "9a102fdd587ba2c4c345e20ae1721e4753b556eb"),
    "mushroom_red_group.glb": ("packs/nature-kit/mushroom-redgroup.glb", "2fe18326f55a4ba1f191e1a717518ef67647244b"),
}
LICENSE_PATH = "LICENSE"
LICENSE_BLOB_SHA = "87fde4aced091c6e191fc86388dc59d570e2562d"


def download(source_path: str, expected_blob_sha: str) -> bytes:
    request = urllib.request.Request(
        SOURCE_BASE + source_path,
        headers={"User-Agent": "SilverhartSagaAssetBootstrap/1.0"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    git_blob = hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\\0" + data).hexdigest()
    if git_blob != expected_blob_sha:
        raise SystemExit(f"Asset verification failed for {source_path}: {git_blob}")
    return data


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for output_name, (source_path, expected_sha) in ASSETS.items():
        data = download(source_path, expected_sha)
        if output_name.endswith(".glb") and not data.startswith(b"glTF"):
            raise SystemExit(f"Invalid GLB header for {source_path}")
        (OUTPUT / output_name).write_bytes(data)

    (OUTPUT / "LICENSE.txt").write_bytes(download(LICENSE_PATH, LICENSE_BLOB_SHA))
    manifest = [
        "# Kenney Nature Kit assets",
        "",
        "Original creator: Kenney",
        "Original pack: https://kenney.nl/assets/nature-kit",
        "License: CC0 1.0 Universal (see LICENSE.txt)",
        f"Verified source mirror: https://github.com/{SOURCE_REPOSITORY}/tree/{SOURCE_COMMIT}/packs/nature-kit",
        f"Source commit: {SOURCE_COMMIT}",
        "",
        "Only the selected models used by Silverhart are downloaded. Each file is",
        "verified against its Git blob SHA-1 from the pinned source commit.",
    ]
    (OUTPUT / "ASSET_SOURCE.md").write_text("\\n".join(manifest) + "\\n", encoding="utf-8")
    print(f"Installed and verified {len(ASSETS)} Kenney Nature Kit models into {OUTPUT}")


if __name__ == "__main__":
    main()
