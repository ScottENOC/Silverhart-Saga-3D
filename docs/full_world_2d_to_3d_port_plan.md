# Full-world 2D-to-3D port plan

## Goal and fidelity contract

Port the complete playable Campaign 2 world and gameplay content from [ScottENOC/Hex-crpg](https://github.com/ScottENOC/Hex-crpg) into Silverhart Saga 3D. The original 2D game is the authoritative source for geography, map scale, settlement layouts, building placement, named characters, factions, creatures, dialogue, quests, items, services, systems, rules, and progression.

**Target: 99% feature and gameplay fidelity, with geographical fidelity at the level of relative placement and world structure.** Preserve the original game's actual settlements, landmarks, factions, characters, creatures, quests, dialogue, items, services, systems, rules and outcomes. Preserve where places sit relative to one another: direction, approximate distance, routes, rivers, mountain/forest regions, borders and travel relationships. The original 2D game used substantial quickly-generated terrain and road detail; reproducing every individual hex, incidental bend or random terrain cell is not required and is not a goal. We should create a coherent 3D landscape that communicates the same world geography. Stairs, upper floors, building footprints, roads and local terrain may be redesigned for 3D where the result preserves the source location's identity, function, access, spatial relationships and gameplay consequences. Record meaningful changes in a deviation register, but do not mistake incidental 2D generation details for required content.

For every ported feature, distinguish:
- **Faithful reproduction:** same source content, placement, identity, rules, interactions, and outcomes.
- **3D adaptation:** different implementation needed for 3D, with equivalent gameplay and documented reason.
- **Not yet ported:** outstanding work; never disguise this as a design choice.

The Godot project must not embed or run the old browser runtime. Rebuild the game cleanly in GDScript while migrating source-authored data and preserving behaviour.

## Confirmed source facts

The original repository is public, on `main`, and contains 893 tracked paths at the time of this audit. The main campaign is Campaign 2:
- `worldMap.js` defines a 16×16 odd-q strategic hex map.
- `campaign2World.js` authors the continuous local world around Hollowmere and other regions, including terrain painting, roads, streams, settlements, landmarks, and scene setup. It is a large source file (~334 KB).
- `campaign2Content.js` and `campaign2Dialogue.js` hold substantial campaign content and dialogue.
- `worldChunkStreaming.js` uses chunk size 24 for continuous-world streaming; chunks are performance/LOD units, not gameplay/loading zones. It keeps a hot radius around every living player-party observer and has special vertical-layer preloading for stairs.
- `world_map_data.js` is a separate embedded 400×400 map used by the old Campaign 3 path. Do not confuse it with the Campaign 2 main campaign.
- `regions.js`, `worldPulse.js`, `worldTime.js`, `settlementScale.js`, `wildernessLivingWorld.js`, `resources.js`, `terrain.js`, and related systems contribute persistent simulation and world behaviour.

The 3D project already has:
- axial hex grid and map data;
- terrain rendering and a separate elevation prototype using cell-centre heights and shared vertex samples;
- a chunk streamer (`scripts/world/hex_world_chunk_streamer.gd`) currently using chunk size 16 and generic seeded terrain outside the authored-village radius;
- authored Hollowmere data and the Hollow Tankard reference interior;
- a separate 3D strategic-map data implementation.

The existing generic 3D chunk terrain is a prototype only. It must not be mistaken for a faithful migration of the original map. The original 2D streamer uses chunk size 24, but we should only adopt that exact size if the 3D renderer/performance tests support it; chunk size is an implementation detail, not a fidelity requirement.

## Current baseline

The 3D project already describes flat-top axial hex coordinates, TP-costed movement, weighted mouse-click A* routing, terrain-aware movement costs, a world clock/calendar, combat initiative work, and a separate elevation prototype. The Hollow Tankard is the current playable building/interior example. The complete world is not yet represented.

## Non-negotiable architecture

1. **Simulation data is authoritative.** Logical world state, occupancy, movement legality, interaction rules, time, combat, quests, inventory, and persistence live in GDScript data/systems. Scene nodes render and expose that state; they do not become the source of game rules.
2. **Stable world coordinates.** Retain the existing axial hex coordinate system for local gameplay. Preserve source coordinates where possible and explicitly document any transform between source odd-q strategic coordinates and local axial coordinates. Chunk boundaries must not change movement, pathfinding, line of sight, ownership, or persistence.
3. **One continuous world.** Chunks are streaming/authoring boundaries, not visible walls or separate levels. Neighbouring chunks must share terrain-edge samples and compatible roads, rivers, paths, and navigation. No loading screens between ordinary neighbouring overworld areas.
4. **Data-driven content.** Regions, settlements, districts, buildings, entrances, interiors, NPCs, creatures, resources, encounters, items, shops, dialogue, quests, and spawn rules should be represented as stable-ID data with references between records. Avoid hard-coding content into scene scripts.
5. **Deterministic generation with feature precedence.** Source-authored named places, landmarks, faction territories, major terrain features, roads/routes, rivers, access relationships and quest locations define the world structure. Their relative placement and gameplay meaning are authoritative, but incidental per-hex terrain and procedural road wiggles need not be copied. The 3D terrain and local routes may be regenerated to create a coherent, attractive and navigable world, provided named features retain their relative geography and travel relationships. Generated detail must never displace or obscure a required feature. Given the same source feature data, seed and generator version, a chunk should rebuild consistently.
6. **Interiors and verticality.** Reuse the working tavern entry/exit and roof-visibility pattern. Each building record identifies its exterior footprint, entrance, interior/floor data, and interaction policy. Stairs and upper-floor navigation may be implemented differently from 2D where that makes a better 3D game, but all source-relevant floors, rooms, access, objects, NPCs, services, quests, and gameplay outcomes must remain represented.
7. **Streaming must preserve state.** Unloading a chunk may remove presentation nodes, but must not reset NPC schedules, dropped items, harvest state, quest flags, doors, containers, regional state, or other simulation state. Every party member/observer and relevant vertical layer must be accounted for, following the original's multi-observer streaming intent.
8. **PC-first authoring and validation.** Heavy Godot/Blender work and asset imports are performed locally in the user's Godot 4.7.2 standard-build environment. GitHub Actions may handle light deterministic validation or asset-independent data checks, not heavyweight scene/mesh production.
9. **Source traceability.** Every migrated content record must retain its original source filename and source identifier/coordinate where possible. Every intentional difference goes in the 3D deviation register with rationale and parity impact.

## World scales and chunk design

Preserve the original distinction between the strategic world map and detailed local world, while treating source scale as a guide to relative geography rather than a requirement to reproduce every local hex:
- Campaign 2 strategic map: 16×16 odd-q cells, with west ocean, Silverhart human lands, eastern orc-held lands, north-eastern dwarven mountains, southern elven forest, river path, faction borders, and named markers.
- Local world: detailed axial hex space. The original code maps 130 local hexes per strategic map cell, with Hollowmere's crossroads as the reference origin. Keep this conversion source-derived; do not compress the entire world into the 16×16 strategic overview.
- Local streaming: original source uses 24-hex chunks as LOD/performance units. 3D chunk dimensions may differ after profiling, but must preserve the source world coordinates and seamlessness.

Do not lock a new world extent or chunk width until the original authored world bounds, current Godot grid, elevation APIs, and renderer costs have been audited.

Each chunk should be buildable from:
- stable chunk ID and axial coordinate bounds;
- source-authored terrain cell records and shared boundary vertex/elevation samples;
- biome, climate, water, vegetation and resource layers;
- roads, trails, rivers and other connected features;
- placed landmarks and settlement/building references;
- spawn/encounter/resource metadata;
- references to authoritative simulation records.

Keep a lightweight world index so the game can locate a settlement, entrance, NPC, quest target, or other point of interest without loading every visual chunk. Use a small active neighbourhood around the player, with adjacent chunks prefetched according to travel direction and movement speed. Persist world changes independently of the lifetime of a chunk scene.

## Porting workstreams

### A. Source-of-truth inventory (first)
Audit the original Hex-crpg repository and enumerate its actual data and systems before generating the full map. Capture:
- world dimensions, coordinate conventions, map layers and region boundaries;
- every named location and its exact position/footprint;
- terrain, elevation, water, roads, paths, vegetation and resource placement;
- every building, entrance, floor, room, interior, service and interaction;
- NPCs, factions, creatures, wildlife and rideable animals;
- dialogue, quests, triggers, encounters and progression gates;
- items, equipment, skills, spells, crafting/harvesting, shops, containers and loot;
- time, weather, movement, combat, regional simulation and other rules.

Produce a traceable parity register: source file/data ID/coordinate -> Godot data ID -> 3D presentation -> gameplay implementation -> validation status. Do not infer missing source content from screenshots or memory when the original files can be inspected.

### B. World data migration
Create versioned, stable-ID Godot resources/data files for the original map and content. Preserve source coordinates and IDs where practical, and record coordinate transforms explicitly. Prefer offline extraction of named features, their positions/relationships and gameplay data into portable resources. Do not spend effort snapshotting every incidental generated terrain hex or exact road wiggle; generate equivalent 3D terrain and routes around the source-backed feature anchors. Add validation for missing references, duplicate IDs, invalid entrances, disconnected roads/rivers, out-of-bounds placements, and orphaned quest targets.

### C. Terrain and chunk renderer
Use the existing elevation representation (cell-centre heights plus shared vertex samples) as the starting point. Build a chunk renderer that can generate continuous terrain surfaces and apply terrain/biome materials, water, cliffs/slopes, and vegetation. Chunk-edge tests must prove there are no cracks or discontinuities. Keep the logical hex grid invisible in normal play. Exact source-authored terrain types and geography take precedence over procedural terrain noise.

### D. Settlement and building placement
Place original settlements, districts, and buildings in the correct relative locations and regional context. Exact 2D footprints are not mandatory; design suitable 3D footprints, collision/navigation, doors, roof visibility, enter/exit transitions, floors, and interior assignment. Preserve the Hollow Tankard as the first reference implementation, then generalise its working pattern to every original settlement and building. A building may use a 3D-native floor/stair solution, but not disappear or lose its original gameplay function.

### E. Living world and gameplay parity
Populate chunks from migrated data and connect NPCs, creatures, wildlife, rideable animals, resources, loot, shops, dialogue, quests, faction systems, regional prosperity/security, world events, caravans, schedules, and encounters to the simulation. A visible object is not complete parity unless its interaction and state changes work.

### F. Persistence, streaming and performance
Save world changes by stable IDs, not by serialising transient scene trees. Add chunk load/unload tests, save/reload tests, deterministic regeneration tests, multi-party-observer tests, vertical-layer tests, and profiling at representative settlement and wilderness densities.

## Milestones and acceptance gates

1. **M0 — source audit:** complete inventory, world bounds, source coordinate transforms, and parity/deviation registers exist. No full-map generation from guessed data.
2. **M1 — chunk proof:** a small multi-chunk source-backed terrain test loads/unloads, has seamless edges, preserves axial movement/pathfinding, and survives save/reload.
3. **M2 — starting region:** Hollowmere is reproduced at correct scale and layout, including stream, bridge, roads, crossroads, every source building, entrances, NPCs and the working tavern interior; the opening event and branches work.
4. **M3 — complete geography:** all original Campaign 2 regions, settlements, districts, wilderness landmarks, roads, rivers, dungeons, forts and named locations are represented and reachable.
5. **M4 — content parity:** all original NPCs, creatures, rideable animals, quests, dialogue, items, services, resources, encounters, faction/regional systems and interactions are migrated and validated.
6. **M5 — production streaming:** the complete world streams and persists reliably at target PC performance, with no visible chunk seams or gameplay changes at chunk boundaries.

A milestone is not complete merely because assets render. The corresponding simulation, interaction, source-coordinate and parity tests must pass.

## First implementation task

Perform M0 before writing a world generator: inspect the original 2D repository and current Godot project structure, identify the actual map/data files and current grid/elevation APIs, extract source-authored world data, and produce the source-to-Godot mapping. Then implement the chunk proof on a feature branch. Keep unrelated character/anatomy work and the integration branch isolated.
