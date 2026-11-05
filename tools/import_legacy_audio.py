#!/usr/bin/env python3
"""Fetch the legacy Silverhart audio at a pinned revision and convert it for Godot."""
from pathlib import Path
from urllib.request import urlretrieve
import shutil
import subprocess
import sys

REPO = "https://raw.githubusercontent.com/ScottENOC/Hex-crpg/4de96f16889d43cae91e03832c8eb1c1b4b00e42"
ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "audio/Title.m4a": "audio/legacy/title.ogg",
    "audio/Arena lobby.m4a": "audio/legacy/arena_lobby.ogg",
    "audio/Arena pre battle.m4a": "audio/legacy/arena_pre_battle.ogg",
    "audio/Arena battle.m4a": "audio/legacy/arena_battle.ogg",
    "audio/Arena battle sting.m4a": "audio/legacy/arena_battle_sting.ogg",
    "audio/Arenalobby2arena.m4a": "audio/legacy/arena_transition.ogg",
    "audio/Arena death.m4a": "audio/legacy/arena_death.ogg",
    "audio/Arena death sting.m4a": "audio/legacy/arena_death_sting.ogg",
    "audio/Constant.m4a": "audio/legacy/legacy_constant.ogg",
    "audio/dialogue/arena_entrance.m4a": "audio/legacy/dialogue/arena_entrance.ogg",
    "audio/dialogue/arena_fight_mid.m4a": "audio/legacy/dialogue/arena_fight_mid.ogg",
    "audio/dialogue/arena_fight_start.m4a": "audio/legacy/dialogue/arena_fight_start.ogg",
    "audio/dialogue/arena_indoor.m4a": "audio/legacy/dialogue/arena_indoor.ogg",
    "audio/dialogue/arena_lobby_1.m4a": "audio/legacy/dialogue/arena_lobby_1.ogg",
    "audio/dialogue/arena_lobby_2.m4a": "audio/legacy/dialogue/arena_lobby_2.ogg",
    "audio/dialogue/arena_lobby_3.m4a": "audio/legacy/dialogue/arena_lobby_3.ogg",
    "audio/dialogue/arena_lobby_4.m4a": "audio/legacy/dialogue/arena_lobby_4.ogg",
    "audio/dialogue/arena_outdoor_day.m4a": "audio/legacy/dialogue/arena_outdoor_day.ogg",
    "audio/dialogue/arena_outdoor_night.m4a": "audio/legacy/dialogue/arena_outdoor_night.ogg",
    "audio/dialogue/arena_victory.m4a": "audio/legacy/dialogue/arena_victory.ogg",
    "audio/dialogue/goblin_1_enemy_seen.m4a": "audio/legacy/dialogue/goblin_1_enemy_seen.ogg",
    "audio/dialogue/grishnak_entry.m4a": "audio/legacy/dialogue/grishnak_entry.ogg",
    "audio/dialogue/pc_1_enemy_seen.m4a": "audio/legacy/dialogue/pc_1_enemy_seen.ogg",
    "audio/effects/parry.wav": "audio/legacy/effects/parry.ogg",
    "audio/effects/parry2.wav": "audio/legacy/effects/parry2.ogg",
}

def main() -> int:
    ffmpeg = shutil.which("ffmpeg")
    source_root = ROOT / "audio" / "source"
    for source, target in ASSETS.items():
        source_path = source_root / source.removeprefix("audio/")
        source_path.parent.mkdir(parents=True, exist_ok=True)
        if not source_path.exists():
            print("Downloading", source)
            urlretrieve(REPO + "/" + source, source_path)
        if not ffmpeg:
            continue
        target_path = ROOT / target
        target_path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([ffmpeg, "-y", "-i", str(source_path), "-vn",
                        "-c:a", "libvorbis", "-q:a", "5", str(target_path)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("Converted", target)
    if not ffmpeg:
        print("Source files downloaded. Install FFmpeg and rerun to create Ogg files.", file=sys.stderr)
        return 2
    print("Imported", len(ASSETS), "legacy audio files.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
