# Campaign 2 whole-world port status

This register distinguishes the **world map** from the **playable authored content** at each location. A map marker or route endpoint is not evidence that its settlement, interiors, residents, quests or interactions have been ported.

## World-scale foundation already in the 3D project

The current Campaign 2 world foundation contains:

- The source-derived 16×16 strategic geography and faction/biome relationships.
- 24 named global axial location anchors and 22 strategic connections.
- Source-derived strategic road traces and a macro-world preview.
- A continuous local axial coordinate frame, deterministic regional terrain, chunk loading and a regional streamed preview.
- A canonical settlement definition registry and shared chunk presenter.
- Source local terrain noise and the Silverhart heartland stream are being ported in follow-on PR #203; these are not yet part of this branch.

The surrounding wilderness is still partly generated from regional terrain rules. It is not yet a faithful, fully authored recreation of every source-world hex.

## Canonical settlement content

The registry on this branch contains five settlement definitions:

| Location | Migrated content | Still outstanding |
|---|---|---|
| Hollowmere | Seven authored buildings, routes, bridge, fields/crops/fences, props, actor placements, terrain and ecology inputs | Full visual/gameplay review; remaining source event, interior and persistence parity |
| Millbrook | One source-positioned house, road spur and two named NPC profiles/placements | Interior construction and services/interactions |
| Emberlode | Foreman's hall, bunkhouse, mine entrance, two road approaches and three named NPCs; source mine levels, stairs, ore, ledger and underground spiders retained as data | Playable interiors/floor transitions, ore interactions, spider spawning on floor -2, dialogue/quest consequences |
| Reddale | Guardhouse, reeve's house, inn, Ironbond guildhouse, manor and smithy; three road approaches and twelve named NPCs; interior/evidence/service metadata | Playable interiors, merchant services, evidence reading, bribes, dialogue and espionage quest consequences |
| Old Mac's Farmstead | Source farmhouse and road spur; pasture polygon, six fence segments and broken-fence clue; seven blood-spatter marks; Old Mac placement; two generated sheep placeholders | Final sheep art/animation, sheep interaction, Nature-gated faint evidence, den dressing/trigger/persistence and reconciliation of the opening-scene Old Mac identity |

The shared chunk presenter renders exterior buildings and surface actors for these definitions. Interior metadata is preserved by the canonical adapter but is not yet a playable interior implementation. Farmstead features are split across their owning chunks so fence segments are not duplicated at chunk boundaries.

## Remaining source-authored world locations

The 24-anchor geography manifest has five canonical settlement definitions above. The following 19 other anchors have partial or no playable site implementations:

| Location | Source content still to port |
|---|---|
| Silverhart | Palace/capital layout, court, guards, services, population and kingdom interactions |
| Skarn-tooth Camp | Goblin camp structures, chief, tribe roster, trade and negotiation/hostility branches |
| Northwatch Fort | Star fort, keep, gate, moat, garrison, siege actors and border-war interactions |
| Ridgehold Fort | Fort and keep, river connection, patrols and faction consequences |
| Skarnak's Hold | Orc stronghold, huts, warlord, guards, trader and troll encounter |
| Kragmoor | Deepholds mountain city, excavated rooms/tunnels, vertical layers, population and mine |
| Sil'thandriel | Sylvan Court capital, vertical/forest architecture, population and faction interactions |
| Hollowmere Guild Den | Interior, guild contact, objects and recruitment/quest interactions |
| Abandoned House | Building, hidden content, disciple/phylactery quest chain |
| Vessel-Seeker's Crypt | Multi-room dungeon, ritual chamber, floors, actors and progression |
| Barrow of Corvin Ashgrave | Barrow rooms, undead encounters and linked quest content |
| Ashveil's Dragon Lair | Lair layout, dragon encounter, rewards and progression |
| Lich Chapterhouse | Chapterhouse layout, necromancer/lich faction content and encounters |
| Emberwood Grove | Terrain clearing, foliage perimeter and spring are in follow-on PR #203; inhabitants, herb interactions, wolf trial, unicorn patrol/tracks and quest interactions remain |
| Vampire Grave | Grave site, vampire encounter and related content |
| Thieves' Cove Caves | Cave network, guild residents, services and quest content |
| Old Mac's Wolf Den | Canonical encounter-site anchor at (-59,204) is registered and the live farm-wolf quest uses that source coordinate; den dressing, trigger and quest persistence remain |
| Unicorn Vale | Roaming encounter area and its eight-waypoint patrol loop |
| Emberlode Mine | Partial: its three-level floor, stairs, ore, ledger and spider records are captured under Emberlode but not playable |

## Next port order

1. **Complete the terrain foundation.** Finish the source-authored local terrain, connected stream/moat network, grove and major fort/landmark footprints; then validate elevation, vegetation and visible material differentiation in the streamed 3D preview.
2. **Finish Old Mac's Farmstead and wolf den.** Replace the sheep placeholder with final art/animation, add sheep interaction, Nature-gated evidence visibility, den dressing and quest persistence; reconcile the opening-scene Old Mac identity/placement. Preserve the source farmstead at (0,194) and wolf den at (-59,204).
3. **Silverhart capital.** This is the kingdom's main hub and unlocks the royal court, services and major faction threads.
4. **Northwatch, Ridgehold and the greenskin sites.** Port the connected border-road sequence, forts, strongholds, gates, garrisons and encounter state.
5. **Kragmoor and Sil'thandriel.** Preserve their distinct vertical/architectural structures and faction populations.
6. **Dungeons and wilderness sites.** Port interiors, encounter triggers, loot, patrols and quest consequences.
7. **World simulation and persistence.** Validate travel, schedules, caravans, faction changes, save/reload and chunk unload/reload across the full map.

## Current validation note

The current branch head passed the full Godot 4.7.2 headless validation workflow, including the canonical settlement builder and its farmstead chunk/model lifecycle assertions. The visual-preview workflow also passed on the preceding branch commit; a run against the latest head was completing its final post-check step at the time this note was written.

## Acceptance rule

A location is not marked ported merely because its marker appears on the macro map. It needs source-traceable data, a 3D presentation, correctly placed actors, working traversal/interactions and automated parity tests for the source behaviours that matter. Visual inspection is an additional requirement, not a substitute for those tests.
