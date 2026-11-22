# Campaign 2 whole-world port status

This register distinguishes the **world map** from the **playable authored content** at each location. A map marker or route endpoint is not evidence that its settlement, interiors, residents, quests or interactions have been ported.

## World-scale foundation already in the 3D project

The current Campaign 2 world foundation contains:

- The source-derived 16×16 strategic geography and faction/biome relationships.
- 24 named global axial location anchors and 22 connections.
- Source-derived road traces and a macro-world preview.
- A continuous local axial coordinate frame, deterministic regional terrain, chunk loading and a regional streamed preview.
- A canonical settlement definition registry and shared chunk presenter.

The surrounding wilderness is still partly generated from regional terrain rules. It is not yet a faithful, fully authored recreation of every source-world hex.

## Canonical settlement content

The registry on this branch contains six settlement definitions:

| Location | Migrated content | Still outstanding |
|---|---|---|
| Hollowmere | Seven authored buildings, routes, bridge, fields/crops/fences, props, actor placements, terrain and ecology inputs | Full visual/gameplay review; remaining source event, interior and persistence parity |
| Millbrook | One source-positioned house, road spur and two named NPC profiles/placements | Interior construction and services/interactions |
| Emberlode | Foreman's hall, bunkhouse, mine entrance, two road approaches and three named NPCs; source mine levels, stairs, ore, ledger and underground spiders retained as data | Playable interiors/floor transitions, ore interactions, spider spawning on floor -2, dialogue/quest consequences |
| Reddale | Guardhouse, reeve's house, inn, Ironbond guildhouse, manor and smithy; three road approaches and twelve named NPCs; interior/evidence/service metadata | Playable interiors, merchant services, evidence reading, bribes, dialogue and espionage quest consequences |
| Kragmoor | Source-positioned Gate Hall structure at (908,-608), south entrance at (908,-605), stone dwarven gate-hall archetype and ground-floor stair-down metadata | Full mountain interior, floors -1 to -5, corridors, stair transitions, king/guards/trader/runesmith/foreman, vermin and Sunken Deep quest gate |

The shared chunk presenter renders the exterior buildings and surface actors for these definitions. Interior metadata is preserved by the canonical adapter but is not yet a playable interior implementation. Kragmoor is currently a first structure slice: its surface Gate Hall is presented, while its descending Deepholds floors remain outstanding.

## Remaining source-authored world locations

These 20 additional location anchors exist in the world geography manifest. The farmstead now has a partial canonical surface definition and a separate source-backed wolf-den encounter-site record; 18 other sites still lack full canonical site definitions. Emberlode Mine is partially represented by its parent settlement's mine metadata but is not yet playable:

| Location | Source content still to port |
|---|---|
| Silverhart | Palace/capital layout, court, guards, services, population and kingdom interactions |
| Old Mac's Farmstead | Farmhouse, road spur, pasture polygon, broken west-fence gap, fallen rail clue, seven source-positioned blood-spatter marks and Old Mac's source NPC placement; hidden wolf-den anchor is registered separately | Sheep model/placements; evidence-visibility gating; visual den dressing; binding the new global den site to the correct quest/encounter lifecycle
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
| Emberwood Grove | Druid grove layout, inhabitants and quest interactions |
| Vampire Grave | Grave site, vampire encounter and related content |
| Thieves' Cove Caves | Cave network, guild residents, services and quest content |
| Old Mac's Wolf Den | Hidden site anchor at (-59,204) is derived from the canonical geography location and exposed through encounter-site lookup | Den presentation, encounter trigger and quest persistence remain outstanding |
| Unicorn Vale | Roaming encounter area and its eight-waypoint patrol loop |
| Emberlode Mine | Partial: its three-level floor, stair, ore, ledger and spider data are captured under Emberlode |

## Next port order

1. **Complete Old Mac's Farmstead and wolf den.** The farmhouse, pasture, broken fence, fallen rail, seven blood-trail marks, two generated sheep placeholders and Old Mac placement are in the canonical stream; the hidden den at (-59,204) is derived from the existing canonical geography record. Next replace the sheep placeholder with final art/animation, add sheep interaction, evidence-visibility gating and den dressing, then reconcile the opening-scene Old Mac identity/placement and complete quest persistence. The live farm-wolf quest now uses the source den coordinate (-59,204); preserve the source farmstead at (0,194).
2. **Silverhart capital.** This is the kingdom's main hub and unlocks the royal court, services and major faction threads.
3. **Northwatch, Ridgehold and the greenskin sites.** Port the connected border-road sequence, forts, strongholds, gates, garrisons and encounter state.
4. **Kragmoor and Sil'thandriel.** Preserve their distinct vertical/architectural structures and faction populations.
5. **Dungeons and wilderness sites.** Port interiors, encounter triggers, loot, patrols and quest consequences.
6. **World simulation and persistence.** Validate travel, schedules, caravans, faction changes, save/reload and chunk unload/reload across the full map.

## Current validation note

The first full validation attempt reached the new Campaign 2 settlement-layout test and exposed three GDScript type-inference parse errors in its test locals (`actors`, `expected_q` and `sheep`). Those declarations have been given explicit types in the current branch head. The validation workflow must be rerun against that new head; the previous run is not a green result.

## Acceptance rule

A location is not marked ported merely because its marker appears on the macro map. It needs source-traceable data, a 3D presentation, correctly placed actors, working traversal/interactions and automated parity tests for the source behaviours that matter. Visual inspection is an additional requirement, not a substitute for those tests.
