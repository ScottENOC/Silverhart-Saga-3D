# Campaign 2 whole-world port status

This register distinguishes the **world map** from the **playable authored content** at each location. A map marker or route endpoint is not evidence that its settlement, interiors, residents, quests or interactions have been ported.

## World-scale foundation already in the 3D project

The current Campaign 2 world foundation contains:

- The source-derived 16×16 strategic geography and faction/biome relationships.
- 24 named global axial location anchors and 22 strategic connections.
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
| Hollowmere | Seven authored buildings, routes, bridge, fields/crops/fences, props, actor placements, terrain and ecology inputs | Full visual/gameplay review; remaining source event, interior and persistence parity |
| Millbrook | One source-positioned house, road spur and two named NPC profiles/placements | Interior construction and services/interactions |
| Emberlode | Foreman's hall, bunkhouse, mine entrance and two road approaches; source-authored three-floor mine stack with surface ledger, reciprocal stairs, gold and blue-gem ore nodes, and two Old Seam spider placement coordinates | Exterior-to-interior entry/exit wiring and visual review; creature spawning and ore interactions remain outside map scope |
| Reddale | Guardhouse, reeve's house, inn, Ironbond guildhouse, manor and smithy; three road approaches and twelve town NPCs; Mirabel Quill placed at the source-authored rocky outcrop ruin to the east | Spider defenders still need a 3D spider asset and actor-kind support; playable interiors, merchant services, evidence reading, bribes, dialogue and espionage quest consequences |
| Kragmoor | Source-derived floors 0 to -5, validated walkable/wall HexMapData, generic 3D floor presentation, authored stair traversal, quest-journal gate bridge and campaign save/load state | Named Ara NPC/creature actors and behaviour, dialogue/trader/runesmith/mining/journal interactions, detailed dressing/lighting, and connection to campaign travel |
| Old Mac's Farmstead | **Accepted as complete for this milestone.** Source farmhouse, road spur, pasture, fence/broken-fence clue, blood evidence and Old Mac placement are accepted; cows are an acceptable livestock substitute for source sheep. Reyna Fletcher is placed at source-derived position (6,198), relative to farmstead centre (0,194), and removed from Hollowmere's opening roster to prevent duplicate actors. | Reyna's dialogue/recruitment state and persistent CharacterState integration still need runtime wiring; the wolf-den encounter remains a separate wilderness site |
| Skarn-tooth Camp | Source-authored chief's hut, five surrounding huts and central campfire at (203,23); reusable hut/campfire archetypes; source road endpoint retained | Visual scale/material review in Godot; actors, dialogue, faction and quest behaviour are outside map scope |
| Skarnak's Hold | Source-authored warlord hut, seven surrounding huts, central campfire, perimeter/gate terrain and road approach at (428,17); large-hut archetype | Visual scale/material review in Godot; guards, trader, troll and faction/quest behaviour are outside map scope |

The shared chunk presenter renders source-authored exterior buildings and map-owned physical props for canonical settlement definitions. The Silverhart Grand Hall/gallery, barracks/loft and wizard tower/study/observatory are registered as source-authored floor stacks in the shared multi-story runtime, with tested stair traversal; four merchant interiors (stables, general goods, clothier and magic shop) are also registered. Council, Queen's chambers, Guild/vault interiors and most settlement interior entry/exit wiring remain outstanding. Other settlement interior metadata is still preserved as data rather than playable space. Kragmoor now has a generic source-driven floor runtime: it uses the canonical floor-map builder to create walkable cells and surrounding walls, presents all six levels, switches the active logical map at authored stairs, applies the What Nests Below quest gate, and stores current-floor/unlocked-stair state through the campaign snapshot adapter. A shared loader can instantiate Kragmoor, but campaign travel does not yet route the player into it. Emberlode Mine also has its source-authored surface, Working Vein and Old Seam floor maps, reciprocal stairs, ledger and ore nodes registered with the same builder; its exterior entry/exit wiring remains. NPC/creature actors and gameplay interactions are separate campaign work. Farmstead features are split across their owning chunks so fence segments are not duplicated at chunk boundaries.

## Remaining source-authored world locations

The 24-anchor geography manifest has six canonical settlement definitions above; Kragmoor and Emberlode Mine are additionally registered as separate multi-story sites. The following 18 other anchors have partial or no playable site implementations:

| Location | Source content still to port |
|---|---|
| Silverhart | Palace core and radius-23 curtain wall with seven watchtowers/two ladders; radius-30 and radius-45 ring roads; Merchant/Noble street grids; four embassies, Ironbond office, Grand Cathedral and diplomatic plaza; commons inn, market board, three outlying homes, six middle-ring houses, radius-60 outer city wall with three-cell gate/two watchtowers, three Warrens shacks, Thieves' Guild and hidden vault. 40 buildings, 33 routes, 513 props and 38 source-named NPC placements are registered for streamed presentation. The source Grand Hall/gallery, barracks/loft and three-level wizard tower are registered as playable runtime floor stacks with tested stair transitions and source prop/actor placement data. | Verify 3D rendering, actor spawn and outer-wall traversal in Godot; complete remaining palace rooms/floors, building entry/exit wiring, doors/reputation gates, NPC interactions, Thieves' Guild quest-state and hidden-vault interactions, schedules and kingdom/faction interactions |
| Skarn-tooth Camp | Source-authored exterior structures, road endpoint and campfire are ported; map presentation is complete pending in-engine visual review |
| Northwatch Fort | Star fort, keep, gate, source moat/waterway, siege engine, distant catapult, oil barrels, six ladder props and keep hearth are ported; visual review remains |
| Ridgehold Fort | Fort walls, keep, downstream waterway and keep hearth are ported; visual review remains |
| Skarnak's Hold | Source-authored exterior huts, warlord hut, campfire, perimeter terrain and road approach are ported; visual review remains |
| Kragmoor | Six floor maps/presentations, stair traversal, quest-gated Sunken Deep and floor-state save/load are implemented; campaign travel routing, named NPC/creature spawning, dialogue and location interactions remain |
| Sil'thandriel | Sylvan Court capital, vertical/forest architecture, population and faction interactions |
| Hollowmere Guild Den | Interior, guild contact, objects and recruitment/quest interactions |
| Abandoned House | Building, hidden content, disciple/phylactery quest chain |
| Vessel-Seeker's Crypt | Source-authored three-room floor, connecting corridors and explicit one-cell wall-ring apertures are registered and map-tested |
| Barrow of Corvin Ashgrave | Source-authored antechamber and sanctum, connecting corridor and door openings are registered and map-tested |
| Ashveil's Dragon Lair | Source-authored radius-six rocky outcrop and radius-two open cave den now receive chunk-scoped rock dressing; dragon actor and encounter are campaign-owned |
| Lich Chapterhouse | Source-authored single-floor stone chapterhouse (4-by-3 room), east entrance and central fireplace are registered and map-tested; inquisitor and witch hunters remain campaign actors | Necromancer/lich faction content, encounter behaviour and chapterhouse runtime entry/exit wiring |
| Emberwood Grove | Terrain clearing, foliage perimeter, spring stone rim and both source herb-patch visuals are ported; inhabitants, gathering and quest behaviour are campaign-owned |
| Vampire Grave | Grave site, vampire encounter and related content |
| Thieves' Cove Caves | Cave network, guild residents, services and quest content |
| Old Mac's Wolf Den | Canonical encounter-site anchor at (-59,204) is registered and the live farm-wolf quest uses that source coordinate; den dressing, trigger and quest persistence remain |
| Unicorn Vale | Source-derived eight-waypoint patrol route and all 24 distinct hoofprint track markers are presented in streamed chunks with exact-once ownership tests | Unicorn actor, roaming patrol simulation, Knowledge: Nature track discovery and dialogue remain campaign-owned |
| Emberlode Mine | Source-authored surface entrance, Working Vein (-1), Old Seam (-2), stairs, gold/blue-gem ore nodes, ledger and two spider spawn coordinates are registered with the shared multi-story floor builder; exterior entry/exit wiring remains |

## Next map port order

1. **Visual verification in Godot.** Review terrain elevation, river continuity, vegetation density, fort props, building scale/materials and chunk load/unload behaviour in the streamed regional world.
2. **Finish remaining physical settlement layouts.** Complete missing source-authored building footprints, roads, walls, gates, districts and landmark dressing, prioritising Silverhart and Sil'thandriel.
3. **Port remaining physical sites.** Add source-traceable terrain, structures and props for the unported dungeons, caves, crypts, graves and wilderness landmarks.
4. **Complete map-owned interiors.** Add floor geometry, doors, stairs and physical room objects where the source defines them; keep entry/exit interfaces compatible with the shared location runtime.
5. **Validate world-scale consistency.** Check strategic-to-regional anchors, road/water precedence, elevation continuity, chunk seams and deterministic streaming.

NPCs, dialogue, services, quests, combat and faction simulation are separate campaign work and are not acceptance criteria for this map port.

## Current validation note

The earlier terrain and settlement commits passed Godot 4.7.2 validation, but the reconciliation commits in this branch chain have new heads. Fresh full validation is required on those updated heads before the chain is considered green.

## Acceptance rule

A physical map location is not marked ported merely because its marker appears on the macro map. It needs source-traceable terrain/building/prop data, a 3D presentation, map-owned traversal where applicable, chunk-safe behaviour and automated parity tests. Visual inspection is also required. NPCs, dialogue, quests and other campaign interactions are deliberately outside this map acceptance rule.
