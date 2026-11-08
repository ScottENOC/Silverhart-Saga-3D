# Legacy audio and game modes

This integration brings the existing Campaign/Arena selector and the audio routing foundation onto the current `dev` branch without merging the old PR #5 branch (which was based on the obsolete `main` branch).

## What is included
- A startup mode selector with Campaign and Arena entry points.
- A persistent AudioManager autoload with Music, Dialogue, SFX, Ambience and UI buses, saved levels and crossfades.
- Explicit mode gates so Arena recordings cannot play in Campaign and vice versa.
- A pinned importer for original Hex-crpg audio masters, converted to Ogg for Godot.
- An explicit Arena placeholder. This is a mode-selection/audio foundation, not a playable Arena port.

## Legacy audio sources
The importer pins original source revision `4de96f16889d43cae91e03832c8eb1c1b4b00e42` and imports the title theme, Arena lobby/pre-battle/battle/death tracks, Arena dialogue, three campaign dialogue candidates, and parry effects.

The original `audio/music/MUSIC_ASSETS.md` describes a separate adaptive wilderness/village stem system. Those stems are a recording specification, not existing music files, so they are not represented as imported legacy tracks.

## Import
Run `python tools/import_legacy_audio.py` with FFmpeg installed. Source masters are downloaded to `audio/source/`; converted Ogg files are written to `audio/legacy/`. Binary assets are generated from the pinned original repository and are not committed by this code-only change.

## Next
1. Make the Web export/Pages pipeline generate and package the imported Ogg assets.
2. Verify actual playback in Godot and the browser build.
3. Replace the Arena placeholder with the original lobby, opponent selection, encounters, rewards and progression, reusing the shared combat and character systems.
