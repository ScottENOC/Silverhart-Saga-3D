# Campaign 2 whole-world port status

This register distinguishes the **world map** from the **playable authored content** at each location. For map-port backlog and source-to-target feature status, see [the feature-level map port register](campaign2_feature_port_register.md). A map marker or route endpoint is not evidence that its settlement or interiors have been ported.

## World-scale foundation already in the 3D project

The current Campaign 2 world foundation contains:

- The source-derived 16×16 strategic geography and faction/biome relationships.
- 25 named global axial location anchors and 22 strategic connections.
- Source-derived strategic road traces and a macro-world preview.
- A continuous local axial coordinate frame, deterministic regional terrain, chunk loading and a regional streamed preview.
- A canonical settlement definition registry and shared chunk presenter.
- Source local terrain noise, the Silverhart heartland stream, Northwatch/Ridgehold waterway and Emberwood Grove terrain are ported. The fort waterway includes a small continuity repair where the original source leaves a gap.
- Authored ground footprints for Skarn-tooth Camp, Skarnak's Hold, Ashveil's Dragon Lair, Sil'thandriel, Kragmoor, Northwatch, Ridgehold and the northern dungeon chain are represented in the regional terrain layer.

The surrounding wilderness is still partly generated from regional terrain rules. It is not yet a faithful, fully authored recreation of every source-world hex.

## Authored settlement and site content

The canonical settlement registry currently contains eight definitions (including Silverhart and the two source-authored greenskin settlements). Kragmoor and Emberlode Mine are source-authored regional sites tracked in the separate multi-story location registry.

| Location | Migrated content | Still outstanding |
|---|---|---|
| Hollowmere | Seven authored buildings, routes, bridge, fields/crops/fences, props, actor placements and terrain/ecology inputs; all seven source-authored starting-village interiors plus the Guild Den have registered floor maps. The source player-cottage plot spur (eight path cells) and 3D plot marker at (13,27) are now presented | Interior entry/exit wiring and Elder Locket physical placement; guild contact, recruitment/services, remaining source events and persistence parity are campaign-owned; cottage construction interaction remains campaign-owned |
| Millbrook | Source-positioned house, road spur and two named NPC profiles/placements; source-authored 3-by-3 house interior, east door and fireplace are registered and floor-tested | Exterior-to-interior entry/exit wiring; services/interactions are campaign-owned |
| Emberlode | Foreman's hall and bunkhouse now have source-authored interior floor maps, source row shifts and walkable doors; mine entrance and two road approaches; source-authored three-floor mine stack with surface ledger, reciprocal stairs, gold and blue-gem ore nodes, and two Old Seam spider placement coordinates | Exterior-to-interior entry/exit wiring; creature spawning and ore interactions remain outside map scope |
| Reddale | Guardhouse, reeve's house, inn, Ironbond guildhouse, manor and smithy; all six source-authored interiors now have floor maps, correct building row shifts, walkable doors and their source fixtures/evidence; three road approaches and twelve town NPCs; Mirabel Quill placed at the source-authored rocky outcrop ruin to the east; the ruin itself is now a named canonical quest-site POI at guildhouse + (14,-10), with chunk-owned collapsed-masonry dressing | Exterior-to-interior entry/exit wiring; spider actor, merchant services, evidence reading, bribes, dialogue and espionage quest consequences are campaign work |
| Kragmoor | Source-derived floors 0 to -5, validated walkable/wall HexMapData, generic 3D floor presentation, authored stair traversal, quest-journal gate bridge and campaign save/load state | Named Ara NPC/creature actors and behaviour, dialogue/trader/runesmith/mining/journal interactions, detailed dressing/lighting, and connection to campaign travel |
| Old Mac's Farmstead | **Accepted as complete for this milestone.** Source farmhouse exterior and road spur, pasture, fence/broken-fence clue, blood evidence and Old Mac placement are accepted; the farmhouse's source-authored 3-by-2 interior and east entrance are now registered and floor-tested; cows are an acceptable livestock substitute for source sheep. Reyna Fletcher is placed at source-derived position (6,198), relative to farmstead centre (0,194), and removed from Hollowmere's opening roster to prevent duplicate actors. | Farmhouse entry/exit wiring; Reyna's dialogue/recruitment state and persistent CharacterState integration are campaign work; the wolf-den encounter remains a separate wilderness site |
| Skarn-tooth Camp | Source-authored chief's hut, five surrounding huts and central campfire at (203,23); reusable hut/campfire archetypes; source road endpoint retained | No known authored-geometry gap; actors, dialogue, faction and quest behaviour are outside map scope |
| Skarnak's Hold | Source-authored warlord hut, seven surrounding huts, central campfire, perimeter/gate terrain and road approach at (428,17); large-hut archetype | Visual scale/material review in Godot; guards, trader, troll and faction/quest behaviour are outside map scope |

The shared chunk presenter renders source-authored exterior buildings and map-owned physical props for canonical settlement definitions. The Silverhart Grand Hall/gallery, barracks/loft and wizard tower/study/observatory are registered as source-authored floor stacks in the shared multi-story runtime, with tested stair traversal; four merchant interiors (stables, general goods, clothier and magic shop), the Queen's private chambers, the Council Chamber, the Thieves' Guild/hidden vault, all seven Hollowmere starting-village interiors plus its Guild Den, and Millbrook's house are also registered as source-authored floor maps; Emberlode's foreman's hall and bunkhouse and Old Mac's farmhouse now have floor maps as well, and all six Reddale buildings have source-authored interior floor definitions. Most settlement interior entry/exit wiring, the guild's campaign interactions and remaining palace/settlement interiors remain outstanding. Other settlement interior metadata is still preserved as data rather than playable space. Kragmoor now has a generic source-driven floor runtime: it uses the canonical floor-map builder to create walkable cells and surrounding walls, presents all six levels, switches the active logical map at authored stairs, applies the What Nests Below quest gate, and stores current-floor/unlocked-stair state through the campaign snapshot adapter. A shared loader can instantiate Kragmoor, but campaign travel does not yet route the player into it. Emberlode Mine also has its source-authored surface, Working Vein and Old Seam floor maps, reciprocal stairs, ledger and ore nodes registered with the same builder; its exterior entry/exit wiring remains. NPC/creature actors and gameplay interactions are separate campaign work. Farmstead features are split across their owning chunks so fence segments are not duplicated at chunk boundaries.

## Remaining source-authored world locations

The 25-anchor geography manifest has six canonical settlement definitions above; Kragmoor and Emberlode Mine are additionally registered as separate multi-story sites. The following 19 other anchors have partial or no playable site implementations:

| Location | Source content still to port |
|---|---|
| Silverhart | Palace core and radius-23 curtain wall with seven watchtowers/two ladders; radius-30 and radius-45 ring roads; Merchant/Noble street grids; four embassies, Ironbond office, Grand Cathedral and diplomatic plaza; commons inn, market board, six outlying homes, six middle-ring houses, radius-60 outer city wall with three-cell gate/two watchtowers, three Warrens shacks, Thieves' Guild and hidden vault. 40 buildings, 33 routes, 512 props and 38 source-named NPC placements are registered for streamed presentation. The source Grand Hall/gallery, barracks/loft and three-level wizard tower are registered as playable runtime floor stacks with tested stair transitions and source prop/actor placement data. | Complete remaining palace rooms/floors and map-owned entrance/return coordinates; actor spawning, NPC interactions, reputation logic, Thieves' Guild quest state, schedules and kingdom/faction interactions are campaign work |
| Skarn-tooth Camp | Source-authored exterior structures, road endpoint and campfire are ported; map presentation is complete; no known authored-geometry gap remains |
| Northwatch Fort | Star fort, keep, gate, source moat/waterway, siege engine, distant catapult, oil barrels, six ladder props and keep hearth are ported; visual review remains |
| Ridgehold Fort | Fort walls, keep, downstream waterway and keep hearth are ported; visual review remains |
| Skarnak's Hold | Source-authored exterior huts, warlord hut, campfire, perimeter terrain and road approach are ported; visual review remains |
| Kragmoor | Six floor maps/presentations, stair traversal, quest-gated Sunken Deep and floor-state save/load are implemented; campaign travel routing, named NPC/creature spawning, dialogue and location interactions remain |
| Sil'thandriel | Source-authored three-level tree-base/lower-canopy/upper-court maps, stair transitions, archive and healer platforms, rope bridge, trunk, branches and herb patches are registered in the shared runtime | Population/NPCs, services and faction interactions are campaign work; no distinct missing major spatial feature is currently identified
| Hollowmere Guild Den | Source-authored 2-by-2 room, south entrance and walkable floor are registered and map-tested | Guild contact, recruitment, services and quest interactions; runtime entry/exit wiring |
| Abandoned House | Source-authored single-room wooden floor (half-width 3, half-height 2), west entrance, journal and phylactery altar positions are registered and map-tested; the two source-painted exterior Path cells between the north-road waypoint and west doorway receive chunk-scoped worn-earth presentation | Dormant skeleton actors/activation, journal/altar interactions, disciple/phylactery quest chain and runtime entry/exit wiring |
| Vessel-Seeker's Crypt | Source-authored three-room floor, connecting corridors and explicit one-cell wall-ring apertures are registered and map-tested; the entrance journal is included as a positioned physical map object |
| Barrow of Corvin Ashgrave | Source-authored antechamber and sanctum, connecting corridor and door openings are registered and map-tested |
| Ashveil's Dragon Lair | Source-authored radius-six rocky outcrop and radius-two open cave den now receive chunk-scoped rock dressing; dragon actor and encounter are campaign-owned |
| Lich Chapterhouse | Source-authored single-floor stone chapterhouse (4-by-3 room), east entrance and central fireplace are registered and map-tested; inquisitor and witch hunters remain campaign actors | Necromancer/lich faction content, encounter behaviour and chapterhouse runtime entry/exit wiring |
| Emberwood Grove | Terrain clearing, foliage perimeter, spring stone rim and both source herb-patch visuals are ported; inhabitants, gathering and quest behaviour are campaign-owned |
| Vampire Grave | Source-anchored disturbed grave, sheep carcass with throat punctures, shattered fang and physical journal are presented by the owning streamed chunk, and canonical site lookup resolves the source anchor; vampire actor/encounter, journal reading, investigation and quest state remain campaign-owned; only map-owned entrance/return wiring is in scope
| Thieves' Cove Caves | Three-level source-authored cave network with all three cave entrances resolved through the canonical `cave_network` encounter-site registry; reciprocal stairs; source journal in the Smugglers' Den, guild-cache evidence in the Hidden Vault and wilderness tunnel-junction marker are registered as physical map objects | Guild residents, services and quest content are campaign-owned; map-owned entrance/return wiring remains |
| Old Mac's Wolf Den | Source-derived anchor at (-59,204) and chunk-owned natural cave-mouth, rock overhang and scattered-bone dressing are implemented; no interior or wolves are invented by the map layer; encounter trigger, live wolf spawning and quest persistence remain campaign-owned
| Unicorn Vale | Source-derived vale centre, eight patrol waypoints and all 24 directional hoofprint markers are represented in the streamed map; live unicorn actor, patrol AI and discovery behaviour remain campaign-owned
| Emberlode Mine | Source-authored surface entrance, Working Vein (-1), Old Seam (-2), stairs, gold/blue-gem ore nodes, ledger and two spider spawn coordinates are registered with the shared multi-story floor builder; exterior entry/exit wiring remains |

## Authored-hex inventory snapshot

Generated by `tools/campaign2_authored_hex_audit.py` against the pinned original source checkout (Hex-crpg commit `4de96f16889d43cae91e03832c8eb1c1b4b00e42`). The CI calculation tests pass.

This is a diagnostic inventory of explicit JSON-backed geometry, **not a source-to-target coverage percentage**. It deliberately excludes regional GDScript features and generated wilderness. The source runtime extractor now resolves the original builder writes, but its terrain-cell totals are still not comparable to this target-side inventory. Use [the feature-level port register](campaign2_feature_port_register.md) for actual remaining work. Do not divide these totals to produce a completion percentage.

| Geometry | Unique hexes / records |
|---|---:|
| Strategic 16×16 grid | 256 cells |
| Strategic roads | 1,633 unique local hexes |
| Settlement building footprints | 2,013 unique local hexes |
| Settlement paths | 717 unique local hexes |
| Map prop anchors | 508 unique local hexes (520 prop records) |
| Field footprints | 63 unique local hexes |
| Fence lines | 22 unique local hexes |
| Crop rows | 0 currently registered |
| **Local exterior authored geometry** | **4,732 unique local hexes after overlap removal** |
| Interior room footprints | 1,543 walkable cells across the registered floor maps (recalculated using the actual Godot floor-builder bounds and row-shift rules) |
| Building records | 67 |
| Settlement path records | 40 |

Per-settlement exterior inventory:

| Settlement | Buildings | Building cells | Path cells | Prop records | Field cells | Fence cells | Unique exterior cells |
|---|---:|---:|---:|---:|---:|---:|---:|
| Millbrook | 1 | 49 | 2 | 0 | 0 | 0 | 51 |
| Emberlode | 3 | 105 | 6 | 0 | 0 | 0 | 111 |
| Reddale | 6 | 201 | 13 | 0 | 0 | 0 | 210 |
| Old Mac's Farmstead | 1 | 35 | 2 | 8 | 63 | 22 | 102 |
| Silverhart | 40 | 1,559 | 694 | 513 | 0 | 0 | 2,625 |
| Skarn-tooth Camp | 7 | 55 | 0 | 0 | 0 | 0 | 55 |
| Skarnak's Hold | 9 | 9 | 0 | 0 | 0 | 0 | 9 |

These category counts overlap; only the 4,732 union is a non-duplicated local exterior total. The 256 strategic cells and 2,915 interior cells are separate scales and are not added to it. Regional authored GDScript features (for example, fort and wilderness terrain/props) are not yet included in this JSON-backed inventory.

## Original source runtime geometry baseline

The pinned original `Hex-crpg/campaign2World.js` scene builder has now been executed headlessly in CI. Its runtime output is captured with the calling source builder attributed to each terrain write. This distinguishes the broad `setupVillageScene` base pass from named feature builders and prevents source-code line counts from being mistaken for hex counts.

| Source runtime measure | Count |
|---|---:|
| Unique terrain cells in the resolved source scene | 16,566 |
| Cells touched only by the broad `setupVillageScene` base pass | 5,242 |
| Cells touched by named feature builders other than the base pass, deduplicated across builders | 11,324 |
| Base-pass / feature-builder overlap | 326 |
| Physical tile-object placements | 246 |
| Interior regions | 72 |
| Multi-storey building definitions | 9 |
| Wild-unicorn patrol waypoints | 8 |

The feature-builder union is useful for source-side footprint diagnostics. It includes roads, stream, settlement footprints, fortifications, interiors, caves, dungeons and landmark terrain. It is **not** a target coverage percentage: builder sets overlap, and the target-side 4,732 exterior-cell inventory excludes regional GDScript features and several map-owned site systems. The feature-level register, not these counts, defines the backlog.

Source terrain cells touched by each owner builder (these figures overlap and must not be summed):

| Source builder | Unique cells touched |
|---|---:|
| Silverhart Palace | 2,584 |
| Dwarven Kingdom / Kragmoor | 1,959 |
| Road painter | 1,633 |
| Northwatch Fort | 1,217 |
| Ridgehold Fort | 937 |
| Stream painter | 902 |
| Elven Capital / Sil'thandriel | 702 |
| Orc Stronghold / Skarnak's Hold | 238 |
| Reddale | 222 |
| Necromancer Crypt | 143 |
| Goblin Camp / Skarn-tooth | 127 |
| Dragon Lair | 127 |
| Emberlode | 115 |
| Lich Barrow | 109 |
| Druid Grove / Emberwood | 91 |
| Path painter | 65 |
| Lich Chapterhouse | 61 |
| Millbrook | 49 |
| Thieves' Cove Caves | 47 |
| Old Mac's Farmstead | 39 |
| Side-quest site geometry (Mirabel's spider ruin) | 37 |
| Abandoned House | 35 |
| Hollowmere Guild Den | 25 |
| Player Cottage Plot | 8 |

The audit now applies the actual `Campaign2MultiStoryFloorMapBuilder` room bounds and `source_building` row-shift convention. The previous interior count of 2,915 was an overcount from treating half-width/half-height as inclusive extents; the corrected walkable-room footprint count is 1,543. The test suite now locks in the correct builder semantics.

## Next map port order

Use [the feature-level port register](campaign2_feature_port_register.md) as the source of truth. The actual remaining work is Kragmoor's surface footprint, missing exterior/interior spatial contracts, remaining Silverhart palace rooms/floors, dynamic cottage/field prefabs where absent, and semantic reconciliation of meaningful physical map objects. Generic terrain fill, vegetation/rock distribution, routine engine verification and visual QA are not separate port tasks.

NPCs, dialogue, services, quests, combat and faction simulation are separate campaign work and are not acceptance criteria for this map port.

## Current validation note

Godot validation and in-engine inspection remain QA gates for all changes. They are not counted as missing map content or included in the map-port backlog.

## Acceptance rule

A physical map location is not marked ported merely because its marker appears on the macro map. It needs source-traceable terrain/building/prop data, a corresponding 3D spatial implementation and map-owned traversal coordinates where applicable. Godot tests and visual inspection remain general QA, not map-port backlog items. NPCs, dialogue, quests and other campaign interactions are deliberately outside this map acceptance rule.
