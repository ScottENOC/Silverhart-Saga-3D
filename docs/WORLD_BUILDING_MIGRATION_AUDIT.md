# World construction and migration audit

**Audit date:** 2026-11-21  
**Working branch:** `feature/world-building-foundation`  
**Target branch:** `dev`

## Executive finding

The project has one strategic geography source and two distinct playable-world presentation paths. The earlier three-way impression came from counting the strategic map UI as a world generator and the retired logical-cell streamer as a separate terrain source.

1. **Production opening campaign:** `scenes/main.tscn` → `WorldRoot` → `Campaign2LocationLoader`. The selected Hollowmere location composes the generic `WorldSettlementPresenter` and the `HollowTankard` runtime controller. Logical cells are materialised through `Campaign2WorldCellLoader` using `Campaign2WorldTerrainData`.
2. **Campaign 2 regional preview:** `scenes/prototypes/campaign2_regional_world_preview.tscn` → `Campaign2WorldTerrainData` → regional chunk presentation. Hollowmere uses the same generic `WorldSettlementPresenter` and authored definition as the production campaign; other settlements use `Campaign2SettlementBuilder`.
3. **Strategic map presentation:** `MainCampaignWorldMapData` adapts `campaign2_geography.json` into the 16×16 overview. It is not a playable-world generator or a second geography authority.

The legacy `HexWorldChunkStreamer` has been removed. Its logical-cell materialisation responsibility is now handled by `Campaign2WorldCellLoader`. The regional preview still owns the only current chunked 3D presentation renderer; it has not yet been promoted to the production campaign.

## Current production call paths

### Opening campaign

- `WorldRoot` selects `data/world/locations/hollowmere.gd` and delegates component staging to `Campaign2LocationLoader`.
- `WorldSettlementPresenter` receives `data/settlements/hollowmere/presentation.gd` and composes authored buildings, routes, bridge, agriculture, props, animal actors and deterministic vegetation through shared factories/generators.
- The same presenter and data definition are used by the regional preview. The former `HollowmereVillage` presentation script has been deleted.
- `HollowTankard` remains the starting tavern's runtime controller: interactions, live door/floor/roof transitions, local NPC/party presentation and encounter behaviour remain controller responsibilities.
- Its static shell, upper storey, roof, taproom furnishings, upper-room partitions, labels and bed anchors are authored in `data/settlements/hollowmere/interiors/` and interpreted by `WorldInteriorLayoutPresenter`.
- Its ground-floor blockers, upper-floor occupancy, building metadata and door registration are authored in `hollow_tankard_layout.gd` and interpreted by `WorldInteriorLayoutRegistrar`.

### Regional preview

- `Campaign2WorldTerrainData` resolves global axial coordinates against the strategic geography, roads, regional hydrology, shared local terrain rules and authored settlement layouts.
- Hollowmere's local area is resolved by `AuthoredSettlementTerrainProvider` using `data/settlements/hollowmere/terrain.gd`; it is not a separate terrain algorithm.
- Hollowmere's exterior is composed by the same `WorldSettlementPresenter` used by the production opening campaign.
- `Campaign2SettlementBuilder` still owns chunk orchestration for other settlement layouts such as Millbrook. Its JSON settlement-layout input is a separate authored path that should eventually converge with the domain-file settlement contract.

### Strategic geography

- `campaign2_geography.json` owns strategic dimensions, local/global transform inputs, region/faction bands, river path and macro-map markers.
- `MainCampaignWorldMapData` is the adapter used by the UI and world provider.
- The strategic map is an index and overview, not a competing source of playable local terrain.

## Authority and duplication map

| Concern | Current authority | Status |
|---|---|---|
| Strategic grid, transform and macro river | `campaign2_geography.json` via `MainCampaignWorldMapData` | Single manifest; adapter used by UI and world provider |
| Regional hydrology | `data/world/regions/silverhart_heartland/hydrology.gd` | Region-owned stream rule and tests |
| Heartland woodland ecology | `data/world/regions/silverhart_heartland/biomes.gd` | Region-owned species/eligibility rules receive local exclusions as context |
| Shared local terrain refinement/elevation | `data/world/terrain/campaign2_local_terrain.gd` | Shared rules for non-settlement terrain |
| Authored settlement movement/terrain | `authored_settlement_terrain.json` + `Campaign2AuthoredSettlementTerrainRegistry` + `AuthoredSettlementTerrainProvider` | Definitions are loaded by stable ID and priority; no location-specific branches in the world terrain adapter |
| Hollowmere buildings/routes/bridge/agriculture/props | `data/settlements/hollowmere/*.gd` | Domain data and shared factories |
| Hollowmere exterior | `WorldSettlementPresenter` + `presentation.gd` | Same generic presenter in production and preview |
| Hollow Tankard static interior | `interiors/*.gd` + shared interior presenter/registrar | Geometry and logical layout extracted; live behaviour remains in controller |
| NPC identity and appearance | `data/characters/hollowmere_npcs.json` | Profile only; no duplicated world coordinates |
| Starting actors, creatures and quest anchors | `data/settlements/hollowmere/placements.gd` | Authored placement data; future companions deferred until their real recruitment regions exist |
| Logical explored cells | `Campaign2WorldCellLoader` + `Campaign2WorldTerrainData` | Replaces legacy streamer; retains existing/materialised state |
| 3D presentation streaming | Regional preview chunk renderer | Preview-only; production promotion still outstanding |

## Work completed in the current migration

- Removed `HexWorldChunkStreamer`; its independent seeded wilderness algorithm and destructive unload behaviour are no longer in production.
- Established the continuous-world architecture and authored-data ownership in ADR 0001.
- Made the strategic geography manifest authoritative for strategic dimensions, transforms, region bands, faction borders, river path and selected markers.
- Moved heartland hydrology and woodland rules into region-owned modules.
- Moved shared Campaign 2 local terrain refinement, elevation and geological rules into a shared world-terrain module.
- Split Hollowmere's authored buildings, routes, bridge, agriculture, props, placements, terrain and tavern interior into domain files.
- Replaced the Hollowmere-specific exterior presenter with `WorldSettlementPresenter`.
- Replaced the Hollow Tankard's static geometry and logical layout construction with shared presenters/registrars.
- Added the generic `AuthoredSettlementTerrainProvider` and migrated all callers to authored modules/provider queries; removed the obsolete compatibility facade.
- Added a validated authored-settlement terrain manifest/registry and removed Hollowmere-specific terrain preloads and branches from `Campaign2WorldTerrainData`.
- Routed both campaign and regional-preview Hollowmere terrain queries through the same authored terrain definition and provider.
- Preserved authored NPC/animal positions and deferred companions whose actual recruitment regions have not yet been built.

## Remaining architecture work

1. **Converge settlement definition formats.** Move the Millbrook/other `campaign2_settlement_layouts.json` path toward the same validated domain-data contract used by Hollowmere. Avoid a second settlement registry.
2. **Consolidate presentation streaming.** Audit the regional preview renderer and promote/generalise it for production only after seam, negative-coordinate, load-order, unload/reload and persistent-state tests pass. Do not reintroduce a second logical streamer.
3. **Complete source-world inventory.** Inspect the original Hex-crpg Campaign 2 content and record every region, settlement, building, route, landmark, encounter and interior with source IDs/provenance and port status.
4. **Move campaign start composition to scenario data.** Keep quest definitions, opening time, player spawn and starting party composition in campaign scenario/content services, not in generic settlement presentation.
5. **Fidelity and visual audit.** Compare Hollowmere's rendered exterior/interior against the authored source and confirm all original coordinates, feature counts, NPC placements and interaction behaviour.

## Required invariants

- One continuous logical world in a single canonical global coordinate frame.
- Regional geography owns cross-settlement terrain, elevation, hydrology and biomes.
- Settlement definitions own only authored local additions and explicit overrides.
- Shared providers interpret data; no generic system branches on settlement IDs.
- Stable IDs and deterministic generation independent of chunk load order.
- Authored buildings, roads, bridges, rivers, entrances, landmarks and quest anchors take precedence over procedural detail.
- Presentation unload never deletes logical cells, campaign state, resources, building state or save data.
- Character appearance/identity and world placement remain separate data domains.
- New settlements should be addable through validated data, not new location-specific construction scripts.

## Acceptance gates before promoting streaming

- Generic-provider parity tests cover stream boundaries, bridge exemption, buildings, doors, paths, farm bounds, forest exclusions and movement blocking.
- Campaign and regional preview return identical terrain/elevation for the same global coordinates.
- Adjacent chunks load in different orders without seams or changes to deterministic feature placement.
- Negative coordinates, settlement crossings and unload/reload preserve continuous terrain and logical state.
- Tavern floors, stairs, doors, occupancy, NPC positions, interactions and save/restore remain functional.
- Authored exterior and interior content matches the source inventory.
