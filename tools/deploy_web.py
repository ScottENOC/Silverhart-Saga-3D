#!/usr/bin/env python3
"""Create a reproducible web-build manifest and publish the iPhone preview.

The preview uses its own private Static Space. It deliberately does not touch
the existing Wren Workshop Space or the HF_SPACE_ID used by that workflow.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

SPACE_ID = "Thisisausername836/silverhart-saga-3d"
REPO_TYPE = "space"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_manifest(web_dir: Path, commit: str) -> Path:
    files = []
    for path in sorted(web_dir.rglob("*")):
        if not path.is_file() or path.name == "build-manifest.json":
            continue
        files.append({
            "path": path.relative_to(web_dir).as_posix(),
            "size": path.stat().st_size,
            "sha256": sha256(path),
        })

    manifest = {
        "schema": 1,
        "project": "Silverhart Saga 3D",
        "commit": commit or "local",
        "engine": "Godot 4.7.2",
        "built_at": datetime.now(timezone.utc).isoformat(),
        "files": files,
    }
    target = web_dir / "build-manifest.json"
    target.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return target


def publish(web_dir: Path, token: str, commit: str) -> None:
    from huggingface_hub import HfApi
    from huggingface_hub.errors import RepositoryNotFoundError

    api = HfApi(token=token)
    try:
        info = api.repo_info(repo_id=SPACE_ID, repo_type=REPO_TYPE)
    except RepositoryNotFoundError:
        print(f"Creating new private Static Space: {SPACE_ID}")
        api.create_repo(
            repo_id=SPACE_ID,
            repo_type=REPO_TYPE,
            private=True,
            space_sdk="static",
            exist_ok=True,
        )
        info = api.repo_info(repo_id=SPACE_ID, repo_type=REPO_TYPE)

    if info.id != SPACE_ID:
        raise RuntimeError(f"Refusing unexpected Hugging Face repository: {info.id}")
    if info.private is not True:
        raise RuntimeError(
            f"Refusing to publish the game to a non-private Space: {SPACE_ID}"
        )

    # Static Space metadata. This is a dedicated Space, not Wren Workshop.
    readme = web_dir / "README.md"
    if not readme.exists():
        readme.write_text(
            "---\n"
            "title: Silverhart Saga 3D\n"
            "sdk: static\n"
            "---\n\n"
            "Private iPhone development preview for Silverhart Saga 3D.\n",
            encoding="utf-8",
        )

    # Include the README in the manifest too, so the uploaded file inventory
    # describes the complete static preview.
    write_manifest(web_dir, commit)

    api.upload_folder(
        repo_id=SPACE_ID,
        repo_type=REPO_TYPE,
        folder_path=str(web_dir),
        commit_message=f"Silverhart Saga web preview {commit[:12] or 'local'}",
    )
    print(f"Published private iPhone preview to {SPACE_ID}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--web-dir", type=Path, required=True)
    args = parser.parse_args()

    web_dir = args.web_dir.resolve()
    if not (web_dir / "index.html").is_file():
        raise SystemExit(f"Missing Godot web export: {web_dir / 'index.html'}")
    if not (web_dir / "index.pck").is_file():
        raise SystemExit(f"Missing Godot resource pack: {web_dir / 'index.pck'}")

    commit = os.environ.get("GITHUB_SHA", "")
    manifest = write_manifest(web_dir, commit)
    print(f"Created {manifest} ({manifest.stat().st_size} bytes)")

    token = os.environ.get("HF_ADMIN_TOKEN", "").strip()
    if not token:
        print(
            "HF_ADMIN_TOKEN is not configured; build and artifact are ready, "
            "but Hugging Face publishing was skipped."
        )
        return 0

    publish(web_dir, token, commit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
