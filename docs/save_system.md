# Campaign save system

## Current implementation

The campaign save service is an autoload (SaveManager) and writes to user://saves/.
It uses Godot's binary FileAccess.store_var() / get_var() format with object decoding
disabled. Each save is a versioned data envelope containing metadata and a plain-data
snapshot. Save writes go to a temporary file first; the previous file is retained as a
.bak while the replacement is committed.

Available slots:
- Eight manual slots (slot_01 through slot_08).
- One quick-save slot (quicksave).
- Three rotating autosave slots (autosave_01 through autosave_03).

F5 writes the quick save. F9 immediately loads it. The in-game Menu exposes Save game
and Load game slot pickers. Manual slots require confirmation before replacement.
Autosaves are attempted every five minutes of real play while outside combat and
dialogue. A starting autosave is created when a new campaign first enters the tavern.

Saves are currently blocked during combat and unresolved reactions. This avoids
pretending that the combat scheduler and in-flight action contexts are fully serialised.

## Snapshot contract

The current Hollow Tankard adapter stores:
- The complete player character-creator profile (the recipe, not a baked mesh).
- CharacterState changes keyed by stable character ID.
- Full records for characters created after the initial baseline.
- NPC appearance parameter overrides relative to their authored params profile.
- Party membership and active party member.
- World clock and campaign journal state.
- Opening-quest / farm-wolf progression flags.
- Camera zoom and rotation.

Static world geometry, NPC definitions, authored loadouts and base appearance profiles
remain in the shipped game data. CharacterState diffs are merged over those definitions
when loading. The player's appearance is regenerated from the saved profile by the
existing Ara character pipeline; generated meshes are not embedded in the save.

## Current limitations / next integration work

This is the first playable persistence pass, not yet a complete campaign persistence
contract. In particular:
- Mutable map cells, doors, containers, ground loot and building/object damage are not
  yet captured.
- Gatherable resource depletion/regrowth state is not yet captured.
- Dynamic actors created after world startup are recorded as character data, but their
  presentation actors are not yet generically respawned on load.
- NPC appearance override storage is wired, but there is not yet a general gameplay
  appearance-editing API that writes those overrides.
- The current campaign has no full combat save/restore; saving is deliberately blocked
  during combat and pending reactions.
- Autosaves are time-based for now; additional quest/area transition checkpoints should
  be added as those systems stabilise.
- Format version 1 currently supports the first snapshot schema. Future changes must add
  explicit migrations rather than silently reinterpret older saves.

## Validation checklist

Run the project with Godot 4.7.2 and verify:
1. F5 creates or replaces the quick save and F9 restores it.
2. Manual slots save, list, load and protect against accidental overwrite.
3. Autosaves rotate and appear in the load list.
4. Character position, health, attributes, skills, inventory, equipment and party
   membership survive a reload.
5. Quest decisions/objectives, reputation and world time survive a reload.
6. Player appearance reconstructs identically from the saved creator profile.
7. Corrupt, missing and newer-version saves fail cleanly without destroying another slot.
8. Saves are unavailable during combat and pending reactions.