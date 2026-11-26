# Campaign 2 map gap audit — what is still missing

**Reference:** `ScottENOC/Hex-crpg` Campaign 2 source  
**Target:** `ScottENOC/Silverhart-Saga-3D`, `dev`  
**Scope:** Geography, terrain, routes, settlement/site footprints, buildings, entrances, interiors as spatial layouts, map-owned physical objects, and their rendering/traversability.

This document is deliberately a **map audit only**. It does not track whether an NPC has been authored, whether dialogue or a quest has been ported, whether an encounter behaves correctly, or whether a faction/simulation system is complete. Those belong in the campaign-content and mechanics records linked below.

## Related audits — do not duplicate their work

The following documents are the source of truth for the excluded work:

- [Campaign source-port status](CAMPAIGN_SOURCE_PORT_STATUS.md) — NPC identity/persistence, dialogue and quest port status, companion relationships and reactivity, schedules, banter and world agency.
- [Campaign 2 NPC and dialogue index](campaign2_npc_dialogue_index.md) — source display names, dialogue IDs and first-pass quest-ID inventory. This is an extraction index, not proof that each branch is migrated.
- [Chief Skarnub dialogue and trust port](skarnub_campaign_dialogue_port.md) — Skarn-tooth content, chief dialogue, favour choices and remaining campaign-runtime wiring.
- [Mechanics port register](MECHANICS_PORT_REGISTER.md) — shared mechanics and behavioural parity, including combat, movement, campaign simulation and other non-map systems.
- [Campaign 2 source inventory](campaign2_source_inventory.md) and [original 2D source audit](original_2d_campaign2_source_audit.md) — source-side inventories and extraction context.

**Boundary rule:** a map item may record the authored location/anchor for an NPC, creature, journal, quest object or encounter trigger. Its dialogue, quest effects, AI, spawning lifecycle and persistence are not map-audit items. If a map task depends on one of those systems, record only the spatial dependency here and link to the owning campaign audit.

## Audit rules

- Preserve meaningful authored geography, broad biome/terrain regions, navigable routes, settlement footprints, landmarks, building placement, entrances, floor layouts and gameplay-significant physical objects.
- Do not count random tree/rock placement, exact procedural road wiggles, or equivalent decorative substitutions as gaps when the same broad terrain or navigable route is represented.
- A macro-map marker, data record, or passing geometry test is not proof that a site is correctly rendered or traversable. Distinguish data present, rendered, connected, and playable spatially.
- Status labels: **Missing** = no target map implementation evidenced; **Partial** = some spatial layers exist but named map work remains; **Verify** = target code exists but source-to-target visual/traversal acceptance has not been established; **Adapted** = intentionally different 3D spatial implementation whose navigability and spatial intent still need acceptance.

## Executive finding

Silverhart Saga 3D has a substantial authored-map foundation: strategic geography, named location anchors, settlement/site footprints, many authored building layouts, and a growing set of source-derived interior floor maps. The remaining map work is not simply "add more terrain". It is concentrated in:

1. Kragmoor's exterior presentation and spatial identity.
2. Completing and visually accepting several major settlement/fort/site footprints.
3. A systematic exterior-to-interior entrance and return-point register.
4. Verifying that important roads, streams, bridges, gates, stairs and strategic-to-local links are connected and traversable.
5. Auditing source-authored physical objects for spatial coverage, while excluding replaceable decoration.

The current geometry counts are not a completion percentage. The existing inventory reports 4,732 unique JSON-backed exterior cells and 1,543 walkable interior cells, while excluding regional GDScript features and some site systems. The source runtime extractor reports 16,566 unique terrain cells, including 11,324 cells touched by named feature builders after deduplication. These figures have different scopes and must not be divided to claim a percentage.

## 1. Location-by-location map gaps

| Area | Status | Map work still required |
|---|---|---|
| **Kragmoor / Deepholds** | **Partial — highest priority** | Exterior presentation is visibly inadequate in the reviewed capture (near-featureless pale surface). Compare and improve the mountain/settlement silhouette, approach, entrance, major built footprint and relationship to surrounding terrain. Six floor maps and stair layouts exist, but verify the spatial footprint of the source's 1,959-cell builder rather than assuming generic floors represent the whole mountain kingdom. |
| **Silverhart** | **Partial** | Verify the full palace core and curtain wall/watchtowers, ring roads, merchant/noble street grids, embassies, Ironbond office, cathedral/plaza, commons/market, outlying and middle-ring houses, outer city wall, three-cell gate/watchtowers, Warrens shacks, Thieves' Guild and hidden-vault spatial layouts. Records exist for 40 buildings, 33 routes, 512 props and 38 authored NPC placements; those counts still need visual/traversal acceptance, not more inventory repetition. Several palace floor stacks are registered; remaining palace rooms/floors and other building interiors need a spatial completeness check. |
| **Sil'thandriel / Sylvan Court** | **Partial** | Three-level tree/canopy floor maps and traversal structures exist. Verify the complete tree-base/canopy/court spatial layout, platforms, trunk/branches, rope bridge, archive/healer platforms and transitions between levels. |
| **Skarnak's Hold** | **Partial** | Revalidate the relocated site: perimeter, gate, wall, warlord-hut clearing, seven surrounding huts, campfire, local anchor, approach road and strategic marker must agree at the new position. The move is on PR #397, not yet on `dev`; do not treat it as merged. |
| **Skarn-tooth Camp** | **Verify** | Source-authored chief's hut, five surrounding huts, campfire and road endpoint are represented. Complete in-engine visual/scale/material acceptance and verify the camp footprint against the terrain. |
| **Northwatch Fort** | **Verify** | Star fort, keep, gate, moat/waterway, siege engine, distant catapult, oil barrels, ladders and hearth are represented. Verify wall/gate geometry, water continuity, traversal and the fort's relationship to the road network. |
| **Ridgehold Fort** | **Verify** | Fort walls, keep, downstream waterway and hearth are represented. Verify wall perimeter, gate/approach geometry, terrain joins and separation from opposing Skarnak's Hold positions. |
| **Emberlode and Emberlode Mine** | **Partial** | Buildings, mine entrance/approaches, floor maps, stairs, ledger and ore-node anchors exist. Verify the settlement footprint and mine surface/underground spatial connections, including entrances and reciprocal stairs. |
| **Reddale** | **Partial** | Six building footprints/interior floor maps, roads and the eastern spider-ruin site exist. Verify town layout, building entrances, the ruin's rocky-outcrop placement and all floor-to-exterior connections. |
| **Hollowmere** | **Partial** | Authored village, stream, bridge, roads, building footprints and floor maps exist. Verify the source building extents/door approaches, guild-den location, stream continuity and usable bridge crossing. The Elder Locket and other object behaviours belong in campaign content; only their physical placement belongs here. |
| **Millbrook** | **Partial** | House, road spur and floor map exist. Verify source-aligned placement, door orientation, route connection and interior floor/entrance geometry. |
| **Old Mac's Farmstead** | **Partial** | Farmhouse, pasture, fence/broken-fence clue, evidence anchors and interior floor exist. Verify its source-relative position at the southern road endpoint, pasture/fence footprint, den approach and farmhouse entry/return geometry. Livestock appearance substitutions are not a map gap. |
| **Abandoned House and northern crypt/barrow chain** | **Partial** | Floor maps and spatial evidence anchors exist. Verify each entrance, corridor, room footprint, wall aperture, return point and connection between the abandoned house, Vessel-Seeker's Crypt and Corvin Ashgrave's Barrow. |
| **Lich Chapterhouse** | **Partial** | Single-floor stone footprint, entrance and fireplace placement exist. Verify approach, entrance orientation, interior footprint and transition back to the exterior. |
| **Thieves' Cove** | **Partial** | Three-level cave network, entrances, reciprocal stairs and evidence-object anchors exist. Verify cave entrance positions, tunnel junction connectivity, floor topology and return routes. |
| **Vampire Grave** | **Verify** | Disturbed grave, carcass, fang and journal positions are represented. Verify the physical site layout and approach; investigation and encounter logic are tracked elsewhere. |
| **Old Mac's Wolf Den** | **Verify** | Source-derived anchor and cave-mouth/overhang/bone dressing exist. Verify the den entrance/approach spatially; wolf spawning and quest behaviour are out of scope here. |
| **Unicorn Vale** | **Verify** | Vale centre, eight patrol waypoints and hoofprint markers are represented. Verify the valley footprint, waypoint geometry and route accessibility; live unicorn AI is out of scope. |
| **Ashveil's Dragon Lair** | **Verify** | Rocky outcrop and cave-den dressing exist. Verify the outcrop/cave spatial shape and approach; dragon actor and encounter behaviour are out of scope. |
| **Emberwood Grove** | **Verify** | Clearing, foliage perimeter, spring rim and herb-patch visuals exist. Verify the clearing boundary, spring placement and connections to surrounding terrain; gathering and quest consequences are out of scope. |
| **Player cottage / field** | **Partial** | Plot marker/approach, field and fence geometry exist. Verify plot access, field/fence footprint, cottage placement and spatial room for future crop rows, livestock and upgrades. Construction/farming mechanics are tracked elsewhere. |

## 2. Cross-cutting map gaps

1. **Kragmoor exterior and settlement presentation.** Resolve the near-blank capture. Compare source landmarks, entrance, approach, mountain silhouette, scale and surrounding terrain. A correct floor-map data structure is not a visually complete mountain kingdom.
2. **Exterior/interior spatial transitions.** Build one register for every authored building/site: exterior entrance hex, destination floor ID, interior door cell, return hex, floor elevation, stairs/ladders, and any spatial gate/door aperture. This audit owns the geometry and coordinate contract; campaign code owns whether a door is locked or an interaction is permitted.
3. **Source physical-object placement.** The source runtime baseline records 246 physical tile-object placements. The target JSON inventory reports 520 prop records across 508 anchors, but this does not prove semantic coverage. Cross-reference map-owned objects such as journals, ledgers, evidence, altars, ore, stairs, doors, ladders, siege equipment and signs. Ignore replaceable decoration. Their interaction effects belong in campaign content.
4. **Agricultural footprint coverage.** The source `buildFarmstead` defines a pasture polygon and six fence runs, but no crop rows; the target `old_mac_farmstead` carries the pasture, all six fence runs, and the broken-fence/blood-trail spatial props. The player-owned field is a separate construction feature where the source supports fencing and planted apple trees, not pre-authored crop rows. Therefore, zero crop rows in the target is **not** a source-port gap and should not be treated as missing content. Remaining work is visual/traversal acceptance of the pasture, fence opening, farmhouse spur and player-field boundary.
5. **Road and water connectivity.** Verify connected travel between meaningful destinations, road continuity, bridges/fords, stream barriers and waterway joins. Road-following NPCs/caravans and their schedules are covered by the campaign audit.
6. **Strategic-to-local coordinate agreement.** Every strategic destination must resolve to the correct local site. For Skarnak's Hold specifically, strategic marker, local anchor, approach road and travel destination must agree after relocation.
7. **Chunk boundaries and ownership.** Authored features that span streamed chunks must join without visible seams or duplicated/missing wall, fence, road, stream or prop segments. Decorative infill can remain procedural where the source does not prescribe exact placement.

## 3. Source-builder cross-check — map responsibilities only

This is a checklist of source spatial builders, not a requirement to reproduce the old renderer or every incidental tile.

| Source builder / family | Target map evidence | Map gap status |
|---|---|---|
| `setupVillageScene`, `paintRoad`, `paintPath`, `paintStreamSegment` | Hollowmere data, strategic/local road data, regional hydrology and terrain streams | **Verify** route connectivity, bridge/water traversal and named approaches |
| `buildFarmstead` | Farmhouse, pasture/fences, evidence anchors and farmhouse floor | **Partial** source-relative location, pasture footprint and den approach |
| `buildGoblinCamp` | Skarn-tooth structures and camp terrain | **Verify** visual/scale/terrain acceptance |
| `buildOrcStronghold` | Skarnak's Hold huts, clearing, wall/gate and approach | **Partial** relocated-site geometry and strategic/local coordinate agreement |
| `buildDwarvenKingdom` / `revealSunkenDeepPassage` | Kragmoor floor registry, gated floor topology and mountain-site anchor | **Partial** exterior footprint, mountain/entrance presentation and full spatial relationship |
| `buildElvenCapital` | Sil'thandriel multi-level location registry and terrain | **Partial** tree/canopy/court geometry and inter-level traversal |
| `buildLichChapterhouse` | Chapterhouse floor map | **Verify** footprint, entrance and exterior connection |
| `buildSideQuestContent` | Named physical quest-site anchors and spatial dressing | **Verify** each site footprint/approach; content logic excluded |
| `buildPlayerCottagePlot`, `buildPlayerCottage`, `upgradePlayerCottage` | Plot marker/approach and dwelling spatial foundations | **Partial** plot/cottage placement and room for spatial upgrades |
| `buyPlayerField`, `placeFieldFence`, `buyFieldLamb`, `plantAppleTree` | Field/fence geometry and farmstead spatial anchors | **Partial / Verify** field and crop-row spatial layout only |
| `buildAbandonedHouse`, `buildNecromancerCrypt`, `buildLichBarrow` | House, crypt and barrow floor maps | **Verify** entrances, rooms, corridors and connected floor topology |
| `buildMillbrook`, `buildEmberlode`, `buildReddale` | Settlement buildings, roads and interior floor layouts | **Partial** full spatial/entrance acceptance |
| `buildDragonLair`, `buildVampireGrave`, `buildDruidGrove`, `spawnWildUnicorn` | Lair, grave, grove and vale spatial sites | **Verify** footprint, approach and map-owned physical markers |
| `buildSilverhartPalace`, `fortifySilverhartManor` | City/settlement records and selected palace floor stacks | **Partial** remaining city districts, walls/gates and interior spatial layouts |
| `buildThievesCoveCaves`, `searchSecretPassage`, `revealSingleTunnelEntrance`, `revealTunnelEntrances`, `openTunnelJunction` | Cave network, entrances, floors and tunnel-junction markers | **Partial** complete tunnel topology, entrances and floor connectivity |
| `buildNorthwatchFort`, `buildRidgeholdFort` | Fort geometry, keeps, waterway and physical siege props | **Verify** perimeter, gate, wall, water and approach connectivity |
| `buildHollowmereGuildDen` | Guild Den floor map | **Verify** room footprint and entrance/return geometry |

## 4. Inventory counts and cautions

- Source runtime scene: 16,566 unique terrain cells; 11,324 cells touched by named feature builders after deduplication; 246 physical tile-object placements; 72 interior regions; 9 multi-storey building definitions; 8 unicorn patrol waypoints.
- Target JSON-backed exterior inventory: 4,732 unique cells, plus regional GDScript features not included in that number; 1,543 walkable cells across registered floor maps in the existing geometry audit.
- Target multi-story location registry contains 71 location records (after the tunnel-network additions merged in PR #408) (many are single-floor), while the source runtime inventory reports 72 interior regions. These are not directly equivalent: some source interiors are represented by settlement-layout metadata and some target records are 3D adaptations. Registration does not prove runtime entry/exit.
- Target settlement-layout registry contains seven definitions on `dev`: Millbrook, Emberlode, Reddale, Old Mac's Farmstead, Silverhart, Skarn-tooth Camp and Skarnak's Hold. Hollowmere uses its separate location presenter; Kragmoor and Emberlode Mine use the multi-story registry.
- No overall completion percentage should be published until every meaningful source spatial feature has a row in a source-to-target register with a clear matching rule.

## 5. Definition of done

A map gap is closed only when:

1. The source spatial feature and its gameplay purpose are identified.
2. The target data/presenter and stable location/feature ID are recorded.
3. The 3D spatial adaptation is documented where it differs from the source.
4. Its footprint, entrances, route connectivity and chunk joins pass relevant tests.
5. Important locations have an in-engine visual/traversal acceptance.

NPC dialogue, quest branches, encounter AI, faction effects, schedules, resource depletion/growth and campaign persistence must be closed in their owning campaign/mechanics audits, not by marking a map row complete.

## 6. Verification pass — 2026-11-26

This pass rechecked the map-only boundary against the current source and target branches, rather than treating the previous audit as immutable.

**Pinned comparison points**

- Source: `ScottENOC/Hex-crpg` `main`, commit `4de96f16889d43cae91e03832c8eb1c1b4b00e42`.
- Target: `ScottENOC/Silverhart-Saga-3D` `dev`, commit `5568921924be1b4b42d071a3d64624214f24cff2`.
- The target commit since the prior audit checkpoint (`4b5024b65aafadb9fe5579ab0b501fb0d61aafdd`) changes encounter/combat runtime and related tests/docs; it does not change map data, geography, settlement layouts, terrain, hydrology or map presentation. The map audit's implementation observations therefore remain applicable to this target head, but this is not a fresh Godot visual or traversal test.

**Manifest cross-check**

The current target data contains:

- 25 named global geography anchors and 22 strategic connections in `campaign2_geography.json`.
- Seven definitions in `campaign2_settlement_layouts.json`: Millbrook, Emberlode, Reddale, Old Mac's Farmstead, Silverhart, Skarn-tooth Camp and Skarnak's Hold.
- 71 registered location records in `campaign2_multistory_locations.json` (including the two tunnel stubs added in PR #408).
- A source-road reference trace in `campaign2_road_paths.json`, pinned to the same source commit above.

These are registration counts, not completion counts. Hollowmere is handled through its own settlement/location implementation rather than being an eighth entry in the seven-record settlement-layout JSON. The broader canonical settlement registry may include it separately. The 70 multi-story location records are not directly comparable with the source extractor's 72 interior regions: registration, room geometry, runtime transitions and successful traversal are different levels of evidence.

**All source spatial builders reconciled**

The current `campaign2World.js` source exposes 86 named functions. The spatial builders and map-mutating reveal helpers relevant to this audit are accounted for below. Helper functions such as `carveBuilding`, `carveFlatRoom`, `carveFloorRoom`, `carvePolygonRoom`, `carveStarFort`, `carveHexKeep`, `paintFloorCorridor`, `openWallGap` and `expandMultiStoryBuildingBounds` are implementation primitives; they are assessed through their calling location builders, not counted as extra locations.

| Source spatial function(s) | Owning target evidence / audit row | Remaining map-only check |
|---|---|---|
| `setupVillageScene` | Hollowmere settlement data, location presenter, road paths, regional hydrology and starting-village floor maps | Confirm source-relative building/door approaches, stream/bridge crossing and continuous roads in the playable streamed world |
| `buildHollowmereGuildDen` | Guild Den multi-story location record and interior presenter | Confirm exterior entrance, return point and floor traversal |
| `buildFarmstead`, `placeFieldFence` | Old Mac's Farmstead settlement layout, agricultural feature factory, farmstead terrain/props | Confirm pasture and broken-fence footprint, farmhouse approach and den approach; crop rows are not source-authored |
| `buildPlayerCottagePlot`, `buildPlayerCottage` | Player plot anchor/approach, field/fence geometry and dwelling presentation | Confirm plot access, cottage footprint/entrance and room for future spatial upgrades |
| `buildGoblinCamp` | Skarn-tooth Camp settlement layout and regional terrain | Visual/scale/terrain acceptance of the complete camp footprint |
| `buildOrcStronghold` | Skarnak's Hold settlement layout and regional terrain | Verify the currently authored position on `dev`; the relocation described in the Skarnak row is still on its separate PR branch and must not be represented as merged |
| `buildNorthwatchFort`, `buildRidgeholdFort` | Fort terrain, wall/bridge feature factories, fort presentation and physical siege-prop records | Verify perimeter, gate, approach, waterway and chunk joins in-engine |
| `buildDwarvenKingdom`, `revealSunkenDeepPassage` | Kragmoor massif/gate terrain, six-floor location registry and gated stair topology | Complete the exterior mountain/entrance silhouette and verify the full surface-to-floor spatial chain |
| `buildElvenCapital` | Sil'thandriel three-level location and canopy presentation | Verify tree/canopy/court footprint, platforms, rope bridge and inter-level routes |
| `buildLichChapterhouse` | Chapterhouse floor map and fireplace/entrance presentation | Verify site approach and exterior/floor transition |
| `buildSideQuestContent` | Named site anchors and physical map-object records | Reconcile each spatial object/site against the source; quest effects and interaction outcomes remain campaign-owned |
| `buildAbandonedHouse`, `buildNecromancerCrypt`, `buildLichBarrow` | Abandoned House, Vessel-Seeker's Crypt and Corvin Ashgrave's Barrow floor maps | Verify entrance apertures, corridor joins, room topology and reciprocal return paths |
| `buildMillbrook`, `buildEmberlode`, `buildReddale` | Settlement layouts, building records and their registered interiors | Verify source-relative building footprints, doors, local road connections and floor transitions |
| `buildDragonLair`, `revealDragonLairArea` | Ashveil's Lair anchor and rocky-outcrop/cave-den terrain presentation | Verify outcrop, den mouth and approach; dragon actor/encounter is out of scope |
| `buildSilverhartPalace` | Silverhart settlement/city records and registered palace/building floor stacks | Complete and verify remaining city districts, walls/gates, building interiors and city traversal |
| `buildThievesCoveCaves`, `revealSingleTunnelEntrance`, `revealTunnelEntrances`, `openTunnelJunction` | Thieves' Cove multi-level cave records, cave entrances and tunnel-junction features | Verify all entrances, junction apertures, reciprocal stairs and connected floor topology |
| `buildVampireGrave` | Vampire Grave site presentation and physical object anchors | Verify site footprint and approach; investigation/encounter behaviour is out of scope |
| `buildDruidGrove` | Emberwood Grove clearing, spring, foliage and herb-patch terrain | Verify clearing boundary, spring and paths into surrounding terrain |
| `spawnWildUnicorn` | Unicorn Vale anchor and eight source-derived patrol waypoints | Verify waypoint geometry and route accessibility only; spawning and AI are out of scope |

The source functions `buildGoblinNPC`, `buildOrcNPC`, `addWallRingDefender` and `spawnIronbondArcCombatants` create or configure actors, not map geometry. Dialogue readers and quest handlers likewise remain outside this audit. Their actor placement anchors may be referenced here only where they affect spatial coverage.

**Anchor coverage check**

The 25 geography IDs have a corresponding location/site row in section 1: Hollowmere, Millbrook, Silverhart, Emberlode, Reddale, Old Mac's Farmstead, Skarn-tooth Camp, Northwatch Fort, Ridgehold Fort, Skarnak's Hold, Kragmoor, Sil'thandriel, Hollowmere Guild Den, Abandoned House, Vessel-Seeker's Crypt, Corvin Ashgrave's Barrow, Ashveil's Dragon Lair, Lich Chapterhouse, Emberwood Grove, Vampire Grave, Thieves' Cove, Emberlode Mine, Old Mac's Wolf Den, Unicorn Vale and Mirabel's Spider Ruin. Mirabel's Spider Ruin is covered in the Reddale row because it is an outlying Reddale site, not a separate settlement. This confirms anchor-list coverage only; it does not certify the site implementations as complete.

## 7. Revised priority order

1. **Kragmoor exterior** — the strongest known visual deficiency and the largest mismatch between an implemented floor system and an inadequately presented surface site.
2. **Entrance/return-point register** — produce a single spatial contract for every building, cave, mine and multi-floor site before wiring more interactions.
3. **Silverhart spatial completion** — reconcile the large city footprint, districts, wall/gates, remaining building interiors and actual traversable routes.
4. **Route and hydrology acceptance** — prove road, stream, bridge, moat and fort-waterway connectivity in the streamed 3D world, including chunk boundaries.
5. **Remaining site visual/traversal acceptance** — Skarn-tooth, Skarnak's Hold, Northwatch, Ridgehold, Sil'thandriel, Emberlode Mine, Reddale, crypt/barrow chain, Thieves' Cove and wilderness sites.
6. **Physical map-object reconciliation** — compare source tile-object placements to target map-owned anchors and presentation; retain meaningful doors, stairs, ladders, journals, ledgers, evidence, ore, altars, siege objects and signs, but allow decorative substitutions.

No source-builder or anchor inventory should be marked complete solely because a target JSON record exists. The definition-of-done gates in section 5 still apply.



## 8. Small-to-large execution approach

Work is ordered by the smallest independently verifiable spatial gap first. A task is only ticked off when its stated evidence exists; an in-engine visual check is explicitly marked as requiring user acceptance.

| Order | Task | Size | Verification owner | Status | Completion gate |
|---|---|---|---|---|---|
| 1 | Remove false-positive crop-row gap; confirm source has no authored crop rows | XS | ChatGPT | **Complete** | Source builder and target data agree; audit corrected |
| 2 | Verify Old Mac pasture/fence/road-spur geometry against source | XS | ChatGPT | **Complete** | Automated coordinate/feature test passes on `dev`; Godot suite passed |
| 3 | Verify Unicorn Vale's eight patrol waypoints are all on usable terrain and connected by a route | S | ChatGPT | **Complete** | Full Godot validation passes with waypoint and patrol-leg route checks |
| 4 | Verify named wilderness-site anchors and natural/explicit approaches (grave, grove, lair, den) | S | ChatGPT | **Complete** | `tests/test_campaign2_regional_features.gd` checks the Vampire Grave, Old Mac's Wolf Den and Druid trial-den anchors are non-void/walkable, and checks continuous non-void/walkable natural approaches to Emberwood Grove and Ashveil's Dragon Lair. Full Godot validation passed on PR #408 head (115/115 steps); no roads invented for off-road sites |
| 5 | Create exterior/interior entrance and return-point register for existing floor maps | M | ChatGPT | Every registered interior has exterior entrance, interior door, return anchor and reciprocal stair data or an explicit documented exception |
| 6 | Add missing map tests for road, stream, bridge, gate and chunk-boundary joins | M | ChatGPT | Targeted Godot tests pass |
| 7 | Complete site-by-site visual/traversal acceptance | M–L | User + ChatGPT | User reviews only the resulting captures/build; ChatGPT records outcomes and fixes defects |
| 8 | Complete Silverhart city spatial reconciliation | L | ChatGPT, then user visual acceptance | Source districts/buildings/walls/routes reconciled, automated tests pass, visual review accepted |
| 9 | Rebuild and validate Kragmoor exterior presentation | L | ChatGPT, then user visual acceptance | Source landmark/entrance footprint implemented, tests pass, user accepts the resulting map view |

The XS/S items are deliberately bounded so several can be completed without requiring the user to open Godot. Larger visual tasks are deferred until their data and automated checks are ready. This is a work order, not a claim that the listed tasks are already complete.
