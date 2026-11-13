# Arena and full character roster port

## Scope and source of truth

This roster is extracted from the original `ScottENOC/Hex-crpg` source, not invented as a replacement bestiary.

- `data/characters/legacy_named_npcs.json`: 98 named/role NPC records with explicit race and gender in `campaign2Content.js`.
- `data/characters/legacy_enemy_roster.json`: all 35 monster templates in `monsters.js`.
- `data/arena/arena_opponents.json`: the 18-entry Arena opponent pool, six beast variants, three dragon progression thresholds, eight scenario types and three lobby service characters from `gameEngine.js`.

## Model coverage status

The existing Hollowmere Ara profile set is only the beginning. The manifest marks those NPCs with reusable profiles already present in `hollowmere_npcs.json`; it does **not** claim that their generated GLBs are checked into the game or already deployed. Other NPCs are marked as requiring appearance profiles.

All 35 enemy templates currently require production 3D models. Existing 2D sprites are linked as reference only. Similar enemies share a model archetype (e.g. goblin, orc, undead, quadruped, dragon, winged humanoid) and receive individual material, scale, equipment and identity variations. Named bosses remain distinct characters, not just random recolours.

## Production model pipeline

1. Finish and pin the generic Ara humanoid base, canonical skeleton, animation set and modular clothing/armour contract.
2. Generate saved appearance profiles and GLBs for the named humanoid NPC roster. Preserve race-specific silhouettes: humans, elves and dwarves must not all look like the same human with different ears.
3. Build dedicated non-human 3D archetypes for goblins, orcs, undead, beasts and fantasy creatures. Reuse rig families where anatomy allows; do not force quadrupeds, spiders or dragons onto the humanoid rig.
4. Give each legacy monster template a model-archetype mapping and variant data; named bosses receive authored identity overrides.
5. Validate every model in Godot with front/side/rear/three-quarter screenshots, skeleton/animation checks and representative equipment.
6. Load the same character definitions in Campaign and Arena. Lobby previews must be the same model/identity that can later be spawned as the actual opponent.

## Arena port order

1. Arena lobby and its announcer, recruiter, shopkeeper, waiting combatant previews and beast pen.
2. Deterministic opponent selection from the source pool, respecting dragon unlock thresholds.
3. Port arena scenario variants and arena boss definitions.
4. Run matches through the shared `WorldSimulation` and combat rules; no separate Arena combat implementation.
5. Apply source rewards/progression and return to lobby; persist completed fights and defeated bosses.
6. Trigger existing imported Arena music/dialogue through AudioManager.

## Important distinction

A manifest is not a finished model pack or a playable Arena. This PR creates the source-backed roster contract and validation so we can build the complete model set without losing track of missing characters. The actual GLB generation, Arena encounter loop and live Pages visual acceptance remain subsequent work.
