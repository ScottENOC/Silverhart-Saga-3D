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

The canonical settlement registry currently contains six definitions (including the first structural phase of Silverhart). Kragmoor is a source-authored regional site tracked in the separate multi-story location registry.

| Location | Migrated content | Still outstanding |
|---|---|---|
| Hollowmere | Seven authored buildings, routes, bridge, fields/crops/fences, props, actor placements, terrain and ecology inputs | Full visual/gameplay review; remaining source event, interior and persistence parity |
| Millbrook | One source-positioned house, road spur and two named NPC profiles/placements | Interior construction and services/interactions |
| Emberlode | Foreman's hall, bunkhouse, mine entrance, two road approaches and three named NPCs; source mine levels, stairs, ore, ledger and underground spiders retained as data | Playable interiors/floor transitions, ore interactions, spider spawning on floor -2, dialogue/quest consequences |
| Reddale | Guardhouse, reeve's house, inn, Ironbond guildhouse, manor and smithy; three road approaches and twelve town NPCs; Mirabel Quill placed at the source-authored rocky outcrop ruin to the east | Spider defenders still need a 3D spider asset and actor-kind support; playable interiors, merchant services, evidence reading, bribes, dialogue and espionage quest consequences |
| Kragmoor | Source-derived floors 0 to -5, validated walkable/wall HexMapData, generic 3D floor presentation, authored stair traversal, quest-journal gate bridge and campaign save/load state | Named Ara NPC/creature actors and behaviour, dialogue/trader/runesmith/mining/journal interactions, detailed dressing/lighting, and connection to campaign travel |
| Old Mac's Farmstead | **Accepted as complete for this milestone.** Source farmhouse, road spur, pasture, fence/broken-fence clue, blood evidence and Old Mac placement are accepted; cows are an acceptable livestock substitute for source sheep. | None for this milestone; the wolf-den encounter remains a separate wilderness site |

The shared chunk presenter renders exterior buildings and surface actors for canonical settlement definitions. The Silverhart Grand Hall/gallery, barracks/loft and wizard tower/study/observatory are registered as source-authored floor stacks in the shared multi-story runtime, with tested stair traversal. Council, Queen's chambers, Guild/vault interiors and all settlement interior entry/exit wiring remain outstanding. Other settlement interior metadata is still preserved as data rather than playable space. Kragmoor now has a generic source-driven floor runtime: it uses the canonical floor-map builder to create walkable cells and surrounding walls, presents all six levels, switches the active logical map at authored stairs, applies the What Nests Below quest gate, and stores current-floor/unlocked-stair state through the campaign snapshot adapter. A shared loader can instantiate the site, but campaign travel does not yet route the player into it; named NPC/creature actors and gameplay interactions remain. Farmstead features are split across their owning chunks so fence segments are not duplicated at chunk boundaries.

## Remaining source-authored world locations

The 24-anchor geography manifest has six canonical settlement definitions above; Kragmoor is additionally registered as a separate multi-story site. The following 18 other anchors have partial or no playable site implementations:

| Location | Source content still to port |
|---|---|
| Silverhart | Palace core and radius-23 curtain wall with seven watchtowers/two ladders; radius-30 and radius-45 ring roads; Merchant/Noble street grids; four embassies, Ironbond office, Grand Cathedral and diplomatic plaza; commons inn, market board, three outlying homes, six middle-ring houses, radius-60 outer city wall with three-cell gate/two watchtowers, three Warrens shacks, Thieves' Guild and hidden vault. 40 buildings, 33 routes, 513 props and 38 source-named NPC placements are registered for streamed presentation. The source Grand Hall/gallery, barracks/loft and three-level wizard tower are registered as playable runtime floor stacks with tested stair transitions and source prop/actor placement data. | Verify 3D rendering, actor spawn and outer-wall traversal in Godot; complete remaining palace rooms/floors, building entry/exit wiring, doors/reputation gates, NPC interactions, Thieves' Guild quest-state and hidden-vault interactions, schedules and kingdom/faction interactions |
| Skarn-tooth Camp | Goblin camp structures, chief, tribe roster, trade and negotiation/hostility branches |
| Northwatch Fort | Star fort, keep, gate, garrison, siege actors and border-war interactions; source moat and connected waterway terrain are ported |
| Ridgehold Fort | Fort and keep, patrols and faction consequences; source downstream waterway terrain is ported |
| Skarnak's Hold | Orc stronghold, huts, warlord, guards, trader and troll encounter |
| Kragmoor | Six floor maps/presentations, stair traversal, quest-gated Sunken Deep and floor-state save/load are implemented; campaign travel routing, named NPC/creature spawning, dialogue and location interactions remain |
| Sil'thandriel | Sylvan Court capital, vertical/forest architecture, population and faction interactions |
| Hollowmere Guild Den | Interior, guild contact, objects and recruitment/quest interactions |
| Abandoned House | Building, hidden content, disciple/phylactery quest chain |
| Vessel-Seeker's Crypt | Multi-room dungeon, ritual chamber, floors, actors and progression |
| Barrow of Corvin Ashgrave | Barrow rooms, undead encounters and linked quest content |
| Ashveil's Dragon Lair | Lair layout, dragon encounter, rewards and progression |
| Lich Chapterhouse | Chapterhouse layout, necromancer/lich faction content and encounters |
| Emberwood Grove | Terrain clearing, foliage perimeter and spring are ported; inhabitants, herb interactions, wolf trial, unicorn patrol/tracks and quest interactions remain |
| Vampire Grave | Grave site, vampire encounter and related content |
| Thieves' Cove Caves | Cave network, guild residents, services and quest content |
| Old Mac's Wolf Den | Canonical encounter-site anchor at (-59,204) is registered and the live farm-wolf quest uses that source coordinate; den dressing, trigger and quest persistence remain |
| Unicorn Vale | Roaming encounter area and its eight-waypoint patrol loop |
| Emberlode Mine | Partial: its three-level floor, stairs, ore, ledger and spider records are captured under Emberlode but not playable |

## Next port order

1. **Validate and refine the terrain foundation.** The source terrain rules, connected waterways, grove and major authored ground footprints are now ported; validate elevation shaping, vegetation density and visible material differentiation in the streamed 3D preview.
2. **Old Mac's Farmstead is accepted as complete for this milestone.** Cows are an acceptable livestock substitute for the source sheep; do not spend further time matching the animal species. The separate wolf-den encounter at (-59,204) remains a wilderness-site task.
3. **Finish Silverhart's playable capital interiors.** Extend the tested Grand Hall/gallery runtime to the barracks, council, wizard tower, Queen's chambers, Guild and vault, then connect doors, actors, services and faction/quest interactions.
4. **Northwatch, Ridgehold and the greenskin sites.** Port the connected border-road sequence, forts, strongholds, gates, garrisons and encounter state.
5. **Finish Kragmoor's gameplay content, then Sil'thandriel.** Add its named Ara actors, creatures, dialogue, trader/runeforge/mining/journal interactions and connect the site to campaign travel before expanding the elven capital.
6. **Dungeons and wilderness sites.** Port interiors, encounter triggers, loot, patrols and quest consequences.
7. **World simulation and persistence.** Validate travel, schedules, caravans, faction changes, save/reload and chunk unload/reload across the full map.

## Current validation note

The earlier terrain and settlement commits passed Godot 4.7.2 validation, but the reconciliation commits in this branch chain have new heads. Fresh full validation is required on those updated heads before the chain is considered green.

## Acceptance rule

A location is not marked ported merely because its marker appears on the macro map. It needs source-traceable data, a 3D presentation, correctly placed actors, working traversal/interactions and automated parity tests for the source behaviours that matter. Visual inspection is an additional requirement, not a substitute for those tests.
