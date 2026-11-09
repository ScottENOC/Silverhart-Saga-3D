# Original 2D source audit — Campaign 2 world port

Source: https://github.com/ScottENOC/Hex-crpg (default branch: main)
Target: https://github.com/ScottENOC/Silverhart-Saga-3D
Target working branch: feature/full-world-port-foundation

## Audit scope and confirmed repository facts

The original repository tree contains 893 tracked paths (recursive Git tree, not truncated). This is a substantial game codebase, not just a map prototype. The main campaign to port is Campaign 2. The separate 400×400 embedded world in world_map_data.js belongs to the old Campaign 3 path and must not be accidentally substituted for Campaign 2.

### Primary world/map sources

| Source file | Role in migration |
|---|---|
| campaign2World.js | Main authored Campaign 2 local world: terrain painting, roads, streams, settlements, landmarks, world setup and many placed objects/NPCs |
| worldMap.js | 16×16 odd-q strategic map and its terrain/faction geography, marker rendering and local-to-world map relationships |
| world_map_data.js | Separate embedded 400×400 map for old Campaign 3; reference only if campaign selection confirms it is required |
| hexMap.js | Local hex-grid coordinate/render/input conventions; port rules and data, not Canvas renderer |
| terrain.js | Terrain definitions, movement and interaction semantics |
| worldChunkStreaming.js | Continuous-world streaming model; original CHUNK_SIZE=24, hot radius=2, multiple party observers, vertical stair preloading |
| settlementScale.js | Settlement tiers, radii, population targets and districts |
| regions.js | Persistent security/prosperity hierarchy and parent-child effects |
| worldPulse.js | Autonomous world events and persistent world changes |
| worldTime.js | World clock hooks and scheduled simulation |
| wildernessLivingWorld.js | Wilderness population/liveliness and world activity |
| resources.js | Harvestable resource definitions/state |
| campaign2Content.js | Campaign 2 content definitions and effects |
| campaign2Dialogue.js | Campaign 2 dialogue, choices and consequence wiring |

### Additional content/system families identified in the tree

- Quest and narrative files: numerous named quest scripts, companion quest chains, espionage quests, questLog.js, namedNpcProgression.js.
- NPC systems: npcBuilder.js, npcRoutineScheduler.js, eventDrivenNpcSchedules.js, npcSocialFacing.js, npcReliability.js, npcProgression.js and related tests.
- Companion/world agency: companionWorldAgency.js, companionMajorQuestReactivity.js, companionQuestChains.js.
- Living-world/camp/caravan systems: campSystem.js, campDeploymentSystem.js, worldPulse.js, wildernessLivingWorld.js.
- Character/creature visual assets: images/characters/creatures includes boar, dragon, eagle, horse, sheep, unicorn, wolf, goblin, orc, undead and other creatures; this is not necessarily the complete spawn roster.
- Resource visuals: images/props/resources/ore_vein.svg and related prop assets.
- Tests provide useful executable source specifications for world geography, world-map scale, settlement content density, buildings, NPC schedules, quests, resources, terrain interactivity, streaming, wilderness and world events.

## Source-derived geography facts already confirmed

- Campaign 2 strategic world is 16×16 odd-q hexes.
- Strategic terrain/faction layout: columns 0–1 western ocean; columns 2–9 predominantly human Silverhart lands; columns 10–15 orc-held east; north-eastern 4×5 mountain block for dwarven Kragmoor; southern forest belt for the elven realm; river path from the mountains toward the western coast. Some border cells are deliberately exchanged between dwarves and orcs.
- Hollowmere crossroads is the local-to-strategic reference origin at strategic row 6 / column 6.
- The local-to-strategic scale constant is WORLD_HEX_SIZE=130 local hexes per strategic cell.
- Source strategic named locations include Hollowmere, Millbrook, Silverhart, Reddale, Emberlode and Old Mac's Farmstead, with additional forts, camps, dungeons and other authored POIs to extract from campaign2World.js and related files.
- The original local world is continuous; chunks are LOD/performance units, not separate gameplay maps.
- Original local streamer uses chunk size 24, hot radius 2, and multiple active player-party observers. It also preloads vertical layers near stairs.
- Source settlement tiers include hamlet, village, town and capital, with distinct default population targets and district data.

## Hollowmere reference slice

The 3D project's existing docs identify the source-backed Hollowmere layout anchors:
- Hollow Tankard centre (0,0)
- General store (0,18)
- Chapel (-14,0)
- Elder's house (0,-12)
- Mira's house (12,9)
- Oskar's house (-6,9)
- Stream near r=-25 and bridge at (8,-25)
- Signposted crossroads (8,24)

The 3D project also has additional authored farmstead/barn data. Compare this against the complete source world rather than assuming current 3D records are exhaustive.

The original opening cast documented in the 3D migration plan includes Wren Talbot, Garrick Holt, Mira Ashbrook, Oskar Vinn, Yvette Marlow, Hendra Wells, Wick Hallow, Elder Marta Wynfield, Dray Coltayne, Tomlin Brask, Hask Greel, Tam Wells (missing-child thread), and Rowan Fletcher (wandering hunter). Validate each identity, starting placement, schedule, dialogue and quest relationship against the original campaign scripts.

The opening event is the Ironbond Company shakedown. Its gating, dialogue branches, faction/reputation effects and later investigator follow-up are part of parity, not optional flavour.

## Critical implementation warning

The current 3D HexWorldChunkStreamer uses CHUNK_SIZE=16 and generic deterministic seeded terrain for un-authored cells outside the authored village radius. This is useful as a technical prototype but is not a faithful full-world port. Do not simply increase its radius or let its procedural terrain fill over source geography. First extract the original source-authored world into stable portable records, then have the chunk system render those records. Procedural detail is allowed only where the source leaves detail unspecified.

The 3D project's existing MIGRATION_MAP.md and MAIN_CAMPAIGN_WORLD_MAP_PLAN.md are useful foundations and should be reconciled with this audit rather than replaced.

## Remaining M0 extraction tasks

1. Parse the complete campaign2World.js source and enumerate every terrain/road/river paint operation, named landmark, settlement, building footprint, door, interior, tile object, NPC and spawn.
2. Extract the full 16×16 strategic map algorithm and all markers into an explicit data asset, preserving odd-q coordinates, terrain types, factions, river path and marker positions.
3. Extract all Campaign 2 content/dialogue IDs and effects from campaign2Content.js and campaign2Dialogue.js.
4. Cross-reference every POI and named character to quests, schedules, factions, region state and world events.
5. Inspect source tests as executable acceptance criteria; port high-value geography/content tests into Godot.
6. Compare source inventory against existing 3D data and create a row-by-row parity register with status: source-only, partially ported, faithful, or 3D-adapted.
7. Record every accepted 3D-native deviation (e.g. stairs and upper floors) in a separate deviation register. Confirm that all affected rooms, interactions and quest paths remain accessible.
