# Full-world port: clarified fidelity and inspection gates

## The target

Port the original Campaign 2 world and game systems into 3D with **99% feature and gameplay fidelity** and **relative-geography fidelity**.

This is not a hex-for-hex conversion exercise. The original 2D terrain and road detail was often generated quickly; exact incidental cells, random forest clumps, individual road wiggles and minor terrain variations are not valuable fidelity targets.

The 3D world should preserve:

- Every meaningful named location: settlements, farms, forts, mines, dungeons, lairs, groves, caves, capitals, landmarks and quest sites.
- The same broad geography: human, orc, dwarf and elf territories; ocean, rivers, mountain ranges, forests and border regions.
- Relative positions and travel relationships: what lies north/south/east/west of what, what is nearby or remote, and which roads, rivers, passes or routes connect places.
- The original inhabitants, factions, creatures, dialogue, quests, items, equipment, shops, services, interactions, progression and gameplay consequences.
- The character and story relationships that make each place meaningful.

The 3D implementation may use different local coordinates, road curves, terrain shapes, building footprints, stairs, floors and interiors. These are design choices, not parity failures, if the important spatial relationships, functions, access and gameplay outcomes are preserved.

## What should be exact versus approximate

| Element | Fidelity requirement |
|---|---|
| Named locations and significant landmarks | Exact identity and complete inclusion |
| Relative position of locations | Preserve direction, approximate distance and regional context |
| Faction territories and borders | Preserve ownership, neighbours and strategic relationships |
| Major geography (sea, rivers, mountains, forests) | Preserve overall shape, direction and world-forming role; 3D may improve detail |
| Roads and travel connections | Preserve destinations, connectivity, meaningful junctions and travel relationships; routes may be redesigned |
| Individual terrain hexes / random foliage | No need for cell-by-cell reproduction |
| Exact generated road wiggles | Not required; use as reference only |
| Building footprints and floor plans | Preserve function, access, important rooms and occupants; redesign for 3D where useful |
| NPCs, creatures, quests, dialogue, items and systems | Preserve content, behaviour, conditions and outcomes |
| Chunk boundaries and sizes | Pure implementation detail; no visible or gameplay discontinuity |

## How to use the source extraction already committed

- `data/world/campaign2_road_paths.json` is a **reference trace** of the original crossroads road-generation algorithm. It is useful for directions, approximate distances, route order and waypoint placement. It is not a demand to render those exact cells or preserve each wiggle.
- The source inventory and NPC/dialogue index are content-discovery aids. They do not mean that the content is implemented in 3D.
- The gap audit's specific coordinate/footprint mismatches identify places where the current prototype should be checked against the source's relative layout. They should not force the 3D world into an awkward exact copy of the old hex grid.

## Revised implementation sequence

1. Finish the content and feature inventory: all named locations, characters, factions, creatures, quests, dialogue, items, services and gameplay systems.
2. Establish the source-backed **world geography manifest**. The first pass now records 24 named destinations and 22 travel connections, with local axial anchors, region membership and the original 130:1 strategic conversion. Continue reconciling it against every source builder, hidden site and quest before treating it as complete.
3. Build the coherent 3D macro-world view. The first browsable strategic preview now exists, and a second regional preview now streams local 24-hex chunks around the camera. It reuses the authored Hollowmere exterior and generates source-biome terrain, road cells, rivers, forests and POI labels outside the authored village radius.
4. Build the continuous chunk streamer against that geography. Chunks stream the world; they do not define or fragment it.
5. Implement settlements, buildings, interiors, NPCs and quests using reusable data-driven systems.
6. Expand the remaining world region by region, validating feature completeness and gameplay parity.
7. Use automated tests for data integrity, connectivity, persistence, quest effects and chunk seams. Use visual inspection for the overall geography, readability and 3D quality.

## When the user should inspect

Do **not** ask the user to inspect the source audit, raw JSON or an empty technical chunk proof. Those are developer artefacts.

The first inspection deliverable now includes **World Preview** (strategic 16×16 geography) and **Regional Map** (streamed local terrain chunks, authored Hollowmere scene, source-derived road/river/biome placement and location jumps). This remains a browsable map-development view rather than a character-controlled travel system; distant settlements still need authored buildings, interiors, NPCs and gameplay. Ask the user to inspect after the regional scene passes Godot validation. The next gate is a playable travel slice and a fully authored neighbouring settlement.

## Current status

The feature branch now contains the source audits, road reference trace, first-pass geography manifest, strategic preview, and a regional preview built on a reusable deterministic terrain data provider. The regional scene reuses the existing Hollowmere exterior and streams nine 24×24 local-hex chunks around its camera target; each chunk batches terrain by biome, adds instanced forest trees, renders the source road traces and river systems, and labels nearby manifest locations. The full world is not yet character-traversable, and distant settlements still need authored content. Godot CI is running against this implementation; do not claim a pass until its result is confirmed.
