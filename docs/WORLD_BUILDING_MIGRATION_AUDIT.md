# World construction and migration audit

**Audit date:** 2026-11-20  
**Working branch:** `feature/world-building-foundation`  
**Target branch:** `dev`

## Executive finding

The project does not currently have three equivalent systems independently generating the playable world. It has two distinct world-construction paths plus a strategic-map presentation:

1. **Production opening campaign:** `scenes/main.tscn` → `WorldRoot` → `WorldSimulation`, `HollowmereVillage` and `HollowTankard`. This is still a fixed, Hollowmere-specific composition.
2. **Campaign 2 regional development preview:** `scenes/prototypes/campaign2_regional_world_preview.tscn` → `Campaign2WorldTerrainData` → a 24×24 chunk renderer and `Campaign2SettlementBuilder`. It uses the same authored Hollowmere exterior as an exclusion/presentation scene and generates the surrounding world from the Campaign 2 geography and settlement manifests.
3. **Strategic map presentation:** `MainCampaignWorldMapData` reads the same Campaign 2 geography manifest and produces a 16×16 strategic overview. This is not a separate playable-world generator.

There was also a fourth-looking component: `HexWorldChunkStreamer`. It was not the regional preview's renderer. It was a logical-cell materialiser that populated `HexMapData` for movement and pathfinding using its own unrelated seeded terrain algorithm. It was still called by `WorldSimulation`; deleting it without replacing that responsibility broke three CI workflows. That responsibility is now being migrated to a data-backed cell loader using the Campaign 2 world terrain provider.

## Current production call paths

### Opening campaign

- `scenes/main.tscn` attaches `scripts/world/world_root.gd`.
- `WorldRoot` creates `WorldSimulation`, registers opening quests/social standings, instantiates `HollowmereVillage`, then instantiates `HollowTankard`.
- `HollowmereVillage` constructs its own ground, authored routes, village buildings, farmstead, agriculture, bridge, signs/quest props, forest and visible wildlife. Its authored definitions are split across `data/settlements/hollowmere/*.gd`, but its runtime assembly is still a location-specific script.
- `HollowTankard` separately constructs the tavern building/interior, upper floor, furniture, doors, map cells and starting NPC/party presentation. It also registers the Hollowmere logical map cells into `WorldSimulation.map_data`.
- The opening composition is therefore not yet driven by the regional world provider. It is a fixed location bootstrap with authored local content.

### Regional preview

- `scenes/prototypes/campaign2_regional_world_preview.tscn` attaches `campaign2_regional_world_preview.gd`.
- The preview instantiates `Campaign2WorldTerrainData`, which reads `campaign2_geography.json`, `campaign2_road_paths.json` and `campaign2_settlement_layouts.json`.
- It uses the shared 24-hex chunk size, builds terrain meshes and deterministic vegetation from global axial coordinates, and delegates settlement buildings/NPC actors to `Campaign2SettlementBuilder`.
- Hollowmere is currently excluded from the preview's procedural terrain by a radius rule and inserted by instantiating the same `HollowmereVillage` script used by the opening campaign.
- The settlement layout manifest currently contains Millbrook. Hollowmere is not yet represented through the generic settlement-builder contract.

### Strategic geography

- `MainCampaignWorldMapData` is a runtime adapter over `campaign2_geography.json`; it is not a second geography source.
- `Campaign2WorldTerrainData` uses that adapter for the local-to-strategic transform, strategic biome/faction grid and regional river path.
- The map UI had stale references to removed static constants (`WORLD_SIZE`, `RIVER_PATH`, `LOCATIONS`). These are being replaced with the adapter's current query methods.

## Authority and duplication map

| Concern | Current authority | Migration status |
|---|---|---|
| Strategic grid dimensions, origin and scale | `campaign2_geography.json` via `MainCampaignWorldMapData` | One manifest; adapter API now used by map UI |
| Regional terrain/elevation and hydrology | `Campaign2WorldTerrainData` + region/world rule modules | Foundation exists; needs logical/presentation parity tests |
| Regional roads and settlement layouts | `campaign2_road_paths.json`, `campaign2_settlement_layouts.json` | Millbrook is generic; Hollowmere not migrated |
| Hollowmere building/route/bridge/agriculture/prop definitions | `data/settlements/hollowmere/*.gd` | Data decomposed; still consumed by Hollowmere-specific presenter |
| Hollowmere logical occupancy/navigation | `HollowmereVillageData` + tavern registration | Still location-specific; must become settlement data/query providers |
| Hollowmere interiors and door/floor behaviour | `HollowTankard` and building registry | Still bespoke; preserve and migrate as reusable interior definitions |
| Hollowmere named NPC identities and starting positions | Tavern/campaign content and character data | Must remain authored; do not randomise or regenerate named identities |
| Presentation streaming | Regional preview's 24-hex chunk renderer | Preview only; not yet production campaign streaming |
| Logical exploration cells | Former `HexWorldChunkStreamer`; now `Campaign2WorldCellLoader` | First convergence slice: uses the same regional world data and preserves loaded state |

## First convergence slice

The removed legacy logical streamer generated grass/forest/outcrop/water with a second seed algorithm and unloaded cells by erasing `HexMapData.cells` and clearing the entire shared vertex-height cache. The replacement `Campaign2WorldCellLoader` now materialises logical cells from `Campaign2WorldTerrainData` using the same 24-hex global chunk indexing as the regional preview. It does not overwrite Hollowmere's authored radius or existing runtime-mutated cells, and it retains explored logical cells rather than deleting gameplay state on chunk movement.

This does **not** yet unify the presentation streamer. It removes the duplicate wilderness terrain authority and repairs the simulation dependency first.

## Hollowmere migration target

Keep the authored content under `data/settlements/hollowmere/`; remove the special runtime pathway, not the settlement's identity or its data.

The target settlement definition must preserve:
- all authored building IDs, footprints, dimensions, entrances and orientations;
- every authored path/road/river route, bridge and landmark;
- fields, crop rows, fences and quest dressing;
- interior definitions, floor/room layout, stairs, doors and traversal links;
- named NPC identities, authored genders/appearance data and starting world positions;
- animal placements and their simulation registrations;
- stable provenance IDs so source-to-3D parity can be tested.

The generic settlement composition system should accept these domain definitions and invoke shared factories. The world root should select a campaign start/location from campaign composition data, not contain a Hollowmere construction recipe. Campaign-specific quests and opening-event rules should live in campaign scenario data/services, not in a generic settlement renderer.

## Migration sequence

1. **Restore one logical terrain authority (this slice):** route simulation exploration-cell materialisation through `Campaign2WorldTerrainData`; retain authored and mutated cells; test negative chunk indexing, settlement footprints, paths and load-order determinism.
2. **Make Hollowmere a generic settlement input:** add validated definitions for its buildings, paths, bridge, agriculture, props, interiors and placements to the same settlement assembly contract. Preserve the existing GDScript domain files initially; data format conversion is not a prerequisite.
3. **Replace the Hollowmere presenter:** move ground/terrain, routes, buildings, agriculture, props, vegetation and creature placements into reusable feature factories invoked by the generic settlement composer. Keep the old presenter temporarily as a parity/reference harness, then remove it after scene-level equivalence tests.
4. **Generalise interiors:** extract the Hollow Tankard and other enterable buildings into reusable building/interior/floor/door definitions. Preserve upper floors, stairs, furniture, interactions and save/restore behaviour.
5. **Move campaign start composition to data:** define the opening location, player spawn, party/NPC placements, starting time and scenario hooks as campaign composition data. Keep narrative quest logic distinct from settlement presentation.
6. **Promote the regional renderer to production:** make the actual campaign and development preview use the same presentation streamer and world provider. Add party/observer-based streaming, cross-chunk features and persistent presentation reconstruction.
7. **Delete compatibility and special-case code:** remove `HollowmereVillage`, the `HollowmereVillageData` compatibility facade and redundant opening-world construction only after all content parity checks pass.

## Acceptance gates before deleting Hollowmere-specific runtime code

- A scene comparison confirms the authored exterior remains in the same global positions and retains all buildings, routes, fields, props, vegetation and animal placements.
- Tavern/interior tests confirm all floors, stairs, doors, furniture, room occupancy, NPC positions and interactions remain functional.
- Named NPC identity, authored gender/appearance and exact starting placements survive the new pipeline.
- The campaign save/restore integration test remains green.
- The production campaign and regional preview query the same world data for the same global coordinates.
- Loading chunks in different orders produces identical terrain, elevation, vegetation and settlement placements.
- Unloading presentation never erases logical cells, runtime state, resources, building state or save data.
