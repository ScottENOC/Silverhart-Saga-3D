# World-building architecture and migration plan

**Status:** implementation in progress  
**Target branch:** `feature/world-building-foundation`  
**Source authority:** `ScottENOC/Hex-crpg`, Campaign 2  
**Runtime:** Godot 4.7.2, GDScript

## Objective

Expand Silverhart Saga 3D until it represents the complete meaningful Campaign 2 world from Hex-crpg. Preserve source-authored geography, named locations, routes, landmarks, settlement identities and gameplay relationships. The old browser runtime is a migration source only; it is not a runtime dependency.

The world must be extended through data and reusable systems. Adding a settlement or building must not require a script named after that location or building, nor modifications to unrelated locations.

NPC generation and migration are explicitly outside this workstream. World data may retain stable NPC references and spawn anchors, but this project does not generate, redesign or bulk-import NPC bodies, hair, clothing, dialogue or behaviour.

## Current codebase findings

The following components already exist and should be evolved rather than duplicated:

| Component | Current responsibility | Required direction |
|---|---|---|
| `MainCampaignWorldMapData` | 16×16 strategic map | Keep as strategic geography source, reconcile against extracted source manifest |
| `Campaign2WorldTerrainData` | Loads geography, roads and settlement layouts; resolves deterministic local terrain | Keep as the local-world data provider; separate authored feature precedence from procedural terrain |
| `HexWorldChunkStreamer` / regional preview streamer | Chunk membership and streamed terrain presentation | Consolidate overlapping streaming responsibilities; preserve simulation state on unload |
| `BuildingRegistry` | Stable building definitions and persistent door state | Keep as authoritative logical registry |
| `BuildingLayoutRegistrar` | Registers building, entrance, doors and interior floor cells | Keep logical registration separate from 3D construction |
| `Campaign2SettlementBuilder` | Chunk-scoped settlement presentation and NPC actors | Limit to orchestration; delegate building construction to shared factory |
| `HollowmereVillage` | Currently builds Hollowmere terrain, roads, stream, buildings, bridge, farm and vegetation | Incrementally replace with data-driven feature presentation |
| `HollowTankard` | Starting playable tavern, interior, interaction and campaign integration | Preserve as working reference; later extract reusable interior components without breaking campaign behaviour |
| `WorldRoot` | Campaign composition and starting location setup | Remove location-specific composition from the global root when location loading is generalised |

### Confirmed debt and gaps

1. `Campaign2SettlementBuilder._build_building()` contained a complete hardcoded timber-house construction routine, including dimensions, wall positions, door, windows, roof, chimney and fireplace. It was not a generic building factory and did not support non-house building kinds.
2. `HollowmereVillage` owns substantial location-specific geometry and feature data. Copying this script for other settlements would multiply maintenance.
3. The starting tavern is a large location-specific presentation/controller. Its gameplay behaviour is valuable and should not be rewritten wholesale as part of the first building-factory change.
4. Logical building registration exists, but it is not a reusable 3D building construction system.
5. The geography and settlement manifests are partial inventories. A first-pass list of strategic destinations is not evidence that every source location, building, route, landmark or feature has been migrated.
6. The regional preview currently has its own chunk-presentation responsibilities while a separate chunk streamer also exists. Their responsibilities and runtime usage need an explicit consolidation decision before production-world expansion.

## Target responsibilities

### 1. Authored world data

Version-controlled, stable-ID records describe:
- strategic regions and faction territories;
- settlements, districts and landmarks;
- local axial coordinates and strategic/local coordinate transforms;
- buildings, footprints, entrance locations and interior/floor definitions;
- roads, trails, bridges, rivers and other major landscape features;
- fields, pastures, camps, ruins, dungeons, mines and resource sites;
- references to NPCs and other campaign content, without owning their generation.

Definitions describe *what exists*, not the sequence of scene-node operations used to construct it.

### 2. World data provider

Loads and validates manifests, resolves references, applies authored-feature precedence and supplies deterministic queries to renderers and simulation systems.

Authored named features must override procedural terrain. Procedural detail must not displace authored roads, buildings, rivers, entrances, quest locations or landmarks.

### 3. Reusable feature factories

Separate reusable systems construct feature categories:
- building factory and architectural archetypes;
- road/path renderer;
- river/watercourse renderer;
- bridge and crossing renderer;
- vegetation and forest generator;
- agricultural feature renderer;
- landmark/prop placement.

Factories receive definitions and return presentation nodes. They do not know the name or identity of a settlement. They do not register simulation rules as a side effect.

### 4. Logical world and simulation

The logical map, building registry, doors, occupancy, navigation, NPC schedules, quest state and persistence remain authoritative. Presentation nodes are disposable. Chunk unload/reload must not reset world state.

### 5. Streaming and composition

The streamer requests data and presentation for a region of the continuous world. Chunk boundaries are performance boundaries, not gameplay boundaries or separate levels. A global campaign composition root selects the active world; it must not contain per-location construction logic.

## Building definition contract

A building instance should carry, at minimum:
- stable `id`;
- archetype or supported kind;
- local axial centre and orientation;
- footprint / dimensions;
- entrance position and facing;
- material/style overrides;
- optional features;
- interior/floor reference;
- source provenance.

The factory resolves an archetype and configurable parameters. It must reject unknown archetypes and invalid dimensions rather than silently constructing a default cottage.

Archetypes share construction routines. Variations are data (dimensions, materials, roof, openings, windows and optional features), not branches named after individual buildings.

The first implementation adds `WorldBuildingFactory` with reusable cottage, shop, chapel, barn and manor presets. `Campaign2SettlementBuilder` delegates to it and retains only chunk orchestration and actor placement. This is an initial construction primitive, not completion of the full building system. Hollowmere's five village buildings, farmhouse and barn now use the same factory; the barn uses a reusable double-door feature. Store signage and the chapel bell tower remain separate presentation add-ons. The river, banks, main roads, village lane, ring road, house spurs and farmyard lane are now authored in `HollowmereVillageData.PRESENTATION_ROUTES` and rendered by `WorldPolylineFeatureFactory`; this does not replace or generate logical path cells. The river crossing is separately authored in `HollowmereVillageData.BRIDGE_PRESENTATION` and assembled by `WorldBridgeFeatureFactory`, with the original deck, rails, posts, placement and rotation preserved.

## Required invariants

- No village-, town-, building- or landmark-specific construction scripts.
- No new code branches based on settlement IDs or individual building IDs in shared factories.
- No duplicate authoritative world maps or competing registries.
- Stable IDs and explicit source provenance for migrated content.
- Deterministic output for the same definition, seed and generator version.
- Authored feature precedence over procedural terrain.
- Chunk boundaries do not affect navigation, ownership, persistence or feature placement.
- Presentation unload never deletes authoritative simulation state.
- NPC generation and character appearance remain outside this workstream.
- New settlements should be added through validated data, not new construction code.

## Incremental migration sequence

1. **Building factory (current slice):** extract the Millbrook hardcoded house into a shared factory; define supported archetypes and data-driven parameters; add isolated tests and CI validation.
2. **Hollowmere feature decomposition:** buildings are now driven by `HollowmereVillageData.BUILDINGS` for both footprints and factory construction. Continue with roads, watercourse, bridge, fields, fences, vegetation and reusable props. Preserve gameplay while each feature is migrated. Keep the tavern playable.
3. **Building and interior convergence:** make all Hollowmere buildings use the same building definitions, logical registry, doors, entrances and reusable interior/floor composition. Do not treat the tavern as a reason to duplicate the system.
4. **Streaming consolidation:** decide the single authoritative streamer and separate data generation, logical world state and disposable presentation. Verify cross-chunk roads, rivers, terrain edges, actors and state restoration.
5. **Source inventory extraction:** systematically inspect Hex-crpg Campaign 2 source and produce complete inventories for settlements, structures, routes, landmarks and authored geography. Keep source IDs and provenance.
6. **Regional migration:** migrate each source location using data and existing factories; validate coordinate transforms and travel connections.
7. **Fidelity audit:** compare every migrated source feature against the source inventory; record faithful reproduction, 3D adaptation or not-yet-ported status.

## Acceptance tests

- Building factory tests cover supported archetypes, configurable dimensions, door orientations, optional features, metadata and invalid definitions.
- Settlement builder tests prove it delegates to shared construction and does not contain geometry.
- Shared world feature tests validate stable IDs, references, coordinate transforms, deterministic generation and authored-feature precedence.
- Streaming tests load/unload adjacent chunks and prove continuity and persistent simulation state.
- Existing Hollowmere, tavern, navigation, save/load and campaign tests remain green throughout.
- A new settlement can be added without editing an existing location script, the building factory, or the streamer.

## Current implementation status

- [x] Architecture baseline inspected on `dev`.
- [x] Reusable building factory introduced.
- [x] Settlement builder delegates building construction to the factory.
- [x] Isolated factory tests added to the Godot validation workflow.
- [x] Run Godot 4.7.2 import and test suite on the feature branch (building-factory slice passed; polyline extraction validation pending).
- [ ] Review generated building appearance in the regional preview.
- [x] Migrate Hollowmere village houses, farmhouse and barn to shared factory definitions.
- [x] Keep store signage and chapel bell tower as separate add-on presentation features.
- [x] Move Hollowmere stream, banks, main roads, village lane, ring road and house spurs into authored presentation route data and a shared polyline renderer.
- [x] Move Hollowmere bridge placement and component geometry into authored data and a shared bridge assembly factory.
- [ ] Migrate Hollowmere fields, fences and remaining props.
- [ ] Consolidate streaming and world composition.
- [ ] Complete source-world feature inventory and regional migration.
