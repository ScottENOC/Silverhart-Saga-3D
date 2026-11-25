# Campaign 2 whole-world port status

This register distinguishes the **world map** from the **playable authored content** at each location. A map marker or route endpoint is not evidence that its settlement, interiors, residents, quests or interactions have been ported.

## World-scale foundation already in the 3D project

The current Campaign 2 world foundation contains:

- The source-derived 16×16 strategic geography and faction/biome relationships.
- 25 named global and local axial location anchors and 22 strategic connections.
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
| Hollowmere | Seven authored buildings, routes, bridge, fields/crops/fences, props, actor placements and terrain/ecology inputs; all seven source-authored starting-village interiors plus the Guild Den have registered floor maps. The source player-cottage plot spur (eight path cells) and 3D plot marker at (13,27) are now presented | Full visual/gameplay review, interior entry/exit wiring, Elder Locket item placement, guild contact, recruitment/services, remaining source events and persistence parity; cottage construction interaction remains campaign-owned |
| Millbrook | Source-positioned house, road spur and two named NPC profiles/placements; source-authored 3-by-3 house interior, east door and fireplace are registered and floor-tested | Visual review, exterior-to-interior entry/exit wiring and services/interactions |
| Emberlode | Foreman's hall and bunkhouse now have source-authored interior floor maps, source row shifts and walkable doors; mine entrance and two road approaches; source-authored three-floor mine stack with surface ledger, reciprocal stairs, gold and blue-gem ore nodes, and two Old Seam spider placement coordinates | Exterior-to-interior entry/exit wiring and visual review; creature spawning and ore interactions remain outside map scope |
| Reddale | Guardhouse, reeve's house, inn, Ironbond guildhouse, manor and smithy; all six source-authored interiors now have floor maps, correct building row shifts, walkable doors and their source fixtures/evidence; three road approaches and twelve town NPCs; Mirabel Quill placed at the source-authored rocky outcrop ruin to the east; the ruin is registered as a hidden canonical quest-site anchor | Spider defenders still need a 3D spider asset and actor-kind support; visual review, exterior-to-interior entry/exit wiring, merchant services, evidence reading, bribes, dialogue and espionage quest consequences |
| Mirabel's Spider Ruin | Source-derived radius-three rocky outcrop at (160,24), chunk-scoped rubble dressing and hidden canonical quest-site lookup; source defender positions (159,24) and (161,24) remain campaign-owned placements | Spider defender assets/actor support, Mirabel's dialogue, quest, loot and visual review |
| Kragmoor | Source-derived floors 0 to -5, validated walkable/wall HexMapData, generic 3D floor presentation, authored stair traversal, quest-journal gate bridge and campaign save/load state | Named Ara NPC/creature actors and behaviour, dialogue/trader/runesmith/mining/journal interactions, detailed dressing/lighting, and connection to campaign travel |
| Old Mac's Farmstead | **Accepted as complete for this milestone.** Source farmhouse exterior and road spur, pasture, fence/broken-fence clue, blood evidence and Old Mac placement are accepted; the farmhouse's source-authored 3-by-2 interior and east entrance are now registered and floor-tested; cows are an acceptable livestock substitute for source sheep. Reyna Fletcher is placed at source-derived position (6,198), relative to farmstead centre (0,194), and removed from Hollowmere's opening roster to prevent duplicate actors. | Visual review and farmhouse entry/exit wiring; Reyna's dialogue/recruitment state and persistent CharacterState integration still need runtime wiring; the wolf-den encounter remains a separate wilderness site |
| Skarn-tooth Camp | Source-authored chief's hut, five surrounding huts and central campfire at (203,23); reusable hut/campfire archetypes; source road endpoint retained | Visual scale/material review in Godot; actors, dialogue, faction and quest behaviour are outside map scope |
| Skarnak's Hold | Source-authored warlord hut, seven surrounding huts, central campfire, perimeter/gate terrain and road approach at (428,17); large-hut archetype | Visual scale/material review in Godot; guards, trader, troll and faction/quest behaviour are outside map scope |

The shared chunk presenter renders source-authored exterior buildings and map-owned physical props for canonical settlement definitions. The Silverhart Grand Hall/gallery, barracks/loft and wizard tower/study/observatory are registered as source-authored floor stacks in the shared multi-story runtime, with tested stair traversal; four merchant interiors (stables, general goods, clothier and magic shop), the Queen's private chambers, the Council Chamber, the Thieves' Guild/hidden vault, all seven Hollowmere starting-village interiors plus its Guild Den, and Millbrook's house are also registered as source-authored floor maps; Emberlode's foreman's hall and bunkhouse and Old Mac's farmhouse now have floor maps as well, and all six Reddale buildings have source-authored interior floor definitions. Most settlement interior entry/exit wiring, the guild's campaign interactions and remaining palace/settlement interiors remain outstanding. Other settlement interior metadata is still preserved as data rather than playable space. Kragmoor now has a generic source-driven floor runtime: it uses the canonical floor-map builder to create walkable cells and surrounding walls, presents all six levels, switches the active logical map at authored stairs, applies the What Nests Below quest gate, and stores current-floor/unlocked-stair state through the campaign snapshot adapter. A shared loader can instantiate Kragmoor, but campaign travel does not yet route the player into it. Emberlode Mine also has its source-authored surface, Working Vein and Old Seam floor maps, reciprocal stairs, ledger and ore nodes registered with the same builder; its exterior entry/exit wiring remains. NPC/creature actors and gameplay interactions are separate campaign work. Farmstead features are split across their owning chunks so fence segments are not duplicated at chunk boundaries.

## Remaining source-authored world locations

The 25-anchor geography manifest has six canonical settlement definitions above; Kragmoor and Emberlode Mine are additionally registered as separate multi-story sites. The following 19 other anchors have partial or no playable site implementations:

| Location | Source content still to port |
|---|---|
| Silverhart | Palace core and radius-23 curtain wall with seven watchtowers/two ladders; radius-30 and radius-45 ring roads; Merchant/Noble street grids; four embassies, Ironbond office, Grand Cathedral and diplomatic plaza; commons inn, market board, three outlying homes, six middle-ring houses, radius-60 outer city wall with three-cell gate/two watchtowers, three Warrens shacks, Thieves' Guild and hidden vault. 40 buildings, 33 routes, 512 props and 38 source-named NPC placements are registered for streamed presentation. The source Grand Hall/gallery, barracks/loft and three-level wizard tower are registered as playable runtime floor stacks with tested stair transitions and source prop/actor placement data. | Verify 3D rendering, actor spawn and outer-wall traversal in Godot; complete remaining palace rooms/floors, building entry/exit wiring, doors/reputation gates, NPC interactions, Thieves' Guild quest-state and hidden-vault interactions, schedules and kingdom/faction interactions |
| Skarn-tooth Camp | Source-authored exterior structures, road endpoint and campfire are ported; map presentation is complete pending in-engine visual review |
| Northwatch Fort | Star fort, keep, gate, source moat/waterway, siege engine, distant catapult, oil barrels, six ladder props and keep hearth are ported; visual review remains |
| Ridgehold Fort | Fort walls, keep, downstream waterway and keep hearth are ported; visual review remains |
| Skarnak's Hold | Source-authored exterior huts, warlord hut, campfire, perimeter terrain and road approach are ported; visual review remains |
| Kragmoor | Six floor maps/presentations, stair traversal, quest-gated Sunken Deep and floor-state save/load are implemented; campaign travel routing, named NPC/creature spawning, dialogue and location interactions remain |
| Sil'thandriel | Source-authored three-level tree-base/lower-canopy/upper-court maps, stair transitions, archive and healer platforms, rope bridge, trunk, branches and herb patches are registered in the shared runtime | Population/NPCs, services, faction interactions, visual review and final traversal review remain
| Hollowmere Guild Den | Source-authored 2-by-2 room, south entrance and walkable floor are registered and map-tested | Guild contact, recruitment, services and quest interactions; runtime entry/exit wiring |
| Abandoned House | Source-authored single-room wooden floor (half-width 3, half-height 2), west entrance, journal and phylactery altar positions are registered and map-tested; the two source-painted exterior Path cells between the north-road waypoint and west doorway receive chunk-scoped worn-earth presentation | Dormant skeleton actors/activation, journal/altar interactions, disciple/phylactery quest chain and runtime entry/exit wiring |
| Vessel-Seeker's Crypt | Source-authored three-room floor, connecting corridors and explicit one-cell wall-ring apertures are registered and map-tested; the entrance journal is included as a positioned physical map object |
| Barrow of Corvin Ashgrave | Source-authored antechamber and sanctum, connecting corridor and door openings are registered and map-tested |
| Ashveil's Dragon Lair | Source-authored radius-six rocky outcrop and radius-two open cave den now receive chunk-scoped rock dressing; dragon actor and encounter are campaign-owned |
| Lich Chapterhouse | Source-authored single-floor stone chapterhouse (4-by-3 room), east entrance and central fireplace are registered and map-tested; inquisitor and witch hunters remain campaign actors | Necromancer/lich faction content, encounter behaviour and chapterhouse runtime entry/exit wiring |
| Emberwood Grove | Terrain clearing, foliage perimeter, spring stone rim and both source herb-patch visuals are ported; inhabitants, gathering and quest behaviour are campaign-owned |
| Vampire Grave | Source-anchored disturbed grave, sheep carcass with throat punctures, shattered fang and physical journal are presented by the owning streamed chunk, and canonical site lookup resolves the source anchor; vampire actor/encounter, journal reading, investigation and quest state remain campaign-owned, with visual review and runtime interaction wiring outstanding
| Thieves' Cove Caves | Three-level source-authored cave network and reciprocal stairs; source journal in the Smugglers' Den, guild-cache evidence in the Hidden Vault and wilderness tunnel-junction marker are registered as physical map objects | Guild residents, services and quest content; visual review and runtime traversal/interaction wiring |
| Old Mac's Wolf Den | Source-derived anchor at (-59,204) and chunk-owned natural cave-mouth, rock overhang and scattered-bone dressing are implemented; no interior or wolves are invented by the map layer; encounter trigger, live wolf spawning and quest persistence remain campaign-owned, with visual review outstanding
| Unicorn Vale | Source-derived vale centre, eight patrol waypoints and all 24 directional hoofprint markers are represented in the streamed map; live unicorn actor, patrol AI and discovery behaviour remain campaign-owned, with visual review outstanding
| Emberlode Mine | Source-authored surface entrance, Working Vein (-1), Old Seam (-2), stairs, gold/blue-gem ore nodes, ledger and two spider spawn coordinates are registered with the shared multi-story floor builder; exterior entry/exit wiring remains |

## Authored-hex inventory snapshot

Generated by `tools/campaign2_authored_hex_audit.py` against the pinned original source checkout (Hex-crpg commit `4de96f16889d43cae91e03832c8eb1c1b4b00e42`). The CI calculation tests pass.

This is an inventory of **explicit geometry currently represented in the 3D project's data**, not a source-to-target coverage percentage. It deliberately excludes procedural terrain and generated wilderness. Source builder loops and helper-generated features still need a runtime extractor before we can calculate the complete original-source denominator.

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

The 11,294 feature-builder union is the best current source-side measure of explicitly built map geometry. It includes roads, stream, settlement footprints, fortifications, interiors, caves, dungeons and landmark terrain. It is **not** a target coverage percentage: builder sets overlap, and the target-side 4,732 exterior-cell inventory still excludes regional GDScript features and several map-owned site systems.

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

1. **Visual verification in Godot.** Review terrain elevation, river continuity, vegetation density, fort props, building scale/materials and chunk load/unload behaviour in the streamed regional world.
2. **Finish remaining physical settlement layouts.** Complete missing source-authored building footprints, roads, walls, gates, districts and landmark dressing, prioritising Silverhart and any remaining unregistered site architecture.
3. **Port remaining physical sites.** Add source-traceable terrain, structures and props for the unported dungeons, caves, crypts, graves and wilderness landmarks.
4. **Complete map-owned interiors.** Add floor geometry, doors, stairs and physical room objects where the source defines them; keep entry/exit interfaces compatible with the shared location runtime.
5. **Validate world-scale consistency.** Check strategic-to-regional anchors, road/water precedence, elevation continuity, chunk seams and deterministic streaming.

NPCs, dialogue, services, quests, combat and faction simulation are separate campaign work and are not acceptance criteria for this map port.

## Current validation note

The earlier terrain and settlement commits passed Godot 4.7.2 validation, but the reconciliation commits in this branch chain have new heads. Fresh full validation is required on those updated heads before the chain is considered green.

## Acceptance rule

A physical map location is not marked ported merely because its marker appears on the macro map. It needs source-traceable terrain/building/prop data, a 3D presentation, map-owned traversal where applicable, chunk-safe behaviour and automated parity tests. Visual inspection is also required. NPCs, dialogue, quests and other campaign interactions are deliberately outside this map acceptance rule.
