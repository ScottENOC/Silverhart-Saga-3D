# Campaign 2 feature-level map port register

**Source:** `ScottENOC/Hex-crpg`, pinned Campaign 2 source commit `4de96f16889d43cae91e03832c8eb1c1b4b00e42`  
**Target:** `ScottENOC/Silverhart-Saga-3D`, `dev`  
**Purpose:** Track distinctive spatial content that exists in the source world and whether its equivalent exists in the 3D project. This is the canonical map-content backlog; it is not a terrain-cell coverage report.

## Counting rule

A unit of map-port work is a **meaningful spatial feature**: a settlement, building group, fortification, road connection, river, dungeon/cave network, named landmark, authored interior, or gameplay-significant physical object.

The following are implementation systems, not thousands of separate port tasks:

- Generic ground/biome fill and terrain noise.
- Procedural forest clumping, tree placement, grass, bushes and decorative rock scattering.
- Exact random road wiggles where the meaningful route and its connections are retained.
- Individual terrain cells written by a source builder when they are merely the raster representation of one larger feature.

A source builder's cell count is useful for understanding its footprint and complexity. It is **not** a count of missing tasks. Source builder footprints overlap, and target data may represent the same feature through different structures or 3D adaptations.

**Do not calculate a completion percentage by dividing 4,732 target JSON-backed exterior cells by 16,566 source runtime terrain cells.** Those counts have different scopes. The 16,566 includes the source base terrain pass; the 4,732 excludes regional GDScript features. Neither is a valid denominator/numerator pair.

## Source feature reconciliation

| Source feature family | Source spatial content | Target implementation evidence | Port status | Actual remaining map work |
|---|---|---|---|---|
| World base: `setupVillageScene` | Broad base terrain, biome and local-world setup | Deterministic regional terrain, local terrain provider, streamed chunk presentation | **Implemented as a system** | No cell-by-cell terrain backlog. Only add a named landform/biome feature if a specific source landmark is absent. |
| Roads and paths: `paintRoad`, `paintPath` | Named travel corridors and local paths | Source-derived strategic roads, local road traces and settlement approaches | **Substantially ported** | No requirement to reproduce every procedural wiggle. Add only a genuinely missing destination connection or road feature. |
| Water: `paintStreamSegment` | Silverhart heartland stream and source watercourse | Regional stream, Northwatch/Ridgehold waterway and chunk-owned water presentation | **Substantially ported** | No general water-cell backlog. A missing bridge, ford or named water connection is a discrete feature task. |
| Hollowmere: `setupVillageScene`, `buildHollowmereGuildDen` | Starting village, seven buildings, fields, bridge, stream, Guild Den | Authored settlement presentation, seven village floor maps, Guild Den floor map, roads, bridge, field/fence and physical props | **Substantially ported** | Add the remaining map-owned entrance/return contracts. Do not count guild dialogue, services or quest effects here. |
| Millbrook: `buildMillbrook` | House, road spur and interior | Source-positioned house, road spur and floor map with door/fireplace | **Ported spatial layout** | Exterior/interior entry and return contract only. |
| Emberlode: `buildEmberlode` | Foreman's hall, bunkhouse, mine surface and approaches | Buildings, floor maps, mine entrance, three-level mine registry, stairs, ledger and ore anchors | **Ported spatial layout** | Exterior-to-interior and mine-surface entry/return contracts. Mine interactions and creature behaviour are campaign work. |
| Reddale: `buildReddale` | Six town buildings, roads and eastern ruin site | Six building/floor definitions, three road approaches, source-positioned ruin and physical dressing | **Ported spatial layout** | Exterior/interior entry and return contracts. The spider actor and quest interactions are not map-port work. |
| Old Mac's Farmstead: `buildFarmstead` | Farmhouse, pasture polygon, six fence runs, broken fence and evidence | Farmhouse/floor, pasture, fence lines, road spur and source-positioned evidence | **Ported spatial layout** | Farmhouse entry/return contract. The wolf den is a separate site. Cows are an accepted visual substitute for sheep. |
| Goblin camp: `buildGoblinCamp` | Chief's hut, five huts, campfire and road endpoint | Source-authored huts, campfire and camp terrain | **Ported spatial layout** | No known authored-geometry backlog. Generic occupants/AI are outside this register. |
| Orc stronghold: `buildOrcStronghold` | Warlord hut, seven huts, campfire, perimeter, gate and approach | Source-authored huts, campfire, perimeter/gate terrain and road approach | **Ported spatial layout** | No known authored-geometry backlog. Do not reopen the site merely for visual QA. |
| Border forts: `buildNorthwatchFort`, `buildRidgeholdFort` | Star fort, keep, gates, walls, moat/waterway, siege props and hearths | Fort footprints, keeps, gates, waterway, siege props, ladders and hearths | **Ported spatial layout** | Only fix a specific missing physical feature or broken connection if one is demonstrated. |
| Deepholds: `buildDwarvenKingdom`, `revealSunkenDeepPassage` | Kragmoor mountain/settlement footprint, approach, entrance and multi-level Sunken Deep | Six floor maps, stair transitions, quest-gated passage, save/load state and deterministic Kragmoor relief profile | **Partial** | Complete the distinctive **surface** site: mountain/settlement silhouette, source landmarks, approach and entrance. The six floor maps do not substitute for the exterior kingdom footprint. |
| Sylvan Court: `buildElvenCapital` | Sil'thandriel tree-base, canopy, upper court and connecting structures | Three-level maps, platforms, trunk/branches, rope bridge and stair transitions | **Ported spatial layout** | No known missing major spatial feature. Population and services are excluded. |
| Silverhart: `buildSilverhartPalace`, `fortifySilverhartManor` | Palace, curtain/outer walls, watchtowers, ring roads, districts, embassies, cathedral, homes, Warrens and guild/vault | 40 buildings, 33 routes, 512 prop records; major city districts/walls; Grand Hall/gallery, barracks/loft, wizard tower stack and several merchant/palace interiors | **Substantially ported; some interior scope remains** | Reconcile the remaining source-named palace rooms/floors and any missing building entrance contracts. Do not treat the already registered city footprint or every source terrain cell as outstanding. |
| Chapterhouse and northern dungeon chain: `buildLichChapterhouse`, `buildAbandonedHouse`, `buildNecromancerCrypt`, `buildLichBarrow` | Chapterhouse, abandoned house, crypt rooms/corridors and barrow rooms | Source-authored floor maps, doors/apertures, fireplace, journal and altar/evidence anchors | **Ported spatial layouts** | Add missing map-owned entrance/return contracts where not already registered. Encounter and quest behaviour are excluded. |
| Thieves' Cove: `buildThievesCoveCaves`, `searchSecretPassage`, `revealSingleTunnelEntrance`, `revealTunnelEntrances`, `openTunnelJunction` | Three-level cave network, entrances, stairs, secret passages and tunnel junctions | Three-level cave network, three entrances, reciprocal stairs, evidence/journal anchors and tunnel-junction marker | **Ported spatial topology** | Only a missing passage/entrance/return coordinate is a map gap. Unlocking and quest-state behaviour belongs to campaign systems. |
| Wilderness sites: `buildDragonLair`, `buildVampireGrave`, `buildDruidGrove`, `spawnWildUnicorn` | Dragon outcrop/cave, grave/evidence, grove/spring/herbs and Unicorn Vale patrol geography | Chunk-owned lair/grave/grove dressing, physical evidence, vale centre, eight patrol waypoints and 24 hoofprint markers | **Ported spatial layouts** | No generic tree/rock backlog. Add only a specific missing named landmark or physical map object. |
| Mirabel's ruin: `buildSideQuestContent` | Rocky outcrop/spider ruin east of Reddale | Canonical named site anchor and chunk-owned collapsed-masonry dressing | **Ported spatial layout** | No map gap identified; spider encounter and quest state are separate. |
| Player cottage and field: `buildPlayerCottagePlot`, `buildPlayerCottage`, `upgradePlayerCottage`, `buyPlayerField`, `placeFieldFence`, `buyFieldLamb`, `plantAppleTree` | Cottage plot/building and upgrades; field boundary/fence and player-placed objects | Plot marker/approach, field/fence geometry and farmstead spatial foundations | **Partial — dynamic construction features** | Reconcile the buildable cottage/upgrade footprints and player-placed field objects as reusable spatial prefabs. The source does not define crop rows, so zero crop rows is not a gap. |
| Physical map objects: source tile-object placements across builders | Doors, stairs, ladders, journals, ledgers, evidence, altars, ore, siege objects, signs and other meaningful objects | Target has 520 prop records across 508 anchors, plus floor-local objects and feature-specific props | **Semantic reconciliation incomplete** | Match source *meaningful object types and placements* to target feature IDs. Do not compare raw counts: decorative props may be grouped, adapted or procedurally placed. |

## Genuine outstanding map work

These are the remaining content tasks. General engine verification and visual QA are deliberately excluded from this list.

1. **Kragmoor surface geography.** Finish the distinctive exterior mountain/settlement footprint, named surface landmarks, approach and entrance. Keep this separate from the already implemented six-floor dungeon runtime.
2. **Exterior/interior spatial contracts.** Complete the entrance/return register for the existing single-floor locations. The current audit records 71 location records / 89 floors, with 62 single-floor locations still lacking an explicit exterior threshold, destination, return anchor and/or documented exception. This is a finite interface backlog, not 62 new interiors.
3. **Silverhart interior remainder.** Reconcile the remaining source-named palace rooms/floors against the existing building and floor registries. Do not rebuild the 40 registered buildings or 33 routes.
4. **Dynamic cottage/field prefabs.** Represent the source's buildable cottage/upgrade footprints and player-placed field objects where the target does not already provide an equivalent reusable spatial prefab.
5. **Meaningful physical-object reconciliation.** Finish the semantic crosswalk for source doors, stairs, ladders, journals, ledgers, evidence, altars, ore, siege objects and signs. Decorative tree/rock/grass placement is not part of this task.

A specific broken road, stream, bridge, gate or chunk join should be added as a discrete defect when identified. A generic instruction to "verify connectivity" is not an outstanding port item.

## Explicitly not map-port backlog

- The 16,566 source terrain cells as individual placements.
- The difference between 16,566 source cells and 4,732 target JSON-backed cells.
- Random tree, bush, grass or rock distribution.
- Exact procedural road wiggles when route topology is retained.
- Crop rows that the source never authored.
- NPC placement/AI, dialogue, services, quests, encounters, faction simulation and persistence.
- Running the game in Godot or visually inspecting the result. Those are general QA gates for all work, not map-port content.

## Measurement

There is **no defensible overall percentage yet**, and this register intentionally does not manufacture one. Completion should be reported by the five remaining feature groups above, with each feature closed when its source spatial purpose has a corresponding target implementation. Source-cell counts remain diagnostic metadata only.
