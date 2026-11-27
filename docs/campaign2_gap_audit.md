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
- Status labels describe missing spatial content only: **Missing**, **Partial**, **Ported**, or **Adapted**. Engine verification and visual QA are universal quality gates, not map-port backlog items.

## Executive finding

The 3D project has ported a substantial amount of the distinctive Campaign 2 world: its strategic geography, settlement footprints, named sites, fortifications, major routes and waterways, many source-authored interiors, and multi-level cave/dungeon structures.

The previous 4,732 / 16,566 comparison is **not a completion ratio**. The numerator counts a limited target-side JSON exterior-cell inventory; the denominator counts all source runtime terrain cells, including the broad base terrain pass. The target count also omits regional GDScript features. Dividing them produces a misleading 25%-style figure and must stop.

The revised unit of work is a meaningful spatial feature, not a terrain cell. Generic ground fill, terrain noise and decorative vegetation/rock distribution are systems. They are not thousands of unported source objects.

The actual remaining map-content work is concentrated in:
1. Kragmoor's distinctive surface mountain/settlement footprint, approach and entrance.
2. Exterior/interior entrance and return contracts for existing floor maps.
3. The remaining source-named Silverhart palace rooms/floors.
4. Reusable spatial prefabs for dynamic cottage/field construction where source features are not represented.
5. Semantic reconciliation of meaningful physical map objects (doors, stairs, journals, evidence, ore, siege objects and signs).

See [the feature-level port register](campaign2_feature_port_register.md) for the source-builder-by-source-builder reconciliation. Visual inspection, Godot execution and routine verification are not counted as outstanding map content.

## 1. Location-by-location map gaps

| Area | Status | Map work still required |
|---|---|---|
| **Kragmoor / Deepholds** | **Partial — highest priority** | Exterior presentation is visibly inadequate in the reviewed capture (near-featureless pale surface). Compare and improve the mountain/settlement silhouette, approach, entrance, major built footprint and relationship to surrounding terrain. Six floor maps and stair layouts exist, but verify the spatial footprint of the source's 1,959-cell builder rather than assuming generic floors represent the whole mountain kingdom. |
| **Silverhart** | **Partial** | Verify the full palace core and curtain wall/watchtowers, ring roads, merchant/noble street grids, embassies, Ironbond office, cathedral/plaza, commons/market, outlying and middle-ring houses, outer city wall, three-cell gate/watchtowers, Warrens shacks, Thieves' Guild and hidden-vault spatial layouts. Records exist for 40 buildings, 33 routes, 512 props and 38 authored NPC placements; those counts still need visual/traversal acceptance, not more inventory repetition. Several palace floor stacks are registered; remaining palace rooms/floors and other building interiors need a spatial completeness check. |
| **Sil'thandriel / Sylvan Court** | **Partial** | Three-level tree/canopy floor maps and traversal structures exist. Verify the complete tree-base/canopy/court spatial layout, platforms, trunk/branches, rope bridge, archive/healer platforms and transitions between levels. |
| **Skarnak's Hold** | **Ported** | Warlord hut, seven surrounding huts, campfire, perimeter/gate terrain and road approach are represented at the source-derived anchor. No separate authored-geometry backlog is currently identified. |
| **Skarn-tooth Camp** | **Ported** | Source-authored chief's hut, five surrounding huts, campfire and road endpoint are represented. Complete in-engine visual/scale/material acceptance and verify the camp footprint against the terrain. |
| **Northwatch Fort** | **Ported** | Star fort, keep, gate, moat/waterway, siege engine, distant catapult, oil barrels, ladders and hearth are represented. Verify wall/gate geometry, water continuity, traversal and the fort's relationship to the road network. |
| **Ridgehold Fort** | **Ported** | Fort walls, keep, downstream waterway and hearth are represented. Verify wall perimeter, gate/approach geometry, terrain joins and separation from opposing Skarnak's Hold positions. |
| **Emberlode and Emberlode Mine** | **Partial** | Buildings, mine entrance/approaches, floor maps, stairs, ledger and ore-node anchors exist. Verify the settlement footprint and mine surface/underground spatial connections, including entrances and reciprocal stairs. |
| **Reddale** | **Partial** | Six building footprints/interior floor maps, roads and the eastern spider-ruin site exist. Verify town layout, building entrances, the ruin's rocky-outcrop placement and all floor-to-exterior connections. |
| **Hollowmere** | **Partial** | Authored village, stream, bridge, roads, building footprints and floor maps exist. Verify the source building extents/door approaches, guild-den location, stream continuity and usable bridge crossing. The Elder Locket and other object behaviours belong in campaign content; only their physical placement belongs here. |
| **Millbrook** | **Partial** | House, road spur and floor map exist. Verify source-aligned placement, door orientation, route connection and interior floor/entrance geometry. |
| **Old Mac's Farmstead** | **Partial** | Farmhouse, pasture, fence/broken-fence clue, evidence anchors and interior floor exist. Verify its source-relative position at the southern road endpoint, pasture/fence footprint, den approach and farmhouse entry/return geometry. Livestock appearance substitutions are not a map gap. |
| **Abandoned House and northern crypt/barrow chain** | **Partial** | Floor maps and spatial evidence anchors exist. Verify each entrance, corridor, room footprint, wall aperture, return point and connection between the abandoned house, Vessel-Seeker's Crypt and Corvin Ashgrave's Barrow. |
| **Lich Chapterhouse** | **Partial** | Single-floor stone footprint, entrance and fireplace placement exist. Verify approach, entrance orientation, interior footprint and transition back to the exterior. |
| **Thieves' Cove** | **Partial** | Three-level cave network, entrances, reciprocal stairs and evidence-object anchors exist. Verify cave entrance positions, tunnel junction connectivity, floor topology and return routes. |
| **Vampire Grave** | **Ported** | Disturbed grave, carcass, fang and journal positions are represented. Verify the physical site layout and approach; investigation and encounter logic are tracked elsewhere. |
| **Old Mac's Wolf Den** | **Ported** | Source-derived anchor and cave-mouth/overhang/bone dressing exist. Verify the den entrance/approach spatially; wolf spawning and quest behaviour are out of scope here. |
| **Unicorn Vale** | **Ported** | Vale centre, eight patrol waypoints and hoofprint markers are represented. Verify the valley footprint, waypoint geometry and route accessibility; live unicorn AI is out of scope. |
| **Ashveil's Dragon Lair** | **Ported** | Rocky outcrop and cave-den dressing exist. Verify the outcrop/cave spatial shape and approach; dragon actor and encounter behaviour are out of scope. |
| **Emberwood Grove** | **Ported** | Clearing, foliage perimeter, spring rim and herb-patch visuals exist. Verify the clearing boundary, spring placement and connections to surrounding terrain; gathering and quest consequences are out of scope. |
| **Player cottage / field** | **Partial** | Plot marker/approach, field and fence geometry exist. Verify plot access, field/fence footprint, cottage placement and spatial room for future crop rows, livestock and upgrades. Construction/farming mechanics are tracked elsewhere. |

## 2. Cross-cutting map gaps

1. **Kragmoor exterior and settlement presentation.** Resolve the near-blank capture. Compare source landmarks, entrance, approach, mountain silhouette, scale and surrounding terrain. A correct floor-map data structure is not a visually complete mountain kingdom.
2. **Exterior/interior spatial transitions.** Build one register for every authored building/site: exterior entrance hex, destination floor ID, interior door cell, return hex, floor elevation, stairs/ladders, and any spatial gate/door aperture. This audit owns the geometry and coordinate contract; campaign code owns whether a door is locked or an interaction is permitted.
3. **Source physical-object placement.** The source runtime baseline records 246 physical tile-object placements. The target JSON inventory reports 520 prop records across 508 anchors, but this does not prove semantic coverage. Cross-reference map-owned objects such as journals, ledgers, evidence, altars, ore, stairs, doors, ladders, siege equipment and signs. Ignore replaceable decoration. Their interaction effects belong in campaign content.
4. **Agricultural footprint coverage.** The source `buildFarmstead` defines a pasture polygon and six fence runs, but no crop rows; the target `old_mac_farmstead` carries the pasture, all six fence runs, and the broken-fence/blood-trail spatial props. The player-owned field is a separate construction feature where the source supports fencing and planted apple trees, not pre-authored crop rows. Therefore, zero crop rows in the target is **not** a source-port gap and should not be treated as missing content. Remaining work is visual/traversal acceptance of the pasture, fence opening, farmhouse spur and player-field boundary.
5. **Road and water connectivity.** Verify connected travel between meaningful destinations, road continuity, bridges/fords, stream barriers and waterway joins. Road-following NPCs/caravans and their schedules are covered by the campaign audit.
6. **Strategic-to-local coordinate agreement.** Every strategic destination must resolve to the correct local site. For Skarnak's Hold specifically, strategic marker, local anchor, approach road and travel destination must agree after relocation.
7. **Chunk boundaries and ownership.** Authored features that span streamed chunks must join without visible seams or duplicated/missing wall, fence, road, stream or prop segments. Decorative infill can remain procedural where the source does not prescribe exact placement.

## 3. Source-builder cross-check — feature-level register

The source runtime extractor resolves the original builders and their terrain writes, but a builder's cell count is not a list of tasks. The source-to-target feature mapping and actual remaining work are recorded in [Campaign 2 feature-level map port register](campaign2_feature_port_register.md).

That register treats `setupVillageScene` as a base-terrain system; groups roads and water by meaningful route; and tracks settlements, forts, capitals, interiors, caves, landmarks, construction features and physical map objects as named spatial features. It explicitly excludes random decoration and generic terrain fill from the backlog.



## 4. Inventory counts and cautions

The existing source/target counts are diagnostic only:

- Source runtime: 16,566 unique terrain cells, of which 5,242 are touched only by the broad `setupVillageScene` base pass; named feature-builder footprints overlap.
- Target JSON-backed exterior inventory: 4,732 unique cells, excluding regional GDScript features and other map-owned systems.
- Target interior registry: 71 location records / 89 floors; source runtime reports 72 interior regions. These are different data models and not directly comparable.
- Source physical tile objects: 246 placements. Target JSON reports 520 prop records across 508 anchors, plus floor-local and feature-specific objects. Raw counts do not establish semantic parity.

**Do not divide 4,732 by 16,566 or publish the result as map completion.** The counts have different scope and represent different things. The feature-level register is the backlog source of truth; no overall percentage is published until all meaningful source spatial features have explicit matching rules.

## 5. Definition of done

A source spatial feature is considered ported when:
1. Its source purpose and meaningful footprint are identified.
2. The target has an equivalent spatial feature or a documented 3D adaptation.
3. Its map-owned physical components (where applicable) are represented.
4. Any known missing entrance, return point, stair, route or named connection is recorded as a concrete task.

Godot execution, visual inspection and routine validation remain important QA for every change, but they are not separate outstanding map-port tasks. NPC dialogue, quest branches, encounter AI, faction effects, schedules and campaign persistence remain in their owning campaign/mechanics audits.

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

1. **Kragmoor surface geography** — finish the actual exterior mountain/settlement silhouette, source landmarks, approach and entrance.
2. **Exterior/interior spatial contracts** — close the finite set of missing entrance, destination-floor and return-anchor definitions for existing locations.
3. **Silverhart interior remainder** — reconcile source-named palace rooms/floors against the existing 40-building, 33-route city implementation.
4. **Dynamic cottage/field spatial prefabs** — add only missing buildable structures and player-placed field-object variants.
5. **Meaningful physical-object crosswalk** — reconcile source doors, stairs, ladders, journals, ledgers, evidence, altars, ore, siege objects and signs.

A concrete missing road, stream, bridge, gate or chunk-join feature can be added when identified. Generic "verify connectivity", "inspect in engine" and procedural decoration are not backlog items.

## 8. Small-to-large execution approach

| Order | Task | Size | Why it is actual map work |
|---|---|---|---|
| 1 | Complete Kragmoor surface footprint, named landmarks, approach and entrance | L | Six underground floors exist; the distinctive surface kingdom footprint is still incomplete. |
| 2 | Finish missing entrance/return contracts for existing single-floor locations | M | The spatial coordinate contract is missing for a finite set of existing interiors; this does not require inventing new rooms. |
| 3 | Reconcile remaining Silverhart palace rooms/floors | M–L | The city footprint is substantially present; the remaining work is specific interior content, not rebuilding the city grid. |
| 4 | Add missing cottage/field construction prefabs | M | Only source-authored dynamic spatial variants not already represented are in scope. |
| 5 | Reconcile meaningful physical map objects | M | Compare semantic object types and placements, not raw prop counts or decorative clutter. |

Routine Godot verification and visual QA are not listed as tasks here. They apply to every implementation and do not change the amount of source content ported.



Work is ordered by the smallest independently verifiable spatial gap first. A task is only ticked off when its stated evidence exists; an in-engine visual check is explicitly marked as requiring user acceptance.

| Order | Task | Size | Verification owner | Status | Completion gate |
|---|---|---|---|---|---|
| 1 | Remove false-positive crop-row gap; confirm source has no authored crop rows | XS | ChatGPT | **Complete** | Source builder and target data agree; audit corrected |
| 2 | Verify Old Mac pasture/fence/road-spur geometry against source | XS | ChatGPT | **Complete** | Automated coordinate/feature test passes on `dev`; Godot suite passed |
| 3 | Verify Unicorn Vale's eight patrol waypoints are all on usable terrain and connected by a route | S | ChatGPT | **Complete** | Full Godot validation passes with waypoint and patrol-leg route checks |
| 4 | Verify named wilderness-site anchors and natural/explicit approaches (grave, grove, lair, den) | S | ChatGPT | **Complete** | `tests/test_campaign2_regional_features.gd` checks the Vampire Grave, Old Mac's Wolf Den and Druid trial-den anchors are non-void/walkable, and checks continuous non-void/walkable natural approaches to Emberwood Grove and Ashveil's Dragon Lair. Full Godot validation passed on PR #408 head (115/115 steps); no roads invented for off-road sites |
| 5 | Create exterior/interior entrance and return-point register for existing floor maps | M | ChatGPT | **In progress** | Register covers all 71 location records / 89 floors and records all interior doors; 62 single-floor locations still need explicit exterior-threshold, destination, return-anchor and runtime entry/return contracts (or documented exceptions). The specialised Guild tunnel entry/return is implemented; ordinary building entry is not. |
| 6 | Add missing map tests for road, stream, bridge, gate and chunk-boundary joins | M | ChatGPT | **In progress** | Reciprocal stair tests (#415), wall chunk-boundary continuity (#416) and Hollowmere bridge traversability (#421) are merged. Road traversability and Skarn-tooth Camp occupancy correction are under validation in #419; regional-stream continuity and gate/road joins still need targeted coverage. |
| 7 | Complete site-by-site visual/traversal acceptance | M–L | User + ChatGPT | **Not started** | User reviews only the resulting captures/build; ChatGPT records outcomes and fixes defects |
| 8 | Complete Silverhart city spatial reconciliation | L | ChatGPT, then user visual acceptance | **Not started** | Source districts/buildings/walls/routes reconciled, automated tests pass, visual review accepted |
| 9 | Rebuild and validate Kragmoor exterior presentation | L | ChatGPT, then user visual acceptance | **Not started** | Source landmark/entrance footprint implemented, tests pass, user accepts the resulting map view |

The XS/S items are deliberately bounded so several can be completed without requiring the user to open Godot. Larger visual tasks are deferred until their data and automated checks are ready. This is a work order, not a claim that the listed tasks are already complete.
