# Full-world 2D-to-3D port plan

## Goal

Port the complete playable world and gameplay content of the original Silverhart Saga / Hex-crpg into Silverhart Saga 3D. The original browser game is the source of truth for world layout, content, rules, names, dialogue, quests, items, and progression. The Godot project owns a clean implementation of those rules; it must not embed or run the old browser runtime.

This is a parity project, not a redesign that silently drops content. Any intentional 3D-only changes should be recorded separately from missing parity.

## Current baseline

The project README identifies the current milestone as the M1 prototype foundation. It already describes flat-top axial hex coordinates, TP-costed movement, weighted mouse-click A* routing, terrain-aware movement costs, a world clock/calendar, combat initiative work, and a separate elevation prototype using centre heights and shared vertex samples. The Hollow Tankard is the current playable building/interior example. This is not yet a complete world representation.

## Non-negotiable architecture

1. **Simulation data is authoritative.** Logical world state, occupancy, movement legality, interaction rules, time, combat, quests, inventory, and persistence live in GDScript data/systems. Scene nodes render and expose that state; they do not become the source of game rules.
2. **Stable world coordinates.** Retain the existing axial hex coordinate system for gameplay. Chunk coordinates are a deterministic grouping of those coordinates; chunk boundaries must not change movement, pathfinding, line of sight, ownership, or persistence.
3. **One continuous world.** Chunks are a streaming/authoring boundary, not visible walls or separate levels. Neighbouring chunks must share terrain-edge samples and compatible roads, rivers, paths, and navigation.
4. **Data-driven content.** Regions, settlements, buildings, entrances, NPCs, creatures, resources, encounters, items, shops, dialogue, quests, and spawn rules should be represented as stable-ID data with references between records. Avoid hard-coding content into scene scripts.
5. **Deterministic generation.** Given the same source data, world seed, and generator version, a chunk should rebuild consistently. Hand-authored landmarks and 2D-map placements take precedence over procedural decoration.
6. **Interiors are separate spaces connected by explicit entrances.** Reuse the working tavern entry/exit and roof-visibility interaction pattern. Each building record identifies its exterior footprint, entrance, interior scene/data, and interaction policy. Not every shed needs a bespoke interior, but every original building must have the correct 3D presence and gameplay role.
7. **Streaming must preserve state.** Unloading a chunk may remove presentation nodes, but must not reset NPC schedules, dropped items, harvest state, quest flags, doors, containers, or other simulation state.
8. **PC-first authoring and validation.** Heavy Godot/Blender work and asset imports are performed locally in the user's Godot 4.7.2 standard-build environment. GitHub Actions may handle light deterministic validation or asset-independent data checks, not heavyweight scene/mesh production.

## Chunk design

Do not lock a chunk width or world extent until the original map format and the existing Godot grid implementation have been audited. Choose a chunk size that gives a useful streaming/authoring unit without making settlements or important landmarks awkwardly straddle boundaries.

Each chunk should be buildable from:
- stable chunk ID and axial coordinate bounds;
- terrain cell records and shared boundary vertex/elevation samples;
- biome, climate, water, vegetation and resource layers;
- roads, trails, rivers and other connected features;
- placed landmarks and settlement/building references;
- spawn/encounter/resource metadata;
- references to authoritative simulation records.

Keep a lightweight world index so the game can locate a settlement, entrance, NPC, quest target, or other point of interest without loading every visual chunk. Use a small active neighbourhood around the player, with adjacent chunks prefetched according to travel direction and movement speed. Persist world changes independently of the lifetime of a chunk scene.

## Porting workstreams

### A. Source-of-truth inventory (first)
Audit the original Hex-crpg repository and enumerate its actual data and systems before generating the full map. Capture:
- world dimensions, coordinate convention, map layers and region boundaries;
- every named location and its exact position/footprint;
- terrain, elevation, water, roads, paths, vegetation and resource placement;
- every building, entrance, interior, service and interaction;
- NPCs, factions, creatures, wildlife and rideable animals;
- dialogue, quests, triggers, encounters and progression gates;
- items, equipment, crafting/harvesting, shops, containers and loot;
- time, weather, movement, combat and other simulation rules.

Produce a traceable parity register: source file/data ID -> Godot data ID -> 3D presentation -> validation status. Do not infer missing source content from screenshots or memory when the original files can be inspected.

### B. World data migration
Create versioned, stable-ID Godot resources/data files for the original map and content. Preserve source coordinates and IDs where practical, and record any coordinate transforms explicitly. Add validation for missing references, duplicate IDs, invalid entrances, disconnected roads/rivers, out-of-bounds placements, and orphaned quest targets.

### C. Terrain and chunk renderer
Use the existing elevation representation (cell-centre heights plus shared vertex samples) as the starting point. Build a chunk renderer that can generate continuous terrain surfaces and apply terrain/biome materials, water, cliffs/slopes, and vegetation. Chunk-edge tests must prove there are no cracks or discontinuities. Keep the logical hex grid invisible in normal play.

### D. Settlement and building placement
Place original settlements and buildings from migrated source data. Support multi-hex footprints, collision/navigation, doors, roof visibility, enter/exit transitions, and interior assignment. Preserve the Hollow Tankard as the first reference implementation, then generalise its working pattern to the rest of the settlement.

### E. Living world and gameplay parity
Populate chunks from the migrated data and connect NPCs, creatures, wildlife, rideable animals, resources, loot, shops, dialogue, quests, and encounters to the existing simulation systems. A visible object is not complete parity unless its interaction and state changes work.

### F. Persistence, streaming and performance
Save world changes by stable IDs, not by serialising transient scene trees. Add chunk load/unload tests, save/reload tests, deterministic regeneration tests, and profiling at representative settlement and wilderness densities.

## Milestones and acceptance gates

1. **M0 — source audit:** a complete inventory and parity register exist; no full-map generation is attempted from guessed data.
2. **M1 — chunk proof:** a small multi-chunk terrain test loads/unloads, has seamless edges, preserves axial movement/pathfinding, and survives save/reload.
3. **M2 — starting region:** the original starting region is reproduced at its correct scale and layout, including terrain, roads, all buildings, entrances, and the working tavern interior.
4. **M3 — complete geography:** all original regions and named locations are represented and reachable; no missing map cells or unplaced landmarks.
5. **M4 — content parity:** all original NPCs, creatures, rideable animals, quests, dialogue, items, services, resources, encounters, and interactions are migrated and validated.
6. **M5 — production streaming:** the complete world streams and persists reliably at target PC performance, with no visible chunk seams or gameplay changes at chunk boundaries.

A milestone is not complete merely because its assets render. The corresponding simulation and interaction tests must pass.

## First implementation task

Perform M0 before writing a world generator: inspect the original 2D repository and current Godot project structure, identify the real map/data files and current grid/elevation APIs, then produce the source-to-Godot mapping. After that, implement the chunk proof on a feature branch. Keep unrelated character/anatomy work and the integration branch isolated.
