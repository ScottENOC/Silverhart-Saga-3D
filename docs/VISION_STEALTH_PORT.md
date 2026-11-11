# Vision, line of sight and stealth port

## Scope of this branch

This branch starts from `dev` and deliberately does not merge the unfinished
`feature/skill-magic-foundation` branch. Vision rules read skill ranks from
`CharacterState.skills`, which already exists on `dev`; missing ranks mean
zero. This allows independent development and later integration testing.

## Source behaviour carried forward

The original `Hex-crpg` implementation establishes:

- Live vision range: 25 hexes.
- Exploration/reveal range: 30 hexes, distinct from live visibility.
- `elf_vision`: +4 vision per rank (maximum rank 2 in the source).
- `goblin_keen_senses`: +3 vision.
- `deep_sense`: +4 vision indoors/underground.
- `elf_darkvision` and `goblin_low_light_eyes`: remove low-light penalties;
  they are not unconditional flat range bonuses.
- `keen_perception`: +10 to stealth/hidden-object detection per rank.
- `inconspicuous` and `shadow_weaver`: +5 stealth-check bonus per rank.
- The source uses hex-ray LOS with terrain/wall and elevation considerations.

The first Godot slice implements the spatial query and source-backed numeric
modifiers. It intentionally keeps spatial visibility separate from stealth
detection: being geometrically visible does not automatically mean an observer
has detected a hidden character.

## Implemented in this slice

- `VisionRules.vision_range()`: base, skill, indoor and low-light range.
- `VisionRules.exploration_range()`: separate exploration radius.
- `VisionRules.has_line_of_sight()`: axial hex interpolation, opaque terrain,
  explicit per-cell blockers and elevated terrain occlusion.
- `VisionRules.can_see()`: combines alive-target check, range and LOS.
- Separate helper bonuses for perception and stealth skills.

Cell dictionaries may specify `blocks_vision: true` and optionally
`vision_block_height` (metres). The opaque terrain IDs currently match the
source's explicit wall set: `wall`, `keep_wall`, `climbable_wall`.
Palisades are not made opaque by name alone; the original source had a
documented inconsistency there, so callers must explicitly mark them if the
new 3D design intends them to block sight.

Unknown intermediate map cells conservatively block LOS. Callers must ensure
the relevant map area is loaded before asking visibility questions.

## Deliberate limitations / next slices

This is not yet a complete stealth system. It does not yet implement fog-of-war
storage/rendering, light-source propagation, hearing, stealth movement,
spellcasting noise, suspicion accumulation, enemy memory/search/pursuit,
party-shared sightings, disguise, or AI target selection. The source's detailed
low-light and illumination model also needs a dedicated port; the initial
implementation preserves the 0.2 low-light range factor and racial exemptions,
but does not yet calculate dynamic light fields.

Next:
1. Add tests for LOS geometry, elevations, blockers, range boundaries and
   source skill modifiers.
2. Connect visibility to player exploration/fog state and ranged attack rules.
3. Port stealth checks, suspicion, last-known positions and enemy search/loss.
4. Integrate with the broader skill catalogue once that branch is ready.
