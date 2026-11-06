# Audio and game-mode migration

## Game modes
The first screen is a mode selector. Campaign and Arena are separate entry paths.
Arena-only tracks must never be started by Campaign. The title theme belongs to
the mode-selection screen. Campaign has no dedicated 3D score wired yet; the
original browser game has a few campaign dialogue clips, while its planned
adaptive music stems were not present in the repository.

## Audio buses
The AudioManager autoload owns Music, Dialogue, SFX, Ambience and UI players.
Levels are independently adjustable and persisted in user://audio_settings.cfg.
All asset playback is optional so the project remains runnable before import.

## Legacy asset inventory
Source: ScottENOC/Hex-crpg, pinned to commit
4de96f16889d43cae91e03832c8eb1c1b4b00e42.

| Legacy asset | Intended 3D use |
|---|---|
| Title.m4a | Main menu music |
| Arena lobby.m4a | Arena lobby |
| Arena pre battle.m4a | Arena pre-battle |
| Arena battle.m4a | Arena battle loop |
| Arena battle sting.m4a | Arena battle transition |
| Arenalobby2arena.m4a | Arena transition sting |
| Arena death.m4a | Arena defeat/death theme |
| Arena death sting.m4a | Arena defeat sting |
| audio/dialogue/arena_*.m4a | Arena announcer and fight dialogue |
| Constant.m4a | Legacy near-silent bed; not enabled by default |
| goblin_1_enemy_seen, grishnak_entry, pc_1_enemy_seen | Campaign dialogue candidates; verify story triggers |
| parry.wav, parry2.wav | Combat parry effects; share only if 3D combat uses that event |

Do not attach Arena dialogue or announcer recordings globally. Trigger them
from matching Arena events only. Campaign dialogue candidates should be
matched to their original story triggers before use.

## Import
Run python tools/import_legacy_audio.py from the repository root. It downloads
the pinned public source assets into audio/source/ and, if FFmpeg is installed,
converts supported files to Ogg Vorbis under audio/legacy/. Source masters are
retained. The runtime references converted Ogg files only.

The import script does not invent missing Campaign music. GarageBand project
or export files must be supplied separately. Export loopable OGG/WAV masters
and assign them to the Campaign music director rather than reusing Arena tracks.
