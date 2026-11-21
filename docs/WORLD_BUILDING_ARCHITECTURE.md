# World-building architecture and migration plan

**Status:** implementation in progress  
**Target branch:** `feature/world-building-foundation`  
**Source authority:** `ScottENOC/Hex-crpg`, Campaign 2  
**Runtime:** Godot 4.7.2, GDScript

## Objective

Expand Silverhart Saga 3D until it represents the complete meaningful Campaign 2 world from Hex-crpg. Preserve source-authored geography, named locations, routes, landmarks, settlement identities and gameplay relationships. The old browser runtime is a migration source only; it is not a runtime dependency.

The world must be extended through data and reusable systems. Adding a settlement or building must not require a script named after that location or building, nor modifications to unrelated locations.

NPC generation and migration are explicitly outside this workstream. World data may retain stable NPC references and spawn anchors, but this project does not generate, redesign or bulk-import NPC bodies, hair, clothing, dialogue or behaviour.

**Accepted project-wide decision:** [ADR 0001 — Continuous world, modular authored data, streamed presentation](adr/0001-continuous-world-and-streamed-presentation.md). This decision is authoritative for the migration plan below. In particular, strategic maps are regional-scale references, not separate playable worlds; settlement-local authoring must map explicitly into the continuous axial world frame.

## Current codebase findings

The following components already exist and should be evolved rather than duplicated:

| Component | Current responsibility | Required direction |
|---|---|---|
| `MainCampaignWorldMapData` | Runtime adapter that builds the 16×16 strategic index | Derive dimensions, coordinate transform, regional bands, faction overrides, river path and marker selection from `campaign2_geography.json` |
| `Campaign2WorldTerrainData` | Loads geography, roads and settlement layouts; resolves authored feature precedence and delegates procedural terrain | Keep as the local-world adapter; authored settlement terrain is discovered through a validated registry, while regional classification, elevation and geological rules remain shared |
| `Campaign2WorldCellLoader` / regional preview streamer | Logical-cell materialisation and streamed terrain presentation | Both query `Campaign2WorldTerrainData`; logical cells persist, while presentation remains disposable |
| `BuildingRegistry` | Stable building definitions and persistent door state | Keep as authoritative logical registry |
| `BuildingLayoutRegistrar` | Registers building, entrance, doors and interior floor cells | Keep logical registration separate from 3D construction |
| `Campaign2SettlementBuilder` | Chunk-scoped settlement presentation and NPC actors | Limit to orchestration; delegate building construction to shared factory |
| `WorldSettlementPresenter` | Composes authored settlement features, ground, vegetation and creature actors | Generic presenter configured entirely by settlement data; used by both campaign and regional preview |
| `HollowTankard` | Starting tavern runtime controller, interactions and campaign integration | Keep live door/floor transitions and gameplay; static geometry and logical interior registration are authored data interpreted by shared presenters/registrars |
| `WorldRoot` | Campaign composition and simulation lifecycle | Select a location definition and delegate component creation to `Campaign2LocationLoader`; keep campaign-wide quest/simulation setup here |

### Confirmed debt and gaps

1. `Campaign2SettlementBuilder._build_building()` contained a complete hardcoded timber-house construction routine, including dimensions, wall positions, door, windows, roof, chimney and fireplace. It was not a generic building factory and did not support non-house building kinds.
2. The former `HollowmereVillage` scene script mixed authored features, environment presentation and animal actors. It has been removed; the generic `WorldSettlementPresenter` now consumes a location-supplied definition. Hollowmere's local terrain and navigation rules now live in `data/settlements/hollowmere/terrain.gd`; `AuthoredSettlementTerrainProvider` interprets those rules for simulation, presentation and interior registration. The former `HollowmereVillageData` compatibility facade has been deleted after migrating its callers to authored definitions and the generic provider.
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

Hollowmere authored data is now separated under `data/settlements/hollowmere/` by ownership: `settlement_definition.gd` (identity and coordinate reference), `terrain.gd` (local movement, stream, path, building and farm-land rules), `buildings.gd`, `routes.gd`, `bridges.gd`, `agriculture.gd` and `props.gd`. Starting actor placement is separately authored in `placements.gd`: the player and character-profile IDs map to campaign axial start cells, and the same file owns Old Mac/Reyna/Tessa quest anchors plus farm and ambient creature placements. `data/characters/hollowmere_npcs.json` now contains appearance/profile data only; its former `hex` fields were removed so character identity and world placement cannot silently disagree (notably Reyna's actual opening position is the authored `(17, 57)` start). The former `HollowmereVillageData` facade has been deleted; authored modules and `AuthoredSettlementTerrainProvider` are now the only sources for these queries. This is an incremental GDScript-resource migration, not a new coordinate frame: all authored axial points remain in `campaign2_local_axial_qr`, with the Hollowmere crossroads reference at `(8, 24)`. Logical navigation queries are implemented by the authored terrain definition and generic provider. The strategic geography manifest is now authoritative for the strategic grid dimensions, the local-axial/strategic transform, region bands, the dwarf/orc border overrides, the strategic river and the selected macro-map markers; `MainCampaignWorldMapData` is only the runtime adapter. `Campaign2WorldTerrainData` now resolves authored settlement bounds through `Campaign2AuthoredSettlementTerrainRegistry`, which loads definitions from `data/world/authored_settlement_terrain.json`; it delegates terrain, movement, vegetation and elevation queries to the generic provider. Adding a settlement terrain definition no longer requires editing the world terrain adapter. The opening campaign's `HollowTankard` bootstrap now uses `Campaign2WorldCellLoader` to materialise the same logical cells used by the regional preview; `WorldInteriorLayoutRegistrar` then applies the authored tavern wall/furniture overlays and upper-floor cells. The cell loader still preserves any already-materialised or saved cell rather than overwriting it. The Silverhart heartland stream centreline and woodland ecology are regional data under `data/world/regions/silverhart_heartland/`, not settlement-owned data. The heartland biome module owns settlement woodland eligibility, tree occupancy, stream-edge species selection and understorey selection; it receives settlement exclusions as context rather than depending on Hollowmere navigation code. Shared Campaign 2 local terrain rules live separately under `data/world/terrain/`: they own strategic-cell terrain refinement, elevation profiles and regional forest/outcrop density. `Campaign2WorldTerrainData` resolves strategic/settlement precedence and delegates to those shared rules plus heartland-specific hydrology.

The Hollow Tankard static interior is now described by `data/settlements/hollowmere/interiors/hollow_tankard_layout.gd`, which composes its structural shell, upper storey, roof, taproom, partitions, room labels, axial bed anchors and floor presentation settings. `WorldInteriorLayoutPresenter` builds those definitions through the reusable interior feature factory. `HollowTankard` now calls that presenter once and retains only live references for door animation, floor visibility, roof cutaway and gameplay interaction; the previous per-feature construction methods have been removed from the controller. Its live door/floor visibility and gameplay interactions remain controller-side; logical building/door registration, ground-floor wall and furniture blockers, and upper-floor cell/partition rules are now authored in `hollow_tankard_layout.gd` and applied by the shared `WorldInteriorLayoutRegistrar`.

`WorldRoot` now selects `data/world/locations/hollowmere.gd` and delegates component instantiation to `Campaign2LocationLoader`. The location manifest identifies the settlement presentation and interior controller by role; the loader validates and stages all components before adding them to the scene tree. This removes Hollowmere-specific node construction from the global campaign root and provides the same composition contract for later locations. It is a composition step, not yet the final elimination of the Hollowmere presentation adapter.

The former `HollowmereVillage` script has now been removed. `WorldSettlementPresenter` receives a location definition and composes its ground plane, shared building/polyline/bridge/agriculture/prop factories, authored creature actors and deterministic vegetation. `data/settlements/hollowmere/presentation.gd` supplies the original palette, feature data, animal placements and vegetation parameters. Vegetation eligibility and species selection now use the same generic authored terrain provider, which supplies local exclusion context to the region-owned heartland biome rules. Both the campaign location loader and regional preview now use this same presenter and data definition. This removes a Hollowmere-specific exterior construction script without changing the authored coordinates or the shared animal-state registration contract. The legacy `HollowmereVillageData` facade has been removed; tests exercise the authored modules and generic provider directly.

The tavern's logical layout has also been extracted. `WorldInteriorLayoutRegistrar` interprets authored ground-floor collision regions, upper-floor partition rules, bed-blocked cells, building metadata and door state from the same layout definition used by the visual presenter. `HollowTankard` now delegates map overlays and building/floor registration instead of embedding those geometry-derived rules in its controller. The controller still owns runtime traversal transitions, door interaction and presentation visibility.

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

The first implementation adds `WorldBuildingFactory` with reusable cottage, shop, chapel, barn and manor presets. `Campaign2SettlementBuilder` delegates to it and retains only chunk orchestration and actor placement. This is an initial construction primitive, not completion of the full building system. Hollowmere's five village buildings, farmhouse and barn now use the same factory; the barn uses a reusable double-door feature. Store signage and the chapel bell tower remain separate presentation add-ons. The river, banks, main roads, village lane, ring road, house spurs and farmyard lane are authored in `data/settlements/hollowmere/routes.gd` and rendered by `WorldPolylineFeatureFactory`; this does not replace or generate logical path cells. The river crossing is separately authored in `data/settlements/hollowmere/bridges.gd` and assembled by `WorldBridgeFeatureFactory`, with the original deck, rails, posts, placement and rotation preserved. Farm field polygons, 17 crop rows and two fence runs are authored in `data/settlements/hollowmere/agriculture.gd` and rendered by `WorldAgriculturalFeatureFactory`; the logical farm-land query and animal/simulation placement remain independent. The store sign, chapel bell tower, crossroads signpost, broken pasture fence and blood trail are authored as primitive assemblies and rendered by `WorldPropFeatureFactory`; quest dressing remains data-owned and does not leak into agricultural or building construction code.

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

The canonical settlement definition contract is now specified in [ADR 0002](adr/0002-settlement-definition-contract.md). The current Hollowmere GDScript composition, Campaign 2 JSON layouts and terrain-only registry are explicitly transitional inputs; none is yet the final catalogue/provider. The next implementation slice is the canonical envelope validator and read-only adapters, followed by moving consumers to the provider. Do not treat the ADR as evidence that runtime convergence is already complete.

1. **Architecture decision and current-world audit (current slice):** accepted in [ADR 0001](adr/0001-continuous-world-and-streamed-presentation.md). Map the existing coordinate frames, geography sources, feature precedence, streamer call sites and simulation-state ownership before changing runtime architecture.
2. **World/region authority:** establish which existing manifests and transforms are authoritative; make the strategic map a coarse index into the continuous world, not a competing playable coordinate system. Add explicit validated transforms where local authoring remains useful.
3. **Hollowmere feature decomposition:** buildings, roads, bridge, agriculture and props use shared factories; authored definitions are now split into domain files under `data/settlements/hollowmere/`. Keep settlement logical rules separate from regional terrain, hydrology and biome ownership. Preserve all existing world coordinates and gameplay behaviour.
4. **Building and interior convergence:** make Hollowmere buildings use the same definitions, logical registry, doors, entrances and reusable interior/floor composition. Keep the tavern playable; do not duplicate its behaviour into another system.
5. **Streaming consolidation:** the legacy `HexWorldChunkStreamer` has been removed. Its logical-cell materialisation responsibility is now handled by `Campaign2WorldCellLoader`, which queries `Campaign2WorldTerrainData` and retains explored cells. The regional preview's presentation streamer remains preview-only; generalise and promote that renderer only after chunk-boundary, load-order and campaign-state tests prove equivalence.
6. **Source inventory and regional migration:** systematically inspect Hex-crpg Campaign 2 source and produce complete inventories for geography, settlements, structures, routes and landmarks. Retain source IDs/provenance and validate every local-to-world transform and travel connection.
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
- [x] Add a data-driven Campaign 2 location loader and move opening-location component composition out of `WorldRoot`.
- [x] Replace the Hollowmere-specific exterior scene script with a shared settlement presenter driven by authored palette, feature, animal and vegetation data; use it in both campaign and regional preview.

- [x] Move Hollow Tankard static shell, upper storey, roof, taproom furnishings, room partitions, labels and beds into authored layout data presented by a shared interior presenter.
- [x] Move Hollow Tankard ground/upper-floor collision rules and logical building/door/floor registration into authored layout data and a shared registrar.

- [x] Move Hollowmere stream, banks, main roads, village lane, ring road and house spurs into authored presentation route data and a shared polyline renderer.
- [x] Move Hollowmere bridge placement and component geometry into authored data and a shared bridge assembly factory.
- [x] Move Hollowmere field polygons, crop rows and fence runs into authored data and a shared agricultural renderer.
- [x] Move store signage, chapel bell tower, crossroads signpost and broken-fence/blood-trail quest dressing into authored prop assemblies and a shared renderer.
- [x] Split Hollowmere authored building, route, bridge, agriculture and prop definitions into domain files with direct module and generic-provider CI coverage.
- [x] Remove the Hollowmere compatibility facade after migrating callers to authored modules and generic-provider tests.
- [x] Resolve authored settlement terrain through a validated world manifest and generic registry instead of hardcoded Hollowmere branches in `Campaign2WorldTerrainData`.
- [x] Make the Campaign 2 geography manifest authoritative for strategic dimensions, transforms, regional bands, faction border overrides, river path and macro-map marker selection.
- [x] Move the Silverhart heartland stream rule into region-owned hydrology data with direct boundary/width tests.
- [x] Move heartland woodland eligibility and species-selection rules into region-owned biome data, leaving settlement geometry as supplied exclusion context.
- [x] Move shared Campaign 2 local terrain classification, elevation profiles, forest density and geological outcrop rules into a world-terrain module with direct threshold tests.
- [x] Replace the duplicate seeded logical exploration terrain generator with `Campaign2WorldCellLoader` backed by `Campaign2WorldTerrainData`; preserve authored cells and explored logical state.
- [x] Route Hollowmere local terrain through the shared Campaign 2 world provider and materialise its opening logical map through `Campaign2WorldCellLoader`; keep tavern walls/furniture as local gameplay overlays.
- [ ] Introduce and validate the canonical settlement definition envelope (ADR 0002).
- [ ] Adapt Hollowmere domain modules and Campaign 2 layout JSON to the same canonical envelope without changing authored coordinates.
- [ ] Replace independent settlement/terrain catalogues with one authoritative settlement provider.
- [ ] Consolidate full-settlement and streamed presentation on the same feature composition service.
- [ ] Complete source-world feature inventory and regional migration.
